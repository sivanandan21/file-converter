import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_format_converter/services/conversion_services.dart';
import 'package:file_format_converter/services/file_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class _TempStorageService extends FileStorageService {
  _TempStorageService(this.directory);

  final Directory directory;

  @override
  Future<Directory> get outputDirectory async => directory;
}

class _FakeOcrEngine implements OcrEngine {
  _FakeOcrEngine(this.text);

  final String text;

  @override
  Future<String> recognizeText(String imagePath) async => text;

  @override
  Future<void> close() async {}
}

const _wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
const _rNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main';

/// Builds a minimal DOCX. [visible] paragraphs are normal text, [hidden]
/// paragraphs use `w:vanish`, and [withImage] adds one embedded PNG.
Uint8List _docxBytes({
  List<String> visible = const [],
  List<String> hidden = const [],
  bool withImage = false,
}) {
  final archive = Archive();
  String run(String text, {bool vanish = false}) =>
      '<w:r>${vanish ? '<w:rPr><w:vanish/></w:rPr>' : ''}<w:t>$text</w:t></w:r>';
  final body = StringBuffer();
  for (final text in visible) {
    body.write('<w:p>${run(text)}</w:p>');
  }
  for (final text in hidden) {
    body.write('<w:p>${run(text, vanish: true)}</w:p>');
  }
  if (withImage) {
    body.write('<w:p><w:r><w:drawing><a:blip r:embed="rId9"/></w:drawing></w:r></w:p>');
  }
  archive.add(ArchiveFile.string('word/document.xml',
      '<?xml version="1.0" encoding="UTF-8"?><w:document xmlns:w="$_wNs" xmlns:r="$_rNs" xmlns:a="$_aNs"><w:body>$body<w:sectPr><w:pgSz w:w="12240" w:h="15840"/></w:sectPr></w:body></w:document>'));
  archive.add(ArchiveFile.string('word/_rels/document.xml.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId9" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/logo.png"/></Relationships>'));
  if (withImage) {
    final image = img.Image(width: 30, height: 30);
    img.fill(image, color: img.ColorRgb8(200, 30, 30));
    archive.add(ArchiveFile.bytes('word/media/logo.png', img.encodePng(image)));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

String _pdfText(List<int> bytes) {
  final document = sf.PdfDocument(inputBytes: bytes);
  try {
    return sf.PdfTextExtractor(document)
        .extractText()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  } finally {
    document.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FileStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('converter_quality_');
    storage = _TempStorageService(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  group('postProcessOcrText', () {
    test('never deletes legitimate symbols, bullets or table pipes', () {
      const input = 'Tom & Jerry \u2022 50% | Total = \$5 + 3 * 2 @ home';
      expect(postProcessOcrText(input), input);
    });

    test('fixes ligatures and a pipe misread as capital I', () {
      expect(postProcessOcrText('\uFB01nal'), 'final');
      expect(postProcessOcrText('|nternational law'), 'International law');
    });

    test('removes stray space before punctuation on the same line only', () {
      expect(postProcessOcrText('Hello , world .'), 'Hello, world.');
      expect(postProcessOcrText('line one\n.NET stays'), 'line one\n.NET stays');
    });

    test('rejoins hyphenated words but keeps capitalised continuations', () {
      expect(postProcessOcrText('inter-\nnational'), 'international');
      expect(postProcessOcrText('Mary-\nAnn'), 'Mary-\nAnn');
    });

    test('drops isolated speck glyphs', () {
      expect(postProcessOcrText('one ~ two'), 'one  two');
    });
  });

  group('preprocessOcrImageBytes', () {
    test('keeps dark ink black and uneven background white', () {
      // Horizontal lighting gradient (150..250) with one darker vertical bar.
      final image = img.Image(width: 200, height: 200);
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          var v = 150 + (x * 100 ~/ 199);
          if (x >= 90 && x <= 94 && y >= 50 && y <= 150) v -= 70;
          image.setPixelRgb(x, y, v, v, v);
        }
      }

      final out = preprocessOcrImageBytes(Uint8List.fromList(img.encodePng(image)));
      expect(out, isNotNull);
      final result = img.decodePng(out!)!;

      expect(result.getPixel(92, 100).r, 0, reason: 'ink must be black');
      expect(result.getPixel(30, 100).r, 255, reason: 'dark side is background');
      expect(result.getPixel(170, 100).r, 255, reason: 'bright side is background');
      expect(result.getPixel(1, 1).r, 255, reason: 'border is cleared');
    });

    test('returns null for data that is not an image', () {
      expect(preprocessOcrImageBytes(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });

  group('sanitizeForPdfText', () {
    test('maps smart punctuation to ASCII for the Helvetica fallback', () {
      expect(
        sanitizeForPdfText('\u201CHi\u201D \u2013 it\u2019s \u2022 ok\u2026', unicode: false),
        '"Hi" - it\'s * ok...',
      );
    });

    test('replaces glyphs outside Latin-1 and keeps accents', () {
      final out = sanitizeForPdfText('Caf\u00E9 \u4E2D', unicode: false);
      expect(out, 'Caf\u00E9 ?');
    });

    test('keeps unicode intact but expands tabs when fonts support it', () {
      expect(sanitizeForPdfText('a\tb \u201Cq\u201D', unicode: true),
          'a    b \u201Cq\u201D');
    });
  });

  group('ImageToPdfService', () {
    test('embeds JPEGs without recompression and uses landscape pages',
        () async {
      final image = img.Image(width: 80, height: 40);
      img.fill(image, color: img.ColorRgb8(10, 120, 200));
      final source = File('${tempDir.path}/wide.jpg');
      await source.writeAsBytes(img.encodeJpg(image, quality: 90));

      final output = await ImageToPdfService(storage).convert([source.path]);
      final bytes = await File(output).readAsBytes();

      expect(latin1.decode(bytes), contains('/DCTDecode'));
      final document = sf.PdfDocument(inputBytes: bytes);
      try {
        final size = document.pages[0].size;
        expect(size.width, greaterThan(size.height));
      } finally {
        document.dispose();
      }
    });

    test('reports unreadable images with a clear message', () async {
      final bad = File('${tempDir.path}/broken.png');
      await bad.writeAsBytes([1, 2, 3, 4, 5]);

      expect(
        () => ImageToPdfService(storage).convert([bad.path]),
        throwsA(isA<ConversionException>().having(
            (e) => e.message, 'message', contains('Unsupported or corrupted'))),
      );
    });
  });

  group('DocxToPdfService', () {
    test('keeps document text when the DOCX also contains an image', () async {
      final docx = File('${tempDir.path}/report.docx');
      await docx.writeAsBytes(
          _docxBytes(visible: ['Quarterly report body text'], withImage: true));

      final output = await DocxToPdfService(storage).convert(docx.path);
      final bytes = await File(output).readAsBytes();

      expect(_pdfText(bytes), contains('Quarterly report body text'));
    });

    test('does not invent a title from the file name', () async {
      final docx = File('${tempDir.path}/MySecretFileName.docx');
      await docx.writeAsBytes(_docxBytes(visible: ['Only this paragraph']));

      final output = await DocxToPdfService(storage).convert(docx.path);
      final text = _pdfText(await File(output).readAsBytes());

      expect(text, contains('Only this paragraph'));
      expect(text, isNot(contains('MySecretFileName')));
    });

    test('renders accented and typographic characters', () async {
      final docx = File('${tempDir.path}/unicode.docx');
      await docx.writeAsBytes(
          _docxBytes(visible: ['Caf\u00E9 \u201Cquoted\u201D \u2022 na\u00EFve']));

      final output = await DocxToPdfService(storage).convert(docx.path);
      final text = _pdfText(await File(output).readAsBytes());

      expect(text, contains('Caf\u00E9'));
      expect(text, contains('na\u00EFve'));
    });

    test('image-only DOCX with hidden text becomes image pages', () async {
      final docx = File('${tempDir.path}/scan.docx');
      await docx.writeAsBytes(
          _docxBytes(hidden: ['searchable hidden text'], withImage: true));

      final output = await DocxToPdfService(storage).convert(docx.path);
      final bytes = await File(output).readAsBytes();

      // Hidden text must not leak into the visible PDF text layer.
      expect(_pdfText(bytes), isNot(contains('searchable hidden text')));
    });

    test('rejects files that are not valid DOCX archives', () async {
      final bad = File('${tempDir.path}/fake.docx');
      await bad.writeAsBytes([0, 1, 2, 3, 4, 5, 6, 7]);

      expect(
        () => DocxToPdfService(storage).convert(bad.path),
        throwsA(isA<ConversionException>()),
      );
    });
  });

  group('PdfToDocxService', () {
    Future<List<PdfPageSnapshot>> visualFactory(
      String pdfPath,
      double dpi,
      PdfToDocxProgress? onProgress,
    ) async {
      final page = img.Image(width: 40, height: 50);
      img.fill(page, color: img.ColorRgb8(255, 255, 255));
      return [
        PdfPageSnapshot(
          pageNumber: 1,
          bytes: Uint8List.fromList(img.encodePng(page)),
          pixelWidth: 40,
          pixelHeight: 50,
          widthPoints: 612,
          heightPoints: 792,
        ),
      ];
    }

    test('graphic-only PDF falls back to page images, not placeholder text',
        () async {
      final pdf = pw.Document()
        ..addPage(pw.Page(build: (_) => pw.SizedBox(width: 1, height: 1)));
      final source = File('${tempDir.path}/diagram.pdf');
      await source.writeAsBytes(await pdf.save());

      final output = await PdfToDocxService(
        storage,
        ocrEngineFactory: () => _FakeOcrEngine(''),
        visualPageFactory: visualFactory,
        ocrPageImageFactory: (pdfPath, pageNumber, dir, dpi) async {
          final file = File('${dir.path}/p$pageNumber.png');
          await file.writeAsBytes([137, 80, 78, 71], flush: true);
          return file.path;
        },
      ).convert(source.path);

      final archive = ZipDecoder().decodeBytes(await File(output).readAsBytes());
      final xml = utf8.decode(archive.findFile('word/document.xml')!.content);
      expect(xml, contains('w:drawing'));
      expect(xml, isNot(contains('no readable text')));
      expect(archive.findFile('word/media/page_1.png'), isNotNull);
    });

    test('text PDF never renders visual pages (lazy fallback)', () async {
      final pdf = pw.Document()
        ..addPage(pw.Page(build: (_) => pw.Text('Plenty of selectable text here')));
      final source = File('${tempDir.path}/text.pdf');
      await source.writeAsBytes(await pdf.save());

      var visualCalls = 0;
      await PdfToDocxService(
        storage,
        visualPageFactory: (pdfPath, dpi, onProgress) async {
          visualCalls++;
          return visualFactory(pdfPath, dpi, onProgress);
        },
      ).convert(source.path);

      expect(visualCalls, 0);
    });

    test('corrupted PDF gives a friendly error', () async {
      final bad = File('${tempDir.path}/bad.pdf');
      await bad.writeAsBytes([1, 2, 3, 4, 5, 6]);

      expect(
        () => PdfToDocxService(storage).convert(bad.path),
        throwsA(isA<ConversionException>()),
      );
    });
  });
}

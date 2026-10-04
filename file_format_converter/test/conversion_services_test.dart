import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_format_converter/services/conversion_services.dart';
import 'package:file_format_converter/services/file_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;

class _TempStorageService extends FileStorageService {
  _TempStorageService(this.directory);

  final Directory directory;

  @override
  Future<Directory> get outputDirectory async => directory;
}

class _FakeOcrEngine implements OcrEngine {
  _FakeOcrEngine(this.text);

  final String text;
  bool closed = false;

  @override
  Future<String> recognizeText(String imagePath) async => text;

  @override
  Future<void> close() async {
    closed = true;
  }
}

void main() {
  late Directory tempDir;
  late FileStorageService storage;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('converter_test_');
    storage = _TempStorageService(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('image to PDF writes a readable PDF from PNG input', () async {
    final image = img.Image(width: 20, height: 20);
    img.fill(image, color: img.ColorRgb8(75, 107, 251));

    final source = File('${tempDir.path}/sample.png');
    await source.writeAsBytes(img.encodePng(image));

    final output = await ImageToPdfService(storage).convert([source.path]);
    final bytes = await File(output).readAsBytes();

    expect(output, endsWith('.pdf'));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });

  test('PDF to DOCX with strong text produces editable text-based DOCX',
      () async {
    final source = File('${tempDir.path}/source.pdf');
    await source.writeAsBytes(
      await _samplePdfBytes('Hello conversion with readable embedded text'),
    );

    final output = await PdfToDocxService(
      storage,
      visualPageFactory: _fakeVisualPageFactory,
    ).convert(source.path);
    final archive = ZipDecoder().decodeBytes(await File(output).readAsBytes());
    final documentXml = archive.findFile('word/document.xml');
    final rels = archive.findFile('word/_rels/document.xml.rels');

    expect(output, endsWith('.docx'));
    expect(documentXml, isNotNull);
    // With strong embedded text, the DOCX should contain editable paragraphs
    expect(utf8.decode(documentXml!.content), contains('Hello conversion'));
    expect(rels, isNotNull);
  });

  test('PDF to DOCX uses OCR text when embedded PDF text is missing', () async {
    final source = File('${tempDir.path}/scanned.pdf');
    await source.writeAsBytes(await _blankPdfBytes());
    final fakeOcr = _FakeOcrEngine('Scanned OCR fallback text');

    final output = await PdfToDocxService(
      storage,
      ocrEngineFactory: () => fakeOcr,
      visualPageFactory: _fakeVisualPageFactory,
      ocrPageImageFactory: (pdfPath, pageNumber, tempDir, dpi) async {
        final pageImage = File('${tempDir.path}/page_$pageNumber.png');
        await pageImage.writeAsBytes([137, 80, 78, 71], flush: true);
        return pageImage.path;
      },
    ).convert(source.path);
    final archive = ZipDecoder().decodeBytes(await File(output).readAsBytes());
    final documentXml = archive.findFile('word/document.xml');

    expect(documentXml, isNotNull);
    expect(utf8.decode(documentXml!.content),
        contains('Scanned OCR fallback text'));
    expect(fakeOcr.closed, isTrue);
  });

  test('DOCX to PDF extracts DOCX text into a readable PDF', () async {
    final sourcePdf = File('${tempDir.path}/source.pdf');
    await sourcePdf.writeAsBytes(
      await _samplePdfBytes('Round trip text with readable embedded content'),
    );
    final docx = await PdfToDocxService(
      storage,
      visualPageFactory: _fakeVisualPageFactory,
    ).convert(sourcePdf.path);

    final output = await DocxToPdfService(storage).convert(docx);
    final bytes = await File(output).readAsBytes();

    expect(output, endsWith('.pdf'));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}

Future<List<int>> _samplePdfBytes(String text) async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (_) => pw.Text(text),
    ),
  );
  return pdf.save();
}

Future<List<int>> _blankPdfBytes() async {
  final pdf = pw.Document();
  pdf.addPage(
    pw.Page(
      build: (_) => pw.SizedBox(width: 1, height: 1),
    ),
  );
  return pdf.save();
}

Future<List<PdfPageSnapshot>> _fakeVisualPageFactory(
  String pdfPath,
  double dpi,
  PdfToDocxProgress? onProgress,
) async {
  onProgress?.call(1, 1, PdfToDocxStage.renderingPages);
  return [
    PdfPageSnapshot(
      pageNumber: 1,
      bytes: Uint8List.fromList(_fakePagePng()),
      pixelWidth: 80,
      pixelHeight: 100,
      widthPoints: 612,
      heightPoints: 792,
    ),
  ];
}

List<int> _fakePagePng() {
  final image = img.Image(width: 80, height: 100);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  img.drawString(
    image,
    'PDF PAGE',
    font: img.arial14,
    x: 8,
    y: 40,
    color: img.ColorRgb8(0, 0, 0),
  );
  return img.encodePng(image);
}

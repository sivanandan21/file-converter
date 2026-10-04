import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:xml/xml.dart';

import 'file_storage_service.dart';

enum PdfToDocxStage { extractingText, renderingPages, recognizingText }

typedef PdfToDocxProgress = void Function(
  int page,
  int total,
  PdfToDocxStage stage,
);

typedef OcrEngineFactory = OcrEngine Function();

typedef OcrPageImageFactory = Future<String> Function(
  String pdfPath,
  int pageNumber,
  Directory tempDir,
  double dpi,
);

typedef PdfVisualPageFactory = Future<List<PdfPageSnapshot>> Function(
  String pdfPath,
  double dpi,
  PdfToDocxProgress? onProgress,
);

class PdfPageSnapshot {
  final int pageNumber;
  final Uint8List bytes;
  final int pixelWidth;
  final int pixelHeight;
  final double widthPoints;
  final double heightPoints;
  final String searchableText;

  const PdfPageSnapshot({
    required this.pageNumber,
    required this.bytes,
    required this.pixelWidth,
    required this.pixelHeight,
    required this.widthPoints,
    required this.heightPoints,
    this.searchableText = '',
  });

  PdfPageSnapshot copyWithSearchableText(String text) {
    return PdfPageSnapshot(
      pageNumber: pageNumber,
      bytes: bytes,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      widthPoints: widthPoints,
      heightPoints: heightPoints,
      searchableText: text,
    );
  }
}

class _DocxImagePage {
  final Uint8List bytes;
  final double widthPoints;
  final double heightPoints;

  const _DocxImagePage({
    required this.bytes,
    required this.widthPoints,
    required this.heightPoints,
  });
}

class _PageSize {
  final double widthPoints;
  final double heightPoints;

  const _PageSize(this.widthPoints, this.heightPoints);
}

class ConversionException implements Exception {
  final String message;

  const ConversionException(this.message);

  @override
  String toString() => message;
}

abstract class OcrEngine {
  Future<String> recognizeText(String imagePath);

  Future<void> close();
}

class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine()
      : _recognizers = [
          mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.latin),
          mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.devanagiri),
          mlkit.TextRecognizer(script: mlkit.TextRecognitionScript.chinese),
        ];

  // Threshold: number of non-whitespace chars before we consider text "strong".
  static const _strongTextScore = 60;
  static const _recognizerTimeout = Duration(seconds: 90);

  final List<mlkit.TextRecognizer> _recognizers;

  @override
  Future<String> recognizeText(String imagePath) async {
    // 1. Pass 1: Preprocessed image (contrast, binarization, sharpening)
    final preprocessedPath = await _preprocessImageForOcr(imagePath);
    final inputImage = mlkit.InputImage.fromFilePath(preprocessedPath);
    final candidates = <String>[];

    for (final recognizer in _recognizers) {
      try {
        final recognized = await recognizer
            .processImage(inputImage)
            .timeout(_recognizerTimeout);
        final ordered = _recognizedTextInReadingOrder(recognized);
        if (ordered.trim().isNotEmpty) {
          candidates.add(ordered);
          if (_textScore(ordered) >= _strongTextScore) {
            break; // Good enough result; skip remaining scripts.
          }
        }
      } on TimeoutException {
        break;
      } catch (_) {
        // Optional script models can fail on some devices; keep the OCR pass alive.
      }
    }

    // 2. Pass 2: Deep scan fallback on original image if score was low
    final topScore = candidates.isEmpty ? 0 : _textScore(candidates.first);
    if (topScore < _strongTextScore) {
      try {
        final originalInputImage = mlkit.InputImage.fromFilePath(imagePath);
        for (final recognizer in _recognizers) {
          try {
            final recognized = await recognizer
                .processImage(originalInputImage)
                .timeout(_recognizerTimeout);
            final ordered = _recognizedTextInReadingOrder(recognized);
            if (ordered.trim().isNotEmpty) {
              candidates.add(ordered);
              if (_textScore(ordered) >= _strongTextScore) {
                break;
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    // Clean up preprocessed temp file if different from original
    if (preprocessedPath != imagePath) {
      try {
        await File(preprocessedPath).delete();
      } catch (_) {}
    }

    if (candidates.isEmpty) return '';
    // Return the candidate with the highest text score
    candidates.sort((a, b) => _textScore(b).compareTo(_textScore(a)));
    return postProcessOcrText(candidates.first.trim());
  }

  /// Image preprocessing for OCR. Runs in a background isolate so the UI
  /// thread never janks on multi-megapixel pages. Returns the original path
  /// when preprocessing is not possible.
  Future<String> _preprocessImageForOcr(String imagePath) async {
    try {
      final outputPath = '${p.withoutExtension(imagePath)}_ocr_prep.png';
      final ok = await Isolate.run(
        () => preprocessOcrImageFile(imagePath, outputPath),
      );
      return ok ? outputPath : imagePath;
    } catch (_) {
      // If preprocessing fails, fall back to original image
      return imagePath;
    }
  }

  @override
  Future<void> close() async {
    for (final recognizer in _recognizers) {
      try {
        await recognizer.close();
      } catch (_) {
        // Closing is best effort; recognizers may already be released natively.
      }
    }
  }
}

/// Preprocess an image file for OCR and write the result to [outputPath].
/// Top-level so it can run inside [Isolate.run]. Returns false on failure.
@visibleForTesting
bool preprocessOcrImageFile(String inputPath, String outputPath) {
  final output = preprocessOcrImageBytes(File(inputPath).readAsBytesSync());
  if (output == null) return false;
  File(outputPath).writeAsBytesSync(output, flush: true);
  return true;
}

/// Pure-Dart OCR preprocessing: luminance → percentile contrast stretch →
/// (dark-background inversion) → adaptive local-mean binarization → border
/// cleanup.
///
/// Adaptive thresholding (integral image) handles uneven lighting, shadows and
/// yellowed paper far better than one global threshold, and flat regions stay
/// white so speckle noise is not amplified.
@visibleForTesting
Uint8List? preprocessOcrImageBytes(Uint8List bytes) {
  final img.Image? image;
  try {
    image = img.decodeImage(bytes);
  } catch (_) {
    // Truncated/garbage data can make format sniffing throw.
    return null;
  }
  if (image == null) return null;
  final width = image.width;
  final height = image.height;
  final total = width * height;
  if (total == 0) return null;

  // 1. Luminance plane.
  final lum = Uint8List(total);
  var index = 0;
  for (final pixel in image) {
    lum[index++] = img.getLuminance(pixel).round().clamp(0, 255).toInt();
  }

  // 2. Percentile contrast stretch (ignores 1% outliers at each end).
  final histogram = List<int>.filled(256, 0);
  for (var i = 0; i < total; i++) {
    histogram[lum[i]]++;
  }
  final lo = _percentileLevel(histogram, total, 0.01);
  final hi = _percentileLevel(histogram, total, 0.99);
  if (hi - lo >= 16) {
    final lut = Uint8List(256);
    final range = hi - lo;
    for (var v = 0; v < 256; v++) {
      lut[v] = (((v - lo) * 255) / range).round().clamp(0, 255).toInt();
    }
    for (var i = 0; i < total; i++) {
      lum[i] = lut[lum[i]];
    }
  }

  // 3. Light-on-dark pages (inverted scans, dark mode screenshots) → invert.
  var lumSum = 0;
  for (var i = 0; i < total; i++) {
    lumSum += lum[i];
  }
  if (lumSum / total < 110) {
    for (var i = 0; i < total; i++) {
      lum[i] = 255 - lum[i];
    }
  }

  // 4. Integral image (Uint32 wrap-around arithmetic is safe because every
  //    window sum is far below 2^32).
  final stride = width + 1;
  final integral = Uint32List(stride * (height + 1));
  for (var y = 0; y < height; y++) {
    var rowSum = 0;
    final rowOffset = y * width;
    final current = (y + 1) * stride;
    final previous = y * stride;
    for (var x = 0; x < width; x++) {
      rowSum += lum[rowOffset + x];
      integral[current + x + 1] =
          (integral[previous + x + 1] + rowSum) & 0xFFFFFFFF;
    }
  }

  // 5. Adaptive threshold: ink = pixel darker than 90% of its local mean.
  final radius = (width ~/ 32) < 12 ? 12 : width ~/ 32;
  final binary = Uint8List(total);
  for (var y = 0; y < height; y++) {
    final y0 = y - radius < 0 ? 0 : y - radius;
    final y1 = y + radius + 1 > height ? height : y + radius + 1;
    for (var x = 0; x < width; x++) {
      final x0 = x - radius < 0 ? 0 : x - radius;
      final x1 = x + radius + 1 > width ? width : x + radius + 1;
      final sum = (integral[y1 * stride + x1] -
              integral[y0 * stride + x1] -
              integral[y1 * stride + x0] +
              integral[y0 * stride + x0]) &
          0xFFFFFFFF;
      final area = (x1 - x0) * (y1 - y0);
      final value = lum[y * width + x];
      binary[y * width + x] = (value * area * 100 < sum * 90) ? 0 : 255;
    }
  }

  // 6. Remove thin scanner-border artifacts.
  const border = 3;
  for (var y = 0; y < height; y++) {
    final inVerticalBorder = y < border || y >= height - border;
    for (var x = 0; x < width; x++) {
      if (inVerticalBorder || x < border || x >= width - border) {
        binary[y * width + x] = 255;
      }
    }
  }

  final output = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: binary.buffer,
    numChannels: 1,
  );
  return Uint8List.fromList(img.encodePng(output));
}

int _percentileLevel(List<int> histogram, int total, double fraction) {
  final target = total * fraction;
  var cumulative = 0;
  for (var level = 0; level < 256; level++) {
    cumulative += histogram[level];
    if (cumulative >= target) return level;
  }
  return 255;
}

/// Post-process OCR text: fix common ML Kit errors, ligatures, and typographic artifacts.
///
/// Every rule is deliberately conservative: it must never delete or rewrite
/// legitimate content such as bullets (•), ampersands, percent signs, table
/// pipes or math symbols.
@visibleForTesting
String postProcessOcrText(String text) {
  var result = text;

  // 1. Unicode ligature fixes (common in scanned PDF fonts)
  result = result
      .replaceAll('\uFB01', 'fi')
      .replaceAll('\uFB02', 'fl')
      .replaceAll('\uFB00', 'ff')
      .replaceAll('\uFB03', 'ffi')
      .replaceAll('\uFB04', 'ffl');

  // 2. Typographic quote artifacts (double forms first so they stay reachable).
  result = result
      .replaceAll('``', '"')
      .replaceAll("''", '"')
      .replaceAll('`', "'");

  // 3. A pipe glued to the front of a lowercase word is a misread capital I
  //    ("|nternational"). Standalone pipes (tables) are left untouched.
  result = result.replaceAllMapped(
    RegExp(r'(^|\s)\|(?=[a-z]+)', multiLine: true),
    (m) => '${m[1]}I',
  );

  // 4. Rejoin words hyphenated across a line break (continuation must start
  //    lowercase so "Mary-\nAnn" style names are preserved).
  result = result.replaceAllMapped(
    RegExp(r'([A-Za-z]{2,})-\n[ \t]*([a-z]{2,})'),
    (m) => '${m[1]}${m[2]}',
  );

  // 5. Remove stray space before , . ; — same line only, never across
  //    newlines, and only when followed by whitespace/end of text.
  result = result.replaceAllMapped(
    RegExp(r'(?<=\S)[ \t]+([,.;])(?=\s|$)'),
    (m) => m[1]!,
  );

  // 6. Drop isolated glyphs that are never meaningful on their own
  //    (specks misread as ~ ^ _ ¬ ¦ ¨ ´ ¸ ˜). Bullets and symbols are kept.
  result = result.replaceAll(RegExp(r'(?<=[ \t])[~^_¬¦¨´¸˜](?=[ \t])'), '');

  // 7. Normalize excessive whitespace and blank lines
  result = result
      .replaceAll(RegExp(r'[ \t]{3,}'), '  ')
      .replaceAll(RegExp(r'\n{4,}'), '\n\n\n');

  return result.trim();
}

class _PreparedPdfImage {
  final Uint8List bytes;
  final int width;
  final int height;

  const _PreparedPdfImage(this.bytes, this.width, this.height);
}

/// Decodes + normalizes an image for PDF embedding. Runs in a background
/// isolate. JPEGs with normal orientation are embedded byte-for-byte (no
/// recompression, no size blow-up); everything else is orientation-baked.
_PreparedPdfImage? _prepareImageForPdf(Uint8List bytes) {
  final isJpeg =
      bytes.length > 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  final decoded = isJpeg ? img.decodeJpg(bytes) : img.decodeImage(bytes);
  if (decoded == null) return null;

  final orientation = decoded.exif.imageIfd.orientation ?? 1;
  if (isJpeg && orientation <= 1) {
    return _PreparedPdfImage(bytes, decoded.width, decoded.height);
  }

  final oriented = img.bakeOrientation(decoded);
  final encoded = isJpeg
      ? Uint8List.fromList(img.encodeJpg(oriented, quality: 95))
      : Uint8List.fromList(img.encodePng(oriented));
  return _PreparedPdfImage(encoded, oriented.width, oriented.height);
}

class ImageToPdfService {
  final FileStorageService _storage;

  ImageToPdfService(this._storage);

  Future<String> convert(List<String> imagePaths) async {
    if (imagePaths.isEmpty) {
      throw const ConversionException('Select at least one image.');
    }

    final pdf = pw.Document();
    for (final imagePath in imagePaths) {
      final prepared = await _readImageForPdf(imagePath);
      final pdfImage = pw.MemoryImage(prepared.bytes);

      // Match the page orientation to the image so landscape photos use the
      // full page instead of shrinking into a portrait page.
      final pageFormat = prepared.width > prepared.height
          ? PdfPageFormat.a4.landscape
          : PdfPageFormat.a4;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Center(
            child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    final baseName = imagePaths.length == 1
        ? p.basenameWithoutExtension(imagePaths.first)
        : '${p.basenameWithoutExtension(imagePaths.first)}_${imagePaths.length}_images';
    final outputPath = await _storage.buildOutputPath(baseName, 'pdf');
    await _storage.writeBytes(outputPath, await pdf.save());
    return outputPath;
  }

  Future<_PreparedPdfImage> _readImageForPdf(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw ConversionException('Image not found: ${p.basename(imagePath)}');
    }

    final bytes = await file.readAsBytes();
    _PreparedPdfImage? prepared;
    try {
      prepared = await Isolate.run(() => _prepareImageForPdf(bytes));
    } catch (_) {
      prepared = null;
    }
    if (prepared == null) {
      throw ConversionException(
          'Unsupported or corrupted image: ${p.basename(imagePath)}');
    }
    return prepared;
  }
}

class _RenderSize {
  final double width;
  final double height;

  const _RenderSize(this.width, this.height);
}

/// Render size for a page at [dpi], clamped so the longest side never exceeds
/// [maxDimension] pixels. Prevents out-of-memory crashes on poster-sized PDFs.
_RenderSize _renderSizeForDpi(
  double widthPoints,
  double heightPoints,
  double dpi, {
  double maxDimension = 4096,
}) {
  final scale = dpi / 72;
  var width = widthPoints * scale;
  var height = heightPoints * scale;
  final longest = width > height ? width : height;
  if (longest > maxDimension) {
    final factor = maxDimension / longest;
    width *= factor;
    height *= factor;
  }
  return _RenderSize(width.roundToDouble(), height.roundToDouble());
}

Future<pdfx.PdfDocument> _openPdfForRendering(String pdfPath) async {
  try {
    return await pdfx.PdfDocument.openFile(pdfPath);
  } catch (_) {
    throw ConversionException(
        'Could not open ${p.basename(pdfPath)}. It may be corrupted or password-protected.');
  }
}

class PdfToImageService {
  final FileStorageService _storage;

  PdfToImageService(this._storage);

  Future<List<String>> convert(
    String pdfPath, {
    double dpi = 150,
    void Function(int page, int total)? onProgress,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw ConversionException('PDF not found: ${p.basename(pdfPath)}');
    }

    final document = await _openPdfForRendering(pdfPath);
    try {
      final pageCount = document.pagesCount;
      final baseName = p.basenameWithoutExtension(pdfPath);
      final outputPaths = <String>[];

      for (var i = 1; i <= pageCount; i++) {
        final page = await document.getPage(i);
        try {
          final size = _renderSizeForDpi(
            page.width,
            page.height,
            dpi,
            maxDimension: 6000,
          );
          final rendered = await page.render(
            width: size.width,
            height: size.height,
            format: pdfx.PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );

          if (rendered == null) {
            throw ConversionException('Could not render page $i.');
          }

          final outputPath =
              await _storage.buildOutputPath('${baseName}_page_$i', 'png');
          await _storage.writeBytes(outputPath, rendered.bytes);
          outputPaths.add(outputPath);
        } finally {
          await page.close();
        }

        onProgress?.call(i, pageCount);
      }

      if (outputPaths.isEmpty) {
        throw const ConversionException(
            'The PDF did not contain renderable pages.');
      }
      return outputPaths;
    } finally {
      await document.close();
    }
  }
}

class PdfToDocxService {
  final FileStorageService _storage;
  final OcrEngineFactory _ocrEngineFactory;
  final OcrPageImageFactory _ocrPageImageFactory;
  final bool _sharedOcrRenderer;
  final PdfVisualPageFactory _visualPageFactory;
  final double ocrDpi;
  final double visualDpi;
  final int minTextCharactersBeforeOcr;

  PdfToDocxService(
    this._storage, {
    OcrEngineFactory? ocrEngineFactory,
    OcrPageImageFactory? ocrPageImageFactory,
    PdfVisualPageFactory? visualPageFactory,
    // 300 DPI for OCR — the sweet spot for ML Kit text recognition accuracy.
    // Lower = blurry text ML Kit misreads; higher = excessive memory pressure.
    this.ocrDpi = 300,
    // 220 DPI for visual embedding — balances DOCX file size vs fidelity.
    this.visualDpi = 220,
    // Lower threshold: trigger OCR even when a little embedded text exists,
    // because many scanned PDFs contain garbled embedded text.
    this.minTextCharactersBeforeOcr = 12,
  })  : _ocrEngineFactory = ocrEngineFactory ?? (() => MlKitOcrEngine()),
        _ocrPageImageFactory = ocrPageImageFactory ?? _renderPdfPageForOcr,
        // When no custom renderer is injected, share ONE open PDF document
        // across all OCR pages instead of re-parsing the file per page.
        _sharedOcrRenderer = ocrPageImageFactory == null,
        _visualPageFactory = visualPageFactory ?? _renderPdfPagesForDocx;

  Future<String> convert(
    String pdfPath, {
    PdfToDocxProgress? onProgress,
  }) async {
    final file = File(pdfPath);
    if (!await file.exists()) {
      throw ConversionException('PDF not found: ${p.basename(pdfPath)}');
    }

    final inputBytes = await file.readAsBytes();
    final embeddedTextByPage = _extractEmbeddedTextByPage(inputBytes);
    final pageCount = embeddedTextByPage.length;
    if (pageCount == 0) {
      throw const ConversionException('The PDF does not contain pages.');
    }

    for (var i = 0; i < pageCount; i++) {
      onProgress?.call(i + 1, pageCount, PdfToDocxStage.extractingText);
    }

    // OCR pass: only for pages whose embedded text is missing/weak.
    final ocrTextByPage = <int, String>{};
    final pagesNeedingOcr = <int>[];
    for (var i = 0; i < pageCount; i++) {
      if (_isWeakText(embeddedTextByPage[i], minTextCharactersBeforeOcr)) {
        pagesNeedingOcr.add(i);
      }
    }

    if (pagesNeedingOcr.isNotEmpty) {
      final tempDir = await Directory.systemTemp.createTemp('ffc_ocr_');
      final ocrEngine = _ocrEngineFactory();
      _OcrRenderSession? session;
      try {
        if (_sharedOcrRenderer) {
          session = await _OcrRenderSession.open(pdfPath);
        }
        for (final pageIndex in pagesNeedingOcr) {
          final pageNumber = pageIndex + 1;
          // Always render a fresh high-DPI image for OCR instead of reusing
          // the lower-DPI visual snapshots. This is the key accuracy fix.
          final imagePath = session != null
              ? await session.render(pageNumber, tempDir, ocrDpi)
              : await _ocrPageImageFactory(
                  pdfPath,
                  pageNumber,
                  tempDir,
                  ocrDpi,
                );
          ocrTextByPage[pageIndex] = await ocrEngine.recognizeText(imagePath);
          // Free disk as we go; scanned books can be hundreds of pages.
          try {
            await File(imagePath).delete();
          } catch (_) {}
          onProgress?.call(
            pageNumber,
            pageCount,
            PdfToDocxStage.recognizingText,
          );
        }
      } finally {
        await session?.close();
        await ocrEngine.close();
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    }

    // Build the best text for each page (embedded vs OCR)
    final paragraphs = _buildBestParagraphsByPage(
      embeddedTextByPage,
      ocrTextByPage,
    );

    Uint8List docxBytes;
    if (paragraphs.isNotEmpty) {
      // Editable DOCX — real text paragraphs that users can edit in Word
      docxBytes = _buildDocx(paragraphs);
    } else {
      // No text anywhere (diagram / photo-only PDF): preserve the pages as
      // images. Rendering is lazy — text PDFs never pay for it.
      final renderedPages =
          await _visualPageFactory(pdfPath, visualDpi, onProgress);
      if (renderedPages.length != pageCount) {
        throw const ConversionException(
            'Could not preserve every PDF page for DOCX output.');
      }
      final searchableTextByPage = _buildBestSearchableTextByPage(
        embeddedTextByPage,
        ocrTextByPage,
      );
      final visualPages = List<PdfPageSnapshot>.generate(
          renderedPages.length,
          (i) => renderedPages[i]
              .copyWithSearchableText(searchableTextByPage[i]));
      docxBytes = _buildDocx([], visualPages: visualPages);
    }

    final baseName = p.basenameWithoutExtension(pdfPath);
    final outputPath = await _storage.buildOutputPath(baseName, 'docx');
    await _storage.writeBytes(outputPath, docxBytes);
    return outputPath;
  }
}

class DocxToPdfService {
  final FileStorageService _storage;

  DocxToPdfService(this._storage);

  Future<String> convert(String docxPath) async {
    final file = File(docxPath);
    if (!await file.exists()) {
      throw ConversionException('DOCX not found: ${p.basename(docxPath)}');
    }
    if (p.extension(docxPath).toLowerCase() != '.docx') {
      throw const ConversionException(
          'Legacy .doc files are not supported. Please choose a .docx file.');
    }

    final docxBytes = await file.readAsBytes();
    final baseName = p.basenameWithoutExtension(docxPath);

    // Visible (non-hidden) paragraphs decide the path: a DOCX with real text
    // must never be reduced to just its images (logos, figures, ...).
    List<String> paragraphs;
    List<_DocxImagePage> imagePages;
    try {
      paragraphs = await _extractDocxParagraphs(docxBytes);
      imagePages =
          paragraphs.isEmpty ? _extractDocxImagePages(docxBytes) : const [];
    } on ConversionException {
      rethrow;
    } catch (_) {
      throw const ConversionException(
          'This file is not a valid DOCX document.');
    }

    if (paragraphs.isEmpty && imagePages.isNotEmpty) {
      // Image-only DOCX (e.g. produced from a scanned PDF): one page per image.
      final pdf = pw.Document();
      for (final page in imagePages) {
        final pdfImage = pw.MemoryImage(page.bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.widthPoints, page.heightPoints),
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.SizedBox.expand(
              child: pw.Image(pdfImage, fit: pw.BoxFit.fill),
            ),
          ),
        );
      }

      final outputPath = await _storage.buildOutputPath(baseName, 'pdf');
      await _storage.writeBytes(outputPath, await pdf.save());
      return outputPath;
    }

    if (paragraphs.isEmpty) {
      throw const ConversionException(
          'No readable text was found in this DOCX.');
    }

    final font = await _loadPdfFonts();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        theme: font.theme,
        build: (_) => [
          ...paragraphs.map(
            (text) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text(
                _sanitizeForPdfText(text, unicode: font.unicode),
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 3),
              ),
            ),
          ),
        ],
      ),
    );

    final outputPath = await _storage.buildOutputPath(baseName, 'pdf');
    await _storage.writeBytes(outputPath, await pdf.save());
    return outputPath;
  }
}

class _PdfFonts {
  final pw.ThemeData theme;
  final bool unicode;

  const _PdfFonts(this.theme, {required this.unicode});
}

/// Loads the bundled Noto Sans family (full Latin/Greek/Cyrillic coverage,
/// curly quotes, bullets, accents). Falls back to built-in Helvetica when the
/// assets are unavailable, in which case text is sanitized to Latin-1.
Future<_PdfFonts> _loadPdfFonts() async {
  try {
    Future<pw.Font> load(String name) async =>
        pw.Font.ttf(await rootBundle.load('assets/fonts/$name'));
    final theme = pw.ThemeData.withFont(
      base: await load('NotoSans-Regular.ttf'),
      bold: await load('NotoSans-Bold.ttf'),
      italic: await load('NotoSans-Italic.ttf'),
      boldItalic: await load('NotoSans-BoldItalic.ttf'),
    );
    return _PdfFonts(theme, unicode: true);
  } catch (_) {
    return _PdfFonts(
      pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
        boldItalic: pw.Font.helveticaBoldOblique(),
      ),
      unicode: false,
    );
  }
}

/// Makes text safe for the PDF writer: tabs → spaces, control chars removed,
/// and (for the Helvetica fallback) smart punctuation mapped to ASCII with
/// unsupported glyphs replaced by '?'.
@visibleForTesting
String sanitizeForPdfText(String text, {required bool unicode}) =>
    _sanitizeForPdfText(text, unicode: unicode);

String _sanitizeForPdfText(String text, {required bool unicode}) {
  var result = text
      .replaceAll('\t', '    ')
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
  if (unicode) return result;

  result = result
      .replaceAll(RegExp('[\u2018\u2019\u201A\u2032]'), "'")
      .replaceAll(RegExp('[\u201C\u201D\u201E\u2033]'), '"')
      .replaceAll(RegExp('[\u2013\u2014\u2212]'), '-')
      .replaceAll('\u2026', '...')
      .replaceAll('\u2022', '*')
      .replaceAll('\u00A0', ' ');
  return String.fromCharCodes(
    result.runes.map((r) => r > 255 ? 0x3F : r),
  );
}

List<String> _extractEmbeddedTextByPage(List<int> inputBytes) {
  final sf.PdfDocument source;
  try {
    source = sf.PdfDocument(inputBytes: inputBytes);
  } catch (e) {
    final message = e.toString().toLowerCase();
    if (message.contains('password') || message.contains('encrypt')) {
      throw const ConversionException(
          'This PDF is password-protected. Remove the password and try again.');
    }
    throw const ConversionException(
        'This PDF could not be read. The file may be corrupted.');
  }
  try {
    final extractor = sf.PdfTextExtractor(source);
    return List.generate(source.pages.count, (i) {
      try {
        return extractor.extractText(startPageIndex: i, endPageIndex: i).trim();
      } catch (_) {
        // Unusual fonts/encodings can break extraction for a single page;
        // returning '' lets the OCR pass recover that page.
        return '';
      }
    });
  } finally {
    source.dispose();
  }
}

/// One open PDF document reused for every OCR page render.
class _OcrRenderSession {
  _OcrRenderSession._(this._document);

  final pdfx.PdfDocument _document;

  static Future<_OcrRenderSession> open(String pdfPath) async =>
      _OcrRenderSession._(await _openPdfForRendering(pdfPath));

  Future<String> render(int pageNumber, Directory tempDir, double dpi) async {
    final page = await _document.getPage(pageNumber);
    try {
      final size = _renderSizeForDpi(page.width, page.height, dpi);
      final rendered = await page.render(
        width: size.width,
        height: size.height,
        format: pdfx.PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      if (rendered == null) {
        throw ConversionException(
            'Could not prepare page $pageNumber for OCR.');
      }

      final output = File(p.join(tempDir.path, 'ocr_page_$pageNumber.png'));
      await output.writeAsBytes(rendered.bytes, flush: true);
      return output.path;
    } finally {
      await page.close();
    }
  }

  Future<void> close() => _document.close();
}

Future<String> _renderPdfPageForOcr(
  String pdfPath,
  int pageNumber,
  Directory tempDir,
  double dpi,
) async {
  final session = await _OcrRenderSession.open(pdfPath);
  try {
    return await session.render(pageNumber, tempDir, dpi);
  } finally {
    await session.close();
  }
}

Future<List<PdfPageSnapshot>> _renderPdfPagesForDocx(
  String pdfPath,
  double dpi,
  PdfToDocxProgress? onProgress,
) async {
  final document = await _openPdfForRendering(pdfPath);
  try {
    final pageCount = document.pagesCount;
    final snapshots = <PdfPageSnapshot>[];

    for (var i = 1; i <= pageCount; i++) {
      final page = await document.getPage(i);
      try {
        final size = _renderSizeForDpi(page.width, page.height, dpi);
        final targetWidth = size.width;
        final targetHeight = size.height;
        final rendered = await page.render(
          width: targetWidth,
          height: targetHeight,
          format: pdfx.PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );

        if (rendered == null) {
          throw ConversionException('Could not preserve page $i.');
        }

        snapshots.add(
          PdfPageSnapshot(
            pageNumber: i,
            bytes: rendered.bytes,
            pixelWidth: rendered.width ?? targetWidth.round(),
            pixelHeight: rendered.height ?? targetHeight.round(),
            widthPoints: page.width.toDouble(),
            heightPoints: page.height.toDouble(),
          ),
        );
      } finally {
        await page.close();
      }

      onProgress?.call(i, pageCount, PdfToDocxStage.renderingPages);
    }

    return snapshots;
  } finally {
    await document.close();
  }
}

List<List<String>> _chosenParagraphsByPage(
  List<String> embeddedTextByPage,
  Map<int, String> ocrTextByPage,
) {
  return List.generate(embeddedTextByPage.length, (i) {
    final embeddedParagraphs =
        _splitPdfTextIntoParagraphs(embeddedTextByPage[i])
            .where((line) => line.isNotEmpty)
            .toList();
    final ocrParagraphs = _splitPdfTextIntoParagraphs(ocrTextByPage[i] ?? '')
        .where((line) => line.isNotEmpty)
        .toList();
    return _chooseBestParagraphs(embeddedParagraphs, ocrParagraphs);
  });
}

/// Real document paragraphs only — never placeholder text. Returns an empty
/// list when NO page has text so the caller can switch to the visual (image)
/// fallback. In a mixed document, text-less pages get a short bracketed note
/// so a missing diagram page is never silently dropped.
List<String> _buildBestParagraphsByPage(
  List<String> embeddedTextByPage,
  Map<int, String> ocrTextByPage,
) {
  final chosenByPage =
      _chosenParagraphsByPage(embeddedTextByPage, ocrTextByPage);
  if (chosenByPage.every((page) => page.isEmpty)) return const [];

  final paragraphs = <String>[];
  for (var i = 0; i < chosenByPage.length; i++) {
    if (chosenByPage[i].isEmpty) {
      paragraphs.add('[Page ${i + 1} contains no extractable text — it may be '
          'an image or blank page.]');
    } else {
      paragraphs.addAll(chosenByPage[i]);
    }
  }
  return paragraphs;
}

/// Per-page plain text used for DOCX alt-text / hidden searchable text.
/// Empty string (not a placeholder) for pages without text.
List<String> _buildBestSearchableTextByPage(
  List<String> embeddedTextByPage,
  Map<int, String> ocrTextByPage,
) {
  return _chosenParagraphsByPage(embeddedTextByPage, ocrTextByPage)
      .map((page) => page.join('\n'))
      .toList();
}

List<String> _chooseBestParagraphs(
  List<String> embeddedParagraphs,
  List<String> ocrParagraphs,
) {
  if (embeddedParagraphs.isEmpty) return ocrParagraphs;
  if (ocrParagraphs.isEmpty) return embeddedParagraphs;

  final embeddedScore = _textScore(embeddedParagraphs.join(' '));
  final ocrScore = _textScore(ocrParagraphs.join(' '));
  // Prefer OCR if it produced meaningfully more content (bias towards OCR
  // since embedded text in scanned PDFs is often garbled/corrupt)
  return ocrScore > embeddedScore + 8 ? ocrParagraphs : embeddedParagraphs;
}

bool _isWeakText(String text, int minCharacters) {
  return _textScore(text) < minCharacters;
}

int _textScore(String text) {
  // Count meaningful word-like tokens rather than raw chars.
  // This avoids short garbled OCR results scoring high due to concatenated noise.
  final nonSpace = text.replaceAll(RegExp(r'\s+'), '').runes.length;
  final wordCount = text.trim().split(RegExp(r'\s+')).where((w) => w.length > 1).length;
  // Weighted: chars + 3× word count rewards coherent readable text
  return nonSpace + (wordCount * 3);
}

/// Reconstruct reading order from ML Kit blocks using a column-aware layout.
/// Groups blocks into vertical columns, then reads top-to-bottom per column.
String _recognizedTextInReadingOrder(mlkit.RecognizedText recognized) {
  if (recognized.blocks.isEmpty) return '';

  final blocks = [...recognized.blocks];
  if (blocks.isEmpty) return '';

  // Determine page width from the rightmost block edge
  final pageWidth = blocks
      .map((b) => b.boundingBox.right)
      .reduce((a, b) => a > b ? a : b);

  // Detect multi-column layout: if any block is within the left 55% of page
  // AND another block is in the right 45%, treat as two-column.
  final midX = pageWidth * 0.52;
  final hasLeftCol = blocks.any((b) => b.boundingBox.left < midX * 0.7);
  final hasRightCol =
      blocks.any((b) => b.boundingBox.left > midX && b.boundingBox.left < pageWidth * 0.95);
  final isTwoColumn = hasLeftCol && hasRightCol;

  List<mlkit.TextBlock> orderedBlocks;
  if (isTwoColumn) {
    // Two-column: sort left column top→bottom, then right column top→bottom
    final leftBlocks = blocks
        .where((b) => b.boundingBox.left < midX)
        .toList()
      ..sort(_compareTextBlocks);
    final rightBlocks = blocks
        .where((b) => b.boundingBox.left >= midX)
        .toList()
      ..sort(_compareTextBlocks);
    orderedBlocks = [...leftBlocks, ...rightBlocks];
  } else {
    orderedBlocks = blocks..sort(_compareTextBlocks);
  }

  final chunks = <String>[];
  for (final block in orderedBlocks) {
    final lines = [...block.lines]..sort(_compareTextLines);
    final lineTexts = lines
        .map((line) => _cleanOcrLine(line.text))
        .where((line) => line.isNotEmpty)
        .toList();
    if (lineTexts.isNotEmpty) {
      chunks.add(lineTexts.join('\n'));
    } else if (block.text.trim().isNotEmpty) {
      chunks.add(_cleanOcrLine(block.text));
    }
  }

  return chunks.isEmpty ? recognized.text.trim() : chunks.join('\n\n');
}

/// Clean a single OCR line: remove stray control characters and normalize spaces.
String _cleanOcrLine(String raw) {
  return raw
      .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}

int _compareTextBlocks(mlkit.TextBlock a, mlkit.TextBlock b) {
  // Primary: top-to-bottom; secondary: left-to-right
  final topDiff = a.boundingBox.top - b.boundingBox.top;
  // Allow 12px tolerance so blocks on the same visual line sort left→right
  if (topDiff.abs() > 12) return topDiff.round();
  return a.boundingBox.left.compareTo(b.boundingBox.left);
}

int _compareTextLines(mlkit.TextLine a, mlkit.TextLine b) {
  final topDiff = a.boundingBox.top - b.boundingBox.top;
  if (topDiff.abs() > 6) return topDiff.round();
  return a.boundingBox.left.compareTo(b.boundingBox.left);
}

Iterable<String> _splitPdfTextIntoParagraphs(String text) {
  final normalized = text.replaceAll(RegExp(r'\r\n?'), '\n');
  return normalized
      .split(RegExp(r'\n{2,}'))
      .map((paragraph) => paragraph.replaceAll(RegExp(r'\s*\n\s*'), ' '))
      .map((paragraph) => paragraph.replaceAll(RegExp(r'[ \t]+'), ' ').trim());
}

/// Extracts the VISIBLE paragraphs of a DOCX. Runs marked `w:vanish` (hidden
/// text, e.g. the searchable text we embed behind preserved page images) are
/// skipped so they never show up as real content.
Future<List<String>> _extractDocxParagraphs(List<int> bytes) async {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final documentFile = archive.findFile('word/document.xml');
  if (documentFile == null) {
    throw const ConversionException(
        'Invalid DOCX: word/document.xml is missing.');
  }

  final documentXml = utf8.decode(documentFile.content);
  final document = XmlDocument.parse(documentXml);
  final paragraphs = <String>[];

  for (final paragraph in document.findAllElements('p', namespace: '*')) {
    final parts = <String>[];
    for (final child in paragraph.descendants.whereType<XmlElement>()) {
      final name = child.name.local;
      if (name != 't' && name != 'tab' && name != 'br') continue;
      if (_isInHiddenRun(child)) continue;
      if (name == 't') {
        parts.add(child.innerText);
      } else if (name == 'tab') {
        parts.add('\t');
      } else {
        parts.add('\n');
      }
    }
    final text = parts.join().replaceAll(RegExp(r'[ \t]+\n'), '\n').trim();
    if (text.isNotEmpty) {
      paragraphs.add(text);
    }
  }

  return paragraphs;
}

bool _isInHiddenRun(XmlElement element) {
  XmlNode? node = element.parent;
  while (node is XmlElement) {
    if (node.name.local == 'r') {
      for (final props in node.findElements('rPr', namespace: '*')) {
        for (final vanish in props.findElements('vanish', namespace: '*')) {
          final value = _xmlAttribute(vanish, 'val');
          if (value == null || (value != '0' && value != 'false')) return true;
        }
      }
      return false;
    }
    node = node.parent;
  }
  return false;
}

List<_DocxImagePage> _extractDocxImagePages(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes, verify: true);
  final documentFile = archive.findFile('word/document.xml');
  final relsFile = archive.findFile('word/_rels/document.xml.rels');
  if (documentFile == null || relsFile == null) {
    return const [];
  }

  final document = XmlDocument.parse(utf8.decode(documentFile.content));
  final rels = XmlDocument.parse(utf8.decode(relsFile.content));
  final pageSize = _extractDocxPageSize(document);
  final imageTargetsById = <String, String>{};

  for (final rel in rels.findAllElements('Relationship', namespace: '*')) {
    final id = _xmlAttribute(rel, 'Id');
    final type = _xmlAttribute(rel, 'Type') ?? '';
    final target = _xmlAttribute(rel, 'Target');
    if (id != null && target != null && type.endsWith('/image')) {
      imageTargetsById[id] = target;
    }
  }

  final pages = <_DocxImagePage>[];
  for (final blip in document.findAllElements('blip', namespace: '*')) {
    final relId = _xmlAttribute(blip, 'embed');
    final target = relId == null ? null : imageTargetsById[relId];
    if (target == null) continue;

    final imageFile = _findArchiveFile(archive, _wordTargetPath(target));
    if (imageFile == null) continue;

    final imageBytes = Uint8List.fromList(imageFile.content);
    final decoded = img.decodeImage(imageBytes);
    final fallbackSize = decoded == null
        ? _PageSize(PdfPageFormat.a4.width, PdfPageFormat.a4.height)
        : _pageSizeForImage(decoded.width, decoded.height);

    pages.add(
      _DocxImagePage(
        bytes: imageBytes,
        widthPoints: pageSize?.widthPoints ?? fallbackSize.widthPoints,
        heightPoints: pageSize?.heightPoints ?? fallbackSize.heightPoints,
      ),
    );
  }

  return pages;
}

ArchiveFile? _findArchiveFile(Archive archive, String path) {
  return archive.findFile(path) ?? archive.findFile(path.replaceAll('\\', '/'));
}

String _wordTargetPath(String target) {
  final normalized = target.replaceAll('\\', '/');
  if (normalized.startsWith('/')) {
    return normalized.substring(1);
  }
  return p.posix.normalize('word/$normalized');
}

_PageSize? _extractDocxPageSize(XmlDocument document) {
  XmlElement? pageSizeElement;
  for (final element in document.findAllElements('pgSz', namespace: '*')) {
    pageSizeElement = element;
    break;
  }
  if (pageSizeElement == null) return null;

  final widthTwips = double.tryParse(_xmlAttribute(pageSizeElement, 'w') ?? '');
  final heightTwips =
      double.tryParse(_xmlAttribute(pageSizeElement, 'h') ?? '');
  if (widthTwips == null || heightTwips == null) return null;

  return _PageSize(widthTwips / 20, heightTwips / 20);
}

_PageSize _pageSizeForImage(int width, int height) {
  final landscape = width > height;
  final pageWidth =
      landscape ? PdfPageFormat.a4.height : PdfPageFormat.a4.width;
  final pageHeight =
      landscape ? PdfPageFormat.a4.width : PdfPageFormat.a4.height;
  return _PageSize(pageWidth, pageHeight);
}

String? _xmlAttribute(XmlElement element, String localName) {
  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}

Uint8List _buildDocx(
  List<String> paragraphs, {
  List<PdfPageSnapshot> visualPages = const [],
}) {
  final archive = Archive();

  void add(String name, String content) {
    archive.add(ArchiveFile.string(name, content));
  }

  void addBytes(String name, List<int> content) {
    archive.add(ArchiveFile.bytes(name, content));
  }

  final hasVisualPages = visualPages.isNotEmpty;
  final hasText = paragraphs.isNotEmpty;

  add(
    '[Content_Types].xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  ${hasVisualPages ? '<Default Extension="png" ContentType="image/png"/>' : ''}
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>''',
  );
  add(
    '_rels/.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''',
  );
  add(
    'word/_rels/document.xml.rels',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${_imageRelationshipsXml(visualPages)}
</Relationships>''',
  );
  add(
    'docProps/core.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>Converted Document</dc:title>
  <dc:creator>File Format Converter</dc:creator>
  <cp:lastModifiedBy>File Format Converter</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String()}</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">${DateTime.now().toUtc().toIso8601String()}</dcterms:modified>
</cp:coreProperties>''',
  );
  add(
    'docProps/app.xml',
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>File Format Converter</Application>
</Properties>''',
  );
  for (final page in visualPages) {
    addBytes('word/media/page_${page.pageNumber}.png', page.bytes);
  }

  // Build the document XML based on whether we have text or image content
  if (hasText && !hasVisualPages) {
    // Pure text-based editable DOCX
    add('word/document.xml', _buildDocumentXml(paragraphs));
  } else if (hasVisualPages) {
    // Image-based DOCX with searchable hidden text
    add('word/document.xml', _buildVisualDocumentXml(visualPages));
  } else {
    add('word/document.xml', _buildDocumentXml(paragraphs));
  }

  final encoded = ZipEncoder().encode(archive);
  if (encoded.isEmpty) {
    throw const ConversionException('Could not create DOCX archive.');
  }
  return Uint8List.fromList(encoded);
}

String _buildDocumentXml(List<String> paragraphs) {
  final body = paragraphs.isEmpty
      ? _paragraphXml('No extractable text found in the source PDF.')
      : paragraphs.map(_paragraphXml).join('\n');

  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
$body
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="708" w:footer="708" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';
}

String _imageRelationshipsXml(List<PdfPageSnapshot> visualPages) {
  return visualPages.asMap().entries.map((entry) {
    final relId = _imageRelId(entry.key);
    final page = entry.value;
    return '  <Relationship Id="$relId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/page_${page.pageNumber}.png"/>';
  }).join('\n');
}

String _buildVisualDocumentXml(List<PdfPageSnapshot> pages) {
  final firstPage = pages.first;
  final body = pages.asMap().entries.map((entry) {
    final pageXml = _pageImageXml(entry.value, entry.key);
    if (entry.key == pages.length - 1) return pageXml;
    return '$pageXml\n${_pageBreakXml()}';
  }).join('\n');

  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
$body
    ${_sectionPropertiesXml(firstPage)}
  </w:body>
</w:document>''';
}

String _pageImageXml(PdfPageSnapshot page, int index) {
  final docPrId = index + 1;
  final relId = _imageRelId(index);
  final cx = _pointsToEmu(page.widthPoints);
  final cy = _pointsToEmu(page.heightPoints);
  final altText = _escapeXml(_shortAltText(page));
  final hiddenText = _hiddenTextXml(page.searchableText);

  return '''    <w:p>
      <w:pPr>
        <w:spacing w:before="0" w:after="0"/>
        <w:jc w:val="center"/>
      </w:pPr>
      <w:r>
        <w:drawing>
          <wp:inline distT="0" distB="0" distL="0" distR="0">
            <wp:extent cx="$cx" cy="$cy"/>
            <wp:docPr id="$docPrId" name="PDF page ${page.pageNumber}" descr="$altText"/>
            <wp:cNvGraphicFramePr>
              <a:graphicFrameLocks noChangeAspect="1"/>
            </wp:cNvGraphicFramePr>
            <a:graphic>
              <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                <pic:pic>
                  <pic:nvPicPr>
                    <pic:cNvPr id="$docPrId" name="page_${page.pageNumber}.png" descr="$altText"/>
                    <pic:cNvPicPr/>
                  </pic:nvPicPr>
                  <pic:blipFill>
                    <a:blip r:embed="$relId"/>
                    <a:stretch>
                      <a:fillRect/>
                    </a:stretch>
                  </pic:blipFill>
                  <pic:spPr>
                    <a:xfrm>
                      <a:off x="0" y="0"/>
                      <a:ext cx="$cx" cy="$cy"/>
                    </a:xfrm>
                    <a:prstGeom prst="rect">
                      <a:avLst/>
                    </a:prstGeom>
                  </pic:spPr>
                </pic:pic>
              </a:graphicData>
            </a:graphic>
          </wp:inline>
        </w:drawing>
      </w:r>
    </w:p>$hiddenText''';
}

String _hiddenTextXml(String text) {
  if (text.trim().isEmpty) return '';
  final runs = text
      .split('\n')
      .map(_escapeXml)
      .map((line) =>
          '<w:r><w:rPr><w:vanish/></w:rPr><w:t xml:space="preserve">$line</w:t></w:r>')
      .join('<w:r><w:rPr><w:vanish/></w:rPr><w:br/></w:r>');
  return '\n    <w:p>$runs</w:p>';
}

String _pageBreakXml() {
  return '    <w:p><w:r><w:br w:type="page"/></w:r></w:p>';
}

String _sectionPropertiesXml(PdfPageSnapshot page) {
  final widthTwips = _pointsToTwips(page.widthPoints);
  final heightTwips = _pointsToTwips(page.heightPoints);
  return '''<w:sectPr>
      <w:pgSz w:w="$widthTwips" w:h="$heightTwips"/>
      <w:pgMar w:top="0" w:right="0" w:bottom="0" w:left="0" w:header="0" w:footer="0" w:gutter="0"/>
    </w:sectPr>''';
}

String _imageRelId(int index) => 'rIdPageImage${index + 1}';

int _pointsToEmu(double points) => (points * 12700).round();

int _pointsToTwips(double points) => (points * 20).round();

String _shortAltText(PdfPageSnapshot page) {
  final text = page.searchableText.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.isEmpty) return 'Preserved PDF page ${page.pageNumber}';
  return text.length <= 240 ? text : '${text.substring(0, 237)}...';
}

String _paragraphXml(String text) {
  final runs = text
      .split('\n')
      .map(_escapeXml)
      .map((line) => '<w:r><w:t xml:space="preserve">$line</w:t></w:r>')
      .join('<w:r><w:br/></w:r>');
  return '    <w:p>$runs</w:p>';
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;')
      .replaceAll(RegExp('[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
}

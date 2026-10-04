import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_format_converter/services/conversion_services.dart';
import 'package:file_format_converter/services/file_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';

class _TempStorageService extends FileStorageService {
  _TempStorageService(this.directory);

  final Directory directory;

  @override
  Future<Directory> get outputDirectory async => directory;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('scanned PDF OCR converts image text into DOCX text',
      (tester) async {
    final tempDir = await Directory.systemTemp.createTemp('ffc_device_ocr_');
    try {
      final imageFile = File('${tempDir.path}/ocr-source.png');
      await imageFile.writeAsBytes(_buildClearTextPng(), flush: true);

      final storage = _TempStorageService(tempDir);
      final pdfPath =
          await ImageToPdfService(storage).convert([imageFile.path]);
      final docxPath = await PdfToDocxService(
        storage,
        ocrDpi: 160,
        minTextCharactersBeforeOcr: 1000,
      ).convert(pdfPath);

      final archive =
          ZipDecoder().decodeBytes(await File(docxPath).readAsBytes());
      final documentXml = archive.findFile('word/document.xml');
      expect(documentXml, isNotNull);

      final text = utf8
          .decode(documentXml!.content)
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .toUpperCase();

      expect(text, contains('OCR'));
      expect(text, contains('12345'));

      final roundTripPdfPath =
          await DocxToPdfService(storage).convert(docxPath);
      final roundTripBytes = await File(roundTripPdfPath).readAsBytes();
      expect(roundTripPdfPath, endsWith('.pdf'));
      expect(ascii.decode(roundTripBytes.take(4).toList()), '%PDF');
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  });
}

List<int> _buildClearTextPng() {
  final image = img.Image(width: 1500, height: 900);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  img.drawString(
    image,
    'OCR VERIFY 12345',
    font: img.arial48,
    x: 90,
    y: 260,
    color: img.ColorRgb8(0, 0, 0),
  );
  img.drawString(
    image,
    'FILE CONVERTER TEST',
    font: img.arial48,
    x: 90,
    y: 340,
    color: img.ColorRgb8(0, 0, 0),
  );
  return img.encodePng(image);
}

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Manages all local file I/O for converted output files.
class FileStorageService {
  static const String _outputFolderName = 'FileFormatConverter';

  /// Returns (and creates if needed) the app's dedicated output directory.
  Future<Directory> get outputDirectory async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _outputFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Build a unique output file path inside the output directory.
  Future<String> buildOutputPath(String baseName, String extension) async {
    final dir = await outputDirectory;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeBaseName = _safeFileName(baseName);
    final safeExtension = extension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    var candidate =
        p.join(dir.path, '${safeBaseName}_$timestamp.$safeExtension');
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = p.join(
          dir.path, '${safeBaseName}_${timestamp}_$suffix.$safeExtension');
      suffix++;
    }
    return candidate;
  }

  /// Write [bytes] to [filePath].
  Future<File> writeBytes(String filePath, List<int> bytes) async {
    final file = File(filePath);
    return file.writeAsBytes(bytes);
  }

  /// List all files in the output directory.
  Future<List<File>> listOutputFiles() async {
    final dir = await outputDirectory;
    return dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  /// Delete a file by path.
  Future<void> deleteFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Rename a file.
  Future<String> renameFile(String filePath, String newBaseName) async {
    final file = File(filePath);
    final ext = p.extension(filePath);
    final dir = p.dirname(filePath);
    var newPath = p.join(dir, '${_safeFileName(newBaseName)}$ext');
    var suffix = 1;
    while (await File(newPath).exists()) {
      newPath = p.join(dir, '${_safeFileName(newBaseName)}_$suffix$ext');
      suffix++;
    }
    final renamed = await file.rename(newPath);
    return renamed.path;
  }

  /// Get file size in bytes.
  Future<int> fileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) return await file.length();
    return 0;
  }

  String _safeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
    return sanitized.isEmpty ? 'converted_file' : sanitized;
  }
}

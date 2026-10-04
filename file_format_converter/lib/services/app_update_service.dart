import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int versionCode;
  final String minVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final String publishedAt;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.minVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.publishedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      minVersion: json['min_version'] as String? ?? '1.0.0',
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? false,
      publishedAt: json['published_at'] as String? ?? '',
    );
  }
}

class AppUpdateService {
  static const String versionJsonUrl =
      'https://file-converter-releases-214516808070.s3.ap-southeast-2.amazonaws.com/version.json';

  /// Checks AWS S3 for a new app update.
  /// Returns [AppUpdateInfo] if a newer version is available, null otherwise.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(versionJsonUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = json.decode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      final updateInfo = AppUpdateInfo.fromJson(data);

      final currentVersion = await _getCurrentVersion();
      if (_isVersionNewer(updateInfo.latestVersion, currentVersion)) {
        return updateInfo;
      }
    } catch (_) {}
    return null;
  }

  /// Downloads the APK directly from AWS S3 with live progress tracking
  Future<String?> downloadApk(
    String downloadUrl, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw HttpException('Download failed (${response.statusCode})');
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = Directory.systemTemp;
      final filePath =
          '${tempDir.path}${Platform.pathSeparator}update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      var receivedBytes = 0;
      await response.stream.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (contentLength > 0) {
            onProgress?.call(
              receivedBytes / contentLength,
              receivedBytes,
              contentLength,
            );
          }
        },
        cancelOnError: true,
      ).asFuture();

      await sink.flush();
      await sink.close();
      client.close();

      return filePath;
    } catch (_) {
      return null;
    }
  }

  /// Launches the downloaded APK to prompt native installation,
  /// or opens the download URL in the browser if APK install isn't supported.
  Future<bool> installApk(String filePath, {String? fallbackUrl}) async {
    try {
      if (Platform.isAndroid && await File(filePath).exists()) {
        final result = await OpenFilex.open(
          filePath,
          type: 'application/vnd.android.package-archive',
        );
        if (result.type == ResultType.done) {
          return true;
        }
      }
    } catch (_) {}

    // Fallback: open URL in browser
    if (fallbackUrl != null && fallbackUrl.isNotEmpty) {
      final uri = Uri.parse(fallbackUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
    }
    return false;
  }

  Future<String> _getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return AppConstants.appVersion;
    }
  }

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0)
  bool _isVersionNewer(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (var i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return latest != current;
    }
  }
}

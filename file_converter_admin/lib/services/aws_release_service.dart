import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import '../config/aws_config.dart';

class AppReleaseInfo {
  final String latestVersion;
  final int versionCode;
  final String minVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;
  final String publishedAt;

  const AppReleaseInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.minVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.publishedAt,
  });

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    return AppReleaseInfo(
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 1,
      minVersion: json['min_version'] as String? ?? '1.0.0',
      downloadUrl: json['download_url'] as String? ?? '',
      releaseNotes: json['release_notes'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? false,
      publishedAt: json['published_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'latest_version': latestVersion,
        'version_code': versionCode,
        'min_version': minVersion,
        'download_url': downloadUrl,
        'release_notes': releaseNotes,
        'force_update': forceUpdate,
        'published_at': publishedAt,
      };
}

class AwsReleaseService {
  /// Fetches the current live version information from AWS S3
  Future<AppReleaseInfo?> fetchCurrentLiveRelease() async {
    try {
      final response = await http.get(
        Uri.parse(AwsConfig.versionJsonUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        return AppReleaseInfo.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// Publishes a new app release to AWS S3.
  /// If [apkFile] is provided, uploads it directly to S3 and generates the download URL.
  Future<AppReleaseInfo> publishRelease({
    required String versionName,
    required int versionCode,
    required String releaseNotes,
    required bool forceUpdate,
    File? apkFile,
    String? customDownloadUrl,
    void Function(double progress, String status)? onProgress,
  }) async {
    await AwsConfig.initCredentials();
    String finalDownloadUrl = customDownloadUrl?.trim() ?? '';

    // 1. Upload APK to S3 if provided
    if (apkFile != null && await apkFile.exists()) {
      onProgress?.call(0.1, 'Uploading APK to AWS S3...');
      final s3Key = 'releases/app-v$versionName.apk';
      final fileBytes = await apkFile.readAsBytes();

      await _putS3Object(
        key: s3Key,
        data: fileBytes,
        contentType: 'application/vnd.android.package-archive',
      );

      finalDownloadUrl = '${AwsConfig.publicBaseUrl}/$s3Key';
      onProgress?.call(0.7, 'APK uploaded successfully.');
    }

    // 2. Upload updated version.json to S3
    onProgress?.call(0.8, 'Publishing version.json to AWS S3...');
    final releaseInfo = AppReleaseInfo(
      latestVersion: versionName,
      versionCode: versionCode,
      minVersion: forceUpdate ? versionName : '1.0.0',
      downloadUrl: finalDownloadUrl,
      releaseNotes: releaseNotes,
      forceUpdate: forceUpdate,
      publishedAt: DateTime.now().toUtc().toIso8601String(),
    );

    final jsonBytes = utf8.encode(json.encode(releaseInfo.toJson()));
    await _putS3Object(
      key: 'version.json',
      data: Uint8List.fromList(jsonBytes),
      contentType: 'application/json',
    );

    onProgress?.call(1.0, 'Release published live to AWS!');
    return releaseInfo;
  }

  /// Uploads data to Amazon S3 using AWS Signature Version 4 (SigV4)
  Future<void> _putS3Object({
    required String key,
    required Uint8List data,
    required String contentType,
  }) async {
    final host = '${AwsConfig.bucketName}.s3.${AwsConfig.region}.amazonaws.com';
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);

    final payloadHash = sha256.convert(data).toString();
    final canonicalUri = '/$key';

    // Canonical headers (must be lowercase and alphabetically sorted)
    final canonicalHeaders =
        'content-type:$contentType\nhost:$host\nx-amz-content-sha256:$payloadHash\nx-amz-date:$amzDate\n';
    const signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';

    final canonicalRequest =
        'PUT\n$canonicalUri\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final canonicalRequestHash =
        sha256.convert(utf8.encode(canonicalRequest)).toString();

    // String to sign
    final credentialScope = '$dateStamp/${AwsConfig.region}/s3/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n$canonicalRequestHash';

    // Signing key derivation
    final signingKey = _getSignatureKey(
      AwsConfig.secretAccessKey,
      dateStamp,
      AwsConfig.region,
      's3',
    );

    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 Credential=${AwsConfig.accessKeyId}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    final url = Uri.parse('https://$host$canonicalUri');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': contentType,
        'Host': host,
        'x-amz-date': amzDate,
        'x-amz-content-sha256': payloadHash,
        'Authorization': authorization,
      },
      body: data,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw HttpException(
        'Failed to upload to S3 (${response.statusCode}): ${response.body}',
      );
    }
  }

  static String _formatAmzDate(DateTime dt) {
    return '${_formatDateStamp(dt)}T${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}Z';
  }

  static String _formatDateStamp(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static List<int> _getSignatureKey(
    String key,
    String dateStamp,
    String regionName,
    String serviceName,
  ) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }
}

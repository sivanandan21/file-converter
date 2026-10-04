import 'dart:convert';
import 'dart:io';

/// AWS S3 Configuration for App Updates & Releases
class AwsConfig {
  AwsConfig._();

  static const String bucketName = 'file-converter-releases-214516808070';
  static const String region = 'ap-southeast-2';

  /// AWS IAM Credentials for S3 uploads.
  /// Kept private — not committed to public repositories.
  static String accessKeyId = const String.fromEnvironment(
    'AWS_ACCESS_KEY_ID',
    defaultValue: '',
  );

  static String secretAccessKey = const String.fromEnvironment(
    'AWS_SECRET_ACCESS_KEY',
    defaultValue: '',
  );

  /// Public base URL for downloading files
  static const String publicBaseUrl =
      'https://$bucketName.s3.$region.amazonaws.com';

  /// Public URL for the version info JSON
  static const String versionJsonUrl = '$publicBaseUrl/version.json';

  /// Loads local untracked credentials if present
  static Future<void> initCredentials() async {
    if (accessKeyId.isNotEmpty && secretAccessKey.isNotEmpty) return;
    try {
      final candidates = [
        File('aws_credentials.local.json'),
        File('../aws_credentials.local.json'),
      ];
      for (final f in candidates) {
        if (await f.exists()) {
          final data =
              json.decode(await f.readAsString()) as Map<String, dynamic>;
          if (data['accessKeyId'] != null) {
            accessKeyId = data['accessKeyId'].toString();
          }
          if (data['secretAccessKey'] != null) {
            secretAccessKey = data['secretAccessKey'].toString();
          }
          return;
        }
      }
    } catch (_) {}
  }
}

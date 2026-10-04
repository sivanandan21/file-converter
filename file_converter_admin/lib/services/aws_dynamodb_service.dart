import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/aws_config.dart';

/// Service for interacting directly with AWS DynamoDB using AWS SigV4
class AwsDynamoDbService {
  static const String tableName = 'file_converter_devices';

  /// Scans all user devices registered in DynamoDB
  Future<List<Map<String, dynamic>>> scanDevices() async {
    await AwsConfig.initCredentials();
    try {
      final payload = json.encode({
        'TableName': tableName,
      });

      final responseBody = await _callDynamo(
        target: 'DynamoDB_20120810.Scan',
        payload: payload,
      );

      final decoded = json.decode(responseBody) as Map<String, dynamic>;
      final rawItems = decoded['Items'] as List<dynamic>? ?? [];

      return rawItems.map((item) => _unmarshal(item as Map<String, dynamic>)).toList()
        ..sort((a, b) {
          final bSeen = b['last_seen']?.toString() ?? '';
          final aSeen = a['last_seen']?.toString() ?? '';
          return bSeen.compareTo(aSeen);
        });
    } catch (e) {
      debugPrint('[AwsDynamoDbService] scanDevices error: $e');
      rethrow;
    }
  }

  /// Gets a single device by ID
  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    await AwsConfig.initCredentials();
    try {
      final payload = json.encode({
        'TableName': tableName,
        'Key': {
          'device_id': {'S': deviceId},
        },
      });

      final responseBody = await _callDynamo(
        target: 'DynamoDB_20120810.GetItem',
        payload: payload,
      );

      final decoded = json.decode(responseBody) as Map<String, dynamic>;
      final item = decoded['Item'] as Map<String, dynamic>?;
      if (item == null) return null;
      return _unmarshal(item);
    } catch (e) {
      debugPrint('[AwsDynamoDbService] getDevice error: $e');
      return null;
    }
  }

  /// Updates the user's plan ('free', 'premium', 'lifetime')
  Future<void> updateDevicePlan(String deviceId, String plan) async {
    await AwsConfig.initCredentials();
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = json.encode({
      'TableName': tableName,
      'Key': {
        'device_id': {'S': deviceId},
      },
      'UpdateExpression': 'SET #p = :plan, #u = :updated_at',
      'ExpressionAttributeNames': {
        '#p': 'plan',
        '#u': 'plan_updated_at',
      },
      'ExpressionAttributeValues': {
        ':plan': {'S': plan},
        ':updated_at': {'S': now},
      },
    });

    await _callDynamo(
      target: 'DynamoDB_20120810.UpdateItem',
      payload: payload,
    );
  }

  /// Sends a force-logout signal to the user device
  Future<void> setForceLogout(String deviceId, bool forceLogout) async {
    await AwsConfig.initCredentials();
    final payload = json.encode({
      'TableName': tableName,
      'Key': {
        'device_id': {'S': deviceId},
      },
      'UpdateExpression': 'SET #fl = :force_logout',
      'ExpressionAttributeNames': {
        '#fl': 'force_logout',
      },
      'ExpressionAttributeValues': {
        ':force_logout': {'BOOL': forceLogout},
      },
    });

    await _callDynamo(
      target: 'DynamoDB_20120810.UpdateItem',
      payload: payload,
    );
  }

  /// Resets daily quotas for the user
  Future<void> resetQuotas(String deviceId) async {
    await AwsConfig.initCredentials();
    final payload = json.encode({
      'TableName': tableName,
      'Key': {
        'device_id': {'S': deviceId},
      },
      'UpdateExpression': 'SET #qc = :zero, #qa = :zero',
      'ExpressionAttributeNames': {
        '#qc': 'daily_conversions',
        '#qa': 'daily_rewarded_ads',
      },
      'ExpressionAttributeValues': {
        ':zero': {'N': '0'},
      },
    });

    await _callDynamo(
      target: 'DynamoDB_20120810.UpdateItem',
      payload: payload,
    );
  }

  /// Deletes a device record from DynamoDB
  Future<void> deleteDevice(String deviceId) async {
    await AwsConfig.initCredentials();
    final payload = json.encode({
      'TableName': tableName,
      'Key': {
        'device_id': {'S': deviceId},
      },
    });

    await _callDynamo(
      target: 'DynamoDB_20120810.DeleteItem',
      payload: payload,
    );
  }

  // ── AWS SigV4 DynamoDB HTTP Transport ──────────────────────────────────────────

  Future<String> _callDynamo({
    required String target,
    required String payload,
  }) async {
    final host = 'dynamodb.${AwsConfig.region}.amazonaws.com';
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final payloadBytes = utf8.encode(payload);
    final payloadHash = sha256.convert(payloadBytes).toString();

    final canonicalHeaders =
        'content-type:application/x-amz-json-1.0\nhost:$host\nx-amz-date:$amzDate\nx-amz-target:$target\n';
    const signedHeaders = 'content-type;host;x-amz-date;x-amz-target';

    final canonicalRequest =
        'POST\n/\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
    final canonicalRequestHash =
        sha256.convert(utf8.encode(canonicalRequest)).toString();

    final credentialScope =
        '$dateStamp/${AwsConfig.region}/dynamodb/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n$canonicalRequestHash';

    final signingKey = _getSignatureKey(
      AwsConfig.secretAccessKey,
      dateStamp,
      AwsConfig.region,
      'dynamodb',
    );

    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 Credential=${AwsConfig.accessKeyId}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

    final response = await http.post(
      Uri.parse('https://$host/'),
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'Host': host,
        'x-amz-date': amzDate,
        'x-amz-target': target,
        'Authorization': authorization,
      },
      body: payload,
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'DynamoDB error (${response.statusCode}): ${response.body}',
      );
    }
    return response.body;
  }

  // ── Attribute Unmarshaling ───────────────────────────────────────────────────

  static Map<String, dynamic> _unmarshal(Map<String, dynamic> item) {
    final result = <String, dynamic>{};
    for (final entry in item.entries) {
      result[entry.key] = _unmarshalValue(entry.value);
    }
    return result;
  }

  static dynamic _unmarshalValue(dynamic val) {
    if (val is! Map) return val;
    if (val.containsKey('S')) return val['S'];
    if (val.containsKey('N')) {
      final str = val['N'].toString();
      return int.tryParse(str) ?? double.tryParse(str) ?? str;
    }
    if (val.containsKey('BOOL')) return val['BOOL'];
    if (val.containsKey('NULL')) return null;
    if (val.containsKey('M')) return _unmarshal(val['M'] as Map<String, dynamic>);
    if (val.containsKey('L')) {
      return (val['L'] as List).map(_unmarshalValue).toList();
    }
    return val;
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
    final kDate = Hmac(sha256, utf8.encode('AWS4$key'))
        .convert(utf8.encode(dateStamp))
        .bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService =
        Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    final kSigning =
        Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    return kSigning;
  }
}

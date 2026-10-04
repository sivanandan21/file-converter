import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../repositories/user_device_repository.dart';

/// AWS DynamoDB implementation of [UserDeviceRepository] — PRIMARY backend.
/// Interacts directly with AWS DynamoDB table `file_converter_devices` in `ap-southeast-2`.
class AwsDynamoDbUserDeviceRepository implements UserDeviceRepository {
  static const String tableName = 'file_converter_devices';
  static const String region = 'ap-southeast-2';

  String _accessKeyId;
  String _secretAccessKey;

  AwsDynamoDbUserDeviceRepository({
    String? accessKeyId,
    String? secretAccessKey,
  })  : _accessKeyId = accessKeyId ??
            const String.fromEnvironment('AWS_ACCESS_KEY_ID', defaultValue: ''),
        _secretAccessKey = secretAccessKey ??
            const String.fromEnvironment('AWS_SECRET_ACCESS_KEY',
                defaultValue: '') {
    if (_accessKeyId.isEmpty || _secretAccessKey.isEmpty) {
      _loadLocalCredentials();
    }
  }

  void _loadLocalCredentials() {
    try {
      final candidates = [
        File('aws_credentials.local.json'),
        File('../aws_credentials.local.json'),
      ];
      for (final f in candidates) {
        if (f.existsSync()) {
          final data =
              json.decode(f.readAsStringSync()) as Map<String, dynamic>;
          if (_accessKeyId.isEmpty && data['accessKeyId'] != null) {
            _accessKeyId = data['accessKeyId'].toString();
          }
          if (_secretAccessKey.isEmpty && data['secretAccessKey'] != null) {
            _secretAccessKey = data['secretAccessKey'].toString();
          }
          return;
        }
      }
    } catch (_) {}
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
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
      debugPrint('[AwsDynamoDb] getDevice error: $e');
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> queryDevices({
    Map<String, dynamic> filter = const {},
  }) async {
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
      var items = rawItems
          .map((item) => _unmarshal(item as Map<String, dynamic>))
          .toList();

      if (filter.isNotEmpty) {
        items = items.where((item) {
          for (final entry in filter.entries) {
            if (item[entry.key]?.toString() != entry.value?.toString()) {
              return false;
            }
          }
          return true;
        }).toList();
      }

      return items;
    } catch (e) {
      debugPrint('[AwsDynamoDb] queryDevices error: $e');
      return [];
    }
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  @override
  Future<void> insertDevice(Map<String, dynamic> data) async {
    await upsertDevice(data['device_id']?.toString() ?? '', data);
  }

  @override
  Future<void> upsertDevice(String deviceId, Map<String, dynamic> data) async {
    final item = _marshal({...data, 'device_id': deviceId});
    final payload = json.encode({
      'TableName': tableName,
      'Item': item,
    });

    await _callDynamo(
      target: 'DynamoDB_20120810.PutItem',
      payload: payload,
    );
  }

  @override
  Future<void> updateDevice(
    String deviceId,
    Map<String, dynamic> fields,
  ) async {
    if (fields.isEmpty) return;

    final expParts = <String>[];
    final names = <String, String>{};
    final values = <String, dynamic>{};

    var i = 0;
    for (final entry in fields.entries) {
      final namePlaceholder = '#f$i';
      final valPlaceholder = ':v$i';
      expParts.add('$namePlaceholder = $valPlaceholder');
      names[namePlaceholder] = entry.key;
      values[valPlaceholder] = _marshalValue(entry.value);
      i++;
    }

    final payload = json.encode({
      'TableName': tableName,
      'Key': {
        'device_id': {'S': deviceId},
      },
      'UpdateExpression': 'SET ${expParts.join(', ')}',
      'ExpressionAttributeNames': names,
      'ExpressionAttributeValues': values,
    });

    await _callDynamo(
      target: 'DynamoDB_20120810.UpdateItem',
      payload: payload,
    );
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
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

  // ── RPC / Atomic Counter ───────────────────────────────────────────────────

  @override
  Future<void> incrementCounter(
    String deviceId,
    String column, {
    int by = 1,
  }) async {
    try {
      final payload = json.encode({
        'TableName': tableName,
        'Key': {
          'device_id': {'S': deviceId},
        },
        'UpdateExpression': 'ADD #col :val',
        'ExpressionAttributeNames': {'#col': column},
        'ExpressionAttributeValues': {
          ':val': {'N': by.toString()}
        },
      });

      await _callDynamo(
        target: 'DynamoDB_20120810.UpdateItem',
        payload: payload,
      );
    } catch (_) {
      // Fallback: read-modify-write
      final existing = await getDevice(deviceId);
      final current = (existing?[column] as num?)?.toInt() ?? 0;
      await updateDevice(deviceId, {column: current + by});
    }
  }

  // ── Health ───────────────────────────────────────────────────────────────────

  @override
  Future<bool> isHealthy() async {
    try {
      final payload = json.encode({
        'TableName': tableName,
        'Limit': 1,
      });
      await _callDynamo(
        target: 'DynamoDB_20120810.Scan',
        payload: payload,
      ).timeout(const Duration(seconds: 4));
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── HTTP SigV4 Transport ───────────────────────────────────────────────────

  Future<String> _callDynamo({
    required String target,
    required String payload,
  }) async {
    const host = 'dynamodb.$region.amazonaws.com';
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

    final credentialScope = '$dateStamp/$region/dynamodb/aws4_request';
    final stringToSign =
        'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n$canonicalRequestHash';

    final signingKey = _getSignatureKey(
      _secretAccessKey,
      dateStamp,
      region,
      'dynamodb',
    );

    final signature =
        Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 Credential=$_accessKeyId/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';

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

  // ── Marshaling Helpers ──────────────────────────────────────────────────────

  static Map<String, dynamic> _marshal(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(key, _marshalValue(value)));
  }

  static dynamic _marshalValue(dynamic val) {
    if (val == null) return {'NULL': true};
    if (val is bool) return {'BOOL': val};
    if (val is num) return {'N': val.toString()};
    if (val is String) return {'S': val};
    if (val is List) {
      return {'L': val.map(_marshalValue).toList()};
    }
    if (val is Map<String, dynamic>) {
      return {'M': _marshal(val)};
    }
    return {'S': val.toString()};
  }

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

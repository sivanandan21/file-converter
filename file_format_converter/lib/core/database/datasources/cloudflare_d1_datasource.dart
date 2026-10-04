import 'dart:convert';
import 'package:http/http.dart' as http;
import '../repositories/user_device_repository.dart';

/// Cloudflare D1 implementation — the SECONDARY (first failover) backend.
///
/// Cloudflare D1 has no native Flutter SDK so we call it through a
/// Cloudflare Worker REST endpoint that you deploy once (see worker/d1_worker.js
/// in the project root).
///
/// Worker environment variables required:
///   DB      → D1 database binding
///   API_KEY → shared secret to authenticate requests from the app
class CloudflareD1UserDeviceRepository implements UserDeviceRepository {
  final String _workerUrl;   // e.g. https://d1-worker.your-name.workers.dev
  final String _apiKey;      // secret header value
  final http.Client _http;

  static const _timeout = Duration(seconds: 8);

  CloudflareD1UserDeviceRepository({
    required String workerUrl,
    required String apiKey,
    http.Client? httpClient,
  })  : _workerUrl = workerUrl.trimRight().replaceAll('/', '').isEmpty
            ? workerUrl
            : workerUrl,
        _apiKey = apiKey,
        _http = httpClient ?? http.Client();

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
      };

  Uri _uri(String path) => Uri.parse('$_workerUrl$path');

  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final res = await _http
        .post(_uri(path),
            headers: _headers, body: jsonEncode(body))
        .timeout(_timeout);
    if (res.statusCode >= 400) {
      throw Exception('D1 Worker error ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  Future<dynamic> _get(String path,
      {Map<String, String>? queryParams}) async {
    final uri = queryParams != null
        ? _uri(path).replace(queryParameters: queryParams)
        : _uri(path);
    final res = await _http
        .get(uri, headers: _headers)
        .timeout(_timeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode >= 400) {
      throw Exception('D1 Worker error ${res.statusCode}: ${res.body}');
    }
    return jsonDecode(res.body);
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    final data = await _get('/devices/$deviceId');
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> queryDevices({
    Map<String, dynamic> filter = const {},
  }) async {
    final params = filter.map((k, v) => MapEntry(k, v.toString()));
    final data = await _get('/devices', queryParams: params);
    if (data == null) return [];
    final list = data as List<dynamic>;
    return list
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  @override
  Future<void> insertDevice(Map<String, dynamic> data) async {
    await _post('/devices', {'action': 'insert', 'data': data});
  }

  @override
  Future<void> upsertDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    await _post('/devices', {
      'action': 'upsert',
      'device_id': deviceId,
      'data': data,
    });
  }

  @override
  Future<void> updateDevice(
    String deviceId,
    Map<String, dynamic> fields,
  ) async {
    await _post('/devices/$deviceId', {
      'action': 'update',
      'fields': fields,
    });
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await _http
        .delete(_uri('/devices/$deviceId'), headers: _headers)
        .timeout(_timeout);
  }

  // ── RPC ─────────────────────────────────────────────────────────────────────

  @override
  Future<void> incrementCounter(
    String deviceId,
    String column, {
    int by = 1,
  }) async {
    await _post('/devices/$deviceId/increment', {
      'column': column,
      'by': by,
    });
  }

  // ── Health ───────────────────────────────────────────────────────────────────

  @override
  Future<bool> isHealthy() async {
    try {
      await _get('/health');
      return true;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as aw;
import '../repositories/user_device_repository.dart';

/// Appwrite implementation — the TERTIARY (last-resort) backend.
///
/// Uses Appwrite Databases (NoSQL document store).
///
/// Setup steps (one-time):
///   1. Create an Appwrite project and note the Project ID.
///   2. Create a Database named "file_converter_db".
///   3. Create a Collection named "user_devices" with the same attributes
///      as the DynamoDB `file_converter_devices` table.
///   4. Set collection permissions to allow your API key to read/write.
///   5. Fill in AppwriteConfig below (or inject via DatabaseManager).
class AppwriteUserDeviceRepository implements UserDeviceRepository {
  final Databases _db;
  final String _databaseId;
  final String _collectionId;

  static const _timeout = Duration(seconds: 8);

  AppwriteUserDeviceRepository({
    required Client client,
    String? apiKey,
    String databaseId = 'file_converter_db',
    String collectionId = 'user_devices',
  })  : _db = Databases(
          apiKey != null
              ? (client..addHeader('X-Appwrite-Key', apiKey))
              : client,
        ),
        _databaseId = databaseId,
        _collectionId = collectionId;

  // ── Helpers ─────────────────────────────────────────────────────────────────

  /// Appwrite documents use '\$id' as the primary key.
  /// We map [deviceId] ↔ document ID so queries are O(1).
  String _docId(String deviceId) =>
      // Appwrite IDs must be ≤36 chars; hash long IDs.
      deviceId.length <= 36
          ? deviceId
          : deviceId.substring(0, 36);

  Map<String, dynamic> _docToMap(aw.Document doc) {
    final data = Map<String, dynamic>.from(doc.data);
    data['device_id'] = doc.$id;
    // Appwrite stores JSON sub-objects as strings; decode them.
    if (data['conversions_by_type'] is String) {
      try {
        data['conversions_by_type'] =
            jsonDecode(data['conversions_by_type'] as String);
      } catch (_) {}
    }
    return data;
  }

  Map<String, dynamic> _prepareWrite(Map<String, dynamic> data) {
    final out = Map<String, dynamic>.from(data);
    out.remove('device_id'); // stored as document $id, not a field
    // Appwrite doesn't support nested JSON natively; serialise it.
    if (out['conversions_by_type'] is Map) {
      out['conversions_by_type'] =
          jsonEncode(out['conversions_by_type']);
    }
    return out;
  }

  // ── Read ────────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    try {
      final doc = await _db
          .getDocument(
            databaseId: _databaseId,
            collectionId: _collectionId,
            documentId: _docId(deviceId),
          )
          .timeout(_timeout);
      return _docToMap(doc);
    } on AppwriteException catch (e) {
      if (e.code == 404) return null;
      rethrow;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> queryDevices({
    Map<String, dynamic> filter = const {},
  }) async {
    final queries = filter.entries
        .map((e) => Query.equal(e.key, e.value))
        .toList();
    final result = await _db
        .listDocuments(
          databaseId: _databaseId,
          collectionId: _collectionId,
          queries: queries,
        )
        .timeout(_timeout);
    return result.documents.map(_docToMap).toList();
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  @override
  Future<void> insertDevice(Map<String, dynamic> data) async {
    final deviceId = data['device_id']?.toString() ?? ID.unique();
    await _db
        .createDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: _docId(deviceId),
          data: _prepareWrite(data),
        )
        .timeout(_timeout);
  }

  @override
  Future<void> upsertDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _db
          .updateDocument(
            databaseId: _databaseId,
            collectionId: _collectionId,
            documentId: _docId(deviceId),
            data: _prepareWrite(data),
          )
          .timeout(_timeout);
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        await insertDevice({...data, 'device_id': deviceId});
      } else {
        rethrow;
      }
    }
  }

  @override
  Future<void> updateDevice(
    String deviceId,
    Map<String, dynamic> fields,
  ) async {
    await _db
        .updateDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: _docId(deviceId),
          data: _prepareWrite(fields),
        )
        .timeout(_timeout);
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await _db
        .deleteDocument(
          databaseId: _databaseId,
          collectionId: _collectionId,
          documentId: _docId(deviceId),
        )
        .timeout(_timeout);
  }

  // ── RPC ─────────────────────────────────────────────────────────────────────

  @override
  Future<void> incrementCounter(
    String deviceId,
    String column, {
    int by = 1,
  }) async {
    // Appwrite has no atomic increment; use read-modify-write.
    final row = await getDevice(deviceId);
    if (row == null) return;
    final current = (row[column] as num?)?.toInt() ?? 0;
    await updateDevice(deviceId, {column: current + by});
  }

  // ── Health ───────────────────────────────────────────────────────────────────

  @override
  Future<bool> isHealthy() async {
    try {
      await _db
          .listDocuments(
            databaseId: _databaseId,
            collectionId: _collectionId,
            queries: [Query.limit(1)],
          )
          .timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }
}

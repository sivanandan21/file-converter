/// Abstract interface every database backend must implement.
///
/// The [UserDeviceRepository] is the single contract used by the rest of the
/// app. Callers never reference a concrete implementation; they talk to the
/// [DatabaseManager] which selects the live backend transparently.
abstract class UserDeviceRepository {
  // ── Read ──────────────────────────────────────────────────────────────────

  /// Fetch a single row by [deviceId]. Returns null when not found.
  Future<Map<String, dynamic>?> getDevice(String deviceId);

  /// Fetch multiple rows matching the given [filter] (column → value).
  /// Pass an empty map to fetch all rows.
  Future<List<Map<String, dynamic>>> queryDevices({
    Map<String, dynamic> filter = const {},
  });

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Insert [data] as a new row. Throws on duplicate key constraint.
  Future<void> insertDevice(Map<String, dynamic> data);

  /// Upsert [data] keyed on [deviceId]. Creates or replaces the row.
  Future<void> upsertDevice(String deviceId, Map<String, dynamic> data);

  /// Update specific [fields] on the row identified by [deviceId].
  Future<void> updateDevice(String deviceId, Map<String, dynamic> fields);

  /// Delete the row identified by [deviceId].
  Future<void> deleteDevice(String deviceId);

  // ── RPC / Helpers ─────────────────────────────────────────────────────────

  /// Increment a numeric counter column atomically.
  /// Falls back to a read-modify-write if the backend has no native RPC.
  Future<void> incrementCounter(
    String deviceId,
    String column, {
    int by = 1,
  });

  // ── Health check ──────────────────────────────────────────────────────────

  /// Returns true if the backend can currently accept write operations.
  /// This is called by [DatabaseManager] before every write to decide
  /// whether a failover is needed.
  Future<bool> isHealthy();
}

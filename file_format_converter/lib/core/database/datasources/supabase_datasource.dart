import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/user_device_repository.dart';

/// Supabase implementation — the PRIMARY backend.
///
/// Uses the existing `user_devices` table and `log_conversion` RPC that the
/// rest of the app already depends on. No schema changes required.
class SupabaseUserDeviceRepository implements UserDeviceRepository {
  final SupabaseClient _client;

  SupabaseUserDeviceRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── Read ────────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDevice(String deviceId) async {
    final row = await _client
        .from('user_devices')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<List<Map<String, dynamic>>> queryDevices({
    Map<String, dynamic> filter = const {},
  }) async {
    var query = _client.from('user_devices').select();
    for (final entry in filter.entries) {
      query = query.eq(entry.key, entry.value);
    }
    final result = await query;
    return List<Map<String, dynamic>>.from(result);
  }

  // ── Write ───────────────────────────────────────────────────────────────────

  @override
  Future<void> insertDevice(Map<String, dynamic> data) async {
    await _client.from('user_devices').insert(data);
  }

  @override
  Future<void> upsertDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    await _client
        .from('user_devices')
        .upsert({...data, 'device_id': deviceId});
  }

  @override
  Future<void> updateDevice(
    String deviceId,
    Map<String, dynamic> fields,
  ) async {
    await _client
        .from('user_devices')
        .update(fields)
        .eq('device_id', deviceId);
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    await _client
        .from('user_devices')
        .delete()
        .eq('device_id', deviceId);
  }

  // ── RPC ─────────────────────────────────────────────────────────────────────

  @override
  Future<void> incrementCounter(
    String deviceId,
    String column, {
    int by = 1,
  }) async {
    // Use the existing log_conversion RPC for total_conversions on non-quota rows.
    // For all other columns (session_count, etc.) use read-modify-write.
    if (column == 'total_conversions' &&
        !deviceId.startsWith('quota:')) {
      try {
        await _client.rpc('log_conversion', params: {
          'did': deviceId,
          'type_key': 'increment',
        });
        return;
      } catch (_) {
        // Fall through to read-modify-write on RPC failure.
      }
    }
    final row = await getDevice(deviceId);
    if (row == null) return;
    final current = (row[column] as num?)?.toInt() ?? 0;
    await updateDevice(deviceId, {column: current + by});
  }

  // ── Health ───────────────────────────────────────────────────────────────────

  @override
  Future<bool> isHealthy() async {
    try {
      // Lightweight probe: fetch one row with a 5-second timeout.
      await _client
          .from('user_devices')
          .select('device_id')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      return true;
    } catch (_) {
      return false;
    }
  }
}

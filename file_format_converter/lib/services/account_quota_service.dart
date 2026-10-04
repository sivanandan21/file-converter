import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/db_manager.dart';

class AccountQuotaSnapshot {
  final int conversionsUsedToday;
  final int rewardedAdsWatchedToday;

  const AccountQuotaSnapshot({
    required this.conversionsUsedToday,
    required this.rewardedAdsWatchedToday,
  });
}

/// Stores per-account daily quota counters using the multi-database backend.
///
/// Previously wrote directly to Supabase. Now delegates to [DatabaseManager]
/// which automatically fails over to Cloudflare D1 → Appwrite. All existing
/// call sites are unchanged — [userId] resolves internally from Supabase auth.
class AccountQuotaService {
  final DatabaseManager _db;

  AccountQuotaService({required DatabaseManager db}) : _db = db;

  /// Current signed-in user ID (same Supabase auth source as before).
  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Fetch today's quota. [userId] defaults to the currently signed-in user.
  Future<AccountQuotaSnapshot?> fetchToday({String? userId}) async {
    final uid = userId ?? _userId;
    if (uid == null) return null;
    try {
      final convRow =
          await _ensureCounterRow(_rowId('conversion', uid), 'Account quota');
      final adRow = await _ensureCounterRow(
        _rowId('rewarded_ad', uid),
        'Rewarded ad quota',
      );
      return AccountQuotaSnapshot(
        conversionsUsedToday: _readCounter(convRow['total_conversions']),
        rewardedAdsWatchedToday: _readCounter(adRow['total_conversions']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<AccountQuotaSnapshot?> recordConversion(
    String typeKey, {
    String? userId,
  }) =>
      _record(kind: 'conversion', typeKey: typeKey, userId: userId ?? _userId);

  Future<AccountQuotaSnapshot?> recordRewardedAd({String? userId}) =>
      _record(
          kind: 'rewarded_ad',
          typeKey: 'rewarded_ad',
          userId: userId ?? _userId);

  // ── Internals ────────────────────────────────────────────────────────────────

  String _rowId(String kind, String userId) => 'quota:$kind:$userId';

  Future<AccountQuotaSnapshot?> _record({
    required String kind,
    required String typeKey,
    required String? userId,
  }) async {
    if (userId == null) return null;
    try {
      final rowId = _rowId(kind, userId);
      await _ensureCounterRow(rowId, 'Account quota');
      await _db.incrementCounter(rowId, 'total_conversions');
      return fetchToday(userId: userId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _ensureCounterRow(
    String rowId,
    String label,
  ) async {
    final existing = await _db.getDevice(rowId);

    if (existing != null) {
      // Reset counter if older than 24 hours.
      final osVersion = existing['os_version'] as String?;
      final startTime =
          osVersion != null ? DateTime.tryParse(osVersion) : null;
      if (startTime == null ||
          DateTime.now().difference(startTime).inHours >= 24) {
        final now = DateTime.now().toUtc().toIso8601String();
        try {
          await _db.updateDevice(rowId, {
            'total_conversions': 0,
            'os_version': now,
          });
        } catch (_) {}
        return {...existing, 'total_conversions': 0, 'os_version': now};
      }
      return existing;
    }

    // Row doesn't exist yet — create it.
    final now = DateTime.now().toUtc().toIso8601String();
    final newRow = <String, dynamic>{
      'device_id': rowId,
      'device_model': label,
      'brand': 'account',
      'os_version': now,
      'app_version': 'quota',
      'plan': 'free',
      'total_conversions': 0,
      'conversions_by_type': <String, int>{},
      'last_seen': now,
    };
    try {
      await _db.insertDevice(newRow);
    } catch (_) {
      // Another client may have inserted first; re-fetch.
    }

    return await _db.getDevice(rowId) ??
        {'device_id': rowId, 'total_conversions': 0, 'os_version': now};
  }

  int _readCounter(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

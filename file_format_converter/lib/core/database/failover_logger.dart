import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'failover_event.dart';
import 'db_provider.dart';

/// Persists failover events locally and notifies the admin via Supabase
/// (best-effort — never throws, since it runs during a failover).
class FailoverLogger {
  static const _prefsKey = 'failover_log';
  static const _maxLocalEvents = 100;

  final SharedPreferences _prefs;

  FailoverLogger(this._prefs);

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Record a failover event locally, then attempt to push it to Supabase
  /// and trigger an admin notification.
  Future<void> log(FailoverEvent event) async {
    _appendLocal(event);
    await _notifyAdmin(event);
    _printToConsole(event);
  }

  /// Returns all locally stored failover events (most-recent first).
  List<FailoverEvent> get localEvents {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FailoverEvent.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────────

  void _appendLocal(FailoverEvent event) {
    try {
      final raw = _prefs.getString(_prefsKey);
      final existing =
          raw != null ? jsonDecode(raw) as List<dynamic> : <dynamic>[];
      existing.add(event.toJson());
      // Trim to max events (keep newest)
      final trimmed = existing.length > _maxLocalEvents
          ? existing.sublist(existing.length - _maxLocalEvents)
          : existing;
      _prefs.setString(_prefsKey, jsonEncode(trimmed));
    } catch (_) {
      // Logging must never crash the app.
    }
  }

  Future<void> _notifyAdmin(FailoverEvent event) async {
    // Push a row to the `failover_log` Supabase table (best-effort).
    // The table should be created once: see db_setup.sql in project root.
    try {
      await Supabase.instance.client.from('failover_log').insert({
        'timestamp': event.timestamp.toIso8601String(),
        'from_provider': event.from.label,
        'to_provider': event.to.label,
        'reason': event.reason,
      });
    } catch (_) {
      // Supabase may itself be offline during a failover; that is fine.
    }
  }

  void _printToConsole(FailoverEvent event) {
    // ignore: avoid_print
    print('[DB-FAILOVER] $event');
  }
}

// ── Provider helper (used in db_manager.dart) ─────────────────────────────────

FailoverLogger? _instance;

FailoverLogger getFailoverLogger(SharedPreferences prefs) {
  _instance ??= FailoverLogger(prefs);
  return _instance!;
}

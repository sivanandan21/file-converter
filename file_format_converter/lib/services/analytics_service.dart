import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../core/database/db_manager.dart';

/// Silently syncs user session & usage data through AWS DynamoDB
/// (with failover to Cloudflare D1 → Appwrite).
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  DatabaseManager? _db;
  String? _deviceId;
  Timer? _planSyncTimer;

  String? get deviceId => _deviceId;

  /// Inject the failover-aware DatabaseManager (called from app.dart).
  void injectDb(DatabaseManager db) => _db ??= db;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Register / update this device in AWS DynamoDB and poll for admin-triggered
  /// plan changes or force-logout signals.
  Future<void> initSession({void Function(String)? onPlanUpdated}) async {
    try {
      // ── Collect device info ────────────────────────────────────────────────
      final info = DeviceInfoPlugin();
      final pkg = await PackageInfo.fromPlatform();
      String hardwareId = '';
      String deviceModel = '';
      String osVersion = '';
      String brand = '';

      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        hardwareId = android.id;
        deviceModel = '${android.manufacturer} ${android.model}';
        osVersion =
            'Android ${android.version.release} (SDK ${android.version.sdkInt})';
        brand = android.brand;
      } else if (Platform.isIOS) {
        final ios = await info.iosInfo;
        hardwareId = ios.identifierForVendor ?? 'unknown';
        deviceModel = ios.model;
        osVersion = '${ios.systemName} ${ios.systemVersion}';
        brand = 'Apple';
      }

      final deviceId = hardwareId.isNotEmpty ? hardwareId : 'device_${DateTime.now().millisecondsSinceEpoch}';
      _deviceId = deviceId;

      final now = DateTime.now().toUtc().toIso8601String();

      // ── Upsert device row in AWS DynamoDB ───────────────────────────────────
      final db = _db;
      if (db != null) {
        final existing = await db.getDevice(deviceId);
        await db.upsertDevice(deviceId, {
          'device_model': deviceModel,
          'brand': brand,
          'os_version': osVersion,
          'app_version': '${pkg.version}+${pkg.buildNumber}',
          'last_seen': now,
          if (existing == null) 'first_seen': now,
          if (existing == null) 'plan': 'free',
        });

        // Increment session counter.
        await db.incrementCounter(deviceId, 'session_count');

        // Check plan immediately
        final currentPlan = existing?['plan']?.toString() ?? 'free';
        onPlanUpdated?.call(currentPlan);
      }

      // ── Periodic poller for admin updates (plan changes / logout) ──────────
      _planSyncTimer?.cancel();
      _planSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) async {
        if (_db == null || _deviceId == null) return;
        try {
          final row = await _db!.getDevice(_deviceId!);
          if (row != null) {
            final plan = (row['plan'] ?? 'free').toString();
            onPlanUpdated?.call(plan);
          }
        } catch (_) {}
      });
    } catch (_) {
      // Analytics errors are non-critical
    }
  }

  /// Call after each successful conversion.
  Future<void> logConversion(String typeKey) async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    try {
      final db = _db;
      if (db != null) {
        await db.incrementCounter(deviceId, 'total_conversions');
        final row = await db.getDevice(deviceId);
        if (row != null) {
          final byType =
              Map<String, dynamic>.from(row['conversions_by_type'] ?? {});
          byType[typeKey] = ((byType[typeKey] as num?)?.toInt() ?? 0) + 1;
          await db.updateDevice(deviceId, {'conversions_by_type': byType});
        }
      }
    } catch (_) {}
  }

  /// Update user plan (free / premium / lifetime).
  Future<void> updatePlan(String plan) async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    try {
      await _db?.updateDevice(deviceId, {
        'plan': plan,
        'plan_updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  void dispose() {
    _planSyncTimer?.cancel();
    _planSyncTimer = null;
  }
}

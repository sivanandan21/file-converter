import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/database/db_manager.dart';

/// Silently syncs user session & usage data through the multi-database
/// failover system (Supabase → Cloudflare D1 → Appwrite).
///
/// ── Key guarantee ─────────────────────────────────────────────────────────
/// Every app launch registers the device in Supabase — even for anonymous
/// (non-signed-in) users — so the admin app always sees all devices and can
/// control them (plan change, force logout, quota reset).
///
/// Real-time plan-change streaming uses Supabase Realtime directly; it
/// degrades gracefully if Supabase is temporarily unavailable.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  DatabaseManager? _db;
  final _supabase = Supabase.instance.client;
  String? _deviceId;
  StreamSubscription<List<Map<String, dynamic>>>? _planSubscription;

  String? get deviceId => _deviceId;

  /// Inject the failover-aware DatabaseManager (called from app.dart).
  void injectDb(DatabaseManager db) => _db ??= db;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Register / update this device in the database and start listening for
  /// admin-triggered plan changes and force-logout signals.
  ///
  /// Safe to call multiple times — subsequent calls refresh the record and
  /// resubscribe Realtime. Works for both signed-in and anonymous users.
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

      // ── Device ID strategy ─────────────────────────────────────────────────
      // Priority: Supabase Auth user ID > hardware device ID.
      // Using the auth user ID means one row per account regardless of device,
      // and anonymous users still get a stable hardware-keyed row.
      final user = _supabase.auth.currentUser;
      final userId = user?.id;
      final userEmail = user?.email;

      final deviceId = (userId != null && userId.isNotEmpty)
          ? userId        // signed-in: use account ID (admin sees per-user)
          : hardwareId;  // anonymous: use stable hardware ID

      _deviceId = deviceId;

      // ── Best-effort IP lookup ──────────────────────────────────────────────
      String? ipAddress;
      final httpClient = HttpClient();
      try {
        httpClient.connectionTimeout = const Duration(seconds: 3);
        final request =
            await httpClient.getUrl(Uri.parse('https://api.ipify.org'));
        final response = await request.close();
        if (response.statusCode == 200) {
          ipAddress = await response.transform(utf8.decoder).join();
        }
      } catch (_) {
      } finally {
        httpClient.close();
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // ── Upsert device row (ALL users — signed in or anonymous) ─────────────
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
          if (ipAddress != null) 'ip_address': ipAddress,
          if (userEmail != null) 'email': userEmail,
        });

        // Increment session counter.
        await db.incrementCounter(deviceId, 'session_count');
      }

      // ── Realtime listener for plan changes + force-logout ──────────────────
      // Runs for ALL users (anonymous and signed-in) so admin controls work
      // regardless of authentication state.
      await _startRealtimeListener(deviceId, onPlanUpdated);
    } catch (_) {
      // Analytics errors are non-critical; suppress silently.
    }
  }

  /// Start (or restart) the Supabase Realtime subscription for this device.
  Future<void> _startRealtimeListener(
    String deviceId,
    void Function(String)? onPlanUpdated,
  ) async {
    await _planSubscription?.cancel();
    _planSubscription = _supabase
        .from('user_devices')
        .stream(primaryKey: ['device_id'])
        .eq('device_id', deviceId)
        .listen(
          (data) async {
            if (data.isEmpty) return;
            final row = data.first;

            // ── Force logout ─────────────────────────────────────────────────
            if (row['force_logout'] == true) {
              try {
                // Clear the flag so the user isn't stuck in a logout loop.
                await _db?.updateDevice(deviceId, {'force_logout': false});
              } catch (_) {}
              try {
                await _supabase.auth.signOut();
              } catch (_) {}
              return;
            }

            // ── Plan change ──────────────────────────────────────────────────
            final plan = (row['plan'] ?? 'free').toString();
            onPlanUpdated?.call(plan);
          },
          onError: (_) {},
        );
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
    _planSubscription?.cancel();
    _planSubscription = null;
  }
}

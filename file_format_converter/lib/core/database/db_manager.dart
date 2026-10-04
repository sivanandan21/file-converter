import 'package:shared_preferences/shared_preferences.dart';
import 'db_provider.dart';
import 'failover_event.dart';
import 'failover_logger.dart';
import 'repositories/user_device_repository.dart';
import 'datasources/supabase_datasource.dart';
import 'datasources/cloudflare_d1_datasource.dart';
import 'datasources/appwrite_datasource.dart';

/// Orchestrates automatic failover across Supabase → Cloudflare D1 → Appwrite.
///
/// All callers interact with this class exactly like a [UserDeviceRepository].
/// Switching is transparent: if a write (or health check) fails on the active
/// backend, the manager promotes the next backend and retries the operation.
///
/// Failover chain:
///   Supabase (primary)
///     └─→ Cloudflare D1 (secondary)
///           └─→ Appwrite (tertiary)
///
/// Recovery: every 5 minutes the manager silently probes Supabase. If it is
/// healthy again, it automatically reinstates it as the active backend.
class DatabaseManager implements UserDeviceRepository {
  // ── State ────────────────────────────────────────────────────────────────────

  DbProvider _active = DbProvider.supabase;
  DbProvider get activeProvider => _active;

  final Map<DbProvider, UserDeviceRepository> _backends;
  final FailoverLogger _logger;

  /// How long to wait before trying to recover to a higher-priority backend.
  static const _recoveryInterval = Duration(minutes: 5);
  DateTime _lastRecoveryAttempt = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Constructor ──────────────────────────────────────────────────────────────

  DatabaseManager._({
    required Map<DbProvider, UserDeviceRepository> backends,
    required FailoverLogger logger,
  })  : _backends = backends,
        _logger = logger;

  /// Factory that wires all three backends.
  ///
  /// [cloudflareWorkerUrl] and [cloudflareApiKey] are required for D1.
  /// [appwriteClient] is required for Appwrite.
  /// Leaving them null effectively skips that tier.
  static DatabaseManager create({
    required SharedPreferences prefs,
    SupabaseUserDeviceRepository? supabaseRepo,
    CloudflareD1UserDeviceRepository? cloudflareRepo,
    AppwriteUserDeviceRepository? appwriteRepo,
  }) {
    final backends = <DbProvider, UserDeviceRepository>{
      DbProvider.supabase:
          supabaseRepo ?? SupabaseUserDeviceRepository(),
      if (cloudflareRepo != null)
        DbProvider.cloudflareD1: cloudflareRepo,
      if (appwriteRepo != null)
        DbProvider.appwrite: appwriteRepo,
    };
    return DatabaseManager._(
      backends: backends,
      logger: getFailoverLogger(prefs),
    );
  }

  // ── Core failover logic ──────────────────────────────────────────────────────

  UserDeviceRepository get _current => _backends[_active]!;

  /// Execute [operation] on the active backend.
  /// On failure, try the next backend(s) in the failover chain.
  /// Throws only when ALL backends have been exhausted.
  Future<T> _withFailover<T>(
    Future<T> Function(UserDeviceRepository repo) operation, {
    bool isWrite = true,
  }) async {
    // Periodically attempt to recover to Supabase.
    await _maybeRecover();

    final chain = _buildChain();
    Exception? lastError;

    for (final provider in chain) {
      final repo = _backends[provider];
      if (repo == null) continue;

      // For write operations, validate health first to detect quota exhaustion.
      if (isWrite && provider != _active) {
        final healthy = await repo.isHealthy();
        if (!healthy) continue;
      }

      try {
        final result = await operation(repo);

        // If we succeeded on a different backend than what was previously
        // active, record the failover.
        if (provider != _active) {
          final event = FailoverEvent(
            timestamp: DateTime.now().utc,
            from: _active,
            to: provider,
            reason: lastError?.toString() ?? 'Primary backend unavailable',
          );
          _active = provider;
          await _logger.log(event);
        }

        return result;
      } on Exception catch (e) {
        lastError = e;
        // Continue to next backend.
      }
    }

    throw lastError ??
        Exception('All database backends are unavailable.');
  }

  /// Returns the ordered list of backends starting from the current active one.
  List<DbProvider> _buildChain() {
    const order = [
      DbProvider.supabase,
      DbProvider.cloudflareD1,
      DbProvider.appwrite,
    ];
    // Start at the active provider; fall forward.
    final startIndex = order.indexOf(_active);
    return [
      ...order.sublist(startIndex),
      ...order.sublist(0, startIndex), // wrap-around (shouldn't normally happen)
    ].where((p) => _backends.containsKey(p)).toList();
  }

  /// If Supabase is healthy and isn't the active backend, reinstate it.
  Future<void> _maybeRecover() async {
    if (_active == DbProvider.supabase) return;
    final now = DateTime.now();
    if (now.difference(_lastRecoveryAttempt) < _recoveryInterval) return;
    _lastRecoveryAttempt = now;

    final supabase = _backends[DbProvider.supabase];
    if (supabase == null) return;
    final healthy = await supabase.isHealthy();
    if (healthy) {
      final event = FailoverEvent(
        timestamp: now.toUtc(),
        from: _active,
        to: DbProvider.supabase,
        reason: 'Supabase recovered — reinstating primary backend',
      );
      _active = DbProvider.supabase;
      await _logger.log(event);
    }
  }

  // ── UserDeviceRepository implementation ─────────────────────────────────────

  @override
  Future<Map<String, dynamic>?> getDevice(String deviceId) =>
      _withFailover((r) => r.getDevice(deviceId), isWrite: false);

  @override
  Future<List<Map<String, dynamic>>> queryDevices({
    Map<String, dynamic> filter = const {},
  }) =>
      _withFailover((r) => r.queryDevices(filter: filter), isWrite: false);

  @override
  Future<void> insertDevice(Map<String, dynamic> data) =>
      _withFailover((r) => r.insertDevice(data));

  @override
  Future<void> upsertDevice(String deviceId, Map<String, dynamic> data) =>
      _withFailover((r) => r.upsertDevice(deviceId, data));

  @override
  Future<void> updateDevice(String deviceId, Map<String, dynamic> fields) =>
      _withFailover((r) => r.updateDevice(deviceId, fields));

  @override
  Future<void> deleteDevice(String deviceId) =>
      _withFailover((r) => r.deleteDevice(deviceId));

  @override
  Future<void> incrementCounter(String deviceId, String column, {int by = 1}) =>
      _withFailover((r) => r.incrementCounter(deviceId, column, by: by));

  @override
  Future<bool> isHealthy() => _current.isHealthy();

  // ── Diagnostics ──────────────────────────────────────────────────────────────

  List<FailoverEvent> get failoverHistory => _logger.localEvents;
}

extension on DateTime {
  DateTime get utc => toUtc();
}

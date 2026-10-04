import 'package:appwrite/appwrite.dart' as aw;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import 'db_manager.dart';
import 'db_provider.dart';
import 'failover_event.dart';
import 'multi_db_config.dart';
import 'datasources/aws_dynamodb_datasource.dart';
import 'datasources/cloudflare_d1_datasource.dart';
import 'datasources/appwrite_datasource.dart';

// ── DatabaseManager provider ─────────────────────────────────────────────────

/// The single [DatabaseManager] instance shared across the app.
/// Inject this anywhere you previously injected [AccountQuotaService].
final databaseManagerProvider = Provider<DatabaseManager>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  // Cloudflare D1 — only wired when config is filled in.
  CloudflareD1UserDeviceRepository? d1Repo;
  if (MultiDbConfig.enableCloudflareD1) {
    d1Repo = CloudflareD1UserDeviceRepository(
      workerUrl: MultiDbConfig.cloudflareWorkerUrl,
      apiKey: MultiDbConfig.cloudflareApiKey,
    );
  }

  // Appwrite — only wired when config is filled in.
  AppwriteUserDeviceRepository? appwriteRepo;
  if (MultiDbConfig.enableAppwrite) {
    final client = aw.Client()
      ..setEndpoint(MultiDbConfig.appwriteEndpoint)
      ..setProject(MultiDbConfig.appwriteProjectId)
      ..setSelfSigned(status: false); // set to true only for local Appwrite
    appwriteRepo = AppwriteUserDeviceRepository(
      client: client,
      apiKey: MultiDbConfig.appwriteApiKey,
    );
  }

  return DatabaseManager.create(
    prefs: prefs,
    awsRepo: AwsDynamoDbUserDeviceRepository(),
    cloudflareRepo: d1Repo,
    appwriteRepo: appwriteRepo,
  );
});

// ── Active provider label (for UI / diagnostics) ─────────────────────────────

/// Streams the name of the currently active database backend.
/// Useful for debugging or showing a status badge in the admin app.
final activeDbProviderProvider = Provider<String>((ref) {
  final manager = ref.watch(databaseManagerProvider);
  return manager.activeProvider.label;
});

// ── Failover history provider ─────────────────────────────────────────────────

/// Read-only list of all past failover events (most-recent first).
final failoverHistoryProvider = Provider<List<FailoverEvent>>((ref) {
  final manager = ref.watch(databaseManagerProvider);
  return manager.failoverHistory;
});

// ── DbProvider state notifier (reactive active backend) ──────────────────────

class DbProviderNotifier extends StateNotifier<DbProvider> {
  final DatabaseManager _manager;

  DbProviderNotifier(this._manager) : super(_manager.activeProvider);

  void refresh() => state = _manager.activeProvider;
}

final dbProviderNotifierProvider =
    StateNotifierProvider<DbProviderNotifier, DbProvider>((ref) {
  final manager = ref.watch(databaseManagerProvider);
  return DbProviderNotifier(manager);
});

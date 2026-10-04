import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/account_quota_service.dart';
import '../services/freemium_service.dart';
import '../services/ad_service.dart';
import '../services/conversion_history_service.dart';
import '../services/file_storage_service.dart';
import '../services/conversion_services.dart';
import '../models/conversion_record.dart';
import '../core/utils/app_utils.dart';
import '../core/database/db_providers.dart';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Infrastructure Providers
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override in ProviderScope');
});

final freemiumServiceProvider = Provider<FreemiumService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return FreemiumService(prefs);
});

final accountQuotaServiceProvider =
    Provider<AccountQuotaService>((ref) => AccountQuotaService(
          db: ref.watch(databaseManagerProvider),
        ));

final adServiceProvider = Provider<AdService>((ref) => AdService());

final fileStorageServiceProvider =
    Provider<FileStorageService>((ref) => FileStorageService());

final conversionHistoryServiceProvider =
    Provider<ConversionHistoryService>((ref) => ConversionHistoryService());

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Conversion Service Providers
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final imageToPdfServiceProvider = Provider<ImageToPdfService>((ref) {
  return ImageToPdfService(ref.watch(fileStorageServiceProvider));
});

final pdfToImageServiceProvider = Provider<PdfToImageService>((ref) {
  return PdfToImageService(ref.watch(fileStorageServiceProvider));
});

final pdfToDocxServiceProvider = Provider<PdfToDocxService>((ref) {
  return PdfToDocxService(ref.watch(fileStorageServiceProvider));
});

final docxToPdfServiceProvider = Provider<DocxToPdfService>((ref) {
  return DocxToPdfService(ref.watch(fileStorageServiceProvider));
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Freemium State Notifier
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class FreemiumState {
  final int conversionsUsed;
  final int conversionsRemaining;
  final bool canConvert;
  final int rewardedAdsWatched;
  final bool canWatchRewardedAd;
  final bool isPro;

  const FreemiumState({
    required this.conversionsUsed,
    required this.conversionsRemaining,
    required this.canConvert,
    required this.rewardedAdsWatched,
    required this.canWatchRewardedAd,
    required this.isPro,
  });
}

class FreemiumNotifier extends StateNotifier<FreemiumState> {
  final FreemiumService _service;

  FreemiumNotifier(this._service) : super(_buildState(_service));

  static FreemiumState _buildState(FreemiumService s) {
    return FreemiumState(
      conversionsUsed: s.conversionsUsedToday,
      conversionsRemaining: s.conversionsRemainingToday,
      canConvert: s.canConvert,
      rewardedAdsWatched: s.rewardedAdsWatchedToday,
      canWatchRewardedAd: s.canWatchRewardedAd,
      isPro: s.isPro,
    );
  }

  Future<void> recordConversion() async {
    await _service.recordConversion();
    state = _buildState(_service);
  }

  Future<void> bindAccount(String? accountId) async {
    await _service.bindAccount(accountId);
    state = _buildState(_service);
  }

  void applyAccountQuota(AccountQuotaSnapshot snapshot) {
    _service.applyRemoteQuota(
      conversionsUsedToday: snapshot.conversionsUsedToday,
      rewardedAdsWatchedToday: snapshot.rewardedAdsWatchedToday,
    );
    state = _buildState(_service);
  }

  Future<void> recordRewardedAd() async {
    await _service.recordRewardedAd();
    state = _buildState(_service);
  }

  Future<void> activatePro() async {
    await _service.activatePro();
    state = _buildState(_service);
  }

  Future<void> deactivatePro() async {
    await _service.deactivatePro();
    state = _buildState(_service);
  }

  void refresh() {
    state = _buildState(_service);
  }
}

final freemiumNotifierProvider =
    StateNotifierProvider<FreemiumNotifier, FreemiumState>((ref) {
  return FreemiumNotifier(ref.watch(freemiumServiceProvider));
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Conversion History Notifier
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ConversionHistoryNotifier extends StateNotifier<List<ConversionRecord>> {
  final ConversionHistoryService _service;

  ConversionHistoryNotifier(this._service) : super(_service.all);

  Future<void> addRecord(ConversionRecord record) async {
    await _service.add(record);
    state = _service.all;
  }

  Future<void> toggleStar(String id) async {
    await _service.toggleStar(id);
    state = _service.all;
  }

  Future<void> deleteRecord(String id) async {
    await _service.delete(id);
    state = _service.all;
  }

  Future<void> clearAll() async {
    await _service.clearAll();
    state = [];
  }

  void refresh() {
    state = _service.all;
  }
}

final conversionHistoryNotifierProvider =
    StateNotifierProvider<ConversionHistoryNotifier, List<ConversionRecord>>(
        (ref) {
  return ConversionHistoryNotifier(ref.watch(conversionHistoryServiceProvider));
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Countdown Timer Provider
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final countdownProvider = StreamProvider<String>((ref) {
  final freemiumService = ref.watch(freemiumServiceProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) {
    final seconds = freemiumService.secondsUntilReset();
    return AppUtils.formatCountdown(seconds);
  });
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Settings
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DarkModeNotifier extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  static const _key = 'dark_mode';

  DarkModeNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  Future<void> toggle() async {
    state = !state;
    await _prefs.setBool(_key, state);
  }

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}

final darkModeProvider =
    StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier(ref.watch(sharedPreferencesProvider));
});

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Active conversion tab (for bottom nav)
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final activeNavIndexProvider = StateProvider<int>((ref) => 0);

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Search query for Recent screen
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

final recentSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredHistoryProvider = Provider<List<ConversionRecord>>((ref) {
  final history = ref.watch(conversionHistoryNotifierProvider);
  final query = ref.watch(recentSearchQueryProvider);
  if (query.isEmpty) return history;
  final q = query.toLowerCase();
  return history.where((r) {
    return r.outputFileName.toLowerCase().contains(q) ||
        r.sourceFileName.toLowerCase().contains(q) ||
        r.conversionType.toLowerCase().contains(q);
  }).toList();
});

final recentFilterTypeProvider = StateProvider<String?>((ref) => null);

final filteredByTypeProvider = Provider<List<ConversionRecord>>((ref) {
  final filtered = ref.watch(filteredHistoryProvider);
  final type = ref.watch(recentFilterTypeProvider);
  if (type == null) return filtered;
  return filtered.where((r) => r.conversionType == type).toList();
});

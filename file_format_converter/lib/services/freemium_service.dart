import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Manages free quotas, rewarded-ad boosts, and Pro state.
///
/// Usage is scoped to the signed-in Supabase user when one is available. This
/// prevents a logout/login cycle from resetting the daily free conversion count.
class FreemiumService {
  final SharedPreferences _prefs;
  String? _accountId;
  int? _remoteConversionsUsedToday;
  int? _remoteRewardedAdsWatchedToday;

  FreemiumService(this._prefs);

  String _key(String baseKey) {
    final accountId = _accountId;
    if (accountId == null || accountId.isEmpty) return baseKey;
    return '$baseKey.account.$accountId';
  }

  String get _conversionCountKey => _key(AppConstants.keyConversionCount);
  String get _conversionDateKey => _key(AppConstants.keyConversionDate);
  String get _rewardedAdCountKey => _key(AppConstants.keyRewardedAdCount);
  String get _rewardedAdDateKey => _key(AppConstants.keyRewardedAdDate);
  String get _isProKey => _key(AppConstants.keyIsPro);

  Future<void> bindAccount(String? accountId) async {
    final normalized = accountId?.trim();
    _accountId = normalized == null || normalized.isEmpty ? null : normalized;
    _remoteConversionsUsedToday = null;
    _remoteRewardedAdsWatchedToday = null;

    if (_accountId != null) {
      await _migrateLegacyUsageToAccount();
    }
  }

  void applyRemoteQuota({
    required int conversionsUsedToday,
    required int rewardedAdsWatchedToday,
  }) {
    _remoteConversionsUsedToday = conversionsUsedToday;
    _remoteRewardedAdsWatchedToday = rewardedAdsWatchedToday;
  }

  Future<void> _migrateLegacyUsageToAccount() async {
    await _migrateLegacyDailyCounter(
      legacyCountKey: AppConstants.keyConversionCount,
      legacyDateKey: AppConstants.keyConversionDate,
      scopedCountKey: _conversionCountKey,
      scopedDateKey: _conversionDateKey,
    );
    await _migrateLegacyDailyCounter(
      legacyCountKey: AppConstants.keyRewardedAdCount,
      legacyDateKey: AppConstants.keyRewardedAdDate,
      scopedCountKey: _rewardedAdCountKey,
      scopedDateKey: _rewardedAdDateKey,
    );

    final legacyPro = _prefs.getBool(AppConstants.keyIsPro);
    if (legacyPro != null && !_prefs.containsKey(_isProKey)) {
      await _prefs.setBool(_isProKey, legacyPro);
      await _prefs.remove(AppConstants.keyIsPro);
    }
  }

  Future<void> _migrateLegacyDailyCounter({
    required String legacyCountKey,
    required String legacyDateKey,
    required String scopedCountKey,
    required String scopedDateKey,
  }) async {
    final legacyDate = _prefs.getString(legacyDateKey);
    final legacyCount = _prefs.getInt(legacyCountKey);
    if (legacyDate == null && legacyCount == null) return;

    final scopedDate = _prefs.getString(scopedDateKey);
    final scopedCount = _prefs.getInt(scopedCountKey) ?? 0;

    if (scopedDate == null) {
      if (legacyDate != null) {
        await _prefs.setString(scopedDateKey, legacyDate);
      }
      await _prefs.setInt(scopedCountKey, legacyCount ?? 0);
    } else if (legacyDate == scopedDate && legacyCount != null) {
      await _prefs.setInt(
        scopedCountKey,
        legacyCount > scopedCount ? legacyCount : scopedCount,
      );
    }

    await _prefs.remove(legacyCountKey);
    await _prefs.remove(legacyDateKey);
  }

  void _resetIfExpired(String countKey, String dateKey) {
    final savedDateStr = _prefs.getString(dateKey);
    if (savedDateStr == null || savedDateStr.isEmpty) {
      _prefs.setInt(countKey, 0);
      _prefs.setString(dateKey, DateTime.now().toIso8601String());
      return;
    }
    try {
      final savedDate = DateTime.parse(savedDateStr);
      if (DateTime.now().difference(savedDate).inHours >= 24) {
        _prefs.setInt(countKey, 0);
        _prefs.setString(dateKey, DateTime.now().toIso8601String());
      }
    } catch (_) {
      _prefs.setInt(countKey, 0);
      _prefs.setString(dateKey, DateTime.now().toIso8601String());
    }
  }

  int secondsUntilReset() {
    final savedDateStr = _prefs.getString(_conversionDateKey);
    if (savedDateStr == null || savedDateStr.isEmpty) {
      return 24 * 3600;
    }
    try {
      final savedDate = DateTime.parse(savedDateStr);
      final expiresAt = savedDate.add(const Duration(hours: 24));
      final diff = expiresAt.difference(DateTime.now()).inSeconds;
      return diff > 0 ? diff : 0;
    } catch (_) {
      return 24 * 3600;
    }
  }

  int get conversionsUsedToday {
    _resetIfExpired(_conversionCountKey, _conversionDateKey);
    final local = _prefs.getInt(_conversionCountKey) ?? 0;
    final remote = _remoteConversionsUsedToday ?? 0;
    return remote > local ? remote : local;
  }

  int get conversionsRemainingToday {
    if (isPro) return 9999;
    final extra = rewardedAdConversionsGranted;
    final limit = AppConstants.freeConversionsPerDay + extra;
    return (limit - conversionsUsedToday).clamp(0, limit);
  }

  bool get canConvert => isPro || conversionsRemainingToday > 0;

  Future<void> recordConversion() async {
    _resetIfExpired(_conversionCountKey, _conversionDateKey);
    await _prefs.setInt(_conversionCountKey, conversionsUsedToday + 1);
  }

  int get rewardedAdsWatchedToday {
    _resetIfExpired(_rewardedAdCountKey, _rewardedAdDateKey);
    final local = _prefs.getInt(_rewardedAdCountKey) ?? 0;
    final remote = _remoteRewardedAdsWatchedToday ?? 0;
    return remote > local ? remote : local;
  }

  bool get canWatchRewardedAd =>
      !isPro && rewardedAdsWatchedToday < AppConstants.maxRewardedAdsPerDay;

  int get rewardedAdConversionsGranted =>
      rewardedAdsWatchedToday * AppConstants.conversionsPerRewardedAd;

  Future<void> recordRewardedAd() async {
    _resetIfExpired(_rewardedAdCountKey, _rewardedAdDateKey);
    await _prefs.setInt(_rewardedAdCountKey, rewardedAdsWatchedToday + 1);
  }

  bool get isPro => _prefs.getBool(_isProKey) ?? false;

  Future<void> activatePro() async {
    await _prefs.setBool(_isProKey, true);
  }

  Future<void> deactivatePro() async {
    await _prefs.setBool(_isProKey, false);
  }

  bool get isOnboardingDone =>
      _prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  Future<void> completeOnboarding() async {
    await _prefs.setBool(AppConstants.keyOnboardingDone, true);
  }
}

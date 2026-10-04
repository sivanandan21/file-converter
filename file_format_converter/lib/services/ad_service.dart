import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad service abstraction layer using Google Mobile Ads SDK.
class AdService {
  RewardedAd? _rewardedAd;
  bool _isRewardedAdReady = false;

  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  // ── Ad Unit IDs ────────

  /// Your rewarded ad unit ID from AdMob console.
  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/5224354917'; // test ID
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-1875596253114137/3399013473'; // Real Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313'; // test ID
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Your banner ad unit ID from AdMob console.
  static String get bannerAdUnitId {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/6300978111'; // test ID
    }
    if (Platform.isAndroid) {
      return 'ca-app-pub-1875596253114137/8258558106'; // Real Banner Ad Unit ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // test ID
    }
    throw UnsupportedError('Unsupported platform');
  }

  // ── Rewarded Ad ───────────────────────────────────────────────────────────

  /// Load a rewarded ad into memory.
  Future<void> loadRewardedAd() async {
    final completer = Completer<void>();
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdReady = true;
          if (!completer.isCompleted) completer.complete();
        },
        onAdFailedToLoad: (err) {
          _isRewardedAdReady = false;
          _rewardedAd = null;
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    return completer.future;
  }

  bool get isRewardedAdReady => _isRewardedAdReady;

  /// Show the rewarded ad. Returns true if the user earned the reward.
  Future<bool> showRewardedAd() async {
    if (!_isRewardedAdReady || _rewardedAd == null) {
      await loadRewardedAd();
    }
    
    if (!_isRewardedAdReady || _rewardedAd == null) {
      return false;
    }

    final completer = Completer<bool>();
    
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        loadRewardedAd(); // Preload next ad
        if (!completer.isCompleted) completer.complete(false);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewardedAd = null;
        _isRewardedAdReady = false;
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      if (!completer.isCompleted) completer.complete(true);
    });

    return completer.future;
  }

  // ── Banner Ad ─────────────────────────────────────────────────────────────

  /// Load a banner ad.
  Future<void> loadBannerAd() async {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          _isBannerAdReady = true;
        },
        onAdFailedToLoad: (ad, err) {
          _isBannerAdReady = false;
          ad.dispose();
        },
      ),
    )..load();
  }

  bool get isBannerAdReady => _isBannerAdReady;
  BannerAd? get bannerAd => _bannerAd;

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isBannerAdReady = false;
  }
}

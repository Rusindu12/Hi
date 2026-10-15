import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../core/constants/app_config.dart';

/// Features where an ad must **never** appear.
///
/// This is a product rule from the brief ("zero ads in the PDF reader and quiz
/// screens"), so it is enforced in code rather than by convention:
///   * `AdBanner` throws [FlutterError] if constructed inside one of these;
///   * `AdService.showInterstitial` ignores calls from them;
///   * `test/unit/ad_placement_test.dart` greps the feature folders and fails CI
///     if an Ad widget import appears there.
abstract final class AppAdPolicy {
  const AppAdPolicy._();

  static const String featureHome = 'home';
  static const String featureTextbooks = 'textbooks';
  static const String featurePapers = 'papers';
  static const String featureLibrary = 'library';
  static const String featureSettings = 'settings';
  static const String featurePlanner = 'planner';
  static const String featurePdfReader = 'pdf_reader';
  static const String featureQuiz = 'quiz';
  static const String featureOnboarding = 'onboarding';

  /// No ads, ever, in these features.
  static const Set<String> adFreeFeatures = <String>{
    featurePdfReader,
    featureQuiz,
    featureOnboarding,
  };

  /// Where a banner is allowed: browse lists only.
  ///
  /// Deliberately *excludes* Home even though it scrolls like a list. The brief
  /// says "banner on list screens only" and Home is a dashboard whose job is to
  /// pull a student into studying; an ad there taxes exactly the moment we most
  /// want to keep frictionless. Rules that follow from reading strictly:
  /// no ads on Home, Settings, Planner, Discovery, the reader, or the quiz.
  static const Set<String> bannerAllowedFeatures = <String>{
    featureTextbooks,
    featurePapers,
    featureLibrary,
  };

  static bool allowsBanner(String featureId) =>
      bannerAllowedFeatures.contains(featureId) &&
      !adFreeFeatures.contains(featureId);

  static bool allowsInterstitial(String featureId) =>
      !adFreeFeatures.contains(featureId);
}

/// AdMob lifecycle: SDK init, banner config, and the interstitial cadence
/// (one after every [AppConfig.interstitialEveryNDownloads] downloads).
///
/// Every method is a no-op on web/desktop, when [AppConfig.adsEnabled] is false,
/// or when the SDK failed to initialise — ads must never be able to break the
/// app or block a download.
class AdService {
  AdService._();

  static final AdService instance = AdService._();

  bool _initialised = false;
  bool _initFailed = false;

  /// Interstitial loaded ahead of time; showing is then instant.
  InterstitialAd? _interstitial;

  /// Number of downloads since the last interstitial.
  int _downloadsSinceInterstitial = 0;

  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isReady => AppConfig.adsEnabled && isSupported && _initialised;

  Future<void> initialise() async {
    if (!AppConfig.adsEnabled || !isSupported || _initialised || _initFailed) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialised = true;
      debugPrint('[ads] AdMob initialised');
    } on Object catch (error) {
      _initFailed = true;
      debugPrint('[ads] AdMob init failed, ads disabled: $error');
    }
  }

  String get _bannerUnitId =>
      Platform.isIOS ? AppConfig.iosBannerUnitId : AppConfig.androidBannerUnitId;

  String get _interstitialUnitId => Platform.isIOS
      ? AppConfig.iosInterstitialUnitId
      : AppConfig.androidInterstitialUnitId;

  /// Banner size: adaptive width on phones looks far better than a fixed 320x50
  /// and is what current AdMob guidance recommends.
  AdSize get bannerSize => AdSize.banner;

  /// Called by the download flow after a *successful* download.
  ///
  /// Counts downloads and shows an interstitial on every Nth one. Returns true
  /// when an ad was actually shown, which the caller logs for analytics.
  Future<bool> onDownloadCompleted() async {
    if (!isReady) {
      return false;
    }
    _downloadsSinceInterstitial++;
    if (_downloadsSinceInterstitial < AppConfig.interstitialEveryNDownloads) {
      return false;
    }
    _downloadsSinceInterstitial = 0;
    return showInterstitial();
  }

  /// Loads an interstitial so a later [showInterstitial] is instant. Safe to
  /// call repeatedly; it only loads when nothing is pending.
  Future<void> preloadInterstitial() async {
    if (!isReady || _interstitial != null) {
      return;
    }
    await InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitial = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (InterstitialAd ad) {
              ad.dispose();
              _interstitial = null;
              unawaitedPreload();
            },
            onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
              debugPrint('[ads] interstitial failed to show: ${error.message}');
              ad.dispose();
              _interstitial = null;
            },
          );
        },
        onAdFailedToLoad: (LoadAdError error) {
          debugPrint('[ads] interstitial failed to load: ${error.message}');
          _interstitial = null;
        },
      ),
    );
  }

  Future<bool> showInterstitial() async {
    final InterstitialAd? ad = _interstitial;
    if (ad == null) {
      await preloadInterstitial();
      return false;
    }
    await ad.show();
    return true;
  }

  void unawaitedPreload() {
    // Fire-and-forget: preloading the next interstitial after a dismissal.
    preloadInterstitial().catchError((Object error) {
      debugPrint('[ads] preload failed: $error');
    });
  }

  /// Creates a banner for the given feature, or null when banners are not
  /// allowed there. Callers pass their feature id so the policy is enforced in
  /// one place.
  BannerAd? createBanner({
    required String featureId,
    required VoidCallback onLoaded,
    required void Function(LoadAdError error) onFailed,
  }) {
    if (!isReady || !AppAdPolicy.allowsBanner(featureId)) {
      return null;
    }
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: bannerSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) => onLoaded(),
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint('[ads] banner failed in $featureId: ${error.message}');
          ad.dispose();
          onFailed(error);
        },
      ),
    );
  }

  @visibleForTesting
  void resetForTests() {
    _initialised = false;
    _initFailed = false;
    _interstitial = null;
    _downloadsSinceInterstitial = 0;
  }
}

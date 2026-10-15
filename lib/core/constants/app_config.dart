/// Compile-time configuration.
///
/// Everything here is injected with `--dart-define` so the same source tree can
/// produce a fully-offline demo build and a cloud-connected release build.
///
/// ```bash
/// # 1. Default build: no Firebase, bundled seed catalogue, test ad units.
/// flutter run
///
/// # 2. Cloud build (after `flutterfire configure`):
/// flutter run --dart-define=USE_FIREBASE=true
///
/// # 3. Release build with real ad units:
/// flutter build appbundle --release \
///   --dart-define=USE_FIREBASE=true \
///   --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXXXXXX/YYYYYYYY
/// ```
library;

abstract final class AppConfig {
  const AppConfig._();

  // ---------------------------------------------------------------------------
  // Firebase
  // ---------------------------------------------------------------------------

  /// Master switch for every Firebase-backed data source (Firestore catalogue,
  /// quiz questions, Storage PDFs, FCM, Analytics, Crashlytics).
  ///
  /// When `false` the app uses [LocalCatalogueSource] and the bundled
  /// `assets/data/*.json` seed content. The app is fully functional without a
  /// `google-services.json`, which is what you want for local development and
  /// for Play Store review builds.
  static const bool useFirebase =
      bool.fromEnvironment('USE_FIREBASE', defaultValue: false);

  // ---------------------------------------------------------------------------
  // AdMob
  //
  // Defaults are Google's official *test* unit IDs. They must be replaced
  // before release: using test IDs in production means you earn nothing, and
  // using real IDs while developing is a policy violation (invalid traffic).
  // ---------------------------------------------------------------------------

  static const bool adsEnabled = bool.fromEnvironment(
    'ADS_ENABLED',
    defaultValue: true,
  );

  static const String testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testBannerIos = 'ca-app-pub-3940256099942544/2934735716';
  static const String testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';

  static const String androidBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ANDROID',
    defaultValue: testBannerAndroid,
  );
  static const String androidInterstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
    defaultValue: testInterstitialAndroid,
  );
  static const String iosBannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_IOS',
    defaultValue: testBannerIos,
  );
  static const String iosInterstitialUnitId = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
    defaultValue: testInterstitialIos,
  );

  /// Interstitial cadence: show one after every Nth successful download.
  /// Downloads only happen for items whose rights allow self-hosting.
  static const int interstitialEveryNDownloads = 3;

  // ---------------------------------------------------------------------------
  // Quiz
  // ---------------------------------------------------------------------------

  /// Seconds allowed per question during a timed quiz.
  static const int secondsPerQuestion = 45;

  /// Number of questions pulled into a single quiz attempt.
  static const int questionsPerQuiz = 10;

  /// A quiz counts towards the "Quiz master" badge at or above this score.
  static const int quizMasterThresholdPercent = 80;
  static const int quizMasterRequiredCount = 5;

  // ---------------------------------------------------------------------------
  // Engagement
  // ---------------------------------------------------------------------------

  static const int streakFreezesPerWeek = 1;
  static const int tenDownloadsBadgeCount = 10;

  // ---------------------------------------------------------------------------
  // Catalogue
  // ---------------------------------------------------------------------------

  /// How long a cached Firestore catalogue stays fresh before a refresh.
  static const Duration catalogueCacheTtl = Duration(hours: 12);

  /// Network timeouts for catalogue/quiz/PDF requests.
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Interstitial + banner are disabled entirely on web/desktop builds.
  static const bool adsSupportedPlatformsOnly = true;
}

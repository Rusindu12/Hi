import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_config.dart';

/// Initialises Firebase **only** when `--dart-define=USE_FIREBASE=true`.
///
/// Why guard it: the app must run on a fresh clone with no `google-services.json`
/// (Play Store review builds, a new contributor, an offline demo). Calling
/// `Firebase.initializeApp()` without configuration throws at startup, so the
/// flag is checked before any Firebase class is touched at runtime.
abstract final class FirebaseBootstrap {
  const FirebaseBootstrap._();

  static bool _initialised = false;

  static bool get isAvailable => AppConfig.useFirebase && _initialised;

  /// Returns true when Firebase came up successfully. Never throws: a failed
  /// init degrades to the local-first experience instead of a white screen.
  static Future<bool> initialise() async {
    if (!AppConfig.useFirebase) {
      debugPrint(
        '[SriEdu] Firebase disabled (USE_FIREBASE=false). '
        'Running on bundled catalogue + local storage.',
      );
      return false;
    }
    if (_initialised) {
      return true;
    }
    try {
      await Firebase.initializeApp();

      // Route Flutter framework errors and uncaught async errors to Crashlytics.
      // In debug builds we keep them on the console so they are readable.
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        if (kReleaseMode) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      };
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        if (kReleaseMode) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        }
        return true;
      };

      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(!kDebugMode);
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(!kDebugMode);

      _initialised = true;
      return true;
    } on Object catch (error, stack) {
      debugPrint('[SriEdu] Firebase init failed, continuing offline: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      return false;
    }
  }
}

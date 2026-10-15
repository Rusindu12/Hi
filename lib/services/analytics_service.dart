import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../data/sources/remote/firebase_bootstrap.dart';

/// Thin, *safe* wrapper around Firebase Analytics + Crashlytics.
///
/// Every call is a no-op when Firebase is off or init failed, so feature code
/// never needs `if (firebaseEnabled)` checks — and no analytics call can ever
/// crash a build.
///
/// Event names are centralised here as constants: Play Console funnels and
/// BigQuery exports stay stable, and typos become a compile error.
abstract final class AnalyticsEvents {
  const AnalyticsEvents._();

  static const String onboardingComplete = 'onboarding_complete';
  static const String languageChanged = 'language_changed';
  static const String bookOpened = 'book_opened';
  static const String paperOpened = 'paper_opened';
  static const String paperDownloaded = 'paper_downloaded';
  static const String downloadDeleted = 'download_deleted';
  static const String pdfPageTurned = 'pdf_page_turned';
  static const String quizStarted = 'quiz_started';
  static const String quizCompleted = 'quiz_completed';
  static const String quizAbandoned = 'quiz_abandoned';
  static const String streakIncremented = 'streak_incremented';
  static const String streakFreezeUsed = 'streak_freeze_used';
  static const String badgeUnlocked = 'badge_unlocked';
  static const String plannerSlotCreated = 'planner_slot_created';
  static const String plannerSlotDeleted = 'planner_slot_deleted';
  static const String favoriteToggled = 'favorite_toggled';
  static const String cacheCleared = 'cache_cleared';
  static const String dataErased = 'data_erased';
  static const String externalSourceOpened = 'external_source_opened';
  static const String interstitialShown = 'interstitial_shown';
}

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  bool _enabled = false;

  /// Called once from `bootstrap()` after [FirebaseBootstrap.initialise].
  void configure() {
    _enabled = AppConfig.useFirebase && FirebaseBootstrap.isAvailable;
  }

  bool get isEnabled => _enabled;

  FirebaseAnalytics? get _analytics => _enabled ? FirebaseAnalytics.instance : null;

  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    if (!_enabled) {
      debugPrint('[analytics] $name ${parameters ?? ''}');
      return;
    }
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters?.map(
          (String key, Object? value) => MapEntry<String, Object>(key, value ?? ''),
        ),
      );
    } on Object catch (error) {
      debugPrint('[analytics] dropped $name: $error');
    }
  }

  Future<void> logScreen(String screenName) async {
    if (!_enabled) {
      return;
    }
    try {
      await _analytics?.logScreenView(screenName: screenName);
    } on Object catch (error) {
      debugPrint('[analytics] screen view dropped: $error');
    }
  }

  /// Records a translation of UI language, so retention can be sliced by language.
  Future<void> setLanguage(String localeCode) async {
    if (!_enabled) {
      return;
    }
    try {
      await _analytics?.setUserProperty(name: 'ui_language', value: localeCode);
    } on Object catch (error) {
      debugPrint('[analytics] user property dropped: $error');
    }
  }

  Future<void> setContentPreferences({
    required String medium,
    required int grade,
  }) async {
    if (!_enabled) {
      return;
    }
    try {
      await _analytics?.setUserProperty(name: 'preferred_medium', value: medium);
      await _analytics?.setUserProperty(name: 'grade', value: grade.toString());
    } on Object catch (error) {
      debugPrint('[analytics] user property dropped: $error');
    }
  }

  /// Non-fatal error reporting. Always logs to the console in debug.
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    String? reason,
    bool fatal = false,
  }) async {
    debugPrint('[error] $reason: $error');
    if (!_enabled) {
      return;
    }
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } on Object catch (reportingFailure) {
      debugPrint('[error] crashlytics unavailable: $reportingFailure');
    }
  }

  /// Attaches a breadcrumb, e.g. "opened paper ol-2019-mathematics-si".
  Future<void> logBreadcrumb(String message) async {
    if (!_enabled) {
      return;
    }
    try {
      await FirebaseCrashlytics.instance.log(message);
    } on Object catch (_) {
      return;
    }
  }
}

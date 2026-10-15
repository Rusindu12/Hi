import 'package:flutter/material.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';
import '../services/analytics_service.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import '../services/planner_service.dart';

/// Owns user preferences and pushes changes to the pieces that care:
/// the theme/locale in `MaterialApp`, notification permissions, and FCM topics.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsRepository repository,
    required PlannerService planner,
    required FcmService fcm,
  })  : _repository = repository,
        _planner = planner,
        _fcm = fcm;

  final SettingsRepository _repository;
  final PlannerService _planner;
  final FcmService _fcm;

  AppSettings get settings => _repository.load();

  Locale? get localeOverride {
    final String? code = settings.localeCode;
    return code == null ? null : Locale(code);
  }

  ThemeMode get themeMode => settings.themeMode;

  double get fontScale => settings.fontScale;

  bool get isOnboarded => settings.onboarded;

  String get studentName => settings.studentName;

  bool get notifyReminders => settings.notifyReminders;

  bool get notifyAnnouncements => settings.notifyAnnouncements;

  // --- Mutations -----------------------------------------------------------

  /// Language switch. Also re-schedules planner reminders because the
  /// notification body text is baked in at schedule time.
  Future<void> setLocale(String localeCode, {bool markOnboarded = true}) async {
    await _repository.partial(
      localeCode: localeCode,
      onboarded: markOnboarded ? true : null,
    );
    AnalyticsService.instance.setLanguage(localeCode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _repository.partial(themeMode: mode);
    notifyListeners();
  }

  Future<void> setFontScale(double scale) async {
    await _repository.partial(fontScale: AppSettings.clampFontScale(scale));
    notifyListeners();
  }

  Future<void> setStudentName(String name) async {
    await _repository.partial(studentName: name.trim());
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _repository.partial(onboarded: true);
    notifyListeners();
  }

  Future<void> setNotifyReminders(bool enabled) async {
    await _repository.partial(notifyReminders: enabled);
    if (enabled) {
      await _planner.ensurePermission();
    }
    notifyListeners();
  }

  Future<void> setNotifyAnnouncements(bool enabled) async {
    await _repository.partial(notifyAnnouncements: enabled);
    await _fcm.setAnnouncementsEnabled(enabled);
    notifyListeners();
  }

  /// Re-schedules planner reminders with the current language.
  Future<void> reschedulePlannerReminders({
    required NotificationService notifications,
    required String Function(String subjectCode) subjectLabelOf,
    required dynamic l10n,
  }) async {
    await notifications.initialise();
    await _planner.rescheduleAll(l10n: l10n, subjectLabelOf: subjectLabelOf);
  }

  /// "Erase all app data": wipes Hive, cancels notifications, resets settings.
  Future<void> eraseAllData({
    required Future<void> Function() onErase,
    required NotificationService notifications,
  }) async {
    await notifications.cancelAll();
    await onErase();
    await _repository.resetCache();
    AnalyticsService.instance.logEvent(AnalyticsEvents.dataErased);
    notifyListeners();
  }
}

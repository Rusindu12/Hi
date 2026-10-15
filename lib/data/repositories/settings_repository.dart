import 'package:flutter/material.dart';

import '../../core/constants/hive_keys.dart';
import '../models/app_settings.dart';
import '../sources/local/hive_store.dart';

/// Reads and writes user preferences.
///
/// Synchronous reads on purpose: settings are needed before the first frame
/// (locale, theme, font scale), so they are cached in memory at startup rather
/// than awaited per build.
class SettingsRepository {
  SettingsRepository(this._store);

  final HiveStore _store;

  AppSettings? _cached;

  /// Loads settings into memory. Safe to call more than once.
  AppSettings load() {
    if (_cached != null) {
      return _cached!;
    }
    final AppSettings settings = AppSettings(
      localeCode: _store.read<String>(HiveBoxes.settings, SettingsKeys.locale),
      themeMode: AppSettings.themeModeFromKey(
        _store.read<String>(HiveBoxes.settings, SettingsKeys.themeMode),
      ),
      fontScale: AppSettings.clampFontScale(
        _store.read<double>(HiveBoxes.settings, SettingsKeys.fontScale) ?? 1.0,
      ),
      studentName:
          _store.read<String>(HiveBoxes.settings, SettingsKeys.studentName) ?? '',
      onboarded:
          _store.read<bool>(HiveBoxes.settings, SettingsKeys.onboarded) ?? false,
      notifyReminders:
          _store.read<bool>(HiveBoxes.settings, SettingsKeys.notifyReminders) ??
              true,
      notifyAnnouncements: _store
              .read<bool>(HiveBoxes.settings, SettingsKeys.notifyAnnouncements) ??
          true,
      plannerPermissionAsked: _store.read<bool>(
            HiveBoxes.settings,
            SettingsKeys.plannerPermissionAsked,
          ) ??
          false,
    );
    _cached = settings;
    return settings;
  }

  /// Convenience for main(): the locale to boot with.
  Locale? bootLocale() {
    final String? code = load().localeCode;
    return code == null ? null : Locale(code);
  }

  Future<void> save(AppSettings settings) async {
    _cached = settings;
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.locale,
      settings.localeCode,
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.themeMode,
      AppSettings.themeModeToKey(settings.themeMode),
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.fontScale,
      settings.fontScale,
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.studentName,
      settings.studentName,
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.onboarded,
      settings.onboarded,
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.notifyReminders,
      settings.notifyReminders,
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.notifyAnnouncements,
      settings.notifyAnnouncements,
    );
    await _store.write(
      HiveBoxes.settings,
      SettingsKeys.plannerPermissionAsked,
      settings.plannerPermissionAsked,
    );
  }

  Future<void> partial({
    String? localeCode,
    bool clearLocale = false,
    ThemeMode? themeMode,
    double? fontScale,
    String? studentName,
    bool? onboarded,
    bool? notifyReminders,
    bool? notifyAnnouncements,
    bool? plannerPermissionAsked,
  }) async {
    final AppSettings next = load().copyWith(
      localeCode: localeCode,
      clearLocale: clearLocale,
      themeMode: themeMode,
      fontScale: fontScale,
      studentName: studentName,
      onboarded: onboarded,
      notifyReminders: notifyReminders,
      notifyAnnouncements: notifyAnnouncements,
      plannerPermissionAsked: plannerPermissionAsked,
    );
    await save(next);
  }

  int? catalogueSyncedAt() =>
      _store.read<int>(HiveBoxes.settings, SettingsKeys.catalogueSyncedAt);

  Future<void> markCatalogueSynced(int millis) => _store.write(
        HiveBoxes.settings,
        SettingsKeys.catalogueSyncedAt,
        millis,
      );

  int downloadCount() =>
      _store.read<int>(HiveBoxes.settings, SettingsKeys.downloadCount) ?? 0;

  Future<int> incrementDownloadCount() async {
    final int next = downloadCount() + 1;
    await _store.write(HiveBoxes.settings, SettingsKeys.downloadCount, next);
    return next;
  }

  /// Used by "erase all app data" and by tests.
  Future<void> resetCache() async {
    _cached = null;
  }
}

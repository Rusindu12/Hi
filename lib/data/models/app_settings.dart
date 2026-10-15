import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// User preferences, mirrored into a single Hive map for fast startup.
@immutable
class AppSettings {
  const AppSettings({
    this.localeCode,
    this.themeMode = ThemeMode.system,
    this.fontScale = 1.0,
    this.studentName = '',
    this.onboarded = false,
    this.notifyReminders = true,
    this.notifyAnnouncements = true,
    this.plannerPermissionAsked = false,
  });

  /// null = follow the device language (matched against supported locales).
  final String? localeCode;

  final ThemeMode themeMode;

  /// 1.0 = default. Clamped to [minFontScale, maxFontScale].
  final double fontScale;

  final String studentName;
  final bool onboarded;
  final bool notifyReminders;
  final bool notifyAnnouncements;
  final bool plannerPermissionAsked;

  static const double minFontScale = 0.9;
  static const double maxFontScale = 1.25;

  /// Presets offered in Settings.
  static const List<double> fontScalePresets = <double>[0.92, 1.0, 1.15];

  static const AppSettings defaults = AppSettings();

  /// True when the user has picked a name, used for the home greeting.
  bool get hasName => studentName.trim().isNotEmpty;

  String get greetingName => hasName ? studentName.trim() : '';

  static ThemeMode themeModeFromKey(String? key) {
    switch (key) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String themeModeToKey(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static double clampFontScale(double value) =>
      value.clamp(minFontScale, maxFontScale);

  AppSettings copyWith({
    String? localeCode,
    ThemeMode? themeMode,
    double? fontScale,
    String? studentName,
    bool? onboarded,
    bool? notifyReminders,
    bool? notifyAnnouncements,
    bool? plannerPermissionAsked,
    bool clearLocale = false,
  }) {
    return AppSettings(
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      studentName: studentName ?? this.studentName,
      onboarded: onboarded ?? this.onboarded,
      notifyReminders: notifyReminders ?? this.notifyReminders,
      notifyAnnouncements: notifyAnnouncements ?? this.notifyAnnouncements,
      plannerPermissionAsked:
          plannerPermissionAsked ?? this.plannerPermissionAsked,
    );
  }

  /// Which medium to preselect for this user: the UI language when it is one of
  /// the teaching mediums, otherwise English.
  String get preferredMedium {
    final String? code = localeCode;
    if (code != null && Mediums.isSupported(code)) {
      return code;
    }
    return Mediums.english;
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.localeCode == localeCode &&
      other.themeMode == themeMode &&
      other.fontScale == fontScale &&
      other.studentName == studentName &&
      other.onboarded == onboarded &&
      other.notifyReminders == notifyReminders &&
      other.notifyAnnouncements == notifyAnnouncements &&
      other.plannerPermissionAsked == plannerPermissionAsked;

  @override
  int get hashCode => Object.hash(
        localeCode,
        themeMode,
        fontScale,
        studentName,
        onboarded,
        notifyReminders,
        notifyAnnouncements,
        plannerPermissionAsked,
      );
}

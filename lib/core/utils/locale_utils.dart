import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../constants/app_constants.dart';

/// Locale plumbing: which languages we ship, how to parse a stored code, and
/// how to turn content *codes* (medium, exam type, weekday) into display text.
abstract final class LocaleUtils {
  const LocaleUtils._();

  /// English is first: it is the template locale for ARB generation.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si'),
    Locale('ta'),
  ];

  static const String fallbackCode = 'en';

  /// Maps a stored/remote code onto a supported locale, defaulting to English.
  static Locale fromCode(String? code) {
    if (code == null || code.isEmpty) {
      return const Locale(fallbackCode);
    }
    final String normalised = code.split(RegExp('[-_]')).first.toLowerCase();
    for (final Locale locale in supportedLocales) {
      if (locale.languageCode == normalised) {
        return locale;
      }
    }
    return const Locale(fallbackCode);
  }

  /// Best match for the device's preferred languages, so a Sinhala phone opens
  /// in Sinhala even before the user picks a language.
  static Locale systemMatch(List<Locale> preferred) {
    for (final Locale locale in preferred) {
      for (final Locale supported in supportedLocales) {
        if (supported.languageCode == locale.languageCode) {
          return supported;
        }
      }
    }
    return const Locale(fallbackCode);
  }

  // --- Content code -> display label ---------------------------------------

  static String mediumLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case Mediums.sinhala:
        return l10n.mediumSinhala;
      case Mediums.tamil:
        return l10n.mediumTamil;
      case Mediums.english:
        return l10n.mediumEnglish;
      default:
        return code.toUpperCase();
    }
  }

  static String examTypeLabel(AppLocalizations l10n, String examType) {
    switch (examType) {
      case ExamTypes.ol:
        return l10n.ppTabOl;
      case ExamTypes.al:
        return l10n.ppTabAl;
      case ExamTypes.grade5:
        return l10n.ppTabGrade5;
      case ExamTypes.term:
        return l10n.ppTabTerm;
      default:
        return l10n.labelAll;
    }
  }

  /// [weekday] follows `DateTime.monday == 1 … DateTime.sunday == 7`.
  /// `0` means "every day" (used by the planner).
  static String weekdayLabel(AppLocalizations l10n, int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return l10n.dayMonday;
      case DateTime.tuesday:
        return l10n.dayTuesday;
      case DateTime.wednesday:
        return l10n.dayWednesday;
      case DateTime.thursday:
        return l10n.dayThursday;
      case DateTime.friday:
        return l10n.dayFriday;
      case DateTime.saturday:
        return l10n.daySaturday;
      case DateTime.sunday:
        return l10n.daySunday;
      default:
        return l10n.plEveryDay;
    }
  }

  /// Short weekday form for compact chips ("Mon", "සඳුදා").
  static String weekdayShortLabel(AppLocalizations l10n, int weekday) {
    final String full = weekdayLabel(l10n, weekday);
    return full.length <= 4 ? full : full.substring(0, 3);
  }

  /// 12-hour clock label that is script-neutral, e.g. "7:30 AM".
  static String timeLabel(int hour, int minute, String localeCode) {
    final int normalisedHour = hour % 24;
    final int display = normalisedHour % 12 == 0 ? 12 : normalisedHour % 12;
    final String suffix = normalisedHour < 12 ? 'AM' : 'PM';
    final String mm = minute.toString().padLeft(2, '0');
    return '$display:$mm $suffix';
  }
}

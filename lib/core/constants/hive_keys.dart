/// Hive box names and keys.
///
/// Every key is a `const` so a typo becomes a compile error instead of a
/// silently-lost favourite.
library;

abstract final class HiveBoxes {
  const HiveBoxes._();

  /// User preferences: locale, theme mode, font scale, student name, toggles.
  static const String settings = 'settings';

  /// Bookmarked books and papers (ids only; metadata comes from the catalogue).
  static const String favorites = 'favorites';

  /// Reading progress: last page per book/paper id.
  static const String progress = 'progress';

  /// Download records for offline files stored in the app documents directory.
  static const String downloads = 'downloads';

  /// "Continue where you left off" entries, most recent first.
  static const String recents = 'recents';

  /// Completed quiz attempts (for the local leaderboard and badges).
  static const String quizResults = 'quiz_results';

  /// Streak state: current, longest, freezes, contributing days.
  static const String streak = 'streak';

  /// Unlocked badges with their earned timestamps.
  static const String badges = 'badges';

  /// Locally-created study planner slots.
  static const String planner = 'planner';

  /// Cached catalogue copies, so the app still opens with no internet.
  static const String cache = 'cache';

  static const List<String> all = <String>[
    settings,
    favorites,
    progress,
    downloads,
    recents,
    quizResults,
    streak,
    badges,
    planner,
    cache,
  ];
}

abstract final class SettingsKeys {
  const SettingsKeys._();

  static const String locale = 'locale';
  static const String themeMode = 'theme_mode';
  static const String fontScale = 'font_scale';
  static const String studentName = 'student_name';
  static const String onboarded = 'onboarded';
  static const String notifyReminders = 'notify_reminders';
  static const String notifyAnnouncements = 'notify_announcements';
  static const String plannerPermissionAsked = 'planner_permission_asked';
  static const String catalogueSyncedAt = 'catalogue_synced_at';
  static const String downloadCount = 'download_count';
  static const String timezoneSet = 'timezone_set';
}

abstract final class CacheKeys {
  const CacheKeys._();

  static const String catalogueJson = 'catalogue_json';
  static const String subjectsJson = 'subjects_json';
  static const String questionsJson = 'questions_json';
}

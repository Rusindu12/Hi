/// Date arithmetic for streak tracking.
///
/// Streaks are stored as *calendar day keys* ('2026-10-15') rather than
/// timestamps: a student studying at 23:59 and again at 00:01 has studied on two
/// different days, and comparing `DateTime`s that include a time would get that
/// wrong. Day keys also make the data human-readable when debugging Hive.
abstract final class DateKeys {
  const DateKeys._();

  /// 'yyyy-MM-dd' for the local calendar day of [value].
  static String day(DateTime value) {
    final DateTime local = value.toLocal();
    final String m = local.month.toString().padLeft(2, '0');
    final String d = local.day.toString().padLeft(2, '0');
    return '${local.year}-$m-$d';
  }

  /// 'yyyy-Www' ISO-ish week key (Monday-based), used for the weekly streak
  /// freeze allowance. Weeks are keyed by the year of that week's Monday, so
  /// 2026-12-31 and 2027-01-01 can fall in the same week bucket.
  static String week(DateTime value) {
    final DateTime monday = startOfWeek(value);
    final String m = monday.month.toString().padLeft(2, '0');
    final String d = monday.day.toString().padLeft(2, '0');
    return '${monday.year}-$m-$d';
  }

  /// Parses a day key back into a local midnight [DateTime].
  /// Returns null for malformed input instead of throwing.
  static DateTime? parseDay(String key) {
    final List<String> parts = key.split('-');
    if (parts.length != 3) {
      return null;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    return DateTime(year, month, day);
  }

  static DateTime startOfDay(DateTime value) {
    final DateTime local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Monday 00:00 of the week containing [value].
  static DateTime startOfWeek(DateTime value) {
    final DateTime day = startOfDay(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Whole calendar days between two keys (b - a). Negative when b is earlier.
  static int daysBetween(String a, String b) {
    final DateTime? first = parseDay(a);
    final DateTime? second = parseDay(b);
    if (first == null || second == null) {
      return 0;
    }
    // Day arithmetic on local midnights can be off by one across DST; Sri Lanka
    // has no DST, but this keeps the helper correct anywhere.
    final int millis = second.difference(first).inMilliseconds;
    return (millis / Duration.millisecondsPerDay).round();
  }

  static bool isSameDay(DateTime a, DateTime b) => day(a) == day(b);

  static bool isToday(String key, DateTime now) => key == day(now);

  static bool isYesterday(String key, DateTime now) {
    final DateTime yesterday = startOfDay(now).subtract(const Duration(days: 1));
    return key == day(yesterday);
  }

  /// The last [count] day keys ending today, oldest first. Drives the
  /// week-strip on the streak card.
  static List<String> lastDays(DateTime now, int count) {
    final DateTime today = startOfDay(now);
    return List<String>.generate(
      count,
      (int i) => day(today.subtract(Duration(days: count - 1 - i))),
    );
  }
}

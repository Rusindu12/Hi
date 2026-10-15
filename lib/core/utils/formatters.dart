import 'package:intl/intl.dart';

/// Small formatting helpers. Units such as "MB" and "KB" are international
/// technical abbreviations and are intentionally not localised; everything
/// that is a *word* comes from `AppLocalizations`.
abstract final class Formatters {
  const Formatters._();

  static const List<String> _byteUnits = <String>['B', 'KB', 'MB', 'GB', 'TB'];

  /// 1536 -> "1.5 KB", 10485760 -> "10 MB".
  static String bytes(int value, {int decimals = 1}) {
    if (value <= 0) {
      return '0 B';
    }
    double size = value.toDouble();
    int unit = 0;
    while (size >= 1024 && unit < _byteUnits.length - 1) {
      size /= 1024;
      unit++;
    }
    final bool whole = size >= 100 || size == size.roundToDouble();
    return '${size.toStringAsFixed(whole ? 0 : decimals)} ${_byteUnits[unit]}';
  }

  /// 5 -> "0:05", 95 -> "1:35".
  static String clock(int totalSeconds) {
    final int safe = totalSeconds < 0 ? 0 : totalSeconds;
    final int minutes = safe ~/ 60;
    final int seconds = safe % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 1234 -> "1.2K" (used for download counters).
  static String compactCount(int value) {
    if (value < 1000) {
      return '$value';
    }
    if (value < 1000000) {
      final double k = value / 1000;
      return '${k.toStringAsFixed(k >= 100 ? 0 : 1)}K';
    }
    final double m = value / 1000000;
    return '${m.toStringAsFixed(1)}M';
  }

  /// Locale-aware short date, e.g. "12 Mar 2025" in English. Falls back to an
  /// ISO string if `intl` has no data loaded for that locale (see main.dart,
  /// which calls `initializeDateFormatting()`).
  static String date(DateTime value, String localeCode) {
    try {
      return DateFormat.yMMMd(localeCode).format(value);
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(value);
    }
  }

  /// "2h ago" style relative label, using `intl` for plural-safe output.
  static String relative(DateTime value, String localeCode, DateTime now) {
    final Duration diff = now.difference(value);
    if (diff.inMinutes < 1) {
      return DateFormat.Hm(localeCode).format(value);
    }
    try {
      return DateFormat.yMMMd(localeCode).add_Hm().format(value);
    } catch (_) {
      return DateFormat('yyyy-MM-dd HH:mm').format(value);
    }
  }

  /// Percentage as an int, guarding against divide-by-zero.
  static int percent(int part, int total) {
    if (total <= 0) {
      return 0;
    }
    return ((part / total) * 100).round();
  }

  /// "mathematics" -> "Mathematics" (fallback when a subject is missing from
  /// the localised name table).
  static String humanizeCode(String code) {
    if (code.isEmpty) {
      return code;
    }
    return code
        .split('_')
        .map(
          (String part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  /// Human readable file name for a downloaded paper, e.g.
  /// "2019-OL-Mathematics-si.pdf".
  static String downloadFileName({
    required String paperId,
    required String extension,
  }) {
    final String safe = paperId.replaceAll(RegExp('[^A-Za-z0-9_-]'), '-');
    return '$safe.$extension';
  }
}

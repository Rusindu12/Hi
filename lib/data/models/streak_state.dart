import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
import '../../core/utils/date_keys.dart';

/// Persisted streak state.
///
/// The rules live in `StreakService`; this class only stores data and answers
/// pure questions about it, which makes the service trivially testable.
@immutable
class StreakState {
  const StreakState({
    this.current = 0,
    this.longest = 0,
    this.totalStudyDays = 0,
    this.lastStudyDay,
    this.studyDays = const <String>[],
    this.frozenDays = const <String>[],
    this.freezeWeeksUsed = const <String>[],
  });

  factory StreakState.fromJson(Map<String, Object?> json) => StreakState(
        current: _int(json['current']),
        longest: _int(json['longest']),
        totalStudyDays: _int(json['totalStudyDays']),
        lastStudyDay: json['lastStudyDay']?.toString(),
        studyDays: _stringList(json['studyDays']),
        frozenDays: _stringList(json['frozenDays']),
        freezeWeeksUsed: _stringList(json['freezeWeeksUsed']),
      );

  static const StreakState empty = StreakState();

  /// Consecutive days up to and including the most recent study day.
  final int current;

  /// Best ever [current].
  final int longest;

  /// Lifetime count of distinct study days (badges use this).
  final int totalStudyDays;

  /// Day key of the most recent qualifying study day.
  final String? lastStudyDay;

  /// Recent day keys, newest first. Capped (see StreakService) so Hive stays
  /// small; 60 days is enough for the week strip and badges.
  final List<String> studyDays;

  /// Days that were skipped using a streak freeze (they keep the chain alive).
  final List<String> frozenDays;

  /// Week keys in which a freeze has already been consumed.
  final List<String> freezeWeeksUsed;

  bool get isActive => current > 0;

  bool studiedToday(DateTime now) =>
      lastStudyDay != null && DateKeys.isToday(lastStudyDay!, now);

  /// True when today has no study yet but the streak is still recoverable.
  bool isAtRisk(DateTime now) {
    if (lastStudyDay == null) {
      return false;
    }
    return DateKeys.isYesterday(lastStudyDay!, now) && !studiedToday(now);
  }

  /// Broken: the last study day is older than yesterday and today is unstudied.
  bool isBroken(DateTime now) {
    if (lastStudyDay == null) {
      return false;
    }
    final int gap = DateKeys.daysBetween(lastStudyDay!, DateKeys.day(now));
    return gap > 1;
  }

  int freezesUsedThisWeek(DateTime now) =>
      freezeWeeksUsed.contains(DateKeys.week(now)) ? 1 : 0;

  int freezesLeft(DateTime now) =>
      (AppConfig.streakFreezesPerWeek - freezesUsedThisWeek(now)).clamp(0, 99);

  bool canUseFreeze(DateTime now) {
    if (freezesLeft(now) <= 0) {
      return false;
    }
    final String today = DateKeys.day(now);
    if (studiedToday(now) || frozenDays.contains(today)) {
      return false;
    }
    // A freeze is only meaningful when a chain exists but today is unstudied.
    return current > 0 && lastStudyDay != null;
  }

  /// The week strip shown on the home card: seven day keys (oldest first) with
  /// a flag for whether each was studied or frozen.
  List<StreakDayMark> weekStrip(DateTime now) {
    final List<String> days = DateKeys.lastDays(now, 7);
    return days
        .map(
          (String key) => StreakDayMark(
            dayKey: key,
            studied: studyDays.contains(key),
            frozen: frozenDays.contains(key),
            isToday: DateKeys.isToday(key, now),
          ),
        )
        .toList();
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'current': current,
        'longest': longest,
        'totalStudyDays': totalStudyDays,
        if (lastStudyDay != null) 'lastStudyDay': lastStudyDay,
        'studyDays': studyDays,
        'frozenDays': frozenDays,
        'freezeWeeksUsed': freezeWeeksUsed,
      };

  StreakState copyWith({
    int? current,
    int? longest,
    int? totalStudyDays,
    String? lastStudyDay,
    List<String>? studyDays,
    List<String>? frozenDays,
    List<String>? freezeWeeksUsed,
  }) {
    return StreakState(
      current: current ?? this.current,
      longest: longest ?? this.longest,
      totalStudyDays: totalStudyDays ?? this.totalStudyDays,
      lastStudyDay: lastStudyDay ?? this.lastStudyDay,
      studyDays: studyDays ?? this.studyDays,
      frozenDays: frozenDays ?? this.frozenDays,
      freezeWeeksUsed: freezeWeeksUsed ?? this.freezeWeeksUsed,
    );
  }
}

/// One cell of the home screen week strip.
@immutable
class StreakDayMark {
  const StreakDayMark({
    required this.dayKey,
    required this.studied,
    required this.frozen,
    required this.isToday,
  });

  final String dayKey;
  final bool studied;
  final bool frozen;
  final bool isToday;

  bool get isMarked => studied || frozen;

  /// 1 = Monday … 7 = Sunday, for the weekday letter under each cell.
  int get weekday =>
      DateKeys.parseDay(dayKey)?.weekday ?? DateTime.monday;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(Object? value) {
  if (value is List) {
    return value.map((Object? e) => e.toString()).toList();
  }
  return const <String>[];
}

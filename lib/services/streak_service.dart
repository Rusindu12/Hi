import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../core/utils/date_keys.dart';
import '../data/models/streak_state.dart';
import '../data/repositories/streak_repository.dart';

/// Outcome of recording a study action.
@immutable
class StreakOutcome {
  const StreakOutcome({
    required this.state,
    required this.incremented,
    required this.previousCurrent,
    this.brokenBefore = false,
  });

  final StreakState state;

  /// True when today had no study yet and this action started/extended it.
  final bool incremented;

  /// Streak length before this action, for the "+1" celebration.
  final int previousCurrent;

  /// True when a previous chain had already lapsed and this action restarted it.
  final bool brokenBefore;

  int get current => state.current;
}

/// The study streak rules.
///
/// Rule (documented in README for users):
///   * Opening a textbook/paper or finishing a quiz counts for **today**.
///   * Consecutive calendar days build the streak; a missed day breaks it.
///   * One **streak freeze** per calendar week can bridge a single missed day.
///   * Longest streak and lifetime study days are never reset.
///
/// Kept free of Flutter widgets and of Hive internals: it takes a repository and
/// a clock, so every rule below is unit-tested in
/// `test/unit/streak_service_test.dart`.
class StreakService {
  StreakService(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final StreakRepository _repository;
  final DateTime Function() _clock;

  /// Hard cap on stored day keys: enough for the week strip, badges and the
  /// longest-streak display, small enough that Hive stays instant.
  static const int maxStoredDays = 60;

  StreakState get state => _repository.load();

  /// Recomputes `current` on app start.
  ///
  /// A streak of 7 that was interrupted three days ago must not still read "7".
  /// Called once per launch, before the UI reads the value, and only writes when
  /// something actually changed.
  Future<StreakState> reconcile({DateTime? now}) async {
    final DateTime moment = now ?? _clock();
    final StreakState current = _repository.load();
    if (current.lastStudyDay == null) {
      return current;
    }

    final int gap = DateKeys.daysBetween(current.lastStudyDay!, DateKeys.day(moment));
    // gap 0 = studied today, 1 = studied yesterday (still alive), >= 2 = lapsed.
    if (gap < 2 || current.current == 0) {
      return current;
    }

    final StreakState reset = current.copyWith(current: 0);
    await _repository.save(reset);
    debugPrint('[streak] lapsed after $gap days, current reset to 0');
    return reset;
  }

  /// Records a qualifying study action for today.
  ///
  /// Idempotent: calling it twice in one day increments only once, which is what
  /// lets the PDF reader *and* the quiz screen both call it safely.
  Future<StreakOutcome> recordStudy({DateTime? now}) async {
    final DateTime moment = now ?? _clock();
    final String today = DateKeys.day(moment);
    final StreakState current = await reconcile(now: moment);

    if (current.studyDays.contains(today)) {
      return StreakOutcome(
        state: current,
        incremented: false,
        previousCurrent: current.current,
      );
    }

    final bool brokenBefore = current.current == 0 && current.lastStudyDay != null;

    int nextCurrent;
    if (current.lastStudyDay == null) {
      nextCurrent = 1;
    } else {
      final int gap = DateKeys.daysBetween(current.lastStudyDay!, today);
      if (gap <= 1) {
        // Yesterday (or the day a freeze bridged) -> extend the chain.
        nextCurrent = current.current + 1;
      } else {
        // Lapsed: today starts a new chain.
        nextCurrent = 1;
      }
    }

    final List<String> days = <String>[today, ...current.studyDays]
        .take(maxStoredDays)
        .toList();

    final StreakState next = current.copyWith(
      current: nextCurrent,
      longest: nextCurrent > current.longest ? nextCurrent : current.longest,
      totalStudyDays: current.totalStudyDays + 1,
      lastStudyDay: today,
      studyDays: days,
    );
    await _repository.save(next);

    return StreakOutcome(
      state: next,
      incremented: true,
      previousCurrent: current.current,
      brokenBefore: brokenBefore,
    );
  }

  /// Whether the freeze button should be enabled right now.
  bool canUseFreeze({DateTime? now}) {
    final DateTime moment = now ?? _clock();
    final StreakState current = _repository.load();
    if (current.freezesLeft(moment) <= 0) {
      return false;
    }
    if (current.current <= 0 || current.lastStudyDay == null) {
      return false;
    }
    final String today = DateKeys.day(moment);
    if (current.studyDays.contains(today) || current.frozenDays.contains(today)) {
      return false;
    }
    // Only a *single* missed day can be bridged; two or more means the chain is
    // gone and freezing would be misleading.
    final int gap = DateKeys.daysBetween(current.lastStudyDay!, today);
    return gap == 2;
  }

  /// Spends this week's freeze to bridge exactly one missed day.
  ///
  /// On success the missed day is recorded as frozen and treated as studied, so
  /// today's action extends the chain instead of restarting it.
  Future<StreakOutcome?> useFreeze({DateTime? now}) async {
    final DateTime moment = now ?? _clock();
    if (!canUseFreeze(now: moment)) {
      return null;
    }
    final StreakState current = _repository.load();
    final String today = DateKeys.day(moment);
    final String missedDay = DateKeys.day(
      DateKeys.startOfDay(moment).subtract(const Duration(days: 1)),
    );

    final List<String> frozen = <String>[missedDay, ...current.frozenDays]
        .take(maxStoredDays)
        .toList();
    final List<String> weeks = <String>[
      ...current.freezeWeeksUsed,
      DateKeys.week(moment),
    ];

    final StreakState next = current.copyWith(
      // Point the chain at the bridged day so today's study extends it.
      lastStudyDay: missedDay,
      frozenDays: frozen,
      freezeWeeksUsed: weeks,
    );
    await _repository.save(next);

    return StreakOutcome(
      state: next,
      incremented: false,
      previousCurrent: current.current,
    );
  }

  /// Lifetime study days, used by the badge rules.
  int get totalStudyDays => _repository.load().totalStudyDays;

  int get longest => _repository.load().longest;

  Future<void> reset() => _repository.clear();

  /// Ceiling on freezes, surfaced so the UI can show "1 left" / "used".
  int get weeklyFreezeAllowance => AppConfig.streakFreezesPerWeek;
}

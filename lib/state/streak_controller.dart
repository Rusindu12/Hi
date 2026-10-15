import 'package:flutter/foundation.dart';

import '../data/models/badge.dart';
import '../data/models/streak_state.dart';
import '../data/repositories/catalogue_repository.dart';
import '../services/analytics_service.dart';
import '../services/badge_service.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';

/// Streak + badges, and the "something happened, celebrate it" queue.
///
/// The UI calls [recordStudy] from the PDF reader and at the end of a quiz — the
/// two actions the brief defines as counting. It is idempotent per day, so
/// calling it from both places is safe.
class StreakController extends ChangeNotifier {
  StreakController({
    required StreakService streak,
    required BadgeService badges,
    required CatalogueRepository catalogue,
  })  : _streak = streak,
        _badges = badges,
        _catalogue = catalogue;

  final StreakService _streak;
  final BadgeService _badges;
  final CatalogueRepository _catalogue;

  StreakState _state = StreakState.empty;
  BadgeCollection _badgeCollection = BadgeCollection.empty;
  bool _loading = true;

  /// Badges waiting to be shown as a snackbar; drained by the shell.
  final List<BadgeId> pendingUnlocks = <BadgeId>[];

  StreakState get state => _state;

  BadgeCollection get badges => _badgeCollection;

  bool get isLoading => _loading;

  int get current => _state.current;

  int get longest => _state.longest;

  int get totalStudyDays => _state.totalStudyDays;

  int get earnedBadgeCount => _badgeCollection.earnedCount;

  int get totalBadgeCount => BadgeId.values.length;

  List<StreakDayMark> weekStrip({DateTime? now}) =>
      _state.weekStrip(now ?? DateTime.now());

  bool studiedToday({DateTime? now}) =>
      _state.studiedToday(now ?? DateTime.now());

  bool isAtRisk({DateTime? now}) => _state.isAtRisk(now ?? DateTime.now());

  int freezesLeft({DateTime? now}) => _state.freezesLeft(now ?? DateTime.now());

  bool canUseFreeze({DateTime? now}) => _streak.canUseFreeze(now: now);

  /// Badge progress for the carousel: (earned, current, target).
  (bool earned, int current, int target) badgeProgress(BadgeId id) {
    final BadgeContext context = _badges.contextFor(_state);
    final bool earned = _badgeCollection.has(id) || _badges.isEarned(id, context);
    final (int, int) progress = _badges.progressFor(id, context);
    return (earned, progress.$1, progress.$2);
  }

  /// App called start-up: recompute a lapsed streak, then refresh badges.
  Future<void> initialise({DateTime? now}) async {
    _loading = true;
    notifyListeners();
    _state = await _streak.reconcile(now: now);
    _badgeCollection = _badges.load();
    _loading = false;
    notifyListeners();
  }

  /// Records a qualifying study action for today.
  ///
  /// Returns true when the streak actually advanced, so callers know whether to
  /// show the "+1" celebration.
  Future<bool> recordStudy({DateTime? now}) async {
    final StreakOutcome outcome = await _streak.recordStudy(now: now);
    _state = outcome.state;
    if (outcome.incremented) {
      AnalyticsService.instance.logEvent(
        AnalyticsEvents.streakIncremented,
        parameters: <String, Object?>{'current': outcome.state.current},
      );
    }
    await _refreshBadges(now: now);
    notifyListeners();
    return outcome.incremented;
  }

  Future<bool> useFreeze({DateTime? now}) async {
    final StreakOutcome? outcome = await _streak.useFreeze(now: now);
    if (outcome == null) {
      return false;
    }
    _state = outcome.state;
    AnalyticsService.instance.logEvent(AnalyticsEvents.streakFreezeUsed);
    notifyListeners();
    return true;
  }

  /// Re-runs badge rules. Called after downloads, quizzes, planner changes and
  /// reading, so a badge never depends on which screen you visited.
  Future<List<BadgeId>> _refreshBadges({DateTime? now}) async {
    final List<BadgeId> unlocked = await _badges.evaluate(_state, now: now);
    _badgeCollection = _badges.load();
    if (unlocked.isNotEmpty) {
      pendingUnlocks.addAll(unlocked);
      for (final BadgeId badge in unlocked) {
        AnalyticsService.instance.logEvent(
          AnalyticsEvents.badgeUnlocked,
          parameters: <String, Object?>{'badge': badge.name},
        );
      }
    }
    return unlocked;
  }

  /// Public hook for other controllers (downloads, planner).
  Future<List<BadgeId>> checkBadges() => _refreshBadges();

  /// Returns and clears the badges waiting to be celebrated.
  ///
  /// Drained by whichever screen caused the unlock (the planner sheet, the quiz
  /// result, a download) so the celebration appears in the right context instead
  /// of ambushing the student after an unrelated tap.
  List<BadgeId> drainPendingUnlocks() {
    if (pendingUnlocks.isEmpty) {
      return const <BadgeId>[];
    }
    final List<BadgeId> drained = List<BadgeId>.of(pendingUnlocks);
    pendingUnlocks.clear();
    return drained;
  }

  /// Optional nudge: when a streak is at risk and reminders are on, fire a local
  /// notification. Deliberately gentle: once per day at most, driven by the
  /// notification id below.
  Future<void> maybeNudgeAtRisk({
    required bool remindersEnabled,
    required NotificationService notifications,
    required String title,
    required String body,
    DateTime? now,
  }) async {
    if (!remindersEnabled || !isAtRisk(now: now)) {
      return;
    }
    await notifications.initialise();
    await notifications.showNow(
      id: NotificationService.streakNudgeNotificationId,
      title: title,
      body: body,
    );
  }

  /// Rows for the Home badges carousel.
  List<BadgeId> get badgeOrder => BadgeId.values;

  String badgeLabel(String code) => _catalogue.subjectLabel(code, 'en');
}

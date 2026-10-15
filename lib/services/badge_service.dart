import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../data/models/badge.dart';
import '../data/models/streak_state.dart';
import '../data/repositories/badge_repository.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/planner_repository.dart';
import '../data/repositories/quiz_history_repository.dart';

/// Everything the badge rules need, gathered once so evaluation is a pure
/// function of state (and therefore easy to test).
@immutable
class BadgeContext {
  const BadgeContext({
    required this.streak,
    required this.quizAttemptCount,
    required this.quizAttemptsAboveThreshold,
    required this.booksOpened,
    required this.downloadCount,
    required this.plannerSlotCount,
  });

  final StreakState streak;
  final int quizAttemptCount;
  final int quizAttemptsAboveThreshold;
  final int booksOpened;
  final int downloadCount;
  final int plannerSlotCount;
}

/// Evaluates and awards badges.
///
/// Rules live in one switch-like list so the "why did I get this badge?" answer
/// is always findable. Evaluation is cheap and idempotent, so it runs after any
/// qualifying action without hammering Hive.
class BadgeService {
  BadgeService({
    required BadgeRepository badges,
    required QuizHistoryRepository quizHistory,
    required LibraryRepository library,
    required PlannerRepository planner,
  })  : _badges = badges,
        _quizHistory = quizHistory,
        _library = library,
        _planner = planner;

  final BadgeRepository _badges;
  final QuizHistoryRepository _quizHistory;
  final LibraryRepository _library;
  final PlannerRepository _planner;

  BadgeCollection get collection => _badges.load();

  /// Builds the context from repositories. Cheap: every source is in-memory Hive.
  BadgeContext contextFor(StreakState streak) => BadgeContext(
        streak: streak,
        quizAttemptCount: _quizHistory.totalAttempts(),
        quizAttemptsAboveThreshold:
            _quizHistory.countAtOrAbove(AppConfig.quizMasterThresholdPercent),
        booksOpened: _library
            .recents()
            .where((dynamic e) => e.kind == 'textbook')
            .length,
        downloadCount: _library.downloadCount(),
        plannerSlotCount: _planner.count(),
      );

  /// True when a badge's condition is satisfied.
  bool isEarned(BadgeId id, BadgeContext context) {
    switch (id) {
      case BadgeId.firstBook:
        return context.booksOpened >= 1;
      case BadgeId.firstQuiz:
        return context.quizAttemptCount >= 1;
      case BadgeId.streak7:
        return context.streak.longest >= 7;
      case BadgeId.streak30:
        return context.streak.longest >= 30;
      case BadgeId.quizMaster:
        return context.quizAttemptsAboveThreshold >=
            AppConfig.quizMasterRequiredCount;
      case BadgeId.tenDownloads:
        return context.downloadCount >= AppConfig.tenDownloadsBadgeCount;
      case BadgeId.plannerPro:
        return context.plannerSlotCount >= 1;
    }
  }

  /// Unlocks every satisfied badge and returns the ones that are *new*, so the
  /// caller can queue a celebration without re-checking state.
  Future<List<BadgeId>> evaluate(StreakState streak, {DateTime? now}) async {
    final BadgeContext context = contextFor(streak);
    final List<BadgeId> unlocked = <BadgeId>[];
    for (final BadgeId id in BadgeId.values) {
      if (!isEarned(id, context)) {
        continue;
      }
      final bool isNew = await _badges.unlock(id, at: now);
      if (isNew) {
        unlocked.add(id);
      }
    }
    if (unlocked.isNotEmpty) {
      debugPrint('[badges] unlocked: ${unlocked.map((BadgeId b) => b.name).join(', ')}');
    }
    return unlocked;
  }

  /// Progress towards locked badges, for the Home badges carousel: returns
  /// (current, target) so the UI can draw a ring.
  (int current, int target) progressFor(BadgeId id, BadgeContext context) {
    switch (id) {
      case BadgeId.firstBook:
        return (context.booksOpened.clamp(0, 1), 1);
      case BadgeId.firstQuiz:
        return (context.quizAttemptCount.clamp(0, 1), 1);
      case BadgeId.streak7:
        return (context.streak.longest.clamp(0, 7), 7);
      case BadgeId.streak30:
        return (context.streak.longest.clamp(0, 30), 30);
      case BadgeId.quizMaster:
        return (
          context.quizAttemptsAboveThreshold
              .clamp(0, AppConfig.quizMasterRequiredCount),
          AppConfig.quizMasterRequiredCount,
        );
      case BadgeId.tenDownloads:
        return (
          context.downloadCount.clamp(0, AppConfig.tenDownloadsBadgeCount),
          AppConfig.tenDownloadsBadgeCount,
        );
      case BadgeId.plannerPro:
        return (context.plannerSlotCount.clamp(0, 1), 1);
    }
  }

  Future<void> reset() => _badges.clear();
}

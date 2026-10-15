import '../../core/constants/hive_keys.dart';
import '../models/quiz_attempt.dart';
import '../sources/local/hive_store.dart';

/// Stores finished quiz attempts so the leaderboard, personal bests and badge
/// rules all work offline and without an account.
class QuizHistoryRepository {
  QuizHistoryRepository(this._store);

  final HiveStore _store;

  static const int _maxAttempts = 200;

  List<QuizAttempt> attempts() {
    final List<QuizAttempt> list =
        _store.readMapList(HiveBoxes.quizResults).map(QuizAttempt.fromJson).toList()
          ..sort((QuizAttempt a, QuizAttempt b) =>
              b.completedAtMillis.compareTo(a.completedAtMillis));
    return list;
  }

  Future<void> save(QuizAttempt attempt) async {
    await _store.writeMap(HiveBoxes.quizResults, attempt.id, attempt.toJson());
    await _prune();
  }

  Future<void> _prune() async {
    final List<QuizAttempt> all = attempts();
    if (all.length <= _maxAttempts) {
      return;
    }
    for (final QuizAttempt attempt in all.sublist(_maxAttempts)) {
      await _store.delete(HiveBoxes.quizResults, attempt.id);
    }
  }

  /// Anonymous local leaderboard: best percentage per subject, keeping the
  /// attempt that achieved it. Capped by [limit].
  List<LeaderboardEntry> leaderboard({int limit = 20, String? subjectCode}) {
    final Map<String, LeaderboardEntry> best = <String, LeaderboardEntry>{};
    for (final QuizAttempt attempt in attempts()) {
      if (subjectCode != null && attempt.subjectCode != subjectCode) {
        continue;
      }
      if (attempt.total == 0) {
        continue;
      }
      final LeaderboardEntry entry = LeaderboardEntry.fromAttempt(attempt);
      final LeaderboardEntry? existing = best[attempt.subjectCode];
      if (existing == null ||
          entry.percent > existing.percent ||
          (entry.percent == existing.percent &&
              entry.completedAtMillis > existing.completedAtMillis)) {
        best[attempt.subjectCode] = entry;
      }
    }
    final List<LeaderboardEntry> sorted = best.values.toList()
      ..sort((LeaderboardEntry a, LeaderboardEntry b) {
        final int byPercent = b.percent.compareTo(a.percent);
        if (byPercent != 0) {
          return byPercent;
        }
        return b.completedAtMillis.compareTo(a.completedAtMillis);
      });
    return sorted.take(limit).toList();
  }

  /// Highest percentage ever achieved for a subject (or overall).
  ///
  /// [excludeAttemptId] is used by the result screen: to decide whether *this*
  /// attempt is a personal best we must compare it against the attempts that
  /// existed before it — and the attempt is already saved by then.
  int bestPercent({String? subjectCode, String? excludeAttemptId}) {
    int best = 0;
    for (final QuizAttempt attempt in attempts()) {
      if (subjectCode != null && attempt.subjectCode != subjectCode) {
        continue;
      }
      if (excludeAttemptId != null && attempt.id == excludeAttemptId) {
        continue;
      }
      if (attempt.percent > best) {
        best = attempt.percent;
      }
    }
    return best;
  }

  /// Count of attempts at or above [thresholdPercent] — the "Quiz master" rule.
  int countAtOrAbove(int thresholdPercent) => attempts()
      .where((QuizAttempt a) => a.total > 0 && a.percent >= thresholdPercent)
      .length;

  int totalAttempts() => attempts().length;

  Future<void> clear() => _store.clearBox(HiveBoxes.quizResults);
}

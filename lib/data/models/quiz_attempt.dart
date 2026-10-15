import 'package:flutter/foundation.dart';

/// A single answer inside an attempt.
@immutable
class QuizAnswer {
  const QuizAnswer({
    required this.questionId,
    required this.selectedIndex,
    required this.correctIndex,
    required this.elapsedSeconds,
  });

  factory QuizAnswer.fromJson(Map<String, Object?> json) => QuizAnswer(
        questionId: (json['questionId'] ?? '').toString(),
        selectedIndex: _int(json['selectedIndex'], -1),
        correctIndex: _int(json['correctIndex'], -1),
        elapsedSeconds: _int(json['elapsedSeconds'], 0),
      );

  final String questionId;

  /// -1 means the student ran out of time or skipped.
  final int selectedIndex;

  final int correctIndex;
  final int elapsedSeconds;

  bool get isSkipped => selectedIndex < 0;

  bool get isCorrect => !isSkipped && selectedIndex == correctIndex;

  Map<String, Object?> toJson() => <String, Object?>{
        'questionId': questionId,
        'selectedIndex': selectedIndex,
        'correctIndex': correctIndex,
        'elapsedSeconds': elapsedSeconds,
      };
}

/// A finished quiz attempt. Persisted in Hive so the leaderboard, "best score"
/// and badge checks all work with no login and no network.
@immutable
class QuizAttempt {
  const QuizAttempt({
    required this.id,
    required this.subjectCode,
    required this.examType,
    required this.medium,
    required this.answers,
    required this.startedAtMillis,
    required this.completedAtMillis,
    this.year,
  });

  factory QuizAttempt.fromJson(Map<String, Object?> json) {
    final List<Object?> raw = (json['answers'] as List<Object?>?) ?? const <Object?>[];
    return QuizAttempt(
      id: (json['id'] ?? '').toString(),
      subjectCode: (json['subject'] ?? '').toString(),
      examType: (json['examType'] ?? '').toString(),
      medium: (json['medium'] ?? '').toString(),
      year: _intOrNull(json['year']),
      answers: raw
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> m) => QuizAnswer.fromJson(m.cast<String, Object?>()))
          .toList(),
      startedAtMillis: _int(json['startedAt'], 0),
      completedAtMillis: _int(json['completedAt'], 0),
    );
  }

  final String id;
  final String subjectCode;
  final String examType;
  final String medium;
  final int? year;
  final List<QuizAnswer> answers;
  final int startedAtMillis;
  final int completedAtMillis;

  int get total => answers.length;

  int get correctCount => answers.where((QuizAnswer a) => a.isCorrect).length;

  int get skippedCount => answers.where((QuizAnswer a) => a.isSkipped).length;

  int get wrongCount => total - correctCount - skippedCount;

  int get percent => total == 0 ? 0 : ((correctCount / total) * 100).round();

  Duration get duration =>
      Duration(milliseconds: completedAtMillis - startedAtMillis);

  DateTime get completedAt => DateTime.fromMillisecondsSinceEpoch(completedAtMillis);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'subject': subjectCode,
        'examType': examType,
        'medium': medium,
        if (year != null) 'year': year,
        'answers': answers.map((QuizAnswer a) => a.toJson()).toList(),
        'startedAt': startedAtMillis,
        'completedAt': completedAtMillis,
      };
}

/// One row of the anonymous local leaderboard.
@immutable
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.attemptId,
    required this.subjectCode,
    required this.examType,
    required this.correctCount,
    required this.total,
    required this.completedAtMillis,
    this.year,
  });

  factory LeaderboardEntry.fromAttempt(QuizAttempt attempt) => LeaderboardEntry(
        attemptId: attempt.id,
        subjectCode: attempt.subjectCode,
        examType: attempt.examType,
        year: attempt.year,
        correctCount: attempt.correctCount,
        total: attempt.total,
        completedAtMillis: attempt.completedAtMillis,
      );

  factory LeaderboardEntry.fromJson(Map<String, Object?> json) => LeaderboardEntry(
        attemptId: (json['attemptId'] ?? '').toString(),
        subjectCode: (json['subject'] ?? '').toString(),
        examType: (json['examType'] ?? '').toString(),
        year: _intOrNull(json['year']),
        correctCount: _int(json['correct'], 0),
        total: _int(json['total'], 0),
        completedAtMillis: _int(json['completedAt'], 0),
      );

  final String attemptId;
  final String subjectCode;
  final String examType;
  final int? year;
  final int correctCount;
  final int total;
  final int completedAtMillis;

  int get percent => total == 0 ? 0 : ((correctCount / total) * 100).round();

  DateTime get completedAt => DateTime.fromMillisecondsSinceEpoch(completedAtMillis);

  Map<String, Object?> toJson() => <String, Object?>{
        'attemptId': attemptId,
        'subject': subjectCode,
        'examType': examType,
        if (year != null) 'year': year,
        'correct': correctCount,
        'total': total,
        'completedAt': completedAtMillis,
      };
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _intOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

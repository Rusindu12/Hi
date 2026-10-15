import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import 'localized_text.dart';

/// One multiple-choice question, mapped 1:1 onto the Firestore `questions`
/// collection documented in docs/FIRESTORE_SCHEMA.md:
///
/// ```json
/// {
///   "subject": "mathematics", "grade": 11, "year": 2019,
///   "examType": "ol", "medium": "si",
///   "questionText": { "en": "...", "si": "...", "ta": "..." },
///   "options": [ { "en": "..." }, ... ],
///   "correctAnswer": 2,
///   "explanation": { "en": "...", "si": "..." },
///   "sourcePaperId": "ol-2019-mathematics-si"
/// }
/// ```
@immutable
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.subjectCode,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    this.grade,
    this.year,
    this.examType,
    this.medium,
    this.explanation = LocalizedText.empty,
    this.sourcePaperId,
    this.difficulty = 1,
  });

  factory QuizQuestion.fromJson(Map<String, Object?> json) {
    final List<Object?> rawOptions =
        (json['options'] as List<Object?>?) ?? const <Object?>[];
    return QuizQuestion(
      id: (json['id'] ?? '').toString(),
      subjectCode: (json['subject'] ?? json['subjectCode'] ?? '').toString(),
      questionText: LocalizedText.fromJson(json['questionText']),
      options: rawOptions.map(LocalizedText.fromJson).toList(),
      correctIndex: _int(json['correctAnswer']),
      grade: _intOrNull(json['grade']),
      year: _intOrNull(json['year']),
      examType: json['examType']?.toString(),
      medium: json['medium']?.toString(),
      explanation: LocalizedText.fromJson(json['explanation']),
      sourcePaperId: json['sourcePaperId']?.toString(),
      difficulty: _intOrNull(json['difficulty']) ?? 1,
    );
  }

  final String id;
  final String subjectCode;
  final LocalizedText questionText;

  /// Always four options (A–D). Stored as localised text because a Sinhala
  /// paper's distractors are themselves Sinhala phrases.
  final List<LocalizedText> options;

  /// Zero-based index into [options].
  final int correctIndex;

  final int? grade;
  final int? year;
  final String? examType;
  final String? medium;
  final LocalizedText explanation;
  final String? sourcePaperId;
  final int difficulty;

  bool get isValid =>
      id.isNotEmpty &&
      options.length >= 2 &&
      correctIndex >= 0 &&
      correctIndex < options.length &&
      questionText.isNotEmpty;

  String text(String localeCode) => questionText.resolve(localeCode);

  String optionText(int index, String localeCode) {
    if (index < 0 || index >= options.length) {
      return '';
    }
    return options[index].resolve(localeCode);
  }

  String explanationText(String localeCode) => explanation.resolve(localeCode);

  bool get hasExplanation => explanation.isNotEmpty;

  String get correctLetter => String.fromCharCode(65 + correctIndex);

  static String letterFor(int index) => String.fromCharCode(65 + index);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'subject': subjectCode,
        'questionText': questionText.toJson(),
        'options': options.map((LocalizedText o) => o.toJson()).toList(),
        'correctAnswer': correctIndex,
        if (grade != null) 'grade': grade,
        if (year != null) 'year': year,
        if (examType != null) 'examType': examType,
        if (medium != null) 'medium': medium,
        if (explanation.isNotEmpty) 'explanation': explanation.toJson(),
        if (sourcePaperId != null) 'sourcePaperId': sourcePaperId,
        'difficulty': difficulty,
      };

  /// A question bank key: subject + year + exam type, used to avoid pulling the
  /// whole collection down on a phone connection.
  static String bankKey({
    required String subjectCode,
    required String examType,
    int? year,
  }) =>
      <String>[
        subjectCode,
        examType,
        if (year != null) year.toString(),
      ].join('_');

  @override
  bool operator ==(Object other) => other is QuizQuestion && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The set of questions a quiz attempt runs on, plus its metadata.
@immutable
class QuestionBank {
  const QuestionBank({
    required this.subjectCode,
    required this.examType,
    required this.medium,
    required this.questions,
    this.year,
  });

  factory QuestionBank.fromJson(Map<String, Object?> json) {
    final List<Object?> raw = (json['questions'] as List<Object?>?) ?? const <Object?>[];
    return QuestionBank(
      subjectCode: (json['subject'] ?? '').toString(),
      examType: (json['examType'] ?? ExamTypes.ol).toString(),
      medium: (json['medium'] ?? Mediums.sinhala).toString(),
      year: _intOrNull(json['year']),
      questions: raw
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> m) => QuizQuestion.fromJson(m.cast<String, Object?>()))
          .where((QuizQuestion q) => q.isValid)
          .toList(),
    );
  }

  final String subjectCode;
  final String examType;
  final String medium;
  final int? year;
  final List<QuizQuestion> questions;

  bool get isEmpty => questions.isEmpty;

  int get length => questions.length;

  String get bankKey => QuizQuestion.bankKey(
        subjectCode: subjectCode,
        examType: examType,
        year: year,
      );

  /// Deterministic shuffle: same seed -> same order, which keeps the timer and
  /// review screen in sync if the widget rebuilds.
  List<QuizQuestion> take(int count, {int seed = 0}) {
    final List<QuizQuestion> pool = List<QuizQuestion>.of(questions);
    if (seed != 0) {
      pool.shuffle(_SeededRandom(seed));
    } else {
      pool.shuffle();
    }
    if (count <= 0 || count >= pool.length) {
      return pool;
    }
    return pool.sublist(0, count);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'subject': subjectCode,
        'examType': examType,
        'medium': medium,
        if (year != null) 'year': year,
        'questions': questions.map((QuizQuestion q) => q.toJson()).toList(),
      };
}

/// Tiny deterministic PRNG so tests can assert a stable question order without
/// pulling in a dependency.
class _SeededRandom implements Comparable<_SeededRandom> {
  _SeededRandom(this._seed);

  int _seed;

  int nextInt(int max) {
    _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
    return _seed % max;
  }

  @override
  int compareTo(_SeededRandom other) => 0;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? -1;
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

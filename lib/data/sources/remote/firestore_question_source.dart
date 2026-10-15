import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../models/question.dart';

/// Firestore-backed question bank.
///
/// Two read paths, cheapest first:
///
/// 1. `question_banks/{bankKey}` — one document holding an array of questions.
///    **This is the recommended layout**: a single document read per quiz, no
///    composite indexes, and perfectly consistent snapshots. Firestore's 1 MiB
///    document ceiling holds roughly 1,000–1,500 MCQs, which is several years of
///    one subject.
/// 2. `questions` collection query (`subject` + `examType` + `year` + `medium`).
///    Used only when no bank document exists. Needs the composite index listed
///    in docs/FIRESTORE_SCHEMA.md, otherwise Firestore rejects the query.
class FirestoreQuestionSource {
  FirestoreQuestionSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  bool get _enabled => AppConfig.useFirebase;

  /// Bank key format: `subject_examType[_year]`, e.g. `mathematics_ol_2019`.
  static String bankKey({
    required String subjectCode,
    required String examType,
    int? year,
  }) =>
      QuizQuestion.bankKey(subjectCode: subjectCode, examType: examType, year: year);

  Future<QuestionBank?> fetchBank({
    required String subjectCode,
    required String examType,
    required String medium,
    int? year,
  }) async {
    if (!_enabled) {
      throw const FirebaseDisabledException(
        'FirestoreQuestionSource used while USE_FIREBASE=false',
      );
    }

    // 1) Single-document bank.
    final QuestionBank? bank = await _fetchFromBankDocument(
      subjectCode: subjectCode,
      examType: examType,
      medium: medium,
      year: year,
    );
    if (bank != null && !bank.isEmpty) {
      return bank;
    }

    // 2) Query fallback.
    return _fetchFromQuestionsCollection(
      subjectCode: subjectCode,
      examType: examType,
      medium: medium,
      year: year,
    );
  }

  Future<QuestionBank?> _fetchFromBankDocument({
    required String subjectCode,
    required String examType,
    required String medium,
    int? year,
  }) async {
    try {
      final String key = bankKey(
        subjectCode: subjectCode,
        examType: examType,
        year: year,
      );
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('question_banks').doc(key).get();
      final Map<String, dynamic>? data = doc.data();
      if (data == null) {
        return null;
      }
      final Map<String, Object?> json = Map<String, Object?>.of(data)
        ..['subject'] = data['subject'] ?? subjectCode
        ..['examType'] = data['examType'] ?? examType
        ..['medium'] = data['medium'] ?? medium
        ..['year'] = data['year'] ?? year;
      final QuestionBank bank = QuestionBank.fromJson(json);
      return bank.isEmpty ? null : bank;
    } on Object catch (error, stack) {
      throw NetworkException(
        'question bank read failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<QuestionBank?> _fetchFromQuestionsCollection({
    required String subjectCode,
    required String examType,
    required String medium,
    int? year,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('questions')
          .where('subject', isEqualTo: subjectCode)
          .where('examType', isEqualTo: examType);
      if (year != null) {
        query = query.where('year', isEqualTo: year);
      }
      // `medium` is intentionally NOT filtered server-side: a paper's questions
      // are usually tagged in one medium but the text is translated, and an
      // over-filtered query returns nothing. We filter locally instead, so a
      // missing translation still yields a usable quiz.
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await query.limit(AppConfig.questionsPerQuiz * 6).get();

      final List<QuizQuestion> questions = <QuizQuestion>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        final Map<String, Object?> json =
            Map<String, Object?>.of(doc.data())..['id'] = doc.id;
        final QuizQuestion q = QuizQuestion.fromJson(json);
        if (q.isValid) {
          questions.add(q);
        }
      }
      final List<QuizQuestion> preferred = questions
          .where((QuizQuestion q) => q.medium == null || q.medium == medium)
          .toList();

      final List<QuizQuestion> chosen = preferred.isEmpty ? questions : preferred;
      if (chosen.isEmpty) {
        return null;
      }
      return QuestionBank(
        subjectCode: subjectCode,
        examType: examType,
        medium: medium,
        year: year,
        questions: chosen,
      );
    } on Object catch (error, stack) {
      throw NetworkException(
        'question query failed (missing composite index?)',
        cause: error,
        stackTrace: stack,
      );
    }
  }
}

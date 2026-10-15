import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../models/question.dart';

/// Offline question bank, read from `assets/data/sample_questions.json`.
///
/// Ships a small hand-written set so Quiz mode is demonstrable without any
/// backend. When Firebase is on, `FirestoreQuestionSource` is tried first and
/// this acts as the fallback for offline study.
class LocalQuestionSource {
  const LocalQuestionSource();

  /// All bundled questions, keyed by [QuizQuestion.bankKey].
  Future<Map<String, QuestionBank>> loadAll() async {
    try {
      final String raw = await rootBundle.loadString(AssetPaths.sampleQuestions);
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const CatalogueException('sample_questions.json is not an object');
      }
      final Map<String, Object?> root = decoded.cast<String, Object?>();
      final List<Object?> rawBanks =
          (root['banks'] as List<Object?>?) ?? const <Object?>[];

      final Map<String, QuestionBank> banks = <String, QuestionBank>{};
      for (final Object? entry in rawBanks) {
        if (entry is! Map) {
          continue;
        }
        final QuestionBank bank =
            QuestionBank.fromJson(entry.cast<String, Object?>());
        if (bank.isEmpty) {
          continue;
        }
        banks[bank.bankKey] = bank;
      }
      return banks;
    } on CatalogueException {
      rethrow;
    } on Object catch (error, stack) {
      throw CatalogueException(
        'Could not read bundled questions: $error',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  /// Questions for one bank: subject + exam type + optional year.
  Future<QuestionBank?> loadBank({
    required String subjectCode,
    required String examType,
    int? year,
  }) async {
    final Map<String, QuestionBank> banks = await loadAll();
    final String key = QuizQuestion.bankKey(
      subjectCode: subjectCode,
      examType: examType,
      year: year,
    );
    return banks[key];
  }

  /// Every (subject, year) combination that has bundled questions, used to
  /// decide which chips to enable on the quiz setup screen.
  Future<List<String>> availableSubjectCodes() async {
    final Map<String, QuestionBank> banks = await loadAll();
    return banks.values
        .map((QuestionBank b) => b.subjectCode)
        .toSet()
        .toList()
      ..sort();
  }
}

import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
import '../models/question.dart';
import '../sources/local/local_question_source.dart';
import '../sources/remote/firestore_question_source.dart';

/// Loads quiz questions: Firestore when configured, bundled assets otherwise,
/// with the local bank used as an offline fallback for remote failures.
class QuestionRepository {
  QuestionRepository({
    LocalQuestionSource? local,
    FirestoreQuestionSource? remote,
  })  : _local = local ?? const LocalQuestionSource(),
        _remote = remote;

  final LocalQuestionSource _local;
  final FirestoreQuestionSource? _remote;

  final Map<String, QuestionBank> _memory = <String, QuestionBank>{};

  Future<QuestionBank?> bank({
    required String subjectCode,
    required String examType,
    required String medium,
    int? year,
  }) async {
    final String key = QuizQuestion.bankKey(
      subjectCode: subjectCode,
      examType: examType,
      year: year,
    );
    final QuestionBank? cached = _memory[key];
    if (cached != null) {
      return cached;
    }

    if (AppConfig.useFirebase && _remote != null) {
      try {
        final QuestionBank? remote = await _remote.fetchBank(
          subjectCode: subjectCode,
          examType: examType,
          medium: medium,
          year: year,
        );
        if (remote != null && !remote.isEmpty) {
          _memory[key] = remote;
          return remote;
        }
      } on Object catch (error) {
        debugPrint('[SriEdu] remote questions unavailable ($key): $error');
      }
    }

    final Map<String, QuestionBank> all = await _local.loadAll();
    // Prefer the exact year; fall back to the subject-wide bank so practice is
    // still possible when a specific year has no bundled questions.
    final QuestionBank? exact = all[key];
    final QuestionBank? anyYear = all[QuizQuestion.bankKey(
          subjectCode: subjectCode,
          examType: examType,
        )];
    final QuestionBank? resolved = exact ?? anyYear;
    if (resolved != null) {
      _memory[key] = resolved;
    }
    return resolved;
  }

  /// Subject codes that have questions available, for enabling quiz chips.
  Future<Set<String>> availableSubjectCodes() async {
    final Set<String> codes = <String>{};
    final Map<String, QuestionBank> local = await _local.loadAll();
    for (final QuestionBank bank in local.values) {
      codes.add(bank.subjectCode);
    }
    for (final QuestionBank bank in _memory.values) {
      codes.add(bank.subjectCode);
    }
    return codes;
  }

  void invalidate() => _memory.clear();
}

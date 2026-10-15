import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../core/constants/app_constants.dart';
import '../data/models/question.dart';
import '../data/models/quiz_attempt.dart';
import '../data/repositories/quiz_history_repository.dart';
import '../data/repositories/question_repository.dart';
import '../services/analytics_service.dart';

enum QuizPhase { setup, loading, running, finished, error }

/// One quiz attempt: load a bank, run a timer, collect answers, score.
///
/// Kept as a [ChangeNotifier] rather than a Bloc so the whole session (including
/// the 1 Hz ticker) is one object that the session page can `watch`. Every
/// transition is also a state change, so the UI never derives its own truth.
class QuizController extends ChangeNotifier {
  QuizController({
    required QuestionRepository questions,
    required QuizHistoryRepository history,
  })  : _questions = questions,
        _history = history;

  final QuestionRepository _questions;
  final QuizHistoryRepository _history;

  // --- Setup selections ----------------------------------------------------

  String examType = ExamTypes.ol;
  String? subjectCode;
  int? year;
  String medium = Mediums.sinhala;

  // --- Session state -------------------------------------------------------

  QuizPhase _phase = QuizPhase.setup;
  Object? _error;
  QuestionBank? _bank;
  List<QuizQuestion> _session = const <QuizQuestion>[];
  final List<QuizAnswer> _answers = <QuizAnswer>[];
  int _index = 0;
  int _remaining = AppConfig.secondsPerQuestion;
  int _questionStartedAt = 0;
  Timer? _ticker;
  bool _answerLocked = false;
  int? _selectedIndex;
  QuizAttempt? _lastAttempt;

  QuizPhase get phase => _phase;

  Object? get error => _error;

  QuestionBank? get bank => _bank;

  /// Questions in the order this attempt used them. The result screen pairs
  /// these with [answers] by index, so the review list and the session can never
  /// disagree about which question was answered.
  List<QuizQuestion> get session => List<QuizQuestion>.unmodifiable(_session);

  /// The attempt produced by the most recent [finish], for the result screen.
  QuizAttempt? get lastAttempt => _lastAttempt;

  int get questionCount => _bank?.length ?? 0;

  int get sessionLength => _session.length;

  int get index => _index;

  int get remainingSeconds => _remaining;

  bool get isLastQuestion => _index >= _session.length - 1;

  bool get canFinish => _session.isNotEmpty;

  /// True once an option is tapped (or the timer expired) and the explanation is
  /// on screen. The user then taps "Next".
  bool get answerLocked => _answerLocked;

  int? get selectedIndex => _selectedIndex;

  QuizQuestion? get currentQuestion =>
      _session.isEmpty || _index >= _session.length ? null : _session[_index];

  List<QuizAnswer> get answers => List<QuizAnswer>.unmodifiable(_answers);

  int get correctCount => _answers.where((QuizAnswer a) => a.isCorrect).length;

  int get wrongCount => _answers
      .where((QuizAnswer a) => !a.isCorrect && !a.isSkipped)
      .length;

  int get skippedCount => _answers.where((QuizAnswer a) => a.isSkipped).length;

  int get percent =>
      _session.isEmpty ? 0 : ((correctCount / _session.length) * 100).round();

  /// True when no answer has been recorded yet — used to hide the "quit?" dialog.
  bool get hasProgress => _answers.isNotEmpty || _answerLocked;

  // --- Setup ---------------------------------------------------------------

  void setExamType(String value) {
    if (examType == value) {
      return;
    }
    examType = value;
    subjectCode = null;
    year = null;
    _bank = null;
    _phase = QuizPhase.setup;
    notifyListeners();
  }

  void setMedium(String value) {
    medium = value;
    _bank = null;
    notifyListeners();
  }

  void setSubject(String? code) {
    subjectCode = code;
    _bank = null;
    notifyListeners();
  }

  void setYear(int? value) {
    year = value;
    _bank = null;
    notifyListeners();
  }

  /// How many questions are available for the current selection, or null while
  /// unknown. Drives the "10 questions" line and the Start button's enabled state.
  Future<int> loadCount() async {
    final QuestionBank? loaded = await _loadBank();
    return loaded?.length ?? 0;
  }

  Future<QuestionBank?> _loadBank() async {
    final String? subject = subjectCode;
    if (subject == null) {
      return null;
    }
    final QuestionBank? loaded = await _questions.bank(
      subjectCode: subject,
      examType: examType,
      medium: medium,
      year: year,
    );
    _bank = loaded;
    return loaded;
  }

  // --- Session -------------------------------------------------------------

  /// Loads questions and starts the timer. Returns false when there is nothing
  /// to practise (empty bank) so the UI can show the empty state.
  Future<bool> start({int seed = 0}) async {
    _phase = QuizPhase.loading;
    _error = null;
    notifyListeners();

    try {
      final QuestionBank? loaded = await _loadBank();
      if (loaded == null || loaded.isEmpty) {
        _phase = QuizPhase.setup;
        notifyListeners();
        return false;
      }
      _session = loaded.take(AppConfig.questionsPerQuiz, seed: seed);
      _resetSessionState();
      _phase = QuizPhase.running;
      _startTimer();
      await AnalyticsService.instance.logEvent(
        AnalyticsEvents.quizStarted,
        parameters: <String, Object?>{
          'subject': subjectCode,
          'exam_type': examType,
          'year': year,
          'count': _session.length,
          'medium': medium,
        },
      );
      notifyListeners();
      return true;
    } on Object catch (error) {
      _phase = QuizPhase.error;
      _error = error;
      notifyListeners();
      return false;
    }
  }

  void _resetSessionState() {
    _answers.clear();
    _index = 0;
    _remaining = AppConfig.secondsPerQuestion;
    _answerLocked = false;
    _selectedIndex = null;
    _questionStartedAt = DateTime.now().millisecondsSinceEpoch;
  }

  void _startTimer() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_phase != QuizPhase.running) {
        return;
      }
      if (_answerLocked) {
        // Pause while the explanation is visible: the clock measures thinking
        // time, not reading time.
        return;
      }
      if (_remaining <= 1) {
        _remaining = 0;
        _recordAnswer(null);
        return;
      }
      _remaining--;
      notifyListeners();
    });
  }

  /// Locks in an answer (or a skip when [optionIndex] is null) and reveals the
  /// explanation.
  void answer(int? optionIndex) {
    if (_phase != QuizPhase.running || _answerLocked) {
      return;
    }
    _recordAnswer(optionIndex);
  }

  void _recordAnswer(int? optionIndex) {
    final QuizQuestion? question = currentQuestion;
    if (question == null) {
      return;
    }
    final int elapsed =
        ((DateTime.now().millisecondsSinceEpoch - _questionStartedAt) / 1000).round();
    _answers.add(
      QuizAnswer(
        questionId: question.id,
        selectedIndex: optionIndex ?? -1,
        correctIndex: question.correctIndex,
        elapsedSeconds: elapsed.clamp(0, AppConfig.secondsPerQuestion),
      ),
    );
    _selectedIndex = optionIndex;
    _answerLocked = true;
    notifyListeners();
  }

  /// Advances to the next question, or finishes.
  void next() {
    if (_phase != QuizPhase.running) {
      return;
    }
    if (isLastQuestion) {
      finish();
      return;
    }
    _index++;
    _remaining = AppConfig.secondsPerQuestion;
    _answerLocked = false;
    _selectedIndex = null;
    _questionStartedAt = DateTime.now().millisecondsSinceEpoch;
    notifyListeners();
  }

  /// Ends the attempt: builds the [QuizAttempt] and persists it locally.
  Future<QuizAttempt> finish() async {
    _ticker?.cancel();
    _phase = QuizPhase.finished;

    final int now = DateTime.now().millisecondsSinceEpoch;
    final QuizAttempt attempt = QuizAttempt(
      // Unique without a uuid dependency: ms precision is enough for one user.
      id: 'attempt_$now',
      subjectCode: subjectCode ?? '',
      examType: examType,
      medium: medium,
      year: year,
      answers: List<QuizAnswer>.of(_answers),
      startedAtMillis: _questionStartedAt,
      completedAtMillis: now,
    );

    _lastAttempt = attempt;
    await _history.save(attempt);
    await AnalyticsService.instance.logEvent(
      AnalyticsEvents.quizCompleted,
      parameters: <String, Object?>{
        'subject': attempt.subjectCode,
        'exam_type': attempt.examType,
        'year': attempt.year,
        'correct': attempt.correctCount,
        'total': attempt.total,
        'percent': attempt.percent,
      },
    );
    notifyListeners();
    return attempt;
  }

  /// Called when the user backs out mid-quiz.
  Future<void> abandon() async {
    _ticker?.cancel();
    if (_answers.isNotEmpty) {
      await AnalyticsService.instance.logEvent(
        AnalyticsEvents.quizAbandoned,
        parameters: <String, Object?>{
          'subject': subjectCode,
          'answered': _answers.length,
        },
      );
    }
    reset();
  }

  /// Back to the setup screen, ready to try again.
  void reset() {
    _ticker?.cancel();
    _phase = QuizPhase.setup;
    _session = const <QuizQuestion>[];
    _answers.clear();
    _index = 0;
    _remaining = AppConfig.secondsPerQuestion;
    _answerLocked = false;
    _selectedIndex = null;
    _error = null;
    _lastAttempt = null;
    notifyListeners();
  }

  /// Re-runs the same selection immediately ("try again" on the result screen).
  Future<bool> retry() async {
    reset();
    return start(seed: DateTime.now().millisecondsSinceEpoch % 100000);
  }

  // --- History -------------------------------------------------------------

  List<LeaderboardEntry> leaderboard({String? subject}) =>
      _history.leaderboard(subjectCode: subject);

  /// Best percentage achieved *before* [attemptId] existed, for the same subject.
  int bestPercentExcluding(String attemptId, {String? subjectCode}) =>
      _history.bestPercent(
        subjectCode: subjectCode ?? this.subjectCode,
        excludeAttemptId: attemptId,
      );

  /// Previous best for this exact selection, so a new record is obvious.
  int bestPercentForCurrentSelection() =>
      _history.bestPercent(subjectCode: subjectCode);

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:sriedu/core/constants/app_config.dart';
import 'package:sriedu/core/utils/date_keys.dart';
import 'package:sriedu/core/utils/formatters.dart';
import 'package:sriedu/data/models/catalogue_item.dart';
import 'package:sriedu/data/models/localized_text.dart';
import 'package:sriedu/data/models/paper_filter.dart';
import 'package:sriedu/data/models/question.dart';
import 'package:sriedu/data/models/streak_state.dart';

/// Pure-Dart tests for the logic that decides what a student sees: filters,
/// localisation fallback, number formatting, the seeded quiz shuffle, and the
/// streak rules (including the one free freeze per week).
///
/// Nothing here touches Hive, Firebase or a widget, so it runs in milliseconds
/// and is the first thing CI should run.
void main() {
  group('LocalizedText', () {
    test('resolves the requested language', () {
      const LocalizedText text = LocalizedText(en: 'Science', si: 'විද්‍යාව', ta: 'அறிவியல்');
      expect(text.resolve('en'), 'Science');
      expect(text.resolve('si'), 'විද්‍යාව');
      expect(text.resolve('ta'), 'அறிவியல்');
    });

    test('falls back to English for a missing language', () {
      const LocalizedText englishOnly = LocalizedText(en: 'Science');
      expect(englishOnly.resolve('si'), 'Science');
      expect(englishOnly.resolve('ta'), 'Science');
      expect(englishOnly.resolve('fr'), 'Science');
    });

    test('parses both the map form and the bare-string form', () {
      final LocalizedText fromMap = LocalizedText.fromJson(<String, Object?>{
        'en': 'Mathematics',
        'si': 'ගණිතය',
      });
      expect(fromMap.en, 'Mathematics');
      expect(fromMap.si, 'ගණිතය');
      expect(fromMap.ta, isNull);
      expect(fromMap.resolve('ta'), 'Mathematics');

      expect(LocalizedText.fromJson('Physics').en, 'Physics');
      expect(LocalizedText.fromJson(null).isEmpty, isTrue);
      expect(LocalizedText.fromJson('').isEmpty, isTrue);
    });
  });

  group('Formatters', () {
    test('bytes stay readable across the whole range', () {
      expect(Formatters.bytes(0), '—');
      expect(Formatters.bytes(-5), '—');
      expect(Formatters.bytes(512), '512 B');
      expect(Formatters.bytes(2048), '2 KB');
      expect(Formatters.bytes(5 * 1024 * 1024), '5 MB');
    });

    test('clock pads seconds for a stable quiz timer layout', () {
      expect(Formatters.clock(0), '0:00');
      expect(Formatters.clock(5), '0:05');
      expect(Formatters.clock(65), '1:05');
      expect(Formatters.clock(3600), '60:00');
      expect(Formatters.clock(-10), '0:00', reason: 'the timer must never go negative');
    });

    test('compact counts are short enough for a list row', () {
      expect(Formatters.compactCount(999), '999');
      expect(Formatters.compactCount(1500), '1.5k');
      expect(Formatters.compactCount(2_400_000), '2.4M');
    });

    test('percent never divides by zero', () {
      expect(Formatters.percent(0, 0), 0);
      expect(Formatters.percent(3, 4), 75);
      expect(Formatters.percent(10, 10), 100);
    });
  });

  group('PaperFilter', () {
    final CatalogueItem paper = CatalogueItem.fromJson(<String, Object?>{
      'id': 'ol-2019-science-en',
      'kind': 'paper',
      'title': <String, Object?>{'en': 'Science 2019', 'si': 'විද්‍යාව 2019'},
      'subject': 'science',
      'medium': 'en',
      'examType': 'ol',
      'year': 2019,
      'rights': 'official_link',
      'sourceUrl': 'https://www.doenets.lk/exam-papers/ol/2019/science-en.pdf',
      'fileSizeBytes': 1000,
      'pageCount': 12,
      'downloadCount': 10,
      'trendingScore': 1,
    });

    test('an empty filter matches everything', () {
      const PaperFilter filter = PaperFilter();
      expect(filter.hasActiveFilters, isFalse);
      expect(filter.matches(paper, 'en'), isTrue);
    });

    test('narrows by exam type, subject, year and medium', () {
      expect(
        const PaperFilter(examType: 'ol', subjectCode: 'science', year: 2019, mediumCode: 'en')
            .matches(paper, 'en'),
        isTrue,
      );
      expect(const PaperFilter(examType: 'al').matches(paper, 'en'), isFalse);
      expect(const PaperFilter(examType: 'ol', subjectCode: 'mathematics').matches(paper, 'en'), isFalse);
      expect(const PaperFilter(examType: 'ol', year: 2018).matches(paper, 'en'), isFalse);
      expect(const PaperFilter(examType: 'ol', mediumCode: 'si').matches(paper, 'en'), isFalse);
    });

    test('searches the localised title, not only English', () {
      const PaperFilter sinhala = PaperFilter(examType: 'ol', query: 'විද්‍යාව');
      expect(sinhala.matches(paper, 'si'), isTrue);
      expect(sinhala.matches(paper, 'en'), isFalse,
          reason: 'the English title does not contain the Sinhala query');

      expect(const PaperFilter(examType: 'ol', query: '  SCIENCE  ').matches(paper, 'en'), isTrue,
          reason: 'search should be trimmed and case-insensitive');
    });

    test('copyWith clears one dimension at a time', () {
      const PaperFilter filter = PaperFilter(
        examType: 'ol',
        subjectCode: 'science',
        year: 2019,
        mediumCode: 'en',
      );
      expect(filter.hasActiveFilters, isTrue);

      final PaperFilter noYear = filter.copyWith(clearYear: true);
      expect(noYear.year, isNull);
      expect(noYear.subjectCode, 'science', reason: 'clearing one filter must not clear the rest');

      expect(filter.copyWith(clearMedium: true).mediumCode, isNull);
      expect(filter.copyWith(clearSubject: true).subjectCode, isNull);
      expect(filter.cleared().hasActiveFilters, isFalse);
      expect(filter.cleared().examType, 'ol', reason: 'the tab is not a filter');
    });

    test('equality is value based, so a rebuild does not churn the list', () {
      const PaperFilter a = PaperFilter(examType: 'ol', year: 2019);
      const PaperFilter b = PaperFilter(examType: 'ol', year: 2019);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a == a.copyWith(clearYear: true), isFalse);
    });
  });

  group('QuizQuestion', () {
    Map<String, Object?> questionJson(String id, {Map<String, Object?>? text}) => <String, Object?>{
          'id': id,
          'questionText': text ?? <String, Object?>{'en': 'Q $id', 'si': 'ප $id'},
          'options': <Object?>[
            <String, Object?>{'en': 'A $id'},
            <String, Object?>{'en': 'B $id'},
            <String, Object?>{'en': 'C $id'},
            <String, Object?>{'en': 'D $id'},
          ],
          'correctAnswer': 2,
          'explanation': <String, Object?>{'en': 'because'},
        };

    test('bank keys follow subject_examType[_year]', () {
      expect(
        QuizQuestion.bankKey(subjectCode: 'mathematics', examType: 'ol', year: 2019),
        'mathematics_ol_2019',
      );
      expect(
        QuizQuestion.bankKey(subjectCode: 'science', examType: 'al'),
        'science_al',
      );
    });

    test('letters map to A-D and the correct index', () {
      final QuizQuestion question = QuizQuestion.fromJson(questionJson('q1'));
      expect(QuizQuestion.letterFor(0), 'A');
      expect(QuizQuestion.letterFor(3), 'D');
      expect(question.correctLetter, 'C');
      expect(question.isValid, isTrue);
      expect(question.optionText(1, 'en'), 'B q1');
      expect(question.optionText(9, 'en'), isEmpty, reason: 'out of range is empty, not a crash');
    });

    test('question text falls back to English when a medium is missing', () {
      final QuizQuestion question = QuizQuestion.fromJson(questionJson('q2'));
      expect(question.text('si'), 'ප q2');
      expect(question.text('ta'), 'Q q2');
      expect(question.explanationText('ta'), 'because');
    });

    test('an invalid question (no options) is rejected rather than shown', () {
      final QuizQuestion broken = QuizQuestion.fromJson(<String, Object?>{
        'id': 'bad',
        'questionText': <String, Object?>{'en': 'Broken'},
        'options': <Object?>[],
        'correctAnswer': 0,
        'explanation': <String, Object?>{'en': ''},
      });
      expect(broken.isValid, isFalse);
    });

    test('the shuffle is deterministic for a given seed', () {
      final QuestionBank bank = QuestionBank.fromJson(<String, Object?>{
        'subject': 'mathematics',
        'examType': 'ol',
        'medium': 'si',
        'year': 2019,
        'questions': <Object?>[
          for (int i = 0; i < 10; i++) questionJson('q$i'),
        ],
      });

      expect(bank.bankKey, 'mathematics_ol_2019');
      expect(bank.length, 10);
      expect(bank.isEmpty, isFalse);

      final List<String> first =
          bank.take(5, seed: 7).map((QuizQuestion q) => q.id).toList();
      final List<String> second =
          bank.take(5, seed: 7).map((QuizQuestion q) => q.id).toList();
      expect(first, equals(second), reason: 'two quiz runs with seed 7 must agree');
      expect(first.length, 5);
      expect(first.toSet().length, 5, reason: 'no question may repeat in one quiz');
      expect(bank.take(0).length, 10, reason: 'count 0 means "everything available"');
      expect(bank.take(99).length, 10, reason: 'asking for more than exists is not an error');
    });

    test('a bank round-trips through JSON', () {
      final QuestionBank bank = QuestionBank.fromJson(<String, Object?>{
        'subject': 'science',
        'examType': 'ol',
        'medium': 'si',
        'year': 2019,
        'questions': <Object?>[questionJson('s1')],
      });
      final Map<String, Object?> encoded = bank.toJson();
      final QuestionBank again = QuestionBank.fromJson(encoded);
      expect(again.bankKey, bank.bankKey);
      expect(again.questions.single.id, 's1');
      expect(again.questions.single.correctIndex, 2);
    });
  });

  group('StreakState', () {
    final DateTime now = DateTime(2026, 10, 15, 9, 30); // a Thursday
    final String today = DateKeys.day(now);
    final String yesterday = DateKeys.day(now.subtract(const Duration(days: 1)));
    final String threeDaysAgo = DateKeys.day(now.subtract(const Duration(days: 3)));

    test('an empty streak is neither at risk nor broken', () {
      expect(StreakState.empty.isActive, isFalse);
      expect(StreakState.empty.isAtRisk(now), isFalse);
      expect(StreakState.empty.isBroken(now), isFalse);
      expect(StreakState.empty.studiedToday(now), isFalse);
    });

    test('studying today satisfies the streak', () {
      final StreakState state = StreakState(current: 5, longest: 5, totalStudyDays: 5, lastStudyDay: today);
      expect(state.studiedToday(now), isTrue);
      expect(state.isAtRisk(now), isFalse, reason: 'nothing is at risk once you have studied');
      expect(state.isBroken(now), isFalse);
    });

    test('yesterday keeps the streak alive but at risk', () {
      final StreakState state = StreakState(current: 4, longest: 4, totalStudyDays: 4, lastStudyDay: yesterday);
      expect(state.studiedToday(now), isFalse);
      expect(state.isAtRisk(now), isTrue);
      expect(state.isBroken(now), isFalse);
    });

    test('a two-day gap breaks the streak', () {
      final StreakState state = StreakState(current: 4, longest: 9, totalStudyDays: 12, lastStudyDay: threeDaysAgo);
      expect(state.isBroken(now), isTrue);
      expect(state.isAtRisk(now), isFalse);
    });

    test('one free freeze per week, and only when it is needed', () {
      final StreakState fresh = StreakState(
        current: 3,
        longest: 3,
        totalStudyDays: 3,
        lastStudyDay: yesterday,
      );
      expect(fresh.freezesUsedThisWeek(now), 0);
      expect(fresh.freezesLeft(now), AppConfig.streakFreezesPerWeek);
      expect(fresh.canUseFreeze(now), isTrue);

      final StreakState alreadyUsed = StreakState(
        current: 3,
        longest: 3,
        totalStudyDays: 3,
        lastStudyDay: yesterday,
        freezeWeeksUsed: <String>[DateKeys.week(now)],
      );
      expect(alreadyUsed.freezesUsedThisWeek(now), 1);
      expect(alreadyUsed.freezesLeft(now), 0);
      expect(alreadyUsed.canUseFreeze(now), isFalse, reason: 'one freeze per week is the rule');

      final StreakState lastWeeksFreeze = StreakState(
        current: 3,
        longest: 3,
        totalStudyDays: 3,
        lastStudyDay: yesterday,
        freezeWeeksUsed: <String>[
          DateKeys.week(now.subtract(const Duration(days: 7))),
        ],
      );
      expect(lastWeeksFreeze.canUseFreeze(now), isTrue,
          reason: 'the allowance resets with the calendar week');

      final StreakState studied = StreakState(
        current: 3,
        longest: 3,
        totalStudyDays: 3,
        lastStudyDay: today,
      );
      expect(studied.canUseFreeze(now), isFalse,
          reason: 'do not burn a freeze on a day that is already counted');
    });

    test('the week strip covers the last seven days, oldest first', () {
      final StreakState state = StreakState(
        current: 2,
        longest: 4,
        totalStudyDays: 8,
        lastStudyDay: today,
        studyDays: <String>[today, yesterday],
        frozenDays: <String>[threeDaysAgo],
      );
      final List<StreakDayMark> strip = state.weekStrip(now);

      expect(strip.length, 7);
      final List<String> keys = strip.map((StreakDayMark mark) => mark.dayKey).toList();
      expect(keys, equals(DateKeys.lastDays(now, 7)));
      expect(keys.first, lessThan(keys.last), reason: 'oldest first, like the UI expects');
      expect(strip.last.dayKey, today);
    });

    test('day and week keys are sortable and parse back', () {
      expect(today, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(DateKeys.parseDay(today), isNotNull);
      expect(DateKeys.parseDay('not-a-date'), isNull);
      expect(DateKeys.daysBetween(yesterday, today), 1);
      expect(DateKeys.daysBetween(today, yesterday), -1);
      expect(DateKeys.week(now), DateKeys.week(now.add(const Duration(days: 3)) - const Duration(days: 3)));
      // Tuesday 00:30 and Sunday 23:30 of the same week share a key.
      expect(DateKeys.week(DateTime(2026, 10, 13, 0, 30)),
          equals(DateKeys.week(DateTime(2026, 10, 18, 23, 30))));
    });
  });
}

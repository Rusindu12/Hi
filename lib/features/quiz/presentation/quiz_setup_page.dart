import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/subject.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/quiz_controller.dart';

/// Screen 5a — Quiz setup: subject + exam type + year, then start.
///
/// No ad banner and no interstitial anywhere in the quiz feature (see
/// [AppAdPolicy]): a student mid-practice is exactly who we must not interrupt.
class QuizSetupPage extends StatefulWidget {
  const QuizSetupPage({super.key});

  @override
  State<QuizSetupPage> createState() => _QuizSetupPageState();
}

class _QuizSetupPageState extends State<QuizSetupPage> {
  bool _loadingCount = false;
  int _available = 0;
  bool _probed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  /// Asks the controller how many questions exist for the current selection, so
  /// "Start" is never a dead end that leads to an empty quiz.
  Future<void> _probe() async {
    final QuizController quiz = context.read<QuizController>();
    if (quiz.subjectCode == null) {
      setState(() {
        _probed = true;
        _available = 0;
      });
      return;
    }
    setState(() => _loadingCount = true);
    final int count = await quiz.loadCount();
    if (!mounted) {
      return;
    }
    setState(() {
      _available = count;
      _loadingCount = false;
      _probed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String localeCode = context.localeCode;
    final QuizController quiz = context.watch<QuizController>();
    final CatalogueController catalogue = context.watch<CatalogueController>();

    final List<Subject> subjects =
        catalogue.subjectsForPapers(examType: quiz.examType);
    final List<int> years = catalogue.availableYears(
      examType: quiz.examType,
      subjectCode: quiz.subjectCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.quizTitle),
            Text(l10n.quizSubtitle, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.quizLeaderboard,
            icon: const Icon(Icons.leaderboard_outlined),
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.leaderboard),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          SectionHeader(title: l10n.ppTitle, icon: Icons.school_outlined),
          ChipRow<String>(
            values: ExamTypes.values,
            selected: quiz.examType,
            labelOf: (String code) => LocaleUtils.examTypeLabel(l10n, code),
            onSelected: (String? code) {
              if (code == null) {
                return;
              }
              quiz.setExamType(code);
              _probe();
            },
          ),
          SectionHeader(title: l10n.quizPickSubject, icon: Icons.menu_book_outlined),
          if (subjects.isEmpty)
            Padding(
              padding: AppSpacing.screen,
              child: InfoBanner(
                message: l10n.quizNoQuestionsBody,
                icon: Icons.info_outline,
              ),
            )
          else
            Padding(
              padding: AppSpacing.screen,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: subjects
                    .map(
                      (Subject subject) => FilterChip(
                        label: Text(subject.displayName(localeCode)),
                        selected: quiz.subjectCode == subject.code,
                        onSelected: (bool selected) {
                          quiz.setSubject(selected ? subject.code : null);
                          _probe();
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          if (years.isNotEmpty) ...<Widget>[
            SectionHeader(title: l10n.quizPickYear, icon: Icons.event_outlined),
            ChipRow<int>(
              values: years,
              selected: quiz.year,
              allLabel: l10n.labelAll,
              allValue: null,
              labelOf: (int year) => '$year',
              onSelected: (int? year) {
                quiz.setYear(year);
                _probe();
              },
            ),
          ],
          SectionHeader(title: l10n.labelMedium, icon: Icons.translate_rounded),
          ChipRow<String>(
            values: Mediums.values,
            selected: quiz.medium,
            labelOf: (String code) => LocaleUtils.mediumLabel(l10n, code),
            onSelected: (String? code) {
              if (code != null) {
                quiz.setMedium(code);
                _probe();
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          Padding(
            padding: AppSpacing.screen,
            child: _SummaryCard(
              available: _available,
              loading: _loadingCount,
              probed: _probed,
              onStart: () => Navigator.of(context).pushNamed(AppRoutes.quizSession),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.available,
    required this.loading,
    required this.probed,
    required this.onStart,
  });

  final int available;
  final bool loading;
  final bool probed;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final QuizController quiz = context.watch<QuizController>();

    if (loading) {
      return const AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SkeletonBox(height: 16, width: 160),
            SizedBox(height: AppSpacing.md),
            SkeletonBox(height: 12, width: 220),
            SizedBox(height: AppSpacing.lg),
            SkeletonBox(height: 52),
          ],
        ),
      );
    }

    if (quiz.subjectCode == null || !probed) {
      return AppCard(
        child: Row(
          children: <Widget>[
            Icon(Icons.touch_app_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                l10n.quizPickSubject,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (available == 0) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.quizNoQuestions, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.quizNoQuestionsBody, style: theme.textTheme.bodySmall),
          ],
        ),
      );
    }

    // Cap the count at what a single quiz uses, so the promise matches reality.
    final int planned = available < 10 ? available : 10;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.quiz_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.quizQuestionCount(planned),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${l10n.quizTimeLeft(AppConfig.secondsPerQuestion)} · ${l10n.labelMedium}: '
            '${LocaleUtils.mediumLabel(l10n, quiz.medium)}',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.quizStart,
            icon: Icons.play_arrow_rounded,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// Exposed for tests: how many questions one quiz attempt uses.
int questionsPerQuiz() => AppConfig.questionsPerQuiz;

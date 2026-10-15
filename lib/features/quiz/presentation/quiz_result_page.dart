import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/question.dart';
import '../../../data/models/quiz_attempt.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/quiz_controller.dart';

/// Screen 5c — quiz result: score, breakdown, review of every question, and the
/// local leaderboard.
class QuizResultPage extends StatelessWidget {
  const QuizResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final QuizController quiz = context.watch<QuizController>();
    final QuizAttempt? attempt = quiz.lastAttempt;

    if (attempt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.quizResultTitle)),
        body: EmptyState(
          illustration: AppIllustration.emptyHistory,
          title: l10n.quizNoQuestions,
          body: l10n.quizNoQuestionsBody,
          actionLabel: l10n.quizBackToList,
          onAction: () => Navigator.of(context)
              .pushNamedAndRemoveUntil(AppRoutes.quiz, (Route<dynamic> r) => false),
          compact: true,
        ),
      );
    }

    final QuizController controller = context.read<QuizController>();
    final bool newRecord = attempt.percent >
        controller.bestPercentExcluding(attempt.id, subjectCode: attempt.subjectCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quizResultTitle),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: <Widget>[
          AppCard(
            child: Column(
              children: <Widget>[
                if (newRecord || attempt.percent >= 80)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(
                          Icons.emoji_events_rounded,
                          color: context.semanticColors.streakFlame,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          newRecord ? l10n.quizNewRecord : l10n.quizPerfect,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ProgressRing(
                  percent: attempt.percent,
                  size: 132,
                  sublabel: l10n.quizYourScore,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.quizScoreValue(attempt.correctCount, attempt.total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '${LocaleUtils.examTypeLabel(l10n, attempt.examType)} · '
                  '${attempt.year ?? ''} · ${LocaleUtils.mediumLabel(l10n, attempt.medium)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _Stat(
                      label: l10n.quizCorrectCount,
                      value: attempt.correctCount,
                      color: context.semanticColors.successFg,
                    ),
                    _Stat(
                      label: l10n.quizWrongCount,
                      value: attempt.wrongCount,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    _Stat(
                      label: l10n.quizSkippedCount,
                      value: attempt.skippedCount,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: l10n.quizTryAgain,
            icon: Icons.refresh_rounded,
            onPressed: () async {
              final NavigatorState navigator = Navigator.of(context);
              await navigator.pushReplacementNamed(AppRoutes.quizSession);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final QuizController quizController = context.read<QuizController>();
              await quizController.reset();
              if (!context.mounted) {
                return;
              }
              await Navigator.of(context).pushReplacementNamed(AppRoutes.quiz);
            },
            icon: const Icon(Icons.list_alt_rounded, size: 20),
            label: Text(l10n.quizBackToList),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.leaderboard),
            icon: const Icon(Icons.leaderboard_outlined, size: 20),
            label: Text(l10n.quizLeaderboard),
          ),
          SectionHeader(
            title: l10n.quizReview,
            icon: Icons.fact_check_outlined,
          ),
          ..._reviewRows(context, quiz, attempt),
        ],
      ),
    );
  }

  List<Widget> _reviewRows(
    BuildContext context,
    QuizController quiz,
    QuizAttempt attempt,
  ) {
    final String localeCode = context.localeCode;
    final List<QuizQuestion> questions = quiz.session;

    return List<Widget>.generate(attempt.answers.length, (int index) {
      final QuizAnswer answer = attempt.answers[index];
      // The session list order matches the answers order (one answer per
      // question, appended in sequence), so index lookup is safe here.
      final QuizQuestion? question =
          index < questions.length ? questions[index] : null;
      if (question == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: _ReviewCard(
          index: index,
          question: question,
          answer: answer,
          localeCode: localeCode,
        ),
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(color: color),
        ),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.localeCode,
  });

  final int index;
  final QuizQuestion question;
  final QuizAnswer answer;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool correct = answer.isCorrect;
    final Color tone = correct
        ? context.semanticColors.successFg
        : (answer.isSkipped
            ? theme.colorScheme.onSurface.withAlpha(150)
            : theme.colorScheme.error);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : (answer.isSkipped
                        ? Icons.remove_circle_outline_rounded
                        : Icons.cancel_rounded),
                size: 18,
                color: tone,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.quizQuestionOf(index + 1, question.options.length),
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(question.text(localeCode), style: theme.textTheme.bodyLarge),
          const SizedBox(height: AppSpacing.md),
          if (!correct) ...<Widget>[
            Text(
              '${l10n.quizYourAnswer}: '
              '${answer.isSkipped ? l10n.quizNotAnswered : '${QuizQuestion.letterFor(answer.selectedIndex)} · ${question.optionText(answer.selectedIndex, localeCode)}'}',
              style: theme.textTheme.bodySmall?.copyWith(color: tone),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            '${l10n.quizCorrectAnswer}: '
            '${QuizQuestion.letterFor(question.correctIndex)} · '
            '${question.optionText(question.correctIndex, localeCode)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.semanticColors.successFg,
            ),
          ),
          if (question.hasExplanation) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(90),
                borderRadius: BorderRadius.circular(AppRadii.tile),
              ),
              child: Text(
                question.explanationText(localeCode),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

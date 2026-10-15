import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../data/models/question.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/quiz_controller.dart';
import '../../../state/streak_controller.dart';

/// Screen 5b — the timed MCQ session.
///
/// Layout: progress + countdown on top, question in the middle, four options,
/// then the explanation panel once an answer is locked.
///
/// This screen is **ad-free by policy** — no banner, no interstitial, enforced
/// by `AppAdPolicy` and by the ad-placement unit test.
class QuizSessionPage extends StatefulWidget {
  const QuizSessionPage({super.key});

  @override
  State<QuizSessionPage> createState() => _QuizSessionPageState();
}

class _QuizSessionPageState extends State<QuizSessionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final QuizController quiz = context.read<QuizController>();
    if (quiz.phase == QuizPhase.running) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final bool started = await quiz.start();
    if (!started && mounted) {
      // Empty bank: send the student back to setup with the empty state visible.
      navigator.pop();
    }
  }

  Future<bool> _confirmExit() async {
    final AppLocalizations l10n = context.l10n;
    final QuizController quiz = context.read<QuizController>();
    if (!quiz.hasProgress) {
      return true;
    }
    final bool leave = await AppDialog.confirm(
      context,
      title: l10n.quizExitTitle,
      body: l10n.quizExitBody,
      confirmLabel: l10n.quizExitConfirm,
      cancelLabel: l10n.actionCancel,
      destructive: true,
      icon: Icons.logout_rounded,
    );
    return leave;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final QuizController quiz = context.watch<QuizController>();

    if (quiz.phase == QuizPhase.loading || quiz.phase == QuizPhase.setup) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.quizTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final QuizQuestion? question = quiz.currentQuestion;
    if (question == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.quizTitle)),
        body: EmptyState(
          illustration: AppIllustration.emptySearch,
          title: l10n.quizNoQuestions,
          body: l10n.quizNoQuestionsBody,
          actionLabel: l10n.actionBack,
          onAction: () => Navigator.of(context).pop(),
          compact: true,
        ),
      );
    }

    final String localeCode = context.localeCode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool leave = await _confirmExit();
        if (!leave || !mounted) {
          return;
        }
        await quiz.abandon();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.quizQuestionOf(quiz.index + 1, quiz.sessionLength)),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: l10n.quizExitConfirm,
            onPressed: () async {
              final bool leave = await _confirmExit();
              if (!leave || !mounted) {
                return;
              }
              await quiz.abandon();
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadii.chip),
                          child: LinearProgressIndicator(
                            value: (quiz.index + 1) / quiz.sessionLength,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _CountdownPill(seconds: quiz.remainingSeconds),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text(
              question.text(localeCode),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppSpacing.xl),
            ...List<Widget>.generate(question.options.length, (int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _OptionButton(
                  letter: QuizQuestion.letterFor(index),
                  text: question.optionText(index, localeCode),
                  state: _optionState(quiz, question, index),
                  onTap: quiz.answerLocked ? null : () => quiz.answer(index),
                ),
              );
            }),
            if (quiz.answerLocked) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _ExplanationPanel(
                question: question,
                localeCode: localeCode,
                selectedIndex: quiz.selectedIndex,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: quiz.isLastQuestion ? l10n.quizFinish : l10n.quizNext,
                icon: quiz.isLastQuestion
                    ? Icons.flag_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: () async {
                  if (!quiz.isLastQuestion) {
                    quiz.next();
                    return;
                  }
                  await quiz.finish();
                  if (!context.mounted) {
                    return;
                  }
                  // Finishing a quiz is a qualifying study action.
                  await context.read<StreakController>().recordStudy();
                  if (!context.mounted) {
                    return;
                  }
                  await Navigator.of(context)
                      .pushReplacementNamed(AppRoutes.quizResult);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  _OptionState _optionState(
    QuizController quiz,
    QuizQuestion question,
    int index,
  ) {
    if (!quiz.answerLocked) {
      return _OptionState.idle;
    }
    if (index == question.correctIndex) {
      return _OptionState.correct;
    }
    if (index == quiz.selectedIndex) {
      return _OptionState.wrong;
    }
    return _OptionState.disabled;
  }
}

enum _OptionState { idle, correct, wrong, disabled }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.letter,
    required this.text,
    required this.state,
    this.onTap,
  });

  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = context.semanticColors;

    final (Color border, Color background, Color? iconColor, IconData? icon) =
        switch (state) {
      _OptionState.correct => (
          semantic.successFg,
          semantic.successBg,
          semantic.successFg,
          Icons.check_circle_rounded,
        ),
      _OptionState.wrong => (
          theme.colorScheme.error,
          theme.colorScheme.errorContainer.withAlpha(120),
          theme.colorScheme.error,
          Icons.cancel_rounded,
        ),
      _OptionState.disabled => (
          theme.colorScheme.outlineVariant,
          theme.colorScheme.surface,
          null,
          null,
        ),
      _OptionState.idle => (
          theme.colorScheme.outlineVariant,
          theme.colorScheme.surface,
          null,
          null,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: border,
          width: state == _OptionState.idle ? 1 : 1.6,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer.withAlpha(150),
                  ),
                  child: Text(
                    letter,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(text, style: theme.textTheme.bodyLarge),
                ),
                if (icon != null && iconColor != null)
                  Icon(icon, color: iconColor, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExplanationPanel extends StatelessWidget {
  const _ExplanationPanel({
    required this.question,
    required this.localeCode,
    required this.selectedIndex,
  });

  final QuizQuestion question;
  final String localeCode;
  final int? selectedIndex;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool wasCorrect = selectedIndex == question.correctIndex;

    return AppCard(
      color: wasCorrect
          ? context.semanticColors.successBg.withAlpha(120)
          : theme.colorScheme.errorContainer.withAlpha(70),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                wasCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                size: 20,
                color: wasCorrect
                    ? context.semanticColors.successFg
                    : theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  wasCorrect ? l10n.quizGoodJob : l10n.quizCorrectAnswer,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (!wasCorrect) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${l10n.quizCorrectAnswer}: '
              '${QuizQuestion.letterFor(question.correctIndex)} · '
              '${question.optionText(question.correctIndex, localeCode)}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
          if (question.hasExplanation) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(l10n.quizExplanation, style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(
              question.explanationText(localeCode),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

/// Countdown that turns red in the last ten seconds.
class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool urgent = seconds <= 10;
    final Color color =
        urgent ? theme.colorScheme.error : theme.colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(urgent ? 40 : 24),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            Formatters.clock(seconds),
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Exposed for tests: the per-question time budget.
int perQuestionSeconds() => AppConfig.secondsPerQuestion;

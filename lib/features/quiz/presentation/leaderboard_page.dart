import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/quiz_attempt.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/quiz_controller.dart';

/// Screen 5d — Local leaderboard.
///
/// Anonymous by design: it ranks *this device's* best attempt per subject. There
/// is no account, no upload and no name — which also means no COPPA/GDPR-K data
/// question for a product whose users are children.
class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final QuizController quiz = context.watch<QuizController>();
    final CatalogueController catalogue = context.read<CatalogueController>();
    final List<LeaderboardEntry> entries = quiz.leaderboard();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.quizLeaderboard)),
      body: entries.isEmpty
          ? EmptyState(
              illustration: AppIllustration.emptyHistory,
              title: l10n.quizLeaderboard,
              body: l10n.quizLeaderboardEmpty,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                InfoBanner(
                  message: l10n.quizLeaderboardBody,
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...List<Widget>.generate(entries.length, (int index) {
                  final LeaderboardEntry entry = entries[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _LeaderboardRow(
                      rank: index + 1,
                      entry: entry,
                      subjectLabel: catalogue.subjectLabel(
                        entry.subjectCode,
                        context.localeCode,
                      ),
                      examLabel: LocaleUtils.examTypeLabel(l10n, entry.examType),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.entry,
    required this.subjectLabel,
    required this.examLabel,
  });

  final int rank;
  final LeaderboardEntry entry;
  final String subjectLabel;
  final String examLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    final bool isTop = rank == 1;
    final Color medal = isTop
        ? context.semanticColors.streakFlame
        : theme.colorScheme.onSurface.withAlpha(140);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTop
                  ? medal.withAlpha(40)
                  : theme.colorScheme.outlineVariant.withAlpha(90),
            ),
            child: isTop
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 20)
                : Text('$rank', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(subjectLabel, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '$examLabel · ${Formatters.date(entry.completedAt, context.localeCode)}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                '${entry.percent}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: entry.percent >= 80
                      ? context.semanticColors.successFg
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                l10n.quizScoreValue(entry.correctCount, entry.total),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/locale_utils.dart';
import '../../data/models/badge.dart';
import '../../data/models/streak_state.dart';
import '../../core/utils/badge_labels.dart';
import '../../core/utils/l10n_ext.dart';
import 'app_card.dart';
import 'illustration.dart';

/// The streak flame. Warm gradient, animated glow, and a number you can read at
/// arm's length — this is the app's most important single pixel cluster.
class StreakFlame extends StatelessWidget {
  const StreakFlame({
    super.key,
    required this.days,
    this.size = 56,
    this.showNumber = true,
    this.dimmed = false,
  });

  final int days;
  final double size;
  final bool showNumber;

  /// When true the flame renders in a muted grey (streak lapsed).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final AppSemanticColors semantic = context.semanticColors;
    final Color flame = dimmed ? semantic.badgeLockedFg : semantic.streakFlame;

    return Semantics(
      label: '$days',
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: dimmed
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        flame.withAlpha(70),
                        flame.withAlpha(20),
                      ],
                    ),
              color: dimmed ? semantic.badgeLockedBg : null,
            ),
          ),
          Icon(Icons.local_fire_department_rounded, size: size * 0.62, color: flame),
          if (showNumber)
            Positioned(
              bottom: size * 0.02,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.chip),
                ),
                child: Text(
                  '$days',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: flame,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Home screen streak card: current/longest, the week strip, and the freeze
/// affordance when it is usable.
class StreakCard extends StatelessWidget {
  const StreakCard({
    super.key,
    required this.state,
    required this.weekStrip,
    required this.freezesLeft,
    required this.canFreeze,
    required this.onUseFreeze,
    this.onTap,
    this.now,
  });

  final StreakState state;
  final List<StreakDayMark> weekStrip;
  final int freezesLeft;
  final bool canFreeze;
  final Future<void> Function() onUseFreeze;
  final VoidCallback? onTap;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final DateTime moment = now ?? DateTime.now();
    final bool studiedToday = state.studiedToday(moment);
    final bool atRisk = state.isAtRisk(moment);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              StreakFlame(
                days: state.current,
                dimmed: state.current == 0,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.homeStreak, style: theme.textTheme.labelMedium),
                    Text(
                      l10n.homeStreakDays(state.current),
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      studiedToday
                          ? l10n.streakTodayDone
                          : (atRisk ? l10n.homeStreakAtRisk : l10n.homeStreakEmpty),
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              if (state.longest > 0)
                Column(
                  children: <Widget>[
                    Text(
                      l10n.streakLongest,
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      '${state.longest}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: context.semanticColors.streakFlame,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weekStrip
                .map((StreakDayMark mark) => _DayCell(mark: mark))
                .toList(),
          ),
          if (canFreeze) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  Icons.ac_unit_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.streakFreezeExplain,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: onUseFreeze,
                  child: Text(l10n.streakUseFreeze),
                ),
              ],
            ),
          ] else if (freezesLeft == 0) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.streakFreezesLeft(0),
              style: theme.textTheme.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.mark});

  final StreakDayMark mark;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = context.semanticColors;
    final Color active = mark.frozen ? theme.colorScheme.primary : semantic.streakFlame;

    return Column(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: mark.isMarked ? active.withAlpha(38) : semantic.streakTrack.withAlpha(90),
            border: mark.isToday
                ? Border.all(color: active, width: 1.6)
                : null,
          ),
          child: Center(
            child: mark.isMarked
                ? Icon(
                    mark.frozen ? Icons.ac_unit_rounded : Icons.check_rounded,
                    size: 16,
                    color: active,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          LocaleUtils.weekdayShortLabel(context.l10n, mark.weekday),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: mark.isToday
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
      ],
    );
  }
}

/// A single badge: earned badges get the warm gradient, locked ones stay grey
/// with a progress ring so the goal is legible.
class BadgeTile extends StatelessWidget {
  const BadgeTile({
    super.key,
    required this.id,
    required this.earned,
    required this.current,
    required this.target,
    this.earnedAt,
  });

  final BadgeId id;
  final bool earned;
  final int current;
  final int target;
  final DateTime? earnedAt;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemanticColors semantic = context.semanticColors;
    final AppLocalizations l10n = context.l10n;
    final double progress = target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);

    return SizedBox(
      width: 108,
      child: Column(
        children: <Widget>[
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                SizedBox(
                  height: 64,
                  width: 64,
                  child: CircularProgressIndicator(
                    value: earned ? 1 : progress,
                    strokeWidth: 4,
                    backgroundColor: semantic.badgeLockedBg,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      earned ? semantic.streakFlame : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: earned ? semantic.accentGradient : null,
                    color: earned ? null : semantic.badgeLockedBg,
                  ),
                  child: Icon(
                    _iconFor(id),
                    size: 24,
                    color: earned ? Colors.white : semantic.badgeLockedFg,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badgeTitle(l10n, id),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: earned ? theme.colorScheme.onSurface : semantic.badgeLockedFg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            earned
                ? (earnedAt == null
                    ? l10n.homeBadges
                    : l10n.badgeEarnedOn(
                        '${earnedAt!.day}/${earnedAt!.month}/${earnedAt!.year}',
                      ))
                : '$current/$target',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  IconData _iconFor(BadgeId id) {
    switch (id) {
      case BadgeId.firstBook:
        return Icons.menu_book_rounded;
      case BadgeId.firstQuiz:
        return Icons.quiz_outlined;
      case BadgeId.streak7:
        return Icons.local_fire_department_rounded;
      case BadgeId.streak30:
        return Icons.whatshot_rounded;
      case BadgeId.quizMaster:
        return Icons.workspace_premium_rounded;
      case BadgeId.tenDownloads:
        return Icons.download_done_rounded;
      case BadgeId.plannerPro:
        return Icons.event_available_rounded;
    }
  }
}

/// Illustration shown when a badge is unlocked (used by the celebration dialog).
class BadgeUnlockedSheet extends StatelessWidget {
  const BadgeUnlockedSheet({super.key, required this.id, required this.onDismiss});

  final BadgeId id;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Illustration(AppIllustration.celebrate, height: 132),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.badgeNewUnlocked(badgeTitle(l10n, id)),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            badgeDescription(l10n, id),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDismiss,
              child: Text(l10n.actionDone),
            ),
          ),
        ],
      ),
    );
  }
}

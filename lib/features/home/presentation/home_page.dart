import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/badge.dart';
import '../../../data/models/catalogue_item.dart';
import '../../../data/models/recent_entry.dart';
import '../../../data/models/study_slot.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/catalogue_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/streak_widgets.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/library_controller.dart';
import '../../../state/planner_controller.dart';
import '../../../state/settings_controller.dart';
import '../../../state/shell_controller.dart';
import '../../../state/streak_controller.dart';
import '../../pdf_reader/presentation/reader_launcher.dart';

/// Screen 2 — Home dashboard.
///
/// Reading order is deliberate: greet, then *do*, then reflect, then browse.
///   greeting -> quick access -> continue reading -> streak -> badges ->
///   today's plan -> trending
///
/// No ad banner here by design (see [AppAdPolicy.bannerAllowedFeatures]).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.watch<CatalogueController>();
    final LibraryController library = context.watch<LibraryController>();
    final StreakController streak = context.watch<StreakController>();
    final PlannerController planner = context.watch<PlannerController>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            // Bundled SVG mark: ~1 KB, and scales to any density without
            // shipping five PNG buckets.
            SvgPicture.asset(
              'assets/illustrations/logo.svg',
              height: 26,
              width: 26,
              excludeFromSemantics: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(l10n.appName),
          ],
        ),
        actions: <Widget>[
          StreakAppBarAction(
            days: streak.current,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.planner),
          ),
          IconButton(
            tooltip: l10n.setTitle,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => catalogue.refresh(),
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: <Widget>[
            const _Greeting(),
            if (catalogue.status == CatalogueStatus.error)
              Padding(
                padding: AppSpacing.screen.copyWith(bottom: AppSpacing.sm),
                child: InfoBanner(
                  message: l10n.errCatalogue,
                  icon: Icons.cloud_off_outlined,
                  tone: InfoTone.warning,
                  actionLabel: l10n.actionRetry,
                  onAction: () => catalogue.load(forceRefresh: true),
                ),
              ),
            if (streak.isAtRisk())
              Padding(
                padding: AppSpacing.screen.copyWith(
                  top: AppSpacing.sm,
                  bottom: 0,
                ),
                child: InfoBanner(
                  message: l10n.homeStreakAtRisk,
                  icon: Icons.local_fire_department_rounded,
                  tone: InfoTone.warning,
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            const _QuickAccessGrid(),
            SectionHeader(
              title: l10n.homeContinue,
              icon: Icons.play_circle_outline_rounded,
            ),
            _ContinueRail(recents: library.recents),
            SectionHeader(title: l10n.homeStreak, icon: Icons.local_fire_department_outlined),
            Padding(
              padding: AppSpacing.screen,
              child: StreakCard(
                state: streak.state,
                weekStrip: streak.weekStrip(),
                freezesLeft: streak.freezesLeft(),
                canFreeze: streak.canUseFreeze(),
                onUseFreeze: () async {
                  final bool used = await streak.useFreeze();
                  if (!context.mounted) {
                    return;
                  }
                  if (used) {
                    AppSnackbar.info(context, l10n.streakFreezeUsed);
                  } else {
                    AppSnackbar.info(context, l10n.streakFreezeUnavailable);
                  }
                },
              ),
            ),
            SectionHeader(
              title: l10n.homeBadges,
              icon: Icons.emoji_events_outlined,
              actionLabel: l10n.homeBadgesEarned(
                streak.earnedBadgeCount,
                streak.totalBadgeCount,
              ),
            ),
            _BadgesRail(streak: streak),
            SectionHeader(title: l10n.homePlannerCard, icon: Icons.event_available_outlined),
            Padding(
              padding: AppSpacing.screen,
              child: _PlannerCard(
                nextSlot: planner.nextSlot(),
                slotCount: planner.slots.length,
                subjectLabelOf: (String code) =>
                    catalogue.subjectLabel(code, context.localeCode),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.planner),
              ),
            ),
            SectionHeader(
              title: l10n.homeTrending,
              icon: Icons.trending_up_rounded,
              actionLabel: l10n.actionSeeAll,
              onActionTap: () =>
                  context.read<ShellController>().go(ShellController.papersTab),
            ),
            _TrendingRail(items: catalogue.trending(limit: 8)),
          ],
        ),
      ),
    );
  }
}

/// Time-aware greeting with the student's name when they have given one.
class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final SettingsController settings = context.watch<SettingsController>();

    final int hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? l10n.greetingMorning
        : (hour < 17 ? l10n.greetingAfternoon : l10n.greetingEvening);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            settings.settings.hasName
                ? l10n.greetingWithName(greeting, settings.settings.greetingName)
                : greeting,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 2),
          Text(l10n.appTagline, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// 2x2 grid of the four primary destinations. Switching tabs (not pushing
/// routes) keeps the back stack clean — see [ShellController].
class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    final List<_QuickCardData> cards = <_QuickCardData>[
      _QuickCardData(
        title: l10n.homeTextbooks,
        subtitle: l10n.homeTextbooksSubtitle,
        icon: Icons.menu_book_rounded,
        tint: Theme.of(context).colorScheme.primary,
        onTap: () => context.read<ShellController>().go(ShellController.booksTab),
      ),
      _QuickCardData(
        title: l10n.homePastPapers,
        subtitle: l10n.homePastPapersSubtitle,
        icon: Icons.description_rounded,
        tint: Theme.of(context).colorScheme.secondary,
        onTap: () => context.read<ShellController>().go(ShellController.papersTab),
      ),
      _QuickCardData(
        title: l10n.homeQuizzes,
        subtitle: l10n.homeQuizzesSubtitle,
        icon: Icons.quiz_rounded,
        tint: const Color(0xFF7C3AED),
        onTap: () => context.read<ShellController>().go(ShellController.quizTab),
      ),
      _QuickCardData(
        title: l10n.homeMyLibrary,
        subtitle: l10n.homeMyLibrarySubtitle,
        icon: Icons.folder_special_rounded,
        tint: context.semanticColors.streakFlame,
        onTap: () =>
            context.read<ShellController>().go(ShellController.libraryTab),
      ),
    ];

    return Padding(
      padding: AppSpacing.screen,
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        // Tall enough for two lines of Sinhala title plus the subtitle.
        childAspectRatio: 1.32,
        children: cards.map((_QuickCardData d) => _QuickCard(data: d)).toList(),
      ),
    );
  }
}

class _QuickCardData {
  const _QuickCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({required this.data});

  final _QuickCardData data;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      semanticLabel: '${data.title}. ${data.subtitle}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: data.tint.withAlpha(30),
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Icon(data.icon, color: data.tint, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal "continue where you left off" rail.
class _ContinueRail extends StatelessWidget {
  const _ContinueRail({required this.recents});

  final List<RecentEntry> recents;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.read<CatalogueController>();
    final String localeCode = context.localeCode;

    if (recents.isEmpty) {
      return Padding(
        padding: AppSpacing.screen,
        child: AppCard(
          child: Row(
            children: <Widget>[
              Icon(
                Icons.history_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l10n.homeContinueEmpty,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: recents.length.clamp(0, 8),
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final RecentEntry entry = recents[index];
          final CatalogueItem? item = catalogue.byId(entry.itemId);
          final String title = item?.displayTitle(localeCode) ??
              (entry.titleSnapshot.isEmpty ? entry.itemId : entry.titleSnapshot);
          final String subjectLabel =
              catalogue.subjectLabel(entry.subjectCode, localeCode);

          return SizedBox(
            width: 220,
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              onTap: item == null
                  ? null
                  : () => openCatalogueItem(context, item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SubjectAvatar(subjectCode: entry.subjectCode, size: 34),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          subjectLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    child: LinearProgressIndicator(
                      value: entry.progress == 0
                          ? 0.06
                          : entry.progress,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.progress == 0
                        ? LocaleUtils.timeLabel(
                            entry.openedAt.hour,
                            entry.openedAt.minute,
                            localeCode,
                          )
                        : l10n.homeProgressLabel(entry.lastPage),
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Badge carousel: earned badges first, then locked ones with their progress.
class _BadgesRail extends StatelessWidget {
  const _BadgesRail({required this.streak});

  final StreakController streak;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: streak.badgeOrder.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final BadgeId id = streak.badgeOrder[index];
          final (bool earned, int current, int target) = streak.badgeProgress(id);
          final BadgeRecord? record = streak.badges.recordFor(id);
          return BadgeTile(
            id: id,
            earned: earned,
            current: current,
            target: target,
            earnedAt: record?.earnedAt,
          );
        },
      ),
    );
  }
}

/// Today's plan summary with a link into the planner.
class _PlannerCard extends StatelessWidget {
  const _PlannerCard({
    required this.nextSlot,
    required this.slotCount,
    required this.subjectLabelOf,
    required this.onTap,
  });

  final StudySlot? nextSlot;
  final int slotCount;
  final String Function(String subjectCode) subjectLabelOf;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final StudySlot? slot = nextSlot;

    if (slot == null) {
      return EmptyState(
        illustration: AppIllustration.emptyPlanner,
        title: l10n.plEmpty,
        body: l10n.homePlannerEmpty,
        actionLabel: l10n.plAddSlot,
        onAction: onTap,
        compact: true,
      );
    }

    return AppCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withAlpha(140),
              borderRadius: BorderRadius.circular(AppRadii.tile),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  LocaleUtils.timeLabel(slot.hour, slot.minute, context.localeCode),
                  style: theme.textTheme.titleSmall,
                ),
                Text(
                  slot.isDaily
                      ? l10n.plEveryDay
                      : LocaleUtils.weekdayShortLabel(l10n, slot.weekday),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(subjectLabelOf(slot.subjectCode), style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  l10n.plReminderBody(subjectLabelOf(slot.subjectCode)),
                  style: theme.textTheme.labelSmall,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
        ],
      ),
    );
  }
}

/// "Trending this week" rail: papers ranked by trend score.
class _TrendingRail extends StatelessWidget {
  const _TrendingRail({required this.items});

  final List<CatalogueItem> items;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.read<CatalogueController>();
    final String localeCode = context.localeCode;

    if (items.isEmpty) {
      return Padding(
        padding: AppSpacing.screen,
        child: InfoBanner(
          message: l10n.homeTrendingEmpty,
          icon: Icons.cloud_download_outlined,
        ),
      );
    }

    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) {
          final CatalogueItem item = items[index];
          return SizedBox(
            width: 210,
            child: PaperListTile(
              item: item,
              title: item.displayTitle(localeCode),
              subjectLabel: catalogue.subjectLabel(item.subjectCode, localeCode),
              mediumLabel: LocaleUtils.mediumLabel(l10n, item.medium),
              download: context.watch<LibraryController>().downloadState(item.id),
              onTap: () => openCatalogueItem(context, item),
              trailing: Text(
                item.yearLabel,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Formatting helper kept next to the screen that uses it, so the trending rail
/// can show a download count without importing the formatter everywhere.
String trendingCountLabel(int count) => Formatters.compactCount(count);

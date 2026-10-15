import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/badge.dart';
import '../../../data/models/study_slot.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../shared/widgets/streak_widgets.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/planner_controller.dart';
import '../../../state/streak_controller.dart';
import '../widgets/add_slot_sheet.dart';

/// Screen 6 — Study planner.
///
/// A deliberately simple timetable: subject + day + time, one weekly repeating
/// reminder each. Grouped by weekday with a "today" highlight so the Home card
/// and this page always agree on what is next.
class PlannerPage extends StatelessWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final PlannerController planner = context.watch<PlannerController>();
    final CatalogueController catalogue = context.read<CatalogueController>();
    final String localeCode = context.localeCode;

    final Map<int, List<StudySlot>> grouped = planner.groupedByWeekday();
    final int todayWeekday = DateTime.now().weekday;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.plTitle),
            Text(l10n.plSubtitle, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: planner.atCapacity
            ? null
            : () => _addSlot(context, planner, catalogue),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.plAddSlot),
      ),
      body: planner.slots.isEmpty
          ? EmptyState(
              illustration: AppIllustration.emptyPlanner,
              title: l10n.plEmpty,
              body: l10n.plEmptyBody,
              actionLabel: l10n.plAddSlot,
              onAction: () => _addSlot(context, planner, catalogue),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                96,
              ),
              children: <Widget>[
                if (!planner.permissionGranted)
                  InfoBanner(
                    message: l10n.plPermissionDenied,
                    icon: Icons.notifications_off_outlined,
                    tone: InfoTone.warning,
                    actionLabel: l10n.plRemindersOn,
                    onAction: () => planner.ensurePermission(),
                  ),
                for (final int weekday in <int>[
                  DateTime.monday,
                  DateTime.tuesday,
                  DateTime.wednesday,
                  DateTime.thursday,
                  DateTime.friday,
                  DateTime.saturday,
                  DateTime.sunday,
                  0,
                ])
                  if (grouped[weekday] != null)
                    _WeekdayBlock(
                      weekday: weekday,
                      slots: grouped[weekday]!,
                      isToday: weekday == todayWeekday,
                      subjectLabelOf: (String code) =>
                          catalogue.subjectLabel(code, localeCode),
                      onToggle: (StudySlot slot, bool enabled) => planner
                          .setEnabled(
                        slot: slot,
                        enabled: enabled,
                        l10n: l10n,
                        subjectLabel:
                            catalogue.subjectLabel(slot.subjectCode, localeCode),
                      ),
                      onDelete: (StudySlot slot) async {
                        final bool confirmed = await AppDialog.confirm(
                          context,
                          title: l10n.plDeleteTitle,
                          body: l10n.plDeleteBody,
                          confirmLabel: l10n.actionDelete,
                          cancelLabel: l10n.actionCancel,
                          destructive: true,
                          icon: Icons.delete_outline_rounded,
                        );
                        if (!confirmed) {
                          return;
                        }
                        await planner.delete(slot);
                        if (context.mounted) {
                          AppSnackbar.info(context, l10n.plDeleted);
                        }
                      },
                      onEdit: (StudySlot slot) =>
                          _addSlot(context, planner, catalogue, existing: slot),
                    ),
              ],
            ),
    );
  }

  Future<void> _addSlot(
    BuildContext context,
    PlannerController planner,
    CatalogueController catalogue, {
    StudySlot? existing,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final StreakController streak = context.read<StreakController>();

    // Ask for notification permission *before* the form: asking afterwards means
    // the student has already done the work and then gets a system prompt.
    final bool granted = await planner.ensurePermission();

    if (!context.mounted) {
      return;
    }

    final StudySlot? saved = await showAddSlotSheet(
      context,
      existing: existing,
      planner: planner,
      catalogue: catalogue,
    );

    if (saved == null) {
      return;
    }

    await streak.checkBadges();

    if (!context.mounted) {
      return;
    }
    if (!granted) {
      AppSnackbar.info(context, l10n.plPermissionDenied);
    } else {
      AppSnackbar.success(context, l10n.plSaved);
    }

    // Celebrate the "Planner pro" badge the first time a slot is created.
    final List<BadgeId> unlocked = streak.drainPendingUnlocks();
    if (unlocked.isEmpty || !context.mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) => BadgeUnlockedSheet(
        id: unlocked.first,
        onDismiss: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }
}

class _WeekdayBlock extends StatelessWidget {
  const _WeekdayBlock({
    required this.weekday,
    required this.slots,
    required this.isToday,
    required this.subjectLabelOf,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
  });

  final int weekday;
  final List<StudySlot> slots;
  final bool isToday;
  final String Function(String code) subjectLabelOf;
  final void Function(StudySlot slot, bool enabled) onToggle;
  final void Function(StudySlot slot) onDelete;
  final void Function(StudySlot slot) onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.md,
            bottom: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Text(
                LocaleUtils.weekdayLabel(l10n, weekday),
                style: theme.textTheme.titleSmall,
              ),
              if (isToday) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                  ),
                  child: Text(
                    l10n.labelToday,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...slots.map(
          (StudySlot slot) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Dismissible(
              key: ValueKey<String>(slot.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (DismissDirection _) async {
                onDelete(slot);
                return false; // the dialog decides; the row stays until then
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Icon(Icons.delete_outline_rounded,
                    color: theme.colorScheme.error),
              ),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: () => onEdit(slot),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withAlpha(140),
                        borderRadius: BorderRadius.circular(AppRadii.tile),
                      ),
                      child: Text(
                        LocaleUtils.timeLabel(
                          slot.hour,
                          slot.minute,
                          context.localeCode,
                        ),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            subjectLabelOf(slot.subjectCode),
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            '${slot.durationMinutes} min',
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: slot.enabled,
                      onChanged: (bool value) => onToggle(slot, value),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

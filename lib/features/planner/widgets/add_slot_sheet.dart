import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/study_slot.dart';
import '../../../data/models/subject.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/planner_controller.dart';

/// Create/edit a study slot: subject, weekday (or every day) and time.
///
/// Returns the saved [StudySlot], or null if the sheet was dismissed.
Future<StudySlot?> showAddSlotSheet(
  BuildContext context, {
  required PlannerController planner,
  required CatalogueController catalogue,
  StudySlot? existing,
}) {
  return showModalBottomSheet<StudySlot>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _AddSlotSheet(
      planner: planner,
      catalogue: catalogue,
      existing: existing,
    ),
  );
}

class _AddSlotSheet extends StatefulWidget {
  const _AddSlotSheet({
    required this.planner,
    required this.catalogue,
    this.existing,
  });

  final PlannerController planner;
  final CatalogueController catalogue;
  final StudySlot? existing;

  @override
  State<_AddSlotSheet> createState() => _AddSlotSheetState();
}

class _AddSlotSheetState extends State<_AddSlotSheet> {
  late String? _subjectCode = widget.existing?.subjectCode;
  late int _weekday = widget.existing?.weekday ?? 0;
  late TimeOfDay _time = TimeOfDay(
    hour: widget.existing?.hour ?? 19,
    minute: widget.existing?.minute ?? 30,
  );
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<Subject> subjects = widget.catalogue.allSubjects();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                widget.existing == null ? l10n.plAddSlot : l10n.plTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),

              _Label(l10n.plSubject),
              if (subjects.isEmpty)
                Text(l10n.tbEmptyBody, style: theme.textTheme.bodySmall)
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 168),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: subjects
                          .map(
                            (Subject subject) => ChoiceChip(
                              label: Text(subject.displayName(context.localeCode)),
                              selected: _subjectCode == subject.code,
                              onSelected: (bool selected) => setState(
                                () => _subjectCode = selected ? subject.code : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),

              _Label(l10n.plDay),
              ChipRow<int>(
                values: <int>[
                  DateTime.monday,
                  DateTime.tuesday,
                  DateTime.wednesday,
                  DateTime.thursday,
                  DateTime.friday,
                  DateTime.saturday,
                  DateTime.sunday,
                ],
                selected: _weekday,
                allLabel: l10n.plEveryDay,
                allValue: 0,
                labelOf: (int weekday) =>
                    LocaleUtils.weekdayLabel(context.l10n, weekday),
                onSelected: (int? weekday) =>
                    setState(() => _weekday = weekday ?? 0),
                padding: EdgeInsets.zero,
              ),

              _Label(l10n.plTime),
              AppPickerTile<void>(
                label: l10n.plTime,
                valueLabel: LocaleUtils.timeLabel(
                  _time.hour,
                  _time.minute,
                  context.localeCode,
                ),
                icon: Icons.schedule_rounded,
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) {
                    setState(() => _time = picked);
                  }
                },
              ),

              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: l10n.plCreate,
                icon: Icons.notifications_active_outlined,
                busy: _saving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final NavigatorState navigator = Navigator.of(context);
    final String? subject = _subjectCode;

    if (subject == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.plSelectSubject)));
      return;
    }

    setState(() => _saving = true);
    final StudySlot? saved = await widget.planner.save(
      existing: widget.existing,
      subjectCode: subject,
      weekday: _weekday,
      hour: _time.hour,
      minute: _time.minute,
      l10n: l10n,
      subjectLabel: widget.catalogue.subjectLabel(subject, context.localeCode),
    );
    if (!mounted) {
      return;
    }
    navigator.pop(saved);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

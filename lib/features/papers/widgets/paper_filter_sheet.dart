import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/paper_filter.dart';
import '../../../data/models/subject.dart';
import '../../../state/catalogue_controller.dart';
import '../../../shared/widgets/app_controls.dart';

/// Bottom sheet for subject / year / medium filters.
///
/// Returns the new [PaperFilter], or null when dismissed — the caller treats
/// null as "leave the list as it was", which is the least surprising behaviour
/// for a dismiss gesture.
Future<PaperFilter?> showPaperFilterSheet(
  BuildContext context, {
  required PaperFilter filter,
  required CatalogueController catalogue,
}) {
  return showModalBottomSheet<PaperFilter>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _PaperFilterSheet(
      filter: filter,
      catalogue: catalogue,
    ),
  );
}

class _PaperFilterSheet extends StatefulWidget {
  const _PaperFilterSheet({required this.filter, required this.catalogue});

  final PaperFilter filter;
  final CatalogueController catalogue;

  @override
  State<_PaperFilterSheet> createState() => _PaperFilterSheetState();
}

class _PaperFilterSheetState extends State<_PaperFilterSheet> {
  late PaperFilter _draft = widget.filter;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    final List<Subject> subjects = widget.catalogue.subjectsForPapers(
      examType: _draft.examType,
      mediumCode: _draft.mediumCode,
    );
    final List<int> years = widget.catalogue.availableYears(
      examType: _draft.examType,
      subjectCode: _draft.subjectCode,
      mediumCode: _draft.mediumCode,
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    l10n.ppTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _draft = _draft.cleared()),
                  child: Text(l10n.actionClearAll),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _GroupLabel(label: l10n.labelSubject),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 168),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: subjects
                      .map(
                        (Subject subject) => FilterChip(
                          label: Text(subject.displayName(context.localeCode)),
                          selected: _draft.subjectCode == subject.code,
                          onSelected: (bool selected) => setState(() {
                            _draft = _draft.copyWith(
                              subjectCode: selected ? subject.code : null,
                              clearSubject: !selected,
                            );
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

            _GroupLabel(label: l10n.labelYear),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: years
                      .map(
                        (int year) => FilterChip(
                          label: Text('$year'),
                          selected: _draft.year == year,
                          onSelected: (bool selected) => setState(() {
                            _draft = _draft.copyWith(
                              year: selected ? year : null,
                              clearYear: !selected,
                            );
                          }),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

            _GroupLabel(label: l10n.labelMedium),
            ChipRow<String>(
              values: Mediums.values,
              selected: _draft.mediumCode,
              allLabel: l10n.labelAll,
              allValue: null,
              labelOf: (String code) => LocaleUtils.mediumLabel(l10n, code),
              onSelected: (String? code) => setState(() {
                _draft = _draft.copyWith(
                  mediumCode: code,
                  clearMedium: code == null,
                );
              }),
              padding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: l10n.actionSave,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(_draft),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium,
      ),
    );
  }
}

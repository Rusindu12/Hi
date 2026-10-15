import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/catalogue_item.dart';
import '../../../data/models/paper_filter.dart';
import '../../../data/models/subject.dart';
import '../../../services/ad_service.dart';
import '../../../shared/widgets/ad_banner.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/catalogue_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/library_controller.dart';
import '../../pdf_reader/presentation/reader_launcher.dart';
import '../widgets/paper_filter_sheet.dart';

/// Screen 4 — Past papers.
///
/// Tabs (O/L · A/L · Grade 5 · Term tests) × filters (subject · year · medium).
/// The filter bar compresses to a single row of chips plus a "filters" button so
/// the list keeps the vertical space it needs on a 5-inch phone.
class PapersPage extends StatefulWidget {
  const PapersPage({super.key, this.initialExamType});

  final String? initialExamType;

  @override
  State<PapersPage> createState() => _PapersPageState();
}

class _PapersPageState extends State<PapersPage>
    with SingleTickerProviderStateMixin {
  late String _examType = widget.initialExamType ?? ExamTypes.ol;
  PaperFilter _filter = const PaperFilter();
  PaperSort _sort = PaperSort.newest;

  @override
  void initState() {
    super.initState();
    _filter = PaperFilter(examType: _examType);
  }

  void _selectExamType(String examType) {
    if (examType == _examType) {
      return;
    }
    setState(() {
      _examType = examType;
      _filter = PaperFilter(examType: examType);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String localeCode = context.localeCode;
    final CatalogueController catalogue = context.watch<CatalogueController>();
    final LibraryController library = context.watch<LibraryController>();

    final List<CatalogueItem> papers =
        catalogue.papers(_filter, localeCode: localeCode, sort: _sort);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ppTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.actionSeeAll,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () async {
              final PaperFilter? result = await showPaperFilterSheet(
                context,
                filter: _filter,
                catalogue: catalogue,
              );
              if (result != null && mounted) {
                setState(() => _filter = result);
              }
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _ExamTabs(
            selected: _examType,
            onSelected: _selectExamType,
          ),
        ),
      ),
      body: Column(
        children: <Widget>[
          _ActiveFilters(
            filter: _filter,
            onCleared: () => setState(() => _filter = _filter.cleared()),
            onRemoveSubject: () =>
                setState(() => _filter = _filter.copyWith(clearSubject: true)),
            onRemoveYear: () =>
                setState(() => _filter = _filter.copyWith(clearYear: true)),
            onRemoveMedium: () =>
                setState(() => _filter = _filter.copyWith(clearMedium: true)),
          ),
          if (_filter.examType == ExamTypes.term)
            Padding(
              padding: AppSpacing.screen.copyWith(bottom: AppSpacing.sm),
              child: InfoBanner(
                message: l10n.ppTermTestNote,
                icon: Icons.school_outlined,
              ),
            ),
          Expanded(
            child: papers.isEmpty
                ? EmptyState(
                    illustration: AppIllustration.emptySearch,
                    title: l10n.ppEmpty,
                    body: l10n.ppEmptyBody,
                    actionLabel: l10n.ppClearFilters,
                    onAction: () => setState(() => _filter = _filter.cleared()),
                    compact: true,
                  )
                : RefreshIndicator(
                    onRefresh: () => catalogue.refresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.sm,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      itemCount: papers.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (BuildContext context, int index) {
                        final CatalogueItem item = papers[index];
                        return PaperListTile(
                          item: item,
                          title: item.displayTitle(localeCode),
                          subjectLabel: catalogue.subjectLabel(
                            item.subjectCode,
                            localeCode,
                          ),
                          mediumLabel: LocaleUtils.mediumLabel(l10n, item.medium),
                          download: library.downloadState(item.id),
                          isFavorite: library.isFavorite(item.id),
                          onToggleFavorite: () => library.toggleFavorite(item.id),
                          onTap: () => openCatalogueItem(context, item),
                        );
                      },
                    ),
                  ),
          ),
          const AdBanner(featureId: AppAdPolicy.featurePapers),
        ],
      ),
    );
  }
}

class _ExamTabs extends StatelessWidget {
  const _ExamTabs({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<String, String> labels = <String, String>{
      ExamTypes.ol: l10n.ppTabOl,
      ExamTypes.al: l10n.ppTabAl,
      ExamTypes.grade5: l10n.ppTabGrade5,
      ExamTypes.term: l10n.ppTabTerm,
    };

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.screen,
        children: labels.entries
            .map(
              (MapEntry<String, String> entry) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (bool _) => onSelected(entry.key),
                  showCheckmark: false,
                  labelStyle: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Chips summarising the active filters, each removable, plus "clear".
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filter,
    required this.onCleared,
    required this.onRemoveSubject,
    required this.onRemoveYear,
    required this.onRemoveMedium,
  });

  final PaperFilter filter;
  final VoidCallback onCleared;
  final VoidCallback onRemoveSubject;
  final VoidCallback onRemoveYear;
  final VoidCallback onRemoveMedium;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.read<CatalogueController>();

    if (!filter.hasActiveFilters) {
      return const SizedBox.shrink();
    }

    final Subject? subject = catalogue.subjects[filter.subjectCode];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (subject != null)
            InputChip(
              label: Text(subject.displayName(context.localeCode)),
              onDeleted: onRemoveSubject,
            ),
          if (filter.year != null)
            InputChip(
              label: Text('${filter.year}'),
              onDeleted: onRemoveYear,
            ),
          if (filter.mediumCode != null)
            InputChip(
              label: Text(
                LocaleUtils.mediumLabel(l10n, filter.mediumCode!),
              ),
              onDeleted: onRemoveMedium,
            ),
          TextButton(
            onPressed: onCleared,
            child: Text(l10n.ppClearFilters),
          ),
        ],
      ),
    );
  }
}

/// Deep-link helper used by the Home trending rail and the quiz empty state.
Future<void> openPapersTab(BuildContext context, {String? examType}) {
  return Navigator.of(context).pushNamed(
    AppRoutes.papers,
    arguments: PaperListArgs(examType: examType),
  );
}

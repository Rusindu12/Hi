import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/catalogue_item.dart';
import '../../../services/ad_service.dart';
import '../../../shared/widgets/ad_banner.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/catalogue_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/library_controller.dart';
import '../../pdf_reader/presentation/reader_launcher.dart';

/// Screen 3b — Textbooks: subject list for one grade, with the medium switch.
///
/// Medium is presented as a filter *within* this screen rather than a separate
/// blocking step. Reason: most students use one medium all year, so a dedicated
/// page would cost them a tap every single visit. The chips start on the medium
/// that matches their UI language ([AppSettings.preferredMedium]).
class TextbookSubjectsPage extends StatefulWidget {
  const TextbookSubjectsPage({
    super.key,
    required this.grade,
    required this.mediumCode,
  });

  final int grade;
  final String mediumCode;

  @override
  State<TextbookSubjectsPage> createState() => _TextbookSubjectsPageState();
}

class _TextbookSubjectsPageState extends State<TextbookSubjectsPage> {
  late String _medium = widget.mediumCode;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String localeCode = context.localeCode;
    final CatalogueController catalogue = context.watch<CatalogueController>();
    final LibraryController library = context.watch<LibraryController>();

    final List<CatalogueItem> books = catalogue.textbooks(
      grade: widget.grade,
      mediumCode: _medium,
      query: _query,
      localeCode: localeCode,
    );

    // Mediums that exist for this grade (with English as a guaranteed fallback
    // so the chip row is never empty).
    final List<String> mediums = catalogue.mediumsForGrade(widget.grade);
    final List<String> effectiveMediums = mediums.isEmpty
        ? <String>[Mediums.english]
        : mediums;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.tbGradeLabel(widget.grade)),
            Text(
              l10n.tbSubjectCount(books.length),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppSearchField(
              hintText: l10n.tbSearchHint,
              onChanged: (String value) => setState(() => _query = value),
              onClear: _query.isEmpty ? null : () => setState(() => _query = ''),
            ),
          ),
          if (effectiveMediums.length > 1)
            ChipRow<String>(
              values: effectiveMediums,
              selected: _medium,
              labelOf: (String code) => LocaleUtils.mediumLabel(l10n, code),
              onSelected: (String? code) {
                if (code != null) {
                  setState(() => _medium = code);
                }
              },
            ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: books.isEmpty
                ? EmptyState(
                    illustration: AppIllustration.emptySearch,
                    title: l10n.tbEmpty,
                    body: l10n.tbEmptyBody,
                    actionLabel: l10n.ppClearFilters,
                    onAction: () {
                      setState(() {
                        _query = '';
                        _medium = Mediums.english;
                      });
                    },
                    compact: true,
                  )
                : RefreshIndicator(
                    onRefresh: () => catalogue.refresh(),
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.xl,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisExtent: 168,
                      ),
                      itemCount: books.length,
                      itemBuilder: (BuildContext context, int index) {
                        final CatalogueItem item = books[index];
                        return TextbookCard(
                          item: item,
                          title: item.displayTitle(localeCode),
                          subjectLabel:
                              catalogue.subjectLabel(item.subjectCode, localeCode),
                          mediumLabel: LocaleUtils.mediumLabel(l10n, item.medium),
                          isFavorite: library.isFavorite(item.id),
                          lastPage: library.lastPageFor(item.id),
                          onToggleFavorite: () => library.toggleFavorite(item.id),
                          onTap: () => openCatalogueItem(context, item),
                        );
                      },
                    ),
                  ),
          ),
          const AdBanner(featureId: AppAdPolicy.featureTextbooks),
        ],
      ),
    );
  }
}

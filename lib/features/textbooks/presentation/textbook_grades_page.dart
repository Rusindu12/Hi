import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../data/models/app_settings.dart';
import '../../../shared/widgets/ad_banner.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../services/ad_service.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/settings_controller.dart';

/// Screen 3a — Textbooks: the grade grid (1–13).
///
/// The step the brief calls "Grade grid → Subject list → Medium selection →
/// PDF reader". Grade is first because it is the only thing a student *always*
/// knows for certain.
class TextbookGradesPage extends StatelessWidget {
  const TextbookGradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.watch<CatalogueController>();
    final Set<int> gradesWithContent = catalogue.gradesWithContent;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.tbTitle),
            Text(l10n.tbSubtitle, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: switch (catalogue.status) {
              CatalogueStatus.loading => const SkeletonList(),
              CatalogueStatus.error => EmptyState(
                  illustration: AppIllustration.emptySearch,
                  title: l10n.tbEmpty,
                  body: l10n.tbEmptyBody,
                  actionLabel: l10n.actionRetry,
                  onAction: () => catalogue.load(forceRefresh: true),
                ),
              _ => RefreshIndicator(
                  onRefresh: () => catalogue.refresh(),
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xl,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: AppSpacing.md,
                      crossAxisSpacing: AppSpacing.md,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: GradeGrid.count,
                    itemBuilder: (BuildContext context, int index) {
                      final int grade = index + GradeGrid.first;
                      final bool hasContent = gradesWithContent.contains(grade);
                      return _GradeTile(
                        grade: grade,
                        hasContent: hasContent,
                      );
                    },
                  ),
                ),
            },
          ),
          // Banners only in browse lists (see AppAdPolicy) — never in the reader.
          const AdBanner(featureId: AppAdPolicy.featureTextbooks),
        ],
      ),
    );
  }
}

/// Grade range constants kept with the screen that renders them. The shared
/// [Grades] constants in core define the curriculum years; this one only knows
/// how many tiles to draw and which ones are exam years.
abstract final class GradeGrid {
  const GradeGrid._();

  static const int first = GradeLevels.min;

  /// 1-13: grade 1 through A/L.
  static const int count = GradeLevels.max - GradeLevels.min + 1;

  static bool isExamYear(int grade) => grade == 5 || grade == 11 || grade == 13;

  static String label(AppLocalizations l10n, int grade) => switch (grade) {
        5 => '${l10n.tbGradeLabel(grade)} · ${l10n.ppTabGrade5}',
        11 => '${l10n.tbGradeLabel(grade)} · ${l10n.ppTabOl}',
        13 => '${l10n.tbGradeLabel(grade)} · ${l10n.ppTabAl}',
        _ => l10n.tbGradeLabel(grade),
      };
}

class _GradeTile extends StatelessWidget {
  const _GradeTile({required this.grade, required this.hasContent});

  final int grade;
  final bool hasContent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final SettingsController settings = context.read<SettingsController>();
    final AppSettings prefs = settings.settings;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      shadow: hasContent,
      color: hasContent ? null : theme.colorScheme.surface.withAlpha(150),
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.textbookSubjects,
        arguments: TextbookSubjectsArgs(
          grade: grade,
          mediumCode: prefs.preferredMedium,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasContent
                  ? theme.colorScheme.primaryContainer.withAlpha(160)
                  : theme.colorScheme.outlineVariant.withAlpha(90),
            ),
            child: Text(
              '$grade',
              style: theme.textTheme.titleLarge?.copyWith(
                color: hasContent
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withAlpha(120),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            GradeGrid.isExamYear(grade)
                ? switch (grade) {
                    5 => l10n.ppTabGrade5,
                    11 => l10n.ppTabOl,
                    _ => l10n.ppTabAl,
                  }
                : l10n.tbGradeLabel(grade),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

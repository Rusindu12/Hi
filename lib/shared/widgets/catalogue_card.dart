import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/l10n_ext.dart';
import '../../data/models/catalogue_item.dart';
import '../../services/download_service.dart';
import 'app_card.dart';

/// Icon per subject code. Emoji-free, single-colour, ~zero APK cost compared to
/// shipping 20 subject images — and they inherit the theme colour.
IconData subjectIcon(String? code) {
  switch (code) {
    case 'mathematics':
      return Icons.calculate_outlined;
    case 'science':
      return Icons.science_outlined;
    case 'sinhala':
      return Icons.translate_rounded;
    case 'tamil':
      return Icons.translate_rounded;
    case 'english':
      return Icons.abc_rounded;
    case 'environment':
      return Icons.park_outlined;
    case 'history':
      return Icons.history_edu_outlined;
    case 'geography':
      return Icons.public_outlined;
    case 'ict':
      return Icons.memory_rounded;
    case 'business_studies':
      return Icons.storefront_outlined;
    case 'accounting':
      return Icons.receipt_long_outlined;
    case 'economics':
      return Icons.trending_up_rounded;
    case 'biology':
      return Icons.biotech_outlined;
    case 'chemistry':
      return Icons.science_rounded;
    case 'physics':
      return Icons.bolt_outlined;
    case 'agriculture':
      return Icons.agriculture_outlined;
    case 'health':
      return Icons.health_and_safety_outlined;
    case 'religion':
      return Icons.self_improvement_rounded;
    case 'civic':
      return Icons.gavel_rounded;
    case 'arts':
      return Icons.palette_outlined;
    default:
      return Icons.menu_book_rounded;
  }
}

/// Colour used for a subject's tint chip. Stable per subject, low saturation so
/// a list of them stays calm.
Color subjectTint(String? code, ColorScheme scheme) {
  final int hash = (code ?? '').codeUnits.fold<int>(7, (int a, int b) => a * 31 + b);
  final List<Color> palette = <Color>[
    scheme.primary,
    scheme.secondary,
    const Color(0xFF7C3AED),
    const Color(0xFF0891B2),
    const Color(0xFFB45309),
    const Color(0xFF15803D),
  ];
  return palette[hash.abs() % palette.length];
}

/// Rounded square with the subject icon — the visual anchor of every book and
/// paper row, and the closest thing this app has to cover art (covers are
/// copyrighted and would also bloat the APK).
class SubjectAvatar extends StatelessWidget {
  const SubjectAvatar({
    super.key,
    required this.subjectCode,
    this.size = 48,
    this.mediumCode,
  });

  final String? subjectCode;
  final double size;
  final String? mediumCode;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color tint = subjectTint(subjectCode, scheme);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadii.tile),
        border: Border.all(color: tint.withAlpha(60)),
      ),
      child: Icon(subjectIcon(subjectCode), color: tint, size: size * 0.5),
    );
  }
}

/// Grid card for a textbook (Textbooks grade → subject step and Home rails).
class TextbookCard extends StatelessWidget {
  const TextbookCard({
    super.key,
    required this.item,
    required this.title,
    required this.subjectLabel,
    required this.mediumLabel,
    required this.onTap,
    this.onToggleFavorite,
    this.isFavorite = false,
    this.lastPage,
  });

  final CatalogueItem item;
  final String title;
  final String subjectLabel;
  final String mediumLabel;
  final VoidCallback onTap;
  final VoidCallback? onToggleFavorite;
  final bool isFavorite;
  final int? lastPage;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SubjectAvatar(subjectCode: item.subjectCode, mediumCode: item.medium),
              const Spacer(),
              if (onToggleFavorite != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 20,
                    color: isFavorite
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withAlpha(120),
                  ),
                  tooltip: l10n.libTabFavorites,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            '$subjectLabel · $mediumLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (lastPage != null && lastPage! > 1)
            Text(
              l10n.homeProgressLabel(lastPage!),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            )
          else if (item.sourceUrl.isNotEmpty)
            Row(
              children: <Widget>[
                Icon(
                  Icons.open_in_new_rounded,
                  size: 12,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.tbOfficialBadge,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// List row for a past paper: subject avatar, title, metadata chips, and a
/// trailing download action whose state comes from [DownloadService].
class PaperListTile extends StatelessWidget {
  const PaperListTile({
    super.key,
    required this.item,
    required this.title,
    required this.subjectLabel,
    required this.mediumLabel,
    required this.onTap,
    this.download,
    this.trailing,
    this.isFavorite = false,
    this.onToggleFavorite,
    this.onOpenMarkingScheme,
  });

  final CatalogueItem item;
  final String title;
  final String subjectLabel;
  final String mediumLabel;
  final VoidCallback onTap;
  final DownloadState? download;
  final Widget? trailing;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  /// Opens the marking scheme that belongs to this paper. Null on screens where
  /// navigation away is not wanted (a picker, for instance): the row then shows
  /// a plain "marking scheme" indicator instead of a tappable link.
  final VoidCallback? onOpenMarkingScheme;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final DownloadState state =
        download ?? DownloadState(itemId: item.id);

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SubjectAvatar(subjectCode: item.subjectCode),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    _MetaChip(label: subjectLabel),
                    if (item.year != null) _MetaChip(label: '${item.year}'),
                    _MetaChip(label: mediumLabel),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.download_outlined,
                      size: 13,
                      color: theme.colorScheme.onSurface.withAlpha(140),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.compactCount(item.downloadCount),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    if (item.fileSizeBytes > 0) ...<Widget>[
                      Icon(
                        Icons.description_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurface.withAlpha(140),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        Formatters.bytes(item.fileSizeBytes),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                    if (item.hasMarkingScheme) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      MarkingSchemeAction(
                        paper: item,
                        onOpen: onOpenMarkingScheme,
                        compact: true,
                      ),
                    ],
                  ],
                ),
                if (state.isDownloading) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.chip),
                    child: LinearProgressIndicator(
                      value: state.progress,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.libDownloading(state.percent),
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: <Widget>[
              if (trailing != null) trailing!,
              if (onToggleFavorite != null)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: isFavorite
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              if (state.isDone)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Icon(
                    Icons.download_done_rounded,
                    size: 18,
                    color: context.semanticColors.successFg,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(110),
        borderRadius: BorderRadius.circular(AppRadii.chip),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

/// Small "official source" watermark used on cards whose rights are
/// `official_link`, so students understand why there is no download button.
class OfficialSourceDot extends StatelessWidget {
  const OfficialSourceDot({super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/illustrations/shield_check.svg',
      height: 14,
      width: 14,
      excludeFromSemantics: true,
      colorFilter: ColorFilter.mode(
        context.semanticColors.successFg,
        BlendMode.srcIn,
      ),
    );
  }
}

/// The "marking scheme" affordance shown on a paper row and in the paper sheet.
///
/// Renders nothing for items that cannot have one (textbooks), an explanatory
/// line when a paper predates digitised schemes, and a tappable chip when the
/// scheme exists — which is the "marking scheme link" the brief asks for.
class MarkingSchemeAction extends StatelessWidget {
  const MarkingSchemeAction({
    super.key,
    required this.paper,
    this.onOpen,
    this.compact = false,
  });

  final CatalogueItem paper;
  final VoidCallback? onOpen;

  /// Compact mode is used inside a list row; the full mode is used in sheets.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    final Color success = context.semanticColors.successFg;

    if (!paper.hasMarkingScheme) {
      if (!CatalogueKind.paperKinds.contains(paper.kind)) {
        return const SizedBox.shrink();
      }
      if (compact) {
        return const SizedBox.shrink();
      }
      return Row(
        children: <Widget>[
          Icon(
            Icons.fact_check_outlined,
            size: 14,
            color: theme.colorScheme.onSurface.withAlpha(120),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              l10n.ppNoMarkingScheme,
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      );
    }

    final Widget label = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.fact_check_outlined, size: compact ? 13 : 16, color: success),
        const SizedBox(width: 6),
        Text(
          compact ? l10n.ppMarkingScheme : l10n.ppMarkingSchemeAvailable,
          style: (compact ? theme.textTheme.labelSmall : theme.textTheme.labelLarge)
              ?.copyWith(color: success),
        ),
        if (onOpen != null && !compact) ...<Widget>[
          const SizedBox(width: 6),
          Icon(Icons.open_in_new_rounded, size: 14, color: success),
        ],
      ],
    );

    if (onOpen == null) {
      return Semantics(
        label: l10n.ppMarkingSchemeAvailable,
        child: label,
      );
    }

    return Semantics(
      button: true,
      label: l10n.ppViewOfficial,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : AppSpacing.md,
            vertical: compact ? 2 : AppSpacing.sm,
          ),
          child: label,
        ),
      ),
    );
  }
}

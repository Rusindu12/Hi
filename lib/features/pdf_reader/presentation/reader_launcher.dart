import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/catalogue_item.dart';
import '../../../services/download_service.dart';
import '../../../services/external_link_service.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/library_controller.dart';
import '../../../state/streak_controller.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/catalogue_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import 'pdf_reader_page.dart';

/// The one entry point for "open this book / paper".
///
/// It centralises the content-policy decision tree so no screen has to think
/// about rights:
///
/// ```
/// is it downloaded?          -> read in app (offline, zero ads)
/// else can we cache it?      -> offer "save for offline" or open the source
/// else (official_link)       -> explain, then open the publisher's site
/// ```
///
/// It also records history and (for reads) the study streak, which is why every
/// open goes through here rather than straight to `Navigator.push`.
Future<void> openCatalogueItem(BuildContext context, CatalogueItem item) async {
  final AppLocalizations l10n = context.l10n;
  final String localeCode = context.localeCode;
  final CatalogueController catalogue = context.read<CatalogueController>();
  final LibraryController library = context.read<LibraryController>();

  final String title = item.displayTitle(localeCode);
  final String subjectLabel = catalogue.subjectLabel(item.subjectCode, localeCode);
  final String subtitle = <String>[
    subjectLabel,
    if (item.year != null) '${item.year}',
    LocaleUtils.mediumLabel(l10n, item.medium),
  ].join(' · ');

  await library.recordOpen(item: item, title: title);
  if (!context.mounted) {
    return;
  }

  final String? localPath = await library.localPathFor(item.id);
  if (!context.mounted) {
    return;
  }

  if (localPath != null) {
    await _pushReader(
      context,
      item: item,
      title: title,
      subtitle: subtitle,
      localPath: localPath,
    );
    return;
  }

  if (!item.canCacheOffline) {
    await _showOfficialSourceSheet(
      context,
      item: item,
      title: title,
      subtitle: subtitle,
    );
    return;
  }

  await _showAcquireSheet(
    context,
    item: item,
    title: title,
    subtitle: subtitle,
  );
}

Future<void> _pushReader(
  BuildContext context, {
  required CatalogueItem item,
  required String title,
  required String subtitle,
  required String localPath,
}) async {
  final LibraryController library = context.read<LibraryController>();
  final int initialPage = library.lastPageFor(item.id);
  await Navigator.of(context).pushNamed(
    AppRoutes.pdfReader,
    arguments: PdfReaderArgs(
      itemId: item.id,
      title: title,
      subtitle: subtitle,
      localPath: localPath,
      initialPage: initialPage,
      externalUrl: item.sourceUrl,
    ),
  );
}

/// Bottom sheet for items SriEdu is *not* allowed to mirror.
Future<void> _showOfficialSourceSheet(
  BuildContext context, {
  required CatalogueItem item,
  required String title,
  required String subtitle,
}) async {
  final AppLocalizations l10n = context.l10n;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _ReaderSheetLayout(
      title: title,
      subtitle: subtitle,
      children: <Widget>[
        InfoBanner(
          message: l10n.tbOfficialBody,
          icon: Icons.verified_outlined,
          tone: InfoTone.success,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            if (item.fileSizeBytes > 0) ...<Widget>[
              _Detail(
                label: l10n.labelFileSize,
                value: Formatters.bytes(item.fileSizeBytes),
              ),
              const SizedBox(width: AppSpacing.lg),
            ],
            _Detail(
              label: l10n.labelMedium,
              value: LocaleUtils.mediumLabel(l10n, item.medium),
            ),
          ],
        ),
        if (item.downloadCount > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Icon(
                Icons.download_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(140),
              ),
              const SizedBox(width: 6),
              Text(
                l10n.ppDownloads(item.downloadCount),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        MarkingSchemeAction(
          paper: item,
          // Pops this sheet first, then runs the normal open flow for the
          // marking scheme so the student sees one sheet at a time.
          onOpen: () async {
            Navigator.of(sheetContext).pop();
            await openMarkingScheme(context, item);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        _OpenSourceButton(
          item: item,
          label: l10n.tbOpenOfficial,
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: item.sourceUrl));
            if (sheetContext.mounted) {
              Navigator.of(sheetContext).pop();
            }
          },
          icon: const Icon(Icons.link_rounded, size: 18),
          label: Text(l10n.actionCopy),
        ),
      ],
    ),
  );
}

/// Bottom sheet for openly licensed / bundled items that can be saved offline.
Future<void> _showAcquireSheet(
  BuildContext context, {
  required CatalogueItem item,
  required String title,
  required String subtitle,
}) async {
  final AppLocalizations l10n = context.l10n;
  final DownloadService downloads = context.read<DownloadService>();
  final LibraryController library = context.read<LibraryController>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) => _ReaderSheetLayout(
      title: title,
      subtitle: subtitle,
      children: <Widget>[
        Text(
          l10n.pdfNoOfflineCopyBody,
          style: Theme.of(sheetContext).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AnimatedBuilder(
          animation: downloads,
          builder: (BuildContext context, Widget? _) {
            final DownloadState state = downloads.stateFor(item.id);
            if (state.isDownloading) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LinearProgressIndicator(value: state.progress),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.libDownloading(state.percent)),
                ],
              );
            }
            return Column(
              children: <Widget>[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await library.download(item);
                        if (!sheetContext.mounted) {
                          return;
                        }
                        Navigator.of(sheetContext).pop();
                        final String? path = await library.localPathFor(item.id);
                        if (path != null && sheetContext.mounted) {
                          await _pushReader(
                            sheetContext,
                            item: item,
                            title: title,
                            subtitle: subtitle,
                            localPath: path,
                          );
                        }
                      } on Object catch (error) {
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                          AppSnackbarFromError.show(sheetContext, error);
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 20),
                    label: Text(l10n.libDownloadNow),
                  ),
                ),
                if (item.hasExternalSource) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _OpenSourceButton(item: item, label: l10n.pdfOpenOfficial),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}

/// Opens the marking scheme that belongs to [paper].
///
/// A marking scheme is a catalogue item of its own, so it runs through exactly
/// the same rights logic as the paper: an `official_link` scheme opens on the
/// publisher's site (and records the study day), a cacheable one is saved
/// offline first. Papers published before marking schemes were digitised simply
/// have none, and the student gets an explanation rather than a dead button.
Future<void> openMarkingScheme(BuildContext context, CatalogueItem paper) async {
  final AppLocalizations l10n = context.l10n;
  final CatalogueController catalogue = context.read<CatalogueController>();

  final CatalogueItem? scheme = catalogue.byId(paper.markingSchemeId);
  if (scheme == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.ppNoMarkingScheme)));
    return;
  }
  await openCatalogueItem(context, scheme);
}

/// Opens the canonical URL and, on success, records today's study day — opening
/// a paper on the publisher's site is still studying.
class _OpenSourceButton extends StatelessWidget {
  const _OpenSourceButton({required this.item, required this.label});

  final CatalogueItem item;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          final StreakController streak = context.read<StreakController>();
          final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
          final NavigatorState navigator = Navigator.of(context);
          final bool opened = await const ExternalLinkService().open(
            item.sourceUrl,
            analyticsLabel: item.kind,
            itemId: item.id,
          );
          if (opened) {
            await streak.recordStudy();
            navigator.pop();
          } else {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.tbCannotOpen)));
          }
        },
        icon: const Icon(Icons.open_in_new_rounded, size: 20),
        label: Text(label),
      ),
    );
  }
}

class _ReaderSheetLayout extends StatelessWidget {
  const _ReaderSheetLayout({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Illustration(AppIllustration.books, height: 56, width: 56),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(subtitle, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.titleSmall),
      ],
    );
  }
}

/// Maps a thrown error to a localised snackbar. Kept here so every screen shows
/// the same wording for the same failure.
abstract final class AppSnackbarFromError {
  const AppSnackbarFromError._();

  static void show(BuildContext context, Object error) {
    final AppLocalizations l10n = context.l10n;
    final String message = switch (error) {
      _ when error.toString().contains('rights=') => l10n.errOfficialOnly,
      _ => l10n.errGeneric,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Exposed for tests: the file name a download would use.
String debugDownloadName(CatalogueItem item) => DownloadNaming.fileNameFor(item);

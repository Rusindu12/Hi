import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/locale_utils.dart';
import '../../../data/models/catalogue_item.dart';
import '../../../data/models/download_record.dart';
import '../../../data/models/recent_entry.dart';
import '../../../services/ad_service.dart';
import '../../../shared/widgets/ad_banner.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/catalogue_card.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/library_controller.dart';
import '../../pdf_reader/presentation/reader_launcher.dart';

/// Screen 7 — My Library: Downloads · Favorites · History, plus storage usage.
///
/// Three tabs rather than one long page: each answers a different question
/// ("what works offline?", "what did I save?", "where was I?").
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final LibraryController library = context.watch<LibraryController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.libTitle),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: Theme.of(context).textTheme.labelMedium,
          tabs: <Widget>[
            Tab(text: l10n.libTabDownloads),
            Tab(text: l10n.libTabFavorites),
            Tab(text: l10n.libTabHistory),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _DownloadsTab(library: library),
                _FavoritesTab(library: library),
                _HistoryTab(library: library),
              ],
            ),
          ),
          const AdBanner(featureId: AppAdPolicy.featureLibrary),
        ],
      ),
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.read<CatalogueController>();
    final List<(DownloadRecord, CatalogueItem?)> rows = library.downloadRows();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: StorageUsageBar(
            title: l10n.libStorage,
            usedLabel: Formatters.bytes(library.storageBytes),
            // 30 MB is the app's own size budget; the bar is a proportion of the
            // app footprint rather than of the whole disk, which needs no plugin
            // and is the number a student can actually act on.
            fraction: (library.storageBytes / (30 * 1024 * 1024)).clamp(0.0, 1.0),
            caption: l10n.libFilesCount(rows.length),
            actionLabel: l10n.libClearCache,
            onAction: () => _confirmClear(context, library),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? EmptyState(
                  illustration: AppIllustration.emptyDownloads,
                  title: l10n.libDownloadsEmpty,
                  body: l10n.libDownloadsEmptyBody,
                  compact: true,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (BuildContext context, int index) {
                    final (DownloadRecord record, CatalogueItem? item) = rows[index];
                    final String title = item?.displayTitle(context.localeCode) ??
                        record.itemId;
                    final String subjectLabel = catalogue.subjectLabel(
                      item?.subjectCode ?? '',
                      context.localeCode,
                    );

                    return PaperListTile(
                      item: item ??
                          CatalogueItem(
                            id: record.itemId,
                            kind: CatalogueKind.paper,
                            title: LocalizedText(en: record.itemId),
                            subjectCode: '',
                            medium: Mediums.english,
                            rights: ContentRights.openLicense,
                            sourceUrl: '',
                          ),
                      title: title,
                      subjectLabel: subjectLabel,
                      mediumLabel: item == null
                          ? ''
                          : LocaleUtils.mediumLabel(context.l10n, item.medium),
                      download: library.downloadState(record.itemId),
                      onTap: () {
                        if (item != null) {
                          openCatalogueItem(context, item);
                        }
                      },
                      trailing: IconButton(
                        tooltip: l10n.actionDelete,
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: item == null
                            ? null
                            : () async {
                                await library.deleteDownload(item);
                                if (context.mounted) {
                                  AppSnackbar.info(context, l10n.libDeleted);
                                }
                              },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    LibraryController library,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await AppDialog.confirm(
      context,
      title: l10n.libClearCacheTitle,
      body: l10n.libClearCacheBody,
      confirmLabel: l10n.libClearCache,
      cancelLabel: l10n.actionCancel,
      destructive: true,
      icon: Icons.cleaning_services_outlined,
    );
    if (!confirmed) {
      return;
    }
    final int freed = await library.clearCache();
    if (context.mounted) {
      AppSnackbar.success(context, l10n.libCacheCleared(Formatters.bytes(freed)));
    }
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.read<CatalogueController>();
    final List<CatalogueItem> items = library.favoriteItems();

    if (items.isEmpty) {
      return EmptyState(
        illustration: AppIllustration.emptyDownloads,
        title: l10n.libFavoritesEmpty,
        body: l10n.libFavoritesEmptyBody,
        compact: true,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final CatalogueItem item = items[index];
        return PaperListTile(
          item: item,
          title: item.displayTitle(context.localeCode),
          subjectLabel:
              catalogue.subjectLabel(item.subjectCode, context.localeCode),
          mediumLabel: LocaleUtils.mediumLabel(l10n, item.medium),
          download: library.downloadState(item.id),
          isFavorite: true,
          onToggleFavorite: () async {
            await library.toggleFavorite(item.id);
            if (context.mounted) {
              AppSnackbar.info(context, l10n.libRemovedFavorite);
            }
          },
          onTap: () => openCatalogueItem(context, item),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.library});

  final LibraryController library;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.read<CatalogueController>();
    final List<RecentEntry> recents = library.recents;

    if (recents.isEmpty) {
      return EmptyState(
        illustration: AppIllustration.emptyHistory,
        title: l10n.libHistoryEmpty,
        body: l10n.libHistoryEmptyBody,
        compact: true,
      );
    }

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final RecentEntry entry = recents[index];
              final CatalogueItem? item = catalogue.byId(entry.itemId);
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                onTap: item == null ? null : () => openCatalogueItem(context, item),
                child: Row(
                  children: <Widget>[
                    SubjectAvatar(subjectCode: entry.subjectCode, size: 36),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item?.displayTitle(context.localeCode) ??
                                entry.titleSnapshot,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(
                            Formatters.relative(
                              entry.openedAt,
                              context.localeCode,
                              DateTime.now(),
                            ),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (entry.lastPage > 1)
                      Text(
                        l10n.homeProgressLabel(entry.lastPage),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: TextButton.icon(
            onPressed: () async {
              await library.clearHistory();
              if (context.mounted) {
                AppSnackbar.info(context, l10n.actionClearAll);
              }
            },
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: Text(l10n.actionClearAll),
          ),
        ),
      ],
    );
  }
}

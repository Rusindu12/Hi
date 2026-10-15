import 'package:flutter/foundation.dart';

import '../data/models/catalogue_item.dart';
import '../data/models/download_record.dart';
import '../data/models/recent_entry.dart';
import '../data/repositories/catalogue_repository.dart';
import '../data/repositories/library_repository.dart';
import '../services/analytics_service.dart';
import '../services/download_service.dart';

/// Drives My Library: favourites, history, downloads and storage usage.
class LibraryController extends ChangeNotifier {
  LibraryController({
    required LibraryRepository repository,
    required CatalogueRepository catalogue,
    required DownloadService downloads,
  })  : _repository = repository,
        _catalogue = catalogue,
        _downloads = downloads {
    _downloads.addListener(onDownloadsChanged);
  }

  final LibraryRepository _repository;
  final CatalogueRepository _catalogue;
  final DownloadService _downloads;

  int _storageBytes = 0;
  bool _storageLoading = false;

  @override
  void dispose() {
    _downloads.removeListener(onDownloadsChanged);
    super.dispose();
  }

  void onDownloadsChanged() => notifyListeners();

  int get storageBytes => _storageBytes;

  bool get storageLoading => _storageLoading;

  // --- Favourites ----------------------------------------------------------

  List<String> get favoriteIds => _repository.favorites();

  bool isFavorite(String itemId) => _repository.isFavorite(itemId);

  /// Resolved favourite items, dropping ids that no longer exist in the
  /// catalogue (for example after a curation change).
  List<CatalogueItem> favoriteItems() {
    final List<CatalogueItem> out = <CatalogueItem>[];
    for (final String id in favoriteIds) {
      final CatalogueItem? item = _catalogue.byId(id);
      if (item != null) {
        out.add(item);
      }
    }
    return out;
  }

  Future<bool> toggleFavorite(String itemId) async {
    final bool nowFavorite = await _repository.toggleFavorite(itemId);
    AnalyticsService.instance.logEvent(
      AnalyticsEvents.favoriteToggled,
      parameters: <String, Object?>{
        'item_id': itemId,
        'favorite': nowFavorite,
      },
    );
    notifyListeners();
    return nowFavorite;
  }

  // --- Downloads -----------------------------------------------------------

  List<DownloadRecord> get downloads => _downloads.downloads;

  DownloadState downloadState(String itemId) => _downloads.stateFor(itemId);

  /// Download records paired with their catalogue metadata, for the list UI.
  List<(DownloadRecord, CatalogueItem?)> downloadRows() {
    return downloads
        .map((DownloadRecord r) => (r, _catalogue.byId(r.itemId)))
        .toList();
  }

  // --- History -------------------------------------------------------------

  List<RecentEntry> get recents => _repository.recents();

  Future<void> clearHistory() async {
    await _repository.clearHistory();
    notifyListeners();
  }

  int lastPageFor(String itemId) => _repository.lastPage(itemId);

  /// Records that an item was opened — powers "Continue where you left off" and
  /// the history tab. Called by the reader launcher before navigation so the
  /// entry exists even if the user backs out immediately.
  Future<void> recordOpen({
    required CatalogueItem item,
    required String title,
    int pageCount = 0,
  }) async {
    await _repository.recordOpen(
      itemId: item.id,
      kind: item.kind,
      subjectCode: item.subjectCode,
      medium: item.medium,
      title: title,
      lastPageRead: _repository.lastPage(item.id),
      pageCount: item.pageCount ?? (pageCount > 0 ? pageCount : null),
    );
    notifyListeners();
  }

  /// Called by the PDF reader (debounced) to persist the current page.
  ///
  /// Writes to both the per-item progress map and the download record, so the
  /// resume point survives even if the student clears their history.
  Future<void> recordReadingProgressForReader({
    required String itemId,
    required int page,
    int? pageCount,
  }) =>
      _downloads.recordReadingProgress(
        itemId: itemId,
        page: page,
        pageCount: pageCount,
      );

  /// Absolute path of an offline copy, or null when it is not downloaded or the
  /// file has been removed from disk.
  Future<String?> localPathFor(String itemId) => _downloads.localPathIfExists(itemId);

  /// Starts a download and resolves to the local path on success.
  Future<String?> download(CatalogueItem item) async {
    await _downloads.download(item);
    return _downloads.localPathIfExists(item.id);
  }

  // --- Storage -------------------------------------------------------------

  Future<void> refreshStorage() async {
    if (_storageLoading) {
      return;
    }
    _storageLoading = true;
    notifyListeners();
    _storageBytes = await _repository.storageUsedBytes();
    _storageLoading = false;
    notifyListeners();
  }

  /// Clears downloads + cache. Returns bytes freed so the snackbar can report it.
  Future<int> clearCache() async {
    final int freed = await _downloads.clearAll();
    await refreshStorage();
    return freed;
  }

  Future<void> deleteDownload(CatalogueItem item) async {
    await _downloads.delete(item);
    await refreshStorage();
  }

  /// Rows whose file is present on disk, used to enable the "downloaded only"
  /// filter in the Library.
  bool isDownloaded(String itemId) => _repository.isDownloaded(itemId);
}

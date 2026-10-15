import 'dart:io';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../data/models/badge.dart';
import '../data/models/catalogue_item.dart';
import '../data/models/download_record.dart';
import '../data/repositories/library_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/sources/remote/storage_file_source.dart';
import 'ad_service.dart';
import 'analytics_service.dart';

enum DownloadStatus { idle, downloading, done, failed }

/// Per-item download state, consumed by the paper/textbook cards.
@immutable
class DownloadState {
  const DownloadState({
    required this.itemId,
    this.status = DownloadStatus.idle,
    this.progress = 0,
    this.bytesWritten = 0,
    this.error,
  });

  final String itemId;
  final DownloadStatus status;
  final double progress;
  final int bytesWritten;
  final Object? error;

  bool get isDownloading => status == DownloadStatus.downloading;

  bool get isDone => status == DownloadStatus.done;

  int get percent => (progress * 100).clamp(0, 100).round();

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    int? bytesWritten,
    Object? error,
    bool clearError = false,
  }) {
    return DownloadState(
      itemId: itemId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      bytesWritten: bytesWritten ?? this.bytesWritten,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Orchestrates offline downloads end to end:
/// policy check -> transfer -> record -> badge check -> interstitial cadence.
///
/// A [ChangeNotifier] so a card can rebuild from `service.stateFor(id)` without
/// every screen wiring its own stream.
class DownloadService extends ChangeNotifier {
  DownloadService({
    required LibraryRepository library,
    required SettingsRepository settings,
    required StorageFileSource files,
    required AdService ads,
    Future<List<BadgeId>> Function()? onBadgeCheck,
  })  : _library = library,
        _settings = settings,
        _files = files,
        _ads = ads,
        _onBadgeCheck = onBadgeCheck;

  final LibraryRepository _library;
  final SettingsRepository _settings;
  final StorageFileSource _files;
  final AdService _ads;
  final Future<List<BadgeId>> Function()? _onBadgeCheck;

  final Map<String, DownloadState> _states = <String, DownloadState>{};

  DownloadState stateFor(String itemId) =>
      _states[itemId] ??
      DownloadState(
        itemId: itemId,
        status: _library.isDownloaded(itemId)
            ? DownloadStatus.done
            : DownloadStatus.idle,
        progress: _library.isDownloaded(itemId) ? 1 : 0,
      );

  /// Badges unlocked by the most recent download (drained by the UI for toasts).
  final List<BadgeId> pendingBadges = <BadgeId>[];

  List<DownloadRecord> get downloads => _library.downloads();

  /// Initiates a download. Throws [ContentPolicyException] when the item may not
  /// be mirrored, and [NetworkException]/[StorageException] on transfer failure —
  /// callers show the localised message.
  Future<DownloadRecord?> download(CatalogueItem item) async {
    if (!item.canCacheOffline) {
      throw ContentPolicyException(
        'item ${item.id} is rights=${item.rights}; open it at its official source',
      );
    }
    if (stateFor(item.id).isDownloading) {
      return null;
    }

    _set(item.id, DownloadState(itemId: item.id, status: DownloadStatus.downloading));

    try {
      final String fileName = Formatters.downloadFileName(
        paperId: item.id,
        extension: _extensionFor(item),
      );
      final String path = await _library.downloadPathFor(fileName);

      final int bytes = await _files.download(
        destinationPath: path,
        storagePath: item.storagePath,
        url: item.sourceUrl,
        onProgress: (double progress) {
          _set(
            item.id,
            DownloadState(
              itemId: item.id,
              status: DownloadStatus.downloading,
              progress: progress,
              bytesWritten: (item.fileSizeBytes * progress).round(),
            ),
          );
        },
      );

      final DownloadRecord record = DownloadRecord(
        itemId: item.id,
        localPath: path,
        sizeBytes: bytes > 0 ? bytes : item.fileSizeBytes,
        downloadedAtMillis: DateTime.now().millisecondsSinceEpoch,
        pageCount: item.pageCount,
      );
      await _library.saveDownload(record);
      _set(
        item.id,
        DownloadState(
          itemId: item.id,
          status: DownloadStatus.done,
          progress: 1,
          bytesWritten: record.sizeBytes,
        ),
      );

      await AnalyticsService.instance.logEvent(
        AnalyticsEvents.paperDownloaded,
        parameters: <String, Object?>{
          'item_id': item.id,
          'subject': item.subjectCode,
          'bytes': record.sizeBytes,
          'rights': item.rights,
        },
      );

      if (_onBadgeCheck != null) {
        pendingBadges.addAll(await _onBadgeCheck());
      }

      // Interstitial cadence: every Nth completed download, never in the reader.
      final bool shown = await _ads.onDownloadCompleted();
      if (shown) {
        await AnalyticsService.instance
            .logEvent(AnalyticsEvents.interstitialShown);
      }
      return record;
    } on AppException catch (error, stack) {
      _set(
        item.id,
        DownloadState(
          itemId: item.id,
          status: DownloadStatus.failed,
          error: error,
        ),
      );
      await AnalyticsService.instance
          .recordError(error, stack, reason: 'download ${item.id}');
      rethrow;
    } on Object catch (error, stack) {
      final AppException wrapped = StorageException(
        'download failed for ${item.id}',
        cause: error,
        stackTrace: stack,
      );
      _set(
        item.id,
        DownloadState(
          itemId: item.id,
          status: DownloadStatus.failed,
          error: wrapped,
        ),
      );
      await AnalyticsService.instance
          .recordError(error, stack, reason: 'download ${item.id}');
      throw wrapped;
    }
  }

  String _extensionFor(CatalogueItem item) {
    final String path = item.storagePath ?? item.sourceUrl;
    final int dot = path.lastIndexOf('.');
    if (dot > 0 && path.length - dot <= 5) {
      return path.substring(dot + 1).toLowerCase();
    }
    return 'pdf';
  }

  /// Deletes an offline copy (Library screen swipe action).
  Future<void> delete(CatalogueItem item) async {
    await _library.removeDownload(item.id);
    _states.remove(item.id);
    await AnalyticsService.instance.logEvent(
      AnalyticsEvents.downloadDeleted,
      parameters: <String, Object?>{'item_id': item.id},
    );
    notifyListeners();
  }

  /// Clears every download and cached file. Returns bytes freed.
  Future<int> clearAll() async {
    final int freed = await _library.clearCache();
    _states.clear();
    await AnalyticsService.instance.logEvent(
      AnalyticsEvents.cacheCleared,
      parameters: <String, Object?>{'bytes_freed': freed},
    );
    notifyListeners();
    return freed;
  }

  /// Path of a completed download, or null when not downloaded / file missing.
  Future<String?> localPathIfExists(String itemId) async {
    final DownloadRecord? record = _library.downloadFor(itemId);
    if (record == null) {
      return null;
    }
    final File file = File(record.localPath);
    if (!await file.exists()) {
      // Record without a file: tidy up so the Library stops lying.
      await _library.removeDownload(itemId);
      return null;
    }
    return record.localPath;
  }

  Future<void> recordReadingProgress({
    required String itemId,
    required int page,
    int? pageCount,
  }) async {
    await _library.saveLastPage(itemId, page);
    final DownloadRecord? record = _library.downloadFor(itemId);
    if (record != null) {
      await _library.saveDownload(
        record.copyWith(lastPage: page, pageCount: pageCount),
      );
    }
    await _library.updateRecentPage(
      itemId: itemId,
      page: page,
      pageCount: pageCount,
    );
  }

  int get downloadsThisSession => _settings.downloadCount();

  void _set(String itemId, DownloadState state) {
    _states[itemId] = state;
    notifyListeners();
  }
}

/// Re-exported for callers that only need the paper id format.
abstract final class DownloadNaming {
  const DownloadNaming._();

  /// Offline copies are always PDFs today; kept as a single place to change if a
  /// future content type (EPUB, MP3 revision audio) is added.
  static String fileNameFor(CatalogueItem item) => Formatters.downloadFileName(
        paperId: item.id,
        extension: 'pdf',
      );

  static bool isPaperKind(String kind) => CatalogueKind.paperKinds.contains(kind);
}

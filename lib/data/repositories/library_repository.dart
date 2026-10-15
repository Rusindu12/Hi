import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/constants/hive_keys.dart';
import '../../core/errors/app_exception.dart';
import '../models/download_record.dart';
import '../models/recent_entry.dart';
import '../sources/local/hive_store.dart';

/// Everything that makes up "My Library": favourites, reading progress,
/// downloads and history — plus the storage maths behind the usage indicator.
class LibraryRepository {
  LibraryRepository(this._store);

  final HiveStore _store;

  static const int _maxRecents = 30;

  // --- Favourites ----------------------------------------------------------

  /// Favourite ids, newest first.
  List<String> favorites() {
    final List<String>? list =
        _store.read<List<dynamic>>(HiveBoxes.favorites, 'ids')?.cast<String>();
    return list ?? const <String>[];
  }

  bool isFavorite(String itemId) => favorites().contains(itemId);

  Future<bool> toggleFavorite(String itemId) async {
    final List<String> current = List<String>.of(favorites());
    final bool nowFavorite = !current.remove(itemId);
    if (nowFavorite) {
      current.insert(0, itemId);
    }
    await _store.write(HiveBoxes.favorites, 'ids', current);
    return nowFavorite;
  }

  Future<void> removeFavorite(String itemId) async {
    final List<String> current = List<String>.of(favorites())..remove(itemId);
    await _store.write(HiveBoxes.favorites, 'ids', current);
  }

  // --- Reading progress ----------------------------------------------------

  /// Last page read for an item (1-based).
  int lastPage(String itemId) => _progressMap()[itemId] ?? 1;

  Map<String, int> _progressMap() {
    final Map<String, Object?>? raw =
        _store.readMap(HiveBoxes.progress, 'pages');
    if (raw == null) {
      return <String, int>{};
    }
    return <String, int>{
      for (final MapEntry<String, Object?> e in raw.entries)
        e.key: int.tryParse(e.value?.toString() ?? '') ?? 1,
    };
  }

  Future<void> saveLastPage(String itemId, int page) async {
    final Map<String, int> map = _progressMap();
    map[itemId] = page;
    await _store.writeMap(
      HiveBoxes.progress,
      'pages',
      map.map((String k, int v) => MapEntry<String, Object?>(k, v)),
    );
  }

  // --- Recents ("Continue where you left off" + history) -------------------

  /// Most recently opened first.
  List<RecentEntry> recents() {
    final List<RecentEntry> entries =
        _store.readMapList(HiveBoxes.recents).map(RecentEntry.fromJson).toList()
          ..sort((RecentEntry a, RecentEntry b) =>
              b.openedAtMillis.compareTo(a.openedAtMillis));
    return entries;
  }

  /// Records that an item was opened. Upserts so an item appears once.
  Future<void> recordOpen({
    required String itemId,
    required String kind,
    required String subjectCode,
    required String medium,
    required String title,
    int lastPageRead = 1,
    int? pageCount,
  }) async {
    final RecentEntry entry = RecentEntry(
      itemId: itemId,
      kind: kind,
      subjectCode: subjectCode,
      medium: medium,
      titleSnapshot: title,
      lastPage: lastPageRead,
      pageCount: pageCount,
      openedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.writeMap(HiveBoxes.recents, itemId, entry.toJson());
    await _pruneRecents();
  }

  Future<void> updateRecentPage({
    required String itemId,
    required int page,
    int? pageCount,
  }) async {
    final Map<String, Object?>? raw =
        _store.readMap(HiveBoxes.recents, itemId);
    if (raw == null) {
      return;
    }
    final RecentEntry entry = RecentEntry.fromJson(raw).copyWith(
      lastPage: page,
      pageCount: pageCount,
    );
    await _store.writeMap(HiveBoxes.recents, itemId, entry.toJson());
  }

  Future<void> _pruneRecents() async {
    final List<RecentEntry> all = recents();
    if (all.length <= _maxRecents) {
      return;
    }
    for (final RecentEntry entry in all.sublist(_maxRecents)) {
      await _store.delete(HiveBoxes.recents, entry.itemId);
    }
  }

  Future<void> clearHistory() => _store.clearBox(HiveBoxes.recents);

  // --- Downloads -----------------------------------------------------------

  List<DownloadRecord> downloads() {
    final List<DownloadRecord> records = _store
        .readMapList(HiveBoxes.downloads)
        .map(DownloadRecord.fromJson)
        .toList()
      ..sort((DownloadRecord a, DownloadRecord b) =>
          b.downloadedAtMillis.compareTo(a.downloadedAtMillis));
    return records;
  }

  DownloadRecord? downloadFor(String itemId) {
    final Map<String, Object?>? raw =
        _store.readMap(HiveBoxes.downloads, itemId);
    return raw == null ? null : DownloadRecord.fromJson(raw);
  }

  bool isDownloaded(String itemId) => downloadFor(itemId) != null;

  Future<void> saveDownload(DownloadRecord record) =>
      _store.writeMap(HiveBoxes.downloads, record.itemId, record.toJson());

  Future<void> removeDownload(String itemId) async {
    final DownloadRecord? record = downloadFor(itemId);
    if (record != null) {
      final File file = File(record.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _store.delete(HiveBoxes.downloads, itemId);
  }

  int downloadCount() => downloads().length;

  /// Bytes currently held by downloaded files, verified against the filesystem
  /// so a deleted-outside-the-app file does not inflate the number.
  Future<int> downloadsSizeBytes() async {
    int total = 0;
    for (final DownloadRecord record in downloads()) {
      final File file = File(record.localPath);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }

  /// Where offline copies live. A single flat directory keeps cleanup simple.
  Future<Directory> downloadsDirectory() async {
    final Directory base = await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/pdfs');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> downloadPathFor(String fileName) async {
    final Directory dir = await downloadsDirectory();
    return '${dir.path}/$fileName';
  }

  // --- Cache / storage -----------------------------------------------------

  /// Deletes every cached file and download, but keeps favourites, streak,
  /// badges and quiz results. Returns the number of bytes freed.
  Future<int> clearCache() async {
    final int freed = await downloadsSizeBytes();
    for (final DownloadRecord record in downloads()) {
      final File file = File(record.localPath);
      if (await file.exists()) {
        try {
          await file.delete();
        } on FileSystemException {
          // A locked file (still open in the reader) is not worth failing for;
          // the record is dropped and the leftover is cleaned next time.
          continue;
        }
      }
    }
    await _store.clearCacheOnly();
    await _pruneDirectory();
    return freed;
  }

  /// Removes stray files in the downloads directory that no record references.
  Future<void> _pruneDirectory() async {
    try {
      final Directory dir = await downloadsDirectory();
      final Set<String> known = downloads()
          .map((DownloadRecord r) => r.localPath)
          .toSet();
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File && !known.contains(entity.path)) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      return;
    }
  }

  /// Total bytes the app occupies for content (downloads + cache directory).
  Future<int> storageUsedBytes() async {
    int total = 0;
    try {
      final Directory dir = await downloadsDirectory();
      await for (final FileSystemEntity entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } on FileSystemException catch (error, stack) {
      throw StorageException('storage scan failed', cause: error, stackTrace: stack);
    }
    return total;
  }

}

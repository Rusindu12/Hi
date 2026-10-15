import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/hive_keys.dart';
import '../../core/errors/app_exception.dart';
import '../models/catalogue_item.dart';
import '../models/official_source.dart';
import '../models/paper_filter.dart';
import '../models/subject.dart';
import '../sources/local/hive_store.dart';
import '../sources/local/local_catalogue_source.dart';
import '../sources/remote/firestore_catalogue_source.dart';

/// Single entry point for catalogue data.
///
/// Resolution order:
///   1. In-memory (already loaded this session).
///   2. Hive cache, if fresh enough ([AppConfig.catalogueCacheTtl]).
///   3. Remote (Firestore) when `USE_FIREBASE=true` **and** it succeeds.
///   4. Bundled assets — always works, never throws for a missing network.
///
/// The bundled fallback is the reason a brand-new install on a bus with no data
/// still shows a full, browsable catalogue.
class CatalogueRepository {
  CatalogueRepository({
    required HiveStore store,
    LocalCatalogueSource? local,
    FirestoreCatalogueSource? remote,
  })  : _store = store,
        _local = local ?? const LocalCatalogueSource(),
        _remote = remote;

  final HiveStore _store;
  final LocalCatalogueSource _local;
  final FirestoreCatalogueSource? _remote;

  CatalogueBundle? _memory;
  SubjectIndex? _subjectIndex;
  List<OfficialSource> _officialSources = const <OfficialSource>[];
  bool _usedRemote = false;

  CatalogueBundle? get current => _memory;

  SubjectIndex get subjects =>
      _subjectIndex ?? SubjectIndex(_memory?.subjects ?? const <Subject>[]);

  List<CatalogueItem> get items => _memory?.items ?? const <CatalogueItem>[];

  List<OfficialSource> get officialSources => _officialSources;

  /// True when the last successful load came from Firestore.
  bool get isRemote => _usedRemote;

  // --- Loading -------------------------------------------------------------

  /// Loads the catalogue, preferring cache then remote then bundled assets.
  ///
  /// [forceRefresh] skips the cache TTL check (used by pull-to-refresh).
  Future<CatalogueBundle> load({bool forceRefresh = false}) async {
    if (_memory != null && !forceRefresh) {
      return _memory!;
    }

    if (!forceRefresh) {
      final CatalogueBundle? cached = _readCache();
      if (cached != null && _isFresh(cached) && cached.items.isNotEmpty) {
        // Still try a background refresh, but never block the UI on it.
        unawaited(_refreshFromRemote().catchError((Object _) => _memory!));
        return _apply(cached, remote: false);
      }
    }

    // Remote first when enabled; a failure falls through to bundled assets.
    if (AppConfig.useFirebase && _remote != null) {
      try {
        final CatalogueBundle remoteBundle = await _remote.fetchCatalogue();
        if (remoteBundle.items.isNotEmpty) {
          _officialSources = await _remote
              .fetchOfficialSources()
              .catchError((Object _) => const <OfficialSource>[]);
          await _writeCache(remoteBundle);
          return _apply(remoteBundle, remote: true);
        }
      } on Object catch (error) {
        debugPrint('[SriEdu] remote catalogue unavailable: $error');
      }
    }

    final CatalogueBundle bundled = await _local.loadCatalogue();
    _officialSources = await _local
        .loadOfficialSources()
        .catchError((Object _) => const <OfficialSource>[]);
    return _apply(bundled, remote: false);
  }

  Future<void> _refreshFromRemote() async {
    if (!AppConfig.useFirebase || _remote == null) {
      return;
    }
    final CatalogueBundle remoteBundle = await _remote.fetchCatalogue();
    if (remoteBundle.items.isEmpty) {
      return;
    }
    await _writeCache(remoteBundle);
    _apply(remoteBundle, remote: true);
  }

  CatalogueBundle _apply(CatalogueBundle bundle, {required bool remote}) {
    _memory = bundle;
    _subjectIndex = SubjectIndex(bundle.subjects);
    _usedRemote = remote;
    return bundle;
  }

  /// Reloads official sources (Settings screen).
  Future<List<OfficialSource>> loadOfficialSources({bool forceRefresh = false}) async {
    if (_officialSources.isNotEmpty && !forceRefresh) {
      return _officialSources;
    }
    if (AppConfig.useFirebase && _remote != null) {
      try {
        _officialSources = await _remote.fetchOfficialSources();
        return _officialSources;
      } on Object catch (error) {
        debugPrint('[SriEdu] official sources remote failed: $error');
      }
    }
    _officialSources = await _local.loadOfficialSources();
    return _officialSources;
  }

  // --- Queries -------------------------------------------------------------

  CatalogueItem? byId(String? id) {
    if (id == null) {
      return null;
    }
    for (final CatalogueItem item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Textbooks for a grade, optionally narrowed to a medium and subject.
  List<CatalogueItem> textbooks({
    required int grade,
    String? mediumCode,
    String? subjectCode,
    String query = '',
    String localeCode = 'en',
  }) {
    final String q = query.trim().toLowerCase();
    return items
        .where((CatalogueItem item) => item.isTextbook)
        .where((CatalogueItem item) => item.grade == grade)
        .where((CatalogueItem item) =>
            mediumCode == null || item.medium == mediumCode)
        .where((CatalogueItem item) =>
            subjectCode == null || item.subjectCode == subjectCode)
        .where((CatalogueItem item) =>
            q.isEmpty || item.searchHaystack(localeCode).contains(q))
        .toList()
      ..sort(_bySubjectThenTitle);
  }

  /// Grades that actually have textbooks, so empty grades are still tappable
  /// but can be shown as "coming soon" rather than a blank list.
  Set<int> gradesWithContent() => items
      .where((CatalogueItem item) => item.isTextbook && item.grade != null)
      .map((CatalogueItem item) => item.grade!)
      .toSet();

  /// Papers matching a filter, sorted.
  List<CatalogueItem> papers(
    PaperFilter filter, {
    required String localeCode,
    PaperSort sort = PaperSort.newest,
  }) {
    final List<CatalogueItem> matched = items
        .where((CatalogueItem item) => item.isPaper)
        .where((CatalogueItem item) => filter.matches(item, localeCode))
        .toList()
      ..sort(sort.comparator());
    return matched;
  }

  /// Distinct years present in the catalogue for an exam type + subject.
  List<int> availableYears({
    String? examType,
    String? subjectCode,
    String? mediumCode,
  }) {
    final Set<int> years = items
        .where((CatalogueItem item) => item.isPaper && item.year != null)
        .where((CatalogueItem item) =>
            examType == null || item.examType == examType)
        .where((CatalogueItem item) =>
            subjectCode == null || item.subjectCode == subjectCode)
        .where((CatalogueItem item) =>
            mediumCode == null || item.medium == mediumCode)
        .map((CatalogueItem item) => item.year!)
        .toSet();
    final List<int> sorted = years.toList()..sort((int a, int b) => b.compareTo(a));
    return sorted;
  }

  /// Subjects that have at least one item for the given filters. Used to grey
  /// out impossible combinations on the Papers and Quiz screens.
  List<Subject> subjectsWithContent({
    String? examType,
    int? grade,
    bool papersOnly = false,
    String? mediumCode,
  }) {
    final Set<String> codes = items
        .where((CatalogueItem item) => !papersOnly || item.isPaper)
        .where((CatalogueItem item) =>
            examType == null || item.examType == examType)
        .where((CatalogueItem item) => grade == null || item.grade == grade)
        .where((CatalogueItem item) =>
            mediumCode == null || item.medium == mediumCode)
        .map((CatalogueItem item) => item.subjectCode)
        .toSet();

    return subjects
        .sorted()
        .where((Subject subject) => codes.contains(subject.code))
        .toList();
  }

  /// "Trending this week": highest trend score, papers only, de-duplicated so
  /// the rail does not show the same subject five times.
  List<CatalogueItem> trending({int limit = 8}) {
    final List<CatalogueItem> sorted = items
        .where((CatalogueItem item) => item.isPaper)
        .toList()
      ..sort((CatalogueItem a, CatalogueItem b) =>
          b.trendScore.compareTo(a.trendScore));

    final Set<String> seenSubjects = <String>{};
    final List<CatalogueItem> out = <CatalogueItem>[];
    for (final CatalogueItem item in sorted) {
      if (seenSubjects.add(item.subjectCode)) {
        out.add(item);
      }
      if (out.length >= limit) {
        break;
      }
    }
    // If the de-duplicated list is short (few subjects), top up.
    if (out.length < limit) {
      for (final CatalogueItem item in sorted) {
        if (!out.contains(item)) {
          out.add(item);
        }
        if (out.length >= limit) {
          break;
        }
      }
    }
    return out;
  }

  int _bySubjectThenTitle(CatalogueItem a, CatalogueItem b) {
    final int subjectOrder = subjects
        .sorted()
        .indexWhere((Subject s) => s.code == a.subjectCode)
        .compareTo(
          subjects.sorted().indexWhere((Subject s) => s.code == b.subjectCode),
        );
    if (subjectOrder != 0) {
      return subjectOrder;
    }
    return a.title.en.compareTo(b.title.en);
  }

  // --- Cache ---------------------------------------------------------------

  CatalogueBundle? _readCache() {
    final Map<String, Object?>? raw =
        _store.readMap(HiveBoxes.cache, CacheKeys.catalogueJson);
    if (raw == null) {
      return null;
    }
    try {
      final List<Map<String, Object?>> subjectsRaw =
          (raw['subjects'] as List<Object?>?)
                  ?.whereType<Map<Object?, Object?>>()
                  .map((Map<Object?, Object?> m) => m.cast<String, Object?>())
                  .toList() ??
              const <Map<String, Object?>>[];
      return CatalogueBundle(
        items: ((raw['items'] as List<Object?>?) ?? const <Object?>[])
            .whereType<Map<Object?, Object?>>()
            .map((Map<Object?, Object?> m) => CatalogueItem.fromJson(m.cast<String, Object?>()))
            .toList(),
        subjects: subjectsRaw.map(Subject.fromJson).toList(),
        version: (raw['version'] as num?)?.toInt() ?? 0,
        syncedAtMillis: (raw['syncedAt'] as num?)?.toInt(),
      );
    } on Object catch (error) {
      debugPrint('[SriEdu] cached catalogue unreadable, ignoring: $error');
      return null;
    }
  }

  bool _isFresh(CatalogueBundle bundle) {
    final int? syncedAt = bundle.syncedAtMillis;
    if (syncedAt == null) {
      return false;
    }
    final DateTime synced = DateTime.fromMillisecondsSinceEpoch(syncedAt);
    return DateTime.now().difference(synced) < AppConfig.catalogueCacheTtl;
  }

  Future<void> _writeCache(CatalogueBundle bundle) async {
    // A bundled-only catalogue is not worth caching: reading the asset is
    // already fast and caching it would mask future asset updates.
    if (!_usedRemote && bundle.syncedAtMillis == null) {
      return;
    }
    final Map<String, Object?> payload = <String, Object?>{
      'items': bundle.items.map((CatalogueItem i) => i.toJson()).toList(),
      'subjects': bundle.subjects.map((Subject s) => s.toJson()).toList(),
      'version': bundle.version,
      'syncedAt': bundle.syncedAtMillis ?? DateTime.now().millisecondsSinceEpoch,
    };
    await _store.writeMap(HiveBoxes.cache, CacheKeys.catalogueJson, payload);
  }

  /// Exposed for tests: the full payload that would be cached, as JSON.
  String debugCachePayload(CatalogueBundle bundle) => jsonEncode(<String, Object?>{
        'items': bundle.items.map((CatalogueItem i) => i.toJson()).toList(),
        'subjects': bundle.subjects.map((Subject s) => s.toJson()).toList(),
        'version': bundle.version,
      });

  /// Drops the in-memory copy so the next [load] hits storage again.
  void invalidate() {
    _memory = null;
    _subjectIndex = null;
  }
}

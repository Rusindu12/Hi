import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../models/catalogue_item.dart';
import '../../models/official_source.dart';
import '../../models/subject.dart';

/// Firestore-backed catalogue.
///
/// Schema (see docs/FIRESTORE_SCHEMA.md):
/// ```
/// catalogue/{itemId}        -> CatalogueItem fields (+ optional storagePath)
/// subjects/{subjectCode}    -> Subject fields
/// official_sources/{id}     -> OfficialSource fields
/// config/catalogue          -> { version: int, updatedAt: timestamp }
/// ```
///
/// Firestore documents use the same field names as the bundled JSON, so the same
/// `toJson`/`fromJson` pair works for both and `tools/seed_firestore.dart` can
/// push local JSON straight up.
///
/// Cost note: we gate on `config/catalogue.version` before pulling the whole
/// collection, so a normal app open costs 1 read instead of N.
class FirestoreCatalogueSource {
  FirestoreCatalogueSource({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  bool get _enabled => AppConfig.useFirebase;

  /// Remote catalogue revision, or null when unreachable.
  Future<int?> fetchVersion() async {
    if (!_enabled) {
      return null;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await _db.collection('config').doc('catalogue').get();
      final Object? version = doc.data()?['version'];
      if (version is int) {
        return version;
      }
      return int.tryParse(version?.toString() ?? '');
    } on Object catch (error, stack) {
      throw NetworkException(
        'catalogue version lookup failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<CatalogueBundle> fetchCatalogue() async {
    if (!_enabled) {
      throw const FirebaseDisabledException(
        'FirestoreCatalogueSource used while USE_FIREBASE=false',
      );
    }
    try {
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
          (await _db.collection('catalogue').limit(2000).get()).docs;

      final List<CatalogueItem> items = <CatalogueItem>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
        final Map<String, Object?> json =
            Map<String, Object?>.of(doc.data())..['id'] = doc.id;
        final CatalogueItem item = CatalogueItem.fromJson(json);
        if (item.id.isNotEmpty) {
          items.add(item);
        }
      }

      final List<Subject> subjects = await _fetchCollection(
        'subjects',
        (Map<String, Object?> json) => Subject.fromJson(json),
      );

      final int version = await fetchVersion() ?? 0;

      return CatalogueBundle(
        items: items,
        subjects: subjects,
        version: version,
        syncedAtMillis: DateTime.now().millisecondsSinceEpoch,
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stack) {
      throw NetworkException(
        'catalogue fetch failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  Future<List<OfficialSource>> fetchOfficialSources() => _fetchCollection(
        'official_sources',
        (Map<String, Object?> json) => OfficialSource.fromJson(json),
      );

  Future<List<T>> _fetchCollection<T>(
    String name,
    T Function(Map<String, Object?> json) build,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _db.collection(name).get();
      final List<T> out = <T>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snapshot.docs) {
        final Map<String, Object?> json =
            Map<String, Object?>.of(doc.data())..['id'] = doc.id;
        out.add(build(json));
      }
      debugPrint('[SriEdu] fetched ${out.length} docs from $name');
      return out;
    } on Object catch (error, stack) {
      throw NetworkException(
        'fetch of $name failed',
        cause: error,
        stackTrace: stack,
      );
    }
  }
}

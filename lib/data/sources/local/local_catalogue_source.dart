import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/app_exception.dart';
import '../../models/catalogue_item.dart';
import '../../models/official_source.dart';
import '../../models/subject.dart';

/// Reads the catalogue bundled with the app.
///
/// This is what makes the app runnable with **zero Firebase configuration**:
/// `assets/data/catalogue.json` ships a realistic seed set, and the app is fully
/// usable offline out of the box. When Firebase is enabled
/// (`--dart-define=USE_FIREBASE=true`) the remote source supersedes this one,
/// but this remains the offline fallback and the seed for `tools/seed_firestore.dart`.
class LocalCatalogueSource {
  const LocalCatalogueSource();

  Future<CatalogueBundle> loadCatalogue() async {
    final Map<String, Object?> json = await _loadJsonMap(AssetPaths.catalogue);
    final List<Object?> rawItems =
        (json['items'] as List<Object?>?) ?? const <Object?>[];
    final List<CatalogueItem> items = rawItems
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> m) => CatalogueItem.fromJson(m.cast<String, Object?>()))
        .where((CatalogueItem item) => item.id.isNotEmpty)
        .toList();

    final List<Subject> subjects = await loadSubjects();
    final int version = (json['version'] as num?)?.toInt() ?? 1;

    if (items.isEmpty) {
      throw const CatalogueException('Bundled catalogue contains no items');
    }

    return CatalogueBundle(
      items: items,
      subjects: subjects,
      version: version,
      syncedAtMillis: null,
    );
  }

  Future<List<Subject>> loadSubjects() async {
    final Map<String, Object?> json = await _loadJsonMap(AssetPaths.subjects);
    final List<Object?> raw = (json['subjects'] as List<Object?>?) ?? const <Object?>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> m) => Subject.fromJson(m.cast<String, Object?>()))
        .where((Subject s) => s.code.isNotEmpty)
        .toList();
  }

  Future<List<OfficialSource>> loadOfficialSources() async {
    final Map<String, Object?> json =
        await _loadJsonMap(AssetPaths.officialSources);
    final List<Object?> raw = (json['sources'] as List<Object?>?) ?? const <Object?>[];
    return raw
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> m) => OfficialSource.fromJson(m.cast<String, Object?>()))
        .where((OfficialSource s) => s.id.isNotEmpty)
        .toList();
  }

  Future<Map<String, Object?>> _loadJsonMap(String assetPath) async {
    try {
      final String raw = await rootBundle.loadString(assetPath);
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
      throw CatalogueException('$assetPath is not a JSON object');
    } on CatalogueException {
      rethrow;
    } on Object catch (error, stack) {
      throw CatalogueException(
        'Could not read $assetPath: $error',
        cause: error,
        stackTrace: stack,
      );
    }
  }
}

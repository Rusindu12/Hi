import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import 'localized_text.dart';
import 'subject.dart';

/// One entry in the catalogue: a textbook, a past paper, a term test, a marking
/// scheme or a sample reading book.
///
/// A single model covers all of them because they share 95% of their fields and
/// because the Home/Textbooks/Papers/Library screens all need to render them
/// with the same card widgets.
@immutable
class CatalogueItem {
  const CatalogueItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subjectCode,
    required this.medium,
    required this.rights,
    required this.sourceUrl,
    this.examType,
    this.grade,
    this.year,
    this.term,
    this.publisher,
    this.fileSizeBytes = 0,
    this.downloadCount = 0,
    this.pageCount,
    this.markingSchemeId,
    this.storagePath,
    this.trendingScore = 0,
    this.updatedAtMillis,
  });

  factory CatalogueItem.fromJson(Map<String, Object?> json) {
    return CatalogueItem(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? CatalogueKind.textbook).toString(),
      title: LocalizedText.fromJson(json['title']),
      subjectCode: (json['subject'] ?? json['subjectCode'] ?? '').toString(),
      medium: (json['medium'] ?? Mediums.english).toString(),
      rights: (json['rights'] ?? ContentRights.officialLink).toString(),
      sourceUrl: (json['sourceUrl'] ?? '').toString(),
      examType: json['examType']?.toString(),
      grade: _intOrNull(json['grade']),
      year: _intOrNull(json['year']),
      term: _intOrNull(json['term']),
      publisher: json['publisher'] == null
          ? null
          : LocalizedText.fromJson(json['publisher']),
      fileSizeBytes: _intOrZero(json['fileSizeBytes'] ?? json['fileSize']),
      downloadCount: _intOrZero(json['downloadCount']),
      pageCount: _intOrNull(json['pageCount']),
      markingSchemeId: json['markingSchemeId']?.toString(),
      storagePath: json['storagePath']?.toString(),
      trendingScore: _intOrZero(json['trendingScore']),
      updatedAtMillis: _intOrNull(json['updatedAt']),
    );
  }

  final String id;

  /// See [CatalogueKind].
  final String kind;

  final LocalizedText title;
  final String subjectCode;

  /// Medium of instruction code: 'en' | 'si' | 'ta'.
  final String medium;

  /// See [ContentRights]. Drives whether offline download is offered.
  final String rights;

  /// Canonical public URL. Always opened through `url_launcher`, never
  /// silently fetched by the app for copyrighted items.
  final String sourceUrl;

  /// 'ol' | 'al' | 'grade5' | 'term' | null for textbooks.
  final String? examType;

  final int? grade;
  final int? year;
  final int? term;
  final LocalizedText? publisher;

  /// Size of the remote file, shown on cards. 0 when unknown.
  final int fileSizeBytes;

  /// Popularity counter used for the "Trending this week" rail.
  final int downloadCount;

  final int? pageCount;

  /// Links a paper to its marking scheme item id, when one exists.
  final String? markingSchemeId;

  /// For cloud-hosted files: the Firestore/Storage path relative to the bucket.
  final String? storagePath;

  /// Server-computed trend score; falls back to [downloadCount] locally.
  final int trendingScore;

  final int? updatedAtMillis;

  // --- Derived -------------------------------------------------------------

  String displayTitle(String localeCode) => title.resolve(localeCode);

  bool get isPaper => kind == CatalogueKind.paper || kind == CatalogueKind.termTest;

  bool get isTextbook => kind == CatalogueKind.textbook;

  bool get hasMarkingScheme =>
      markingSchemeId != null && markingSchemeId!.isNotEmpty;

  /// Copyright decision in one place: only openly licensed or bundled content
  /// may be mirrored into app storage. Official government publications open in
  /// the browser instead (see docs/CONTENT_POLICY.md).
  bool get canCacheOffline => rights != ContentRights.officialLink;

  bool get hasExternalSource => sourceUrl.trim().isNotEmpty;

  int get trendScore => trendingScore > 0 ? trendingScore : downloadCount;

  /// Human label for the paper line, e.g. "2019 · Sinhala medium".
  String get yearLabel => year?.toString() ?? '';

  /// Everything searchable, lower-cased once for the filter chips and search
  /// field. Kept off `==`/`hashCode` on purpose.
  String searchHaystack(String localeCode) => <String>[
        title.en,
        title.si ?? '',
        title.ta ?? '',
        subjectCode,
        medium,
        year?.toString() ?? '',
        examType ?? '',
        grade?.toString() ?? '',
        publisher?.en ?? '',
      ].join(' ').toLowerCase();

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'kind': kind,
        'title': title.toJson(),
        'subject': subjectCode,
        'medium': medium,
        'rights': rights,
        'sourceUrl': sourceUrl,
        if (examType != null) 'examType': examType,
        if (grade != null) 'grade': grade,
        if (year != null) 'year': year,
        if (term != null) 'term': term,
        if (publisher != null) 'publisher': publisher!.toJson(),
        'fileSizeBytes': fileSizeBytes,
        'downloadCount': downloadCount,
        if (pageCount != null) 'pageCount': pageCount,
        if (markingSchemeId != null) 'markingSchemeId': markingSchemeId,
        if (storagePath != null) 'storagePath': storagePath,
        'trendingScore': trendingScore,
        if (updatedAtMillis != null) 'updatedAt': updatedAtMillis,
      };

  CatalogueItem copyWith({
    String? id,
    String? kind,
    LocalizedText? title,
    String? subjectCode,
    String? medium,
    String? rights,
    String? sourceUrl,
    String? examType,
    int? grade,
    int? year,
    int? term,
    LocalizedText? publisher,
    int? fileSizeBytes,
    int? downloadCount,
    int? pageCount,
    String? markingSchemeId,
    String? storagePath,
    int? trendingScore,
    int? updatedAtMillis,
  }) {
    return CatalogueItem(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      title: title ?? this.title,
      subjectCode: subjectCode ?? this.subjectCode,
      medium: medium ?? this.medium,
      rights: rights ?? this.rights,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      examType: examType ?? this.examType,
      grade: grade ?? this.grade,
      year: year ?? this.year,
      term: term ?? this.term,
      publisher: publisher ?? this.publisher,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadCount: downloadCount ?? this.downloadCount,
      pageCount: pageCount ?? this.pageCount,
      markingSchemeId: markingSchemeId ?? this.markingSchemeId,
      storagePath: storagePath ?? this.storagePath,
      trendingScore: trendingScore ?? this.trendingScore,
      updatedAtMillis: updatedAtMillis ?? this.updatedAtMillis,
    );
  }

  @override
  bool operator ==(Object other) => other is CatalogueItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Discriminator values for [CatalogueItem.kind].
abstract final class CatalogueKind {
  const CatalogueKind._();

  static const String textbook = 'textbook';
  static const String paper = 'paper';
  static const String termTest = 'term_test';
  static const String markingScheme = 'marking_scheme';
  static const String syllabus = 'syllabus';
  static const String sample = 'sample';

  /// Kinds that belong in the Past Papers section.
  static const List<String> paperKinds = <String>[paper, termTest, markingScheme];
}

/// The whole downloadable content tree: items plus the subject dictionary used
/// to render their names.
@immutable
class CatalogueBundle {
  const CatalogueBundle({
    required this.items,
    required this.subjects,
    this.syncedAtMillis,
    this.version = 0,
  });

  factory CatalogueBundle.fromJson(Map<String, Object?> json) {
    final List<Object?> rawItems = (json['items'] as List<Object?>?) ?? const <Object?>[];
    return CatalogueBundle(
      items: rawItems
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> m) => CatalogueItem.fromJson(m.cast<String, Object?>()))
          .toList(),
      subjects: const <Subject>[], // subjects arrive from a separate asset
      syncedAtMillis: _intOrNull(json['syncedAt']),
      version: _intOrZero(json['version']),
    );
  }

  final List<CatalogueItem> items;
  final List<Subject> subjects;
  final int? syncedAtMillis;
  final int version;

  Map<String, Object?> toJson() => <String, Object?>{
        'items': items.map((CatalogueItem i) => i.toJson()).toList(),
        'version': version,
        if (syncedAtMillis != null) 'syncedAt': syncedAtMillis,
      };

  CatalogueBundle copyWith({
    List<CatalogueItem>? items,
    List<Subject>? subjects,
    int? syncedAtMillis,
    int? version,
  }) {
    return CatalogueBundle(
      items: items ?? this.items,
      subjects: subjects ?? this.subjects,
      syncedAtMillis: syncedAtMillis ?? this.syncedAtMillis,
      version: version ?? this.version,
    );
  }
}

int? _intOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  return int.tryParse(value.toString());
}

int _intOrZero(Object? value) => _intOrNull(value) ?? 0;

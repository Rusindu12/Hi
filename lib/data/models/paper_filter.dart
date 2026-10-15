import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import 'catalogue_item.dart';

/// Immutable filter state for the Past Papers screen.
///
/// A value object so the whole filter row can be rebuilt from one
/// `setState`/`notifyListeners`, and so "clear filters" is a single assignment.
@immutable
class PaperFilter {
  const PaperFilter({
    this.examType = ExamTypes.ol,
    this.subjectCode,
    this.year,
    this.mediumCode,
    this.query = '',
  });

  /// Tab selection: 'ol' | 'al' | 'grade5' | 'term'.
  final String examType;

  /// null = all subjects.
  final String? subjectCode;

  /// null = all years.
  final int? year;

  /// null = all mediums.
  final String? mediumCode;

  /// Free-text query, matched against the item's search haystack.
  final String query;

  bool get hasActiveFilters =>
      subjectCode != null ||
      year != null ||
      mediumCode != null ||
      query.trim().isNotEmpty;

  /// Clears everything except the exam tab.
  PaperFilter cleared() => PaperFilter(examType: examType);

  PaperFilter copyWith({
    String? examType,
    String? subjectCode,
    int? year,
    String? mediumCode,
    String? query,
    bool clearSubject = false,
    bool clearYear = false,
    bool clearMedium = false,
  }) {
    return PaperFilter(
      examType: examType ?? this.examType,
      subjectCode: clearSubject ? null : (subjectCode ?? this.subjectCode),
      year: clearYear ? null : (year ?? this.year),
      mediumCode: clearMedium ? null : (mediumCode ?? this.mediumCode),
      query: query ?? this.query,
    );
  }

  /// True when [item] should be visible under this filter.
  bool matches(CatalogueItem item, String localeCode) {
    if (item.examType != null && item.examType != examType) {
      return false;
    }
    if (subjectCode != null && item.subjectCode != subjectCode) {
      return false;
    }
    if (year != null && item.year != year) {
      return false;
    }
    if (mediumCode != null && item.medium != mediumCode) {
      return false;
    }
    final String q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return true;
    }
    return item.searchHaystack(localeCode).contains(q);
  }

  @override
  bool operator ==(Object other) =>
      other is PaperFilter &&
      other.examType == examType &&
      other.subjectCode == subjectCode &&
      other.year == year &&
      other.mediumCode == mediumCode &&
      other.query == query;

  @override
  int get hashCode => Object.hash(examType, subjectCode, year, mediumCode, query);
}

/// Sort orders offered on the papers list.
enum PaperSort {
  newest,
  mostDownloaded,
  smallest;

  /// Comparator factory so the UI does not need to know the field names.
  Comparator<CatalogueItem> comparator() {
    switch (this) {
      case PaperSort.newest:
        return (CatalogueItem a, CatalogueItem b) =>
            (b.year ?? 0).compareTo(a.year ?? 0);
      case PaperSort.mostDownloaded:
        return (CatalogueItem a, CatalogueItem b) =>
            b.downloadCount.compareTo(a.downloadCount);
      case PaperSort.smallest:
        return (CatalogueItem a, CatalogueItem b) =>
            a.fileSizeBytes.compareTo(b.fileSizeBytes);
    }
  }
}

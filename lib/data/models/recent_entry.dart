import 'package:flutter/foundation.dart';

/// One row of "Continue where you left off" and of the Library history tab.
///
/// The title is stored *resolved* as well as localised so history stays
/// readable even if the catalogue changes or the item is later removed.
@immutable
class RecentEntry {
  const RecentEntry({
    required this.itemId,
    required this.kind,
    required this.subjectCode,
    required this.medium,
    required this.openedAtMillis,
    this.titleSnapshot = '',
    this.lastPage = 1,
    this.pageCount,
  });

  factory RecentEntry.fromJson(Map<String, Object?> json) => RecentEntry(
        itemId: (json['itemId'] ?? '').toString(),
        kind: (json['kind'] ?? '').toString(),
        subjectCode: (json['subject'] ?? '').toString(),
        medium: (json['medium'] ?? '').toString(),
        titleSnapshot: (json['title'] ?? '').toString(),
        lastPage: _int(json['lastPage'], 1),
        pageCount: json['pageCount'] == null ? null : _int(json['pageCount']),
        openedAtMillis: _int(json['openedAt']),
      );

  final String itemId;
  final String kind;
  final String subjectCode;
  final String medium;
  final String titleSnapshot;
  final int lastPage;
  final int? pageCount;
  final int openedAtMillis;

  DateTime get openedAt => DateTime.fromMillisecondsSinceEpoch(openedAtMillis);

  /// Progress 0..1 for the thin progress bar on the resume card.
  double get progress {
    final int? total = pageCount;
    if (total == null || total <= 0) {
      return 0;
    }
    return (lastPage / total).clamp(0.0, 1.0);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'itemId': itemId,
        'kind': kind,
        'subject': subjectCode,
        'medium': medium,
        'title': titleSnapshot,
        'lastPage': lastPage,
        if (pageCount != null) 'pageCount': pageCount,
        'openedAt': openedAtMillis,
      };

  RecentEntry copyWith({
    String? itemId,
    String? kind,
    String? subjectCode,
    String? medium,
    String? titleSnapshot,
    int? lastPage,
    int? pageCount,
    int? openedAtMillis,
  }) {
    return RecentEntry(
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      subjectCode: subjectCode ?? this.subjectCode,
      medium: medium ?? this.medium,
      titleSnapshot: titleSnapshot ?? this.titleSnapshot,
      lastPage: lastPage ?? this.lastPage,
      pageCount: pageCount ?? this.pageCount,
      openedAtMillis: openedAtMillis ?? this.openedAtMillis,
    );
  }

  @override
  bool operator ==(Object other) => other is RecentEntry && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

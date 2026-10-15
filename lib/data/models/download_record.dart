import 'package:flutter/foundation.dart';

/// A file saved to app storage for offline reading.
///
/// Only items whose [CatalogueItem.canCacheOffline] is true ever produce one of
/// these (see docs/CONTENT_POLICY.md).
@immutable
class DownloadRecord {
  const DownloadRecord({
    required this.itemId,
    required this.localPath,
    required this.sizeBytes,
    required this.downloadedAtMillis,
    this.lastPage = 1,
    this.pageCount,
  });

  factory DownloadRecord.fromJson(Map<String, Object?> json) => DownloadRecord(
        itemId: (json['itemId'] ?? '').toString(),
        localPath: (json['localPath'] ?? '').toString(),
        sizeBytes: _int(json['sizeBytes']),
        downloadedAtMillis: _int(json['downloadedAt']),
        lastPage: _int(json['lastPage'], 1),
        pageCount: json['pageCount'] == null ? null : _int(json['pageCount']),
      );

  final String itemId;

  /// Absolute path inside the app documents directory.
  final String localPath;

  final int sizeBytes;
  final int downloadedAtMillis;

  /// Reading position, cached per download so the reader can resume offline.
  final int lastPage;

  final int? pageCount;

  DateTime get downloadedAt => DateTime.fromMillisecondsSinceEpoch(downloadedAtMillis);

  Map<String, Object?> toJson() => <String, Object?>{
        'itemId': itemId,
        'localPath': localPath,
        'sizeBytes': sizeBytes,
        'downloadedAt': downloadedAtMillis,
        'lastPage': lastPage,
        if (pageCount != null) 'pageCount': pageCount,
      };

  DownloadRecord copyWith({
    String? itemId,
    String? localPath,
    int? sizeBytes,
    int? downloadedAtMillis,
    int? lastPage,
    int? pageCount,
  }) {
    return DownloadRecord(
      itemId: itemId ?? this.itemId,
      localPath: localPath ?? this.localPath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      downloadedAtMillis: downloadedAtMillis ?? this.downloadedAtMillis,
      lastPage: lastPage ?? this.lastPage,
      pageCount: pageCount ?? this.pageCount,
    );
  }

  @override
  bool operator ==(Object other) => other is DownloadRecord && other.itemId == itemId;

  @override
  int get hashCode => itemId.hashCode;
}

int _int(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

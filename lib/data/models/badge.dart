import 'package:flutter/foundation.dart';

/// Every badge the app can award.
///
/// Adding a badge means: add an enum value here, add its two ARB keys in all
/// three locales (`badgeX` / `badgeXDesc`), and add a rule in
/// `BadgeService.evaluate`. Enum `name` is what gets persisted, so never rename
/// a value without a migration.
enum BadgeId {
  firstBook,
  firstQuiz,
  streak7,
  streak30,
  quizMaster,
  tenDownloads,
  plannerPro;

  /// Stable storage key.
  String get storageKey => name;

  static BadgeId? fromStorageKey(String? key) {
    if (key == null) {
      return null;
    }
    for (final BadgeId badge in BadgeId.values) {
      if (badge.name == key) {
        return badge;
      }
    }
    return null;
  }
}

/// An unlocked badge plus when it was earned.
@immutable
class BadgeRecord {
  const BadgeRecord({required this.id, required this.earnedAtMillis});

  factory BadgeRecord.fromJson(Map<String, Object?> json) => BadgeRecord(
        id: BadgeId.fromStorageKey(json['id']?.toString()) ?? BadgeId.firstBook,
        earnedAtMillis: _int(json['earnedAt']),
      );

  final BadgeId id;
  final int earnedAtMillis;

  DateTime get earnedAt => DateTime.fromMillisecondsSinceEpoch(earnedAtMillis);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id.storageKey,
        'earnedAt': earnedAtMillis,
      };
}

/// Immutable badge collection used by the Home screen and the unlock snackbar.
@immutable
class BadgeCollection {
  const BadgeCollection(this.records);

  factory BadgeCollection.fromJsonList(List<Object?> raw) {
    return BadgeCollection(
      raw
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> m) => BadgeRecord.fromJson(m.cast<String, Object?>()))
          .toList(),
    );
  }

  static const BadgeCollection empty = BadgeCollection(<BadgeRecord>[]);

  final List<BadgeRecord> records;

  int get earnedCount => records.length;

  int get totalCount => BadgeId.values.length;

  bool has(BadgeId id) => records.any((BadgeRecord r) => r.id == id);

  BadgeRecord? recordFor(BadgeId id) {
    for (final BadgeRecord record in records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  /// Newest first, so recently-earned badges lead the carousel.
  List<BadgeRecord> newestFirst() {
    final List<BadgeRecord> sorted = List<BadgeRecord>.of(records)
      ..sort((BadgeRecord a, BadgeRecord b) =>
          b.earnedAtMillis.compareTo(a.earnedAtMillis));
    return sorted;
  }

  List<Object?> toJsonList() =>
      records.map((BadgeRecord r) => r.toJson()).toList();
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

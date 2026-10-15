import 'package:flutter/foundation.dart';

/// A single row of the study timetable: "Physics, Tuesday 19:30, reminder on".
///
/// Slots are stored locally (Hive) and scheduled as weekly local notifications.
/// No server round-trip: a student can build a timetable on a bus.
@immutable
class StudySlot {
  const StudySlot({
    required this.id,
    required this.subjectCode,
    required this.notificationId,
    this.weekday = 0,
    this.hour = 19,
    this.minute = 30,
    this.durationMinutes = 45,
    this.enabled = true,
  });

  factory StudySlot.fromJson(Map<String, Object?> json) => StudySlot(
        id: (json['id'] ?? '').toString(),
        subjectCode: (json['subject'] ?? '').toString(),
        notificationId: _int(json['notificationId'], 0),
        weekday: _int(json['weekday'], 0),
        hour: _int(json['hour'], 19),
        minute: _int(json['minute'], 30),
        durationMinutes: _int(json['durationMinutes'], 45),
        enabled: json['enabled'] != false,
      );

  final String id;
  final String subjectCode;

  /// Stable id handed to `flutter_local_notifications`, so editing a slot
  /// replaces the existing reminder instead of creating a duplicate.
  final int notificationId;

  /// `DateTime.monday` (1) … `DateTime.sunday` (7). `0` = every day.
  final int weekday;

  final int hour;
  final int minute;
  final int durationMinutes;
  final bool enabled;

  bool get isDaily => weekday == 0;

  String get idKey => id;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'subject': subjectCode,
        'notificationId': notificationId,
        'weekday': weekday,
        'hour': hour,
        'minute': minute,
        'durationMinutes': durationMinutes,
        'enabled': enabled,
      };

  StudySlot copyWith({
    String? id,
    String? subjectCode,
    int? notificationId,
    int? weekday,
    int? hour,
    int? minute,
    int? durationMinutes,
    bool? enabled,
  }) {
    return StudySlot(
      id: id ?? this.id,
      subjectCode: subjectCode ?? this.subjectCode,
      notificationId: notificationId ?? this.notificationId,
      weekday: weekday ?? this.weekday,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) => other is StudySlot && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

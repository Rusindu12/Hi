import 'package:flutter/foundation.dart';

import '../data/models/study_slot.dart';
import '../services/analytics_service.dart';
import '../services/planner_service.dart';

/// Study planner state: the slot list, today's plan, and permission handling.
class PlannerController extends ChangeNotifier {
  PlannerController(this._service);

  final PlannerService _service;

  bool _permissionGranted = false;
  bool _busy = false;

  bool get permissionGranted => _permissionGranted;

  bool get busy => _busy;

  bool get atCapacity => _service.count >= PlannerService.maxSlots;

  List<StudySlot> get slots => _service.slots;

  List<StudySlot> todaySlots({DateTime? now}) =>
      _service.todaySlots(now ?? DateTime.now());

  bool get hasSlots => slots.isNotEmpty;

  /// Grouped for the timetable view: 1..7 then daily slots under key 0.
  Map<int, List<StudySlot>> groupedByWeekday() {
    final Map<int, List<StudySlot>> grouped = <int, List<StudySlot>>{};
    for (final StudySlot slot in slots) {
      grouped.putIfAbsent(slot.weekday, () => <StudySlot>[]).add(slot);
    }
    return grouped;
  }

  /// Requests notification permission, remembering the answer for the session.
  Future<bool> ensurePermission() async {
    _permissionGranted = await _service.ensurePermission();
    notifyListeners();
    return _permissionGranted;
  }

  /// Creates or updates a slot. Returns the saved slot.
  Future<StudySlot?> save({
    StudySlot? existing,
    required String subjectCode,
    required int weekday,
    required int hour,
    required int minute,
    required dynamic l10n,
    required String subjectLabel,
  }) async {
    _busy = true;
    notifyListeners();
    try {
      final StudySlot? slot = await _service.save(
        existing: existing,
        subjectCode: subjectCode,
        weekday: weekday,
        hour: hour,
        minute: minute,
        l10n: l10n,
        subjectLabel: subjectLabel,
      );
      if (slot != null && existing == null) {
        AnalyticsService.instance.logEvent(
          AnalyticsEvents.plannerSlotCreated,
          parameters: <String, Object?>{
            'subject': subjectCode,
            'weekday': weekday,
            'hour': hour,
          },
        );
      }
      return slot;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> delete(StudySlot slot) async {
    await _service.delete(slot);
    AnalyticsService.instance.logEvent(
      AnalyticsEvents.plannerSlotDeleted,
      parameters: <String, Object?>{'subject': slot.subjectCode},
    );
    notifyListeners();
  }

  Future<void> setEnabled({
    required StudySlot slot,
    required bool enabled,
    required dynamic l10n,
    required String subjectLabel,
  }) async {
    await _service.setEnabled(
      slot: slot,
      enabled: enabled,
      l10n: l10n,
      subjectLabel: subjectLabel,
    );
    notifyListeners();
  }

  /// Slot shown on the Home card: the next one today, else the first of the day.
  StudySlot? nextSlot({DateTime? now}) {
    final DateTime moment = now ?? DateTime.now();
    final List<StudySlot> today = todaySlots(now: moment);
    if (today.isEmpty) {
      return null;
    }
    final int minutesNow = moment.hour * 60 + moment.minute;
    for (final StudySlot slot in today) {
      if (slot.hour * 60 + slot.minute >= minutesNow) {
        return slot;
      }
    }
    return today.first;
  }
}

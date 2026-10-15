import 'package:flutter/foundation.dart';

import '../data/models/study_slot.dart';
import '../data/repositories/planner_repository.dart';
import '../l10n/generated/app_localizations.dart';
import 'notification_service.dart';

/// Turns planner CRUD into "save the slot **and** schedule its reminder".
///
/// Notification ids are allocated here (never by the UI) because a duplicate id
/// silently replaces another slot's reminder on Android.
class PlannerService {
  PlannerService({
    required PlannerRepository repository,
    required NotificationService notifications,
    String Function()? idFactory,
  })  : _repository = repository,
        _notifications = notifications,
        _idFactory = idFactory ??
            (() => 'slot_${DateTime.now().microsecondsSinceEpoch}');

  final PlannerRepository _repository;
  final NotificationService _notifications;
  final String Function() _idFactory;

  static const int maxSlots = 20;

  List<StudySlot> get slots => _repository.slots();

  int get count => _repository.count();

  List<StudySlot> todaySlots(DateTime now) =>
      _repository.slotsForWeekday(now.weekday);

  /// Asks for notification permission once and remembers the answer, so the
  /// prompt is not repeated on every slot creation.
  Future<bool> ensurePermission() async {
    if (!_notifications.isSupported) {
      return false;
    }
    if (!_notifications.isInitialised) {
      await _notifications.initialise();
    }
    return _notifications.requestPermission();
  }

  /// Creates or updates a slot and (re)schedules its reminder.
  ///
  /// Returns the saved slot, or null when the reminder could not be scheduled
  /// *and* the platform does not support notifications at all — in that case the
  /// slot is still saved locally, because the timetable is useful on its own.
  Future<StudySlot?> save({
    StudySlot? existing,
    required String subjectCode,
    required int weekday,
    required int hour,
    required int minute,
    required AppLocalizations l10n,
    required String subjectLabel,
  }) async {
    final StudySlot slot = (existing ??
            StudySlot(
              id: _idFactory(),
              subjectCode: subjectCode,
              notificationId: _repository.nextNotificationId(),
            ))
        .copyWith(
      subjectCode: subjectCode,
      weekday: weekday,
      hour: hour,
      minute: minute,
      enabled: true,
    );

    await _repository.save(slot);
    await _notifications.scheduleSlot(
      slot: slot,
      l10n: l10n,
      subjectLabel: subjectLabel,
    );
    debugPrint('[planner] saved ${slot.id} day=${slot.weekday} ${slot.hour}:${slot.minute}');
    return slot;
  }

  /// Deletes a slot and cancels its reminder.
  Future<void> delete(StudySlot slot) async {
    await _notifications.cancel(slot.notificationId);
    await _repository.delete(slot.id);
    debugPrint('[planner] deleted ${slot.id}');
  }

  /// Enables/disables a slot without losing its schedule.
  Future<StudySlot> setEnabled({
    required StudySlot slot,
    required bool enabled,
    required AppLocalizations l10n,
    required String subjectLabel,
  }) async {
    final StudySlot next = slot.copyWith(enabled: enabled);
    await _repository.save(next);
    if (enabled) {
      await _notifications.scheduleSlot(
        slot: next,
        l10n: l10n,
        subjectLabel: subjectLabel,
      );
    } else {
      await _notifications.cancel(next.notificationId);
    }
    return next;
  }

  /// Re-schedules everything, needed after:
  ///   * the UI language changes (notification text is baked in at schedule time)
  ///   * the device reboots and the app is opened
  Future<void> rescheduleAll({
    required AppLocalizations l10n,
    required String Function(String subjectCode) subjectLabelOf,
  }) async {
    if (!_notifications.isSupported) {
      return;
    }
    if (!_notifications.isInitialised) {
      await _notifications.initialise();
    }
    await _notifications.rescheduleAll(
      slots: slots.where((StudySlot s) => s.enabled).toList(),
      l10n: l10n,
      subjectLabelOf: subjectLabelOf,
    );
  }

  Future<void> clear() async {
    for (final StudySlot slot in slots) {
      await _notifications.cancel(slot.notificationId);
    }
    await _repository.clear();
  }
}

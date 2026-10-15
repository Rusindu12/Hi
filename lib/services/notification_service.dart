import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models/study_slot.dart';
import '../l10n/generated/app_localizations.dart';

/// Local notification plumbing for the study planner.
///
/// Weekly repeating reminders are scheduled as `DateTimeComponents.dayOfWeekAndTime`
/// so they survive a reboot and never need a server. Notification ids are stored
/// on the slot itself, which means editing a slot replaces its reminder instead
/// of stacking duplicates.
///
/// All methods degrade to no-ops on web/desktop so the same code compiles
/// everywhere.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'sriedu_study_reminders';
  static const String _channelName = 'Study reminders';
  static const String _channelDescription =
      'Daily reminders for your study planner slots';

  bool _initialised = false;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  bool get isInitialised => _initialised;

  /// Wires up the plugin and the timezone database.
  Future<void> initialise() async {
    if (!isSupported || _initialised) {
      return;
    }
    try {
      tzdata.initializeTimeZones();

      const AndroidInitializationSettings android =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[notifications] tapped payload=${response.payload}');
        },
      );

      // Android 8+ requires the channel to exist before scheduling.
      final AndroidFlutterLocalNotificationsPlugin? androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );

      _initialised = true;
    } on Object catch (error, stack) {
      debugPrint('[notifications] init failed: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
    }
  }

  /// Asks for notification permission. Returns true when granted.
  /// Android 13+ and iOS both require an explicit prompt.
  Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    try {
      final AndroidFlutterLocalNotificationsPlugin? android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final bool? granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }
      final IOSFlutterLocalNotificationsPlugin? ios =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final bool? granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } on Object catch (error) {
      debugPrint('[notifications] permission request failed: $error');
    }
    return false;
  }

  /// Schedules (or reschedules) a slot's weekly reminder.
  ///
  /// [l10n] is used for the notification body so the reminder arrives in the
  /// language the student chose.
  Future<bool> scheduleSlot({
    required StudySlot slot,
    required AppLocalizations l10n,
    required String subjectLabel,
  }) async {
    if (!isSupported || !_initialised) {
      return false;
    }
    try {
      await _plugin.zonedSchedule(
        slot.notificationId,
        l10n.appName,
        _bodyFor(l10n, subjectLabel),
        _nextInstanceOf(slot),
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            ticker: l10n.plTitle,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents:
            slot.isDaily ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
        payload: slot.id,
      );
      return true;
    } on Object catch (error, stack) {
      debugPrint('[notifications] schedule failed for ${slot.id}: $error');
      debugPrintStack(stackTrace: stack, maxFrames: 4);
      return false;
    }
  }

  String _bodyFor(AppLocalizations l10n, String subjectLabel) {
    if (subjectLabel.trim().isEmpty) {
      return l10n.plReminderBodyGeneric;
    }
    return l10n.plReminderBody(subjectLabel);
  }

  /// Next occurrence of the slot in the device's timezone. For daily slots this
  /// is today if the time has not passed yet, otherwise tomorrow.
  tz.TZDateTime _nextInstanceOf(StudySlot slot) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      slot.hour,
      slot.minute,
    );

    if (slot.isDaily) {
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      return scheduled;
    }

    final int targetWeekday = slot.weekday.clamp(DateTime.monday, DateTime.sunday);
    while (scheduled.weekday != targetWeekday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  Future<void> cancel(int notificationId) async {
    if (!isSupported || !_initialised) {
      return;
    }
    try {
      await _plugin.cancel(notificationId);
    } on Object catch (error) {
      debugPrint('[notifications] cancel failed: $error');
    }
  }

  Future<void> cancelAll() async {
    if (!isSupported || !_initialised) {
      return;
    }
    try {
      await _plugin.cancelAll();
    } on Object catch (error) {
      debugPrint('[notifications] cancelAll failed: $error');
    }
  }

  /// Shows an immediate notification (used for a "streak at risk" nudge when the
  /// app is opened after a missed day).
  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!isSupported || !_initialised) {
      return;
    }
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } on Object catch (error) {
      debugPrint('[notifications] show failed: $error');
    }
  }

  /// Debug helper used by the planner screen's "test reminder" affordance.
  static const int streakNudgeNotificationId = 900;

  /// Reschedules every enabled slot, e.g. after a language change (the body text
  /// is baked in at schedule time) or after a reboot.
  Future<void> rescheduleAll({
    required List<StudySlot> slots,
    required AppLocalizations l10n,
    required String Function(String subjectCode) subjectLabelOf,
  }) async {
    for (final StudySlot slot in slots) {
      if (!slot.enabled) {
        continue;
      }
      await scheduleSlot(
        slot: slot,
        l10n: l10n,
        subjectLabel: subjectLabelOf(slot.subjectCode),
      );
    }
  }
}

/// Shared constants so callers do not invent ids.
abstract final class NotificationChannels {
  const NotificationChannels._();

  static const String reminders = 'sriedu_study_reminders';
  static const String announcements = 'sriedu_announcements';

  /// FCM topic for "new papers" announcements.
  static const String announcementsTopic = 'sriedu_announcements';
}

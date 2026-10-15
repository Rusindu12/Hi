import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import 'analytics_service.dart';
import 'notification_service.dart';

/// Handles a message delivered while the app is backgrounded or terminated.
///
/// Must be a top-level function with `@pragma('vm:entry-point')`: Android may
/// spawn a fresh isolate to run it, so it cannot capture anything.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[fcm] background message: ${message.messageId}');
}

/// Cloud Messaging for "new papers published" announcements.
///
/// Honours the Settings toggle (`notifyAnnouncements`): we subscribe/unsubscribe
/// from the topic rather than filtering locally, so a student who opts out stops
/// consuming their data allowance too.
///
/// No-op when Firebase is disabled or on web, so the same build runs everywhere.
class FcmService {
  FcmService();

  bool _initialised = false;
  bool _subscribed = false;

  bool get isSupported =>
      AppConfig.useFirebase && !kIsWeb;

  bool get isSubscribed => _subscribed;

  Future<void> initialise() async {
    if (!isSupported || _initialised) {
      return;
    }
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        // Deep-link target is carried in `data.route`; the router reads it on
        // next start, so we only log here.
        debugPrint('[fcm] opened from message: ${message.data}');
      });

      _initialised = true;
    } on Object catch (error, stack) {
      debugPrint('[fcm] init failed: $error');
      await AnalyticsService.instance
          .recordError(error, stack, reason: 'fcm init');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) {
      return;
    }
    // Foreground messages are surfaced through our own channel so the styling
    // matches the rest of the app's notifications.
    final NotificationService notifications = NotificationService();
    await notifications.initialise();
    await notifications.showNow(
      id: message.messageId?.hashCode ?? 700,
      title: notification.title ?? '',
      body: notification.body ?? '',
    );
  }

  /// Called from Settings when the toggle changes.
  Future<void> setAnnouncementsEnabled(bool enabled) async {
    if (!isSupported) {
      return;
    }
    try {
      await initialise();
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      if (enabled && !_subscribed) {
        await messaging.subscribeToTopic(NotificationChannels.announcementsTopic);
        _subscribed = true;
      } else if (!enabled && _subscribed) {
        await messaging
            .unsubscribeFromTopic(NotificationChannels.announcementsTopic);
        _subscribed = false;
      }
    } on Object catch (error) {
      debugPrint('[fcm] topic change failed: $error');
    }
  }

  /// Device token, kept for a future "notify me when my paper is uploaded"
  /// feature and useful in Crashlytics when debugging message delivery.
  Future<String?> token() async {
    if (!isSupported) {
      return null;
    }
    try {
      return await FirebaseMessaging.instance.getToken();
    } on Object {
      return null;
    }
  }
}

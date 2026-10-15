package lk.sriedu.app

import io.flutter.embedding.android.FlutterActivity

/**
 * Single Flutter activity.
 *
 * No platform code is needed: PDF rendering, notifications, downloads and ads are
 * all handled by plugins in Dart, which keeps the APK small and makes Flutter SDK
 * upgrades a pubspec change rather than a Java change.
 *
 * If you add a MethodChannel later, override `configureFlutterEngine` and call
 * `super` first so plugin registration still happens.
 */
class MainActivity : FlutterActivity()

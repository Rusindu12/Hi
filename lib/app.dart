import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/router/app_router.dart';
import 'core/router/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/locale_utils.dart';
import 'l10n/generated/app_localizations.dart';
import 'state/settings_controller.dart';

/// Root widget: theme, locale and routing.
///
/// Locale resolution order:
///   1. the language the user picked in onboarding / Settings;
///   2. the device language, if we ship it (en/si/ta);
///   3. English.
class SriEduApp extends StatelessWidget {
  const SriEduApp({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController settings = context.watch<SettingsController>();
    final AppSettingsView view = AppSettingsView.of(settings);

    return MaterialApp(
      title: 'SriEdu',
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: settings.isOnboarded ? AppRoutes.home : AppRoutes.onboarding,
      theme: AppTheme.light(locale: view.locale, fontScale: view.fontScale),
      darkTheme: AppTheme.dark(locale: view.locale, fontScale: view.fontScale),
      themeMode: settings.themeMode,
      locale: view.locale,
      supportedLocales: LocaleUtils.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (Locale? device, Iterable<Locale> supported) {
        // Honour an explicit user choice above everything else.
        if (settings.localeOverride != null) {
          return settings.localeOverride;
        }
        if (device == null) {
          return const Locale(LocaleUtils.fallbackCode);
        }
        return LocaleUtils.systemMatch(<Locale>[device, ...supported]);
      },
      // System text scaling is respected but clamped, because at 2x the Sinhala
      // and Tamil line boxes start overflowing fixed-height cards.
      builder: (BuildContext context, Widget? child) {
        final MediaQueryData media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.85,
              maxScaleFactor: 1.4,
            ),
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: view.isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}

/// Small value object so [SriEduApp] reads clearly and the locale/dark decisions
/// are computed once per build.
@immutable
class AppSettingsView {
  const AppSettingsView({
    required this.locale,
    required this.fontScale,
    required this.isDark,
  });

  factory AppSettingsView.of(SettingsController controller) {
    final Brightness platform =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final bool isDark = switch (controller.themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => platform == Brightness.dark,
    };
    return AppSettingsView(
      locale: LocaleUtils.fromCode(controller.settings.localeCode),
      fontScale: controller.fontScale,
      isDark: isDark,
    );
  }

  final Locale locale;
  final double fontScale;
  final bool isDark;
}

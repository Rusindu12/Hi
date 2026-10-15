import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Assembles [ThemeData] for both brightnesses.
///
/// Deliberately *not* configured here (and instead handled by our own widgets)
/// because their class names changed in recent Flutter releases and would
/// produce deprecation noise or compile breaks across SDK versions:
///   * `cardTheme`        -> use [AppCard]
///   * `dialogTheme`      -> use [AppDialog]
///   * `tabBarTheme`      -> style [TabBar] at the call site
///   * `inputDecorationTheme` -> use [AppInputDecoration]
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light({
    required Locale locale,
    required double fontScale,
  }) {
    final ColorScheme scheme = _scheme(Brightness.light);
    return _base(
      scheme: scheme,
      locale: locale,
      fontScale: fontScale,
      semantic: AppSemanticColors.light,
      scaffold: AppColors.canvas,
    );
  }

  static ThemeData dark({
    required Locale locale,
    required double fontScale,
  }) {
    final ColorScheme scheme = _scheme(Brightness.dark);
    return _base(
      scheme: scheme,
      locale: locale,
      fontScale: fontScale,
      semantic: AppSemanticColors.dark,
      scaffold: AppColors.canvasDark,
    );
  }

  static ColorScheme _scheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme seeded = ColorScheme.fromSeed(
      seedColor: AppColors.teal600,
      brightness: brightness,
    );

    return seeded.copyWith(
      primary: isDark ? AppColors.teal500 : AppColors.teal600,
      onPrimary: Colors.white,
      primaryContainer: isDark ? AppColors.teal700 : AppColors.teal100,
      onPrimaryContainer: isDark ? Colors.white : AppColors.teal700,
      secondary: isDark ? const Color(0xFF7BA7FF) : AppColors.blue600,
      onSecondary: isDark ? const Color(0xFF0B1220) : Colors.white,
      secondaryContainer: isDark ? const Color(0xFF1E2A44) : AppColors.blue100,
      onSecondaryContainer:
          isDark ? const Color(0xFFD6E2FF) : AppColors.blue700,
      tertiary: isDark ? AppColors.flame500 : AppColors.flame600,
      onTertiary: Colors.white,
      tertiaryContainer: isDark ? const Color(0xFF3A2410) : AppColors.amber100,
      onTertiaryContainer:
          isDark ? const Color(0xFFFFE0B2) : AppColors.warning600,
      error: isDark ? const Color(0xFFF87171) : AppColors.danger600,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3B1618) : AppColors.danger100,
      onErrorContainer: isDark ? const Color(0xFFFECACA) : const Color(0xFF7F1D1D),
      surface: isDark ? AppColors.surfaceDark : AppColors.surface,
      onSurface: isDark ? const Color(0xFFE6EDF7) : AppColors.ink900,
      outline: isDark ? AppColors.lineDark : AppColors.ink300,
      outlineVariant: isDark ? AppColors.lineDark : AppColors.line,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? const Color(0xFFE6EDF7) : AppColors.ink900,
      onInverseSurface: isDark ? AppColors.ink900 : Colors.white,
      inversePrimary: isDark ? AppColors.teal600 : AppColors.teal500,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Locale locale,
    required double fontScale,
    required AppSemanticColors semantic,
    required Color scaffold,
  }) {
    final TextTheme text = AppTypography.textTheme(
      locale: locale,
      fontScale: fontScale,
      scheme: scheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scaffold,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        toolbarTextStyle: text.bodyMedium,
        // Sinhala/Tamil app bar titles sit lower than Latin ones; a fixed
        // height keeps the header stable when switching language.
        toolbarHeight: 60,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadii.tile)),
        ),
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 3,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
        linearMinHeight: 6,
      ),
      // Sinhala/Tamil glyphs are taller; give list separators room.
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
        minVerticalPadding: AppSpacing.md,
      ),
    );
  }
}

/// Convenience accessor for the semantic palette.
extension AppThemeX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}

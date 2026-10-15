import 'package:flutter/material.dart';

/// Builds the app text theme.
///
/// Two things matter here for a South Asian audience:
///  1. Sinhala and Tamil are *complex scripts*, so line height is raised
///     (~1.15x) to stop stacked diacritics from colliding between lines.
///  2. The bundled Noto families are set as the primary family for the matching
///     locale and as a *fallback* everywhere else, so a Sinhala name typed into
///     an English UI still renders instead of showing tofu boxes.
abstract final class AppTypography {
  const AppTypography._();

  static const String sinhalaFamily = 'NotoSansSinhala';
  static const String tamilFamily = 'NotoSansTamil';

  /// Extra leading applied to complex scripts.
  static const double _complexScriptLeading = 1.15;

  static String? _primaryFamily(Locale locale) {
    switch (locale.languageCode) {
      case 'si':
        return sinhalaFamily;
      case 'ta':
        return tamilFamily;
      default:
        return null;
    }
  }

  static List<String> _fallbacks(Locale locale) {
    final String code = locale.languageCode;
    return <String>[
      if (code != 'si') sinhalaFamily,
      if (code != 'ta') tamilFamily,
    ];
  }

  /// Returns a complete [TextTheme] for [locale], scaled by [fontScale]
  /// (1.0 = default) and coloured for the given [brightness].
  static TextTheme textTheme({
    required Locale locale,
    required double fontScale,
    required ColorScheme scheme,
  }) {
    final bool complexScript =
        locale.languageCode == 'si' || locale.languageCode == 'ta';
    final double leading = complexScript ? _complexScriptLeading : 1.0;

    TextStyle style({
      required double size,
      required FontWeight weight,
      required double height,
      Color? color,
      double? letterSpacing,
    }) {
      return TextStyle(
        fontSize: size * fontScale,
        fontWeight: weight,
        height: height * leading,
        color: color ?? scheme.onSurface,
        letterSpacing: letterSpacing,
        fontFamily: _primaryFamily(locale),
        fontFamilyFallback: _fallbacks(locale),
      );
    }

    // NOTE: `withAlpha` (not `withValues`/`withOpacity`) — `withValues` only
    // exists on Flutter 3.27+ and `withOpacity` is deprecated from 3.27, so
    // `withAlpha` is the one call that is clean on every supported SDK.
    final Color muted = scheme.onSurface.withAlpha(184);

    return TextTheme(
      displaySmall: style(size: 30, weight: FontWeight.w700, height: 1.25),
      headlineLarge: style(size: 26, weight: FontWeight.w700, height: 1.25),
      headlineMedium: style(size: 22, weight: FontWeight.w700, height: 1.3),
      headlineSmall: style(size: 20, weight: FontWeight.w600, height: 1.3),
      titleLarge: style(size: 18, weight: FontWeight.w600, height: 1.3),
      titleMedium: style(size: 16, weight: FontWeight.w600, height: 1.3),
      titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.3),
      bodyLarge: style(size: 16, weight: FontWeight.w400, height: 1.45),
      bodyMedium: style(size: 14, weight: FontWeight.w400, height: 1.45),
      bodySmall: style(
        size: 12,
        weight: FontWeight.w400,
        height: 1.4,
        color: muted,
      ),
      labelLarge: style(size: 15, weight: FontWeight.w600, height: 1.2),
      labelMedium: style(
        size: 13,
        weight: FontWeight.w500,
        height: 1.2,
        color: muted,
      ),
      labelSmall: style(
        size: 11,
        weight: FontWeight.w500,
        height: 1.2,
        color: muted,
        letterSpacing: 0.3,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Raw palette. Widgets should prefer `Theme.of(context).colorScheme` or the
/// semantic colours published by [AppSemanticColors]; these constants exist so
/// the theme itself has a single source of truth.
abstract final class AppColors {
  const AppColors._();

  // --- Brand: friendly teal + blue -----------------------------------------
  static const Color teal700 = Color(0xFF0B6470);
  static const Color teal600 = Color(0xFF0F7B8A);
  static const Color teal500 = Color(0xFF14919B);
  static const Color teal200 = Color(0xFFA9DBE0);
  static const Color teal100 = Color(0xFFD8F0F2);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue100 = Color(0xFFDCE7FF);

  // --- Warm accents: streaks and badges ------------------------------------
  static const Color flame600 = Color(0xFFF97316);
  static const Color flame500 = Color(0xFFFB923C);
  static const Color amber400 = Color(0xFFFBBF24);
  static const Color amber100 = Color(0xFFFEF3C7);
  static const Color plum600 = Color(0xFF7C3AED);
  static const Color plum100 = Color(0xFFEDE9FE);

  // --- Feedback ------------------------------------------------------------
  static const Color success600 = Color(0xFF15803D);
  static const Color success100 = Color(0xFFDCFCE7);
  static const Color danger600 = Color(0xFFDC2626);
  static const Color danger100 = Color(0xFFFEE2E2);
  static const Color warning600 = Color(0xFFB45309);

  // --- Neutrals (light) ----------------------------------------------------
  static const Color ink900 = Color(0xFF0F172A);
  static const Color ink700 = Color(0xFF334155);
  static const Color ink500 = Color(0xFF64748B);
  static const Color ink300 = Color(0xFFCBD5E1);
  static const Color line = Color(0xFFE2E8F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color canvas = Color(0xFFF5F8FB);

  // --- Neutrals (dark) ----------------------------------------------------
  static const Color inkDark900 = Color(0xFF070C14);
  static const Color canvasDark = Color(0xFF0B1220);
  static const Color surfaceDark = Color(0xFF131C2B);
  static const Color surfaceDarkElevated = Color(0xFF1B2637);
  static const Color lineDark = Color(0xFF243044);

  // --- Gradients ----------------------------------------------------------
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[teal500, blue600],
  );

  static const LinearGradient streakGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[flame600, amber400],
  );
}

/// Semantic colours that Material's [ColorScheme] does not model (streak flame,
/// success/warning chips, card shadows). Exposed as a [ThemeExtension] so both
/// themes stay in sync and widgets never hard-code a hex value.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.streakFlame,
    required this.streakTrack,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.badgeLockedBg,
    required this.badgeLockedFg,
    required this.cardShadow,
    required this.accentGradient,
  });

  final Color streakFlame;
  final Color streakTrack;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color badgeLockedBg;
  final Color badgeLockedFg;
  final Color cardShadow;
  final Gradient accentGradient;

  static const AppSemanticColors light = AppSemanticColors(
    streakFlame: AppColors.flame600,
    streakTrack: AppColors.line,
    successFg: AppColors.success600,
    successBg: AppColors.success100,
    warningFg: AppColors.warning600,
    warningBg: AppColors.amber100,
    badgeLockedBg: AppColors.line,
    badgeLockedFg: AppColors.ink500,
    cardShadow: Color(0x14213A54),
    accentGradient: AppColors.streakGradient,
  );

  static const AppSemanticColors dark = AppSemanticColors(
    streakFlame: AppColors.flame500,
    streakTrack: AppColors.lineDark,
    successFg: Color(0xFF4ADE80),
    successBg: Color(0xFF10331F),
    warningFg: Color(0xFFFCD34D),
    warningBg: Color(0xFF3A2A08),
    badgeLockedBg: AppColors.lineDark,
    badgeLockedFg: Color(0xFF94A3B8),
    cardShadow: Color(0x40000000),
    accentGradient: AppColors.streakGradient,
  );

  @override
  AppSemanticColors copyWith({
    Color? streakFlame,
    Color? streakTrack,
    Color? successFg,
    Color? successBg,
    Color? warningFg,
    Color? warningBg,
    Color? badgeLockedBg,
    Color? badgeLockedFg,
    Color? cardShadow,
    Gradient? accentGradient,
  }) {
    return AppSemanticColors(
      streakFlame: streakFlame ?? this.streakFlame,
      streakTrack: streakTrack ?? this.streakTrack,
      successFg: successFg ?? this.successFg,
      successBg: successBg ?? this.successBg,
      warningFg: warningFg ?? this.warningFg,
      warningBg: warningBg ?? this.warningBg,
      badgeLockedBg: badgeLockedBg ?? this.badgeLockedBg,
      badgeLockedFg: badgeLockedFg ?? this.badgeLockedFg,
      cardShadow: cardShadow ?? this.cardShadow,
      accentGradient: accentGradient ?? this.accentGradient,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      streakFlame: Color.lerp(streakFlame, other.streakFlame, t)!,
      streakTrack: Color.lerp(streakTrack, other.streakTrack, t)!,
      successFg: Color.lerp(successFg, other.successFg, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      warningFg: Color.lerp(warningFg, other.warningFg, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      badgeLockedBg: Color.lerp(badgeLockedBg, other.badgeLockedBg, t)!,
      badgeLockedFg: Color.lerp(badgeLockedFg, other.badgeLockedFg, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      accentGradient: t < 0.5 ? accentGradient : other.accentGradient,
    );
  }
}

/// Layout tokens. 16px card radius, soft shadows and an 8pt spacing scale are
/// the design brief's contract; keeping them here stops drift.
abstract final class AppRadii {
  const AppRadii._();

  static const double card = 16;
  static const double sheet = 24;
  static const double chip = 999;
  static const double input = 14;
  static const double button = 14;
  static const double tile = 12;
}

abstract final class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Standard screen padding: 16 horizontal.
  static const EdgeInsets screen = EdgeInsets.symmetric(horizontal: lg);

  /// Bottom padding that clears the custom navigation bar plus the ad banner.
  static const double navBarHeight = 68;
}

abstract final class AppShadows {
  const AppShadows._();

  static List<BoxShadow> soft(Color shadow) => <BoxShadow>[
        BoxShadow(
          color: shadow,
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Snackbars, in three flavours, so tones stay consistent across screens.
abstract final class AppSnackbar {
  const AppSnackbar._();

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, Tone.success);

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, Tone.info);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, Tone.error);

  /// Celebration used for badge unlocks and new quiz records.
  static void celebrate(BuildContext context, String message) =>
      _show(context, message, Icons.emoji_events_outlined, Tone.streak);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Tone tone,
  ) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color accent = switch (tone) {
      Tone.success => context.semanticColors.successFg,
      Tone.error => scheme.error,
      Tone.streak => context.semanticColors.streakFlame,
      Tone.info => scheme.primary,
    };

    // Replace rather than queue: a burst of "badge unlocked" toasts should show
    // the latest, not play a 5-second queue the student has to wait through.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: <Widget>[
              Icon(icon, color: accent, size: 20),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

enum Tone { success, info, error, streak }

/// Confirmation dialogs (`AlertDialog` styled centrally).
abstract final class AppDialog {
  const AppDialog._();

  /// Returns true when the user confirms. A barrier tap resolves to false, which
  /// is what every destructive action in the app wants.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required String cancelLabel,
    bool destructive = false,
    IconData? icon,
  }) async {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        icon: icon == null
            ? null
            : Icon(
                icon,
                color: destructive ? scheme.error : scheme.primary,
                size: 28,
              ),
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

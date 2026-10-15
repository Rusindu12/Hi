import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'illustration.dart';

/// The one empty-state layout used everywhere: illustration, title, one sentence
/// of guidance, and at most one clear action.
///
/// Having a single widget means every empty screen in the app looks deliberate
/// rather than like something failed to load.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final AppIllustration illustration;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Compact mode (list tabs) drops the illustration to 96 px and tightens
  /// spacing so it fits inside a tab without scrolling.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Illustration(
              illustration,
              height: compact ? 96 : 152,
            ),
            SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(170),
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact inline notice used for "offline", "official source" and other
/// one-line explanations inside a scroll view.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.message,
    this.icon = Icons.info_outline,
    this.tone = InfoTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData icon;
  final InfoTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final (Color bg, Color fg) = switch (tone) {
      InfoTone.neutral => (
          theme.colorScheme.primaryContainer.withAlpha(120),
          theme.colorScheme.onPrimaryContainer,
        ),
      InfoTone.success => (
          context.semanticColors.successBg,
          context.semanticColors.successFg,
        ),
      InfoTone.warning => (
          context.semanticColors.warningBg,
          context.semanticColors.warningFg,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.tile),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: fg),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: fg,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

enum InfoTone { neutral, success, warning }

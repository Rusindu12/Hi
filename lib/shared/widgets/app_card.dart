import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The app's single card primitive: 16 px radius, soft shadow, 1 px hairline.
///
/// Replaces `Card`/`CardTheme` deliberately: the `cardTheme` API was renamed to
/// `CardThemeData` in Flutter 3.27, so using a plain widget keeps this codebase
/// compiling cleanly on every supported SDK *and* gives exact control over the
/// brief's design language.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.margin,
    this.radius = AppRadii.card,
    this.color,
    this.gradient,
    this.border = true,
    this.shadow = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final bool border;
  final bool shadow;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final AppSemanticColors semantic = context.semanticColors;

    final BorderRadius borderRadius = BorderRadius.circular(radius);

    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surface) : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: border
            ? Border.all(color: scheme.outlineVariant.withAlpha(140), width: 1)
            : null,
        boxShadow: shadow ? AppShadows.soft(semantic.cardShadow) : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: scheme.primary.withAlpha(28),
          highlightColor: scheme.primary.withAlpha(14),
          child: content,
        ),
      );
    }

    if (semanticLabel != null) {
      content = Semantics(label: semanticLabel, button: onTap != null, child: content);
    }

    return margin == null
        ? content
        : Padding(padding: margin!, child: content);
  }
}

/// Section header used above every list/rail: title, optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
    this.icon,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionLabel != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

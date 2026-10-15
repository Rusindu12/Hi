import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Primary action button: full-width, 52 px tall, brand gradient-free (flat
/// teal) so it reads as *the* action on the screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.expand = true,
    this.tone = PrimaryTone.primary,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool expand;
  final PrimaryTone tone;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color? background = switch (tone) {
      PrimaryTone.primary => null,
      PrimaryTone.danger => scheme.error,
      PrimaryTone.streak => context.semanticColors.streakFlame,
    };

    final Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (busy)
          const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        else if (icon != null)
          Icon(icon, size: 20),
        if (busy || icon != null) const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );

    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      backgroundColor: background,
      foregroundColor: background == null ? null : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      textStyle: Theme.of(context).textTheme.labelLarge,
    );

    return SizedBox(
      width: expand ? double.infinity : null,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: style,
        child: child,
      ),
    );
  }
}

enum PrimaryTone { primary, danger, streak }

/// Horizontal, scrollable row of selectable chips (subjects, years, mediums).
///
/// Built on [ChoiceChip] rather than a hand-rolled widget so accessibility,
/// focus handling and RTL come for free from the framework.
class ChipRow<T> extends StatelessWidget {
  const ChipRow({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.allLabel,
    this.allValue,
    this.padding = AppSpacing.screen,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onSelected;

  /// When non-null a leading "All" chip is rendered that clears the selection.
  final String? allLabel;
  final T? allValue;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: <Widget>[
          if (allLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(allLabel!),
                selected: selected == allValue,
                onSelected: (bool _) => onSelected(allValue),
                labelStyle: theme.textTheme.labelMedium,
                showCheckmark: false,
              ),
            ),
          ...values.map(
            (T value) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(labelOf(value)),
                selected: selected == value,
                onSelected: (bool _) => onSelected(value),
                labelStyle: theme.textTheme.labelMedium,
                showCheckmark: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Search input styled to match the cards.
///
/// Styling lives here rather than in a global `inputDecorationTheme`, which was
/// renamed to `InputDecorationThemeData` in newer Flutter releases.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.onClear,
  });

  final String hintText;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(130),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(140),
        ),
        suffixIcon: onClear == null
            ? null
            : IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.6),
        ),
      ),
    );
  }
}

/// Labelled row that opens a picker (used by Settings and the planner form).
class AppPickerTile<T> extends StatelessWidget {
  const AppPickerTile({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.onTap,
    this.icon,
    this.helper,
  });

  final String label;
  final String valueLabel;
  final VoidCallback onTap;
  final IconData? icon;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(label, style: theme.textTheme.titleSmall),
                  if (helper != null)
                    Text(helper!, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            Text(
              valueLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withAlpha(120),
            ),
          ],
        ),
      ),
    );
  }
}

/// Switch row with a title and optional explanation.
class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 2,
      ),
      secondary: icon == null
          ? null
          : Icon(icon, size: 20, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.labelSmall),
    );
  }
}

/// Thin label + value row (storage usage, version, timezone).
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface.withAlpha(170),
            ),
          ),
        ],
      ),
    );
  }
}

/// Storage usage: bar plus "128 MB used" caption, with the clear button.
class StorageUsageBar extends StatelessWidget {
  const StorageUsageBar({
    super.key,
    required this.title,
    required this.usedLabel,
    required this.fraction,
    required this.caption,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String usedLabel;
  final double fraction;
  final String caption;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.sd_storage_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(title, style: theme.textTheme.titleSmall),
              ),
              Text(usedLabel, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.chip),
            child: LinearProgressIndicator(value: fraction.clamp(0.0, 1.0)),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(caption, style: theme.textTheme.labelSmall),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular percentage ring for quiz results and badge progress.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    required this.size,
    this.label,
    this.sublabel,
    this.color,
  });

  final int percent;
  final double size;
  final String? label;
  final String? sublabel;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color ring = color ??
        (percent >= 80
            ? context.semanticColors.successFg
            : percent >= 50
                ? theme.colorScheme.primary
                : theme.colorScheme.error);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              strokeWidth: size * 0.09,
              backgroundColor: theme.colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(ring),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label ?? '$percent%',
                style: theme.textTheme.headlineSmall?.copyWith(color: ring),
              ),
              if (sublabel != null)
                Text(
                  sublabel!,
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton placeholder used while the catalogue/quiz loads.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A card-shaped skeleton list, shown while the first catalogue load runs.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) => const AppCard(
        child: Row(
          children: <Widget>[
            SkeletonBox(height: 48, width: 48, radius: 12),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SkeletonBox(height: 14, width: 180),
                  SizedBox(height: AppSpacing.sm),
                  SkeletonBox(height: 10, width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

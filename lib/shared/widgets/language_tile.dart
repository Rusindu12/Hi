import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/l10n_ext.dart';

/// One selectable language: native script name, a Latin subtitle, and the flag
/// that the UI will switch to *that* language immediately.
///
/// Labels are always shown in their own script ("සිංහල", "தமிழ்") rather than
/// translated, because a student who cannot read the current UI language must
/// still be able to find their own.
class LanguageTile extends StatelessWidget {
  const LanguageTile({
    super.key,
    required this.code,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  static const Map<String, String> _nativeNames = <String, String>{
    'en': 'English',
    'si': 'සිංහල',
    'ta': 'தமிழ்',
  };

  static const Map<String, String> _englishNames = <String, String>{
    'en': 'English',
    'si': 'Sinhala',
    'ta': 'Tamil',
  };

  static String nativeName(String code) => _nativeNames[code] ?? code;

  static String englishName(String code) => _englishNames[code] ?? code;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = nativeName(code);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: compact ? AppSpacing.md : AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withAlpha(150)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withAlpha(selected ? 40 : 20),
              ),
              child: Text(
                name.characters.first,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Explicit family so the native script renders even while the
                  // app is still in another language.
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: switch (code) {
                        'si' => 'NotoSansSinhala',
                        'ta' => 'NotoSansTamil',
                        _ => null,
                      },
                    ),
                  ),
                  if (code != 'en')
                    Text(
                      englishName(code),
                      style: theme.textTheme.labelSmall,
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Row of three language pills, used on the onboarding slide and in Settings.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({
    super.key,
    required this.selectedCode,
    required this.onSelected,
  });

  final String selectedCode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.language_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(l10n.chooseLanguageTitle,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final String code in <String>['en', 'si', 'ta'])
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: LanguageTile(
              code: code,
              selected: selectedCode == code,
              onTap: () => onSelected(code),
              compact: true,
            ),
          ),
      ],
    );
  }
}

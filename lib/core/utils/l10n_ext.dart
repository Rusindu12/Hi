import 'package:flutter/widgets.dart';

// Re-exported so any widget that needs the localisation *type* (for a helper
// signature) only has to import this one file.
export '../../l10n/generated/app_localizations.dart';

import '../../l10n/generated/app_localizations.dart';

/// `context.l10n.homeStreak` instead of `AppLocalizations.of(context)!.homeStreak`.
///
/// `l10n.yaml` sets `nullable-getter: false`, so this never returns null.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Active UI language code, e.g. 'en', 'si', 'ta'.
  String get localeCode => Localizations.localeOf(this).languageCode;
}

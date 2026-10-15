import '../../data/models/badge.dart';
import '../../l10n/generated/app_localizations.dart';

/// Maps badge ids to localised copy.
///
/// Kept next to the models rather than inside them so `data/` stays free of
/// Flutter/UI imports, and kept in one place so adding a badge cannot leave a
/// locale missing its label.
String badgeTitle(AppLocalizations l10n, BadgeId id) {
  switch (id) {
    case BadgeId.firstBook:
      return l10n.badgeFirstBook;
    case BadgeId.firstQuiz:
      return l10n.badgeFirstQuiz;
    case BadgeId.streak7:
      return l10n.badgeStreak7;
    case BadgeId.streak30:
      return l10n.badgeStreak30;
    case BadgeId.quizMaster:
      return l10n.badgeQuizMaster;
    case BadgeId.tenDownloads:
      return l10n.badgeTenDownloads;
    case BadgeId.plannerPro:
      return l10n.badgePlanner;
  }
}

String badgeDescription(AppLocalizations l10n, BadgeId id) {
  switch (id) {
    case BadgeId.firstBook:
      return l10n.badgeFirstBookDesc;
    case BadgeId.firstQuiz:
      return l10n.badgeFirstQuizDesc;
    case BadgeId.streak7:
      return l10n.badgeStreak7Desc;
    case BadgeId.streak30:
      return l10n.badgeStreak30Desc;
    case BadgeId.quizMaster:
      return l10n.badgeQuizMasterDesc;
    case BadgeId.tenDownloads:
      return l10n.badgeTenDownloadsDesc;
    case BadgeId.plannerPro:
      return l10n.badgePlannerDesc;
  }
}

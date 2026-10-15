import 'package:flutter/material.dart';

import '../../features/library/presentation/library_page.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/papers/presentation/papers_page.dart';
import '../../features/pdf_reader/presentation/pdf_reader_page.dart';
import '../../features/planner/presentation/planner_page.dart';
import '../../features/quiz/presentation/leaderboard_page.dart';
import '../../features/quiz/presentation/quiz_result_page.dart';
import '../../features/quiz/presentation/quiz_session_page.dart';
import '../../features/quiz/presentation/quiz_setup_page.dart';
import '../../features/settings/presentation/licenses_page.dart';
import '../../features/settings/presentation/official_sources_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shell/presentation/app_shell.dart';
import '../../features/textbooks/presentation/textbook_grades_page.dart';
import '../../features/textbooks/presentation/textbook_subjects_page.dart';
import '../../shared/widgets/not_found_page.dart';
import 'app_routes.dart';

/// Maps route names to pages. One switch, so "which screen is this?" is always
/// answerable by reading a single file.
abstract final class AppRouter {
  const AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.onboarding:
        return _page(const OnboardingPage(), settings);

      case AppRoutes.home:
        return _page(const AppShell(), settings);

      case AppRoutes.textbooks:
        return _page(const TextbookGradesPage(), settings);

      case AppRoutes.textbookSubjects:
        final TextbookSubjectsArgs? args =
            settings.arguments as TextbookSubjectsArgs?;
        return _page(
          TextbookSubjectsPage(
            grade: args?.grade ?? 1,
            mediumCode: args?.mediumCode ?? 'en',
          ),
          settings,
        );

      case AppRoutes.papers:
        final PaperListArgs? args = settings.arguments as PaperListArgs?;
        return _page(PapersPage(initialExamType: args?.examType), settings);

      case AppRoutes.quiz:
        return _page(const QuizSetupPage(), settings);

      case AppRoutes.quizSession:
        return _page(const QuizSessionPage(), settings);

      case AppRoutes.quizResult:
        return _page(const QuizResultPage(), settings);

      case AppRoutes.leaderboard:
        return _page(const LeaderboardPage(), settings);

      case AppRoutes.planner:
        return _page(const PlannerPage(), settings);

      case AppRoutes.library:
        return _page(const LibraryPage(), settings);

      case AppRoutes.settings:
        return _page(const SettingsPage(), settings);

      case AppRoutes.officialSources:
        return _page(const OfficialSourcesPage(), settings);

      case AppRoutes.licenses:
        return _page(const LicensesPage(), settings);

      case AppRoutes.pdfReader:
        final PdfReaderArgs? args = settings.arguments as PdfReaderArgs?;
        if (args == null) {
          return _page(
            const NotFoundPage(debugRoute: AppRoutes.pdfReader),
            settings,
          );
        }
        return _page(
          PdfReaderPage(
            itemId: args.itemId,
            title: args.title,
            subtitle: args.subtitle,
            localPath: args.localPath,
            initialPage: args.initialPage,
            externalUrl: args.externalUrl,
          ),
          settings,
        );

      default:
        return _page(NotFoundPage(debugRoute: settings.name), settings);
    }
  }

  /// Consistent transition for the whole app: right-to-left on Android (the
  /// Material default is a vertical fade, which feels wrong for a document
  /// drill-down like Grade -> Subject -> Book).
  static PageRoute<T> _page<T extends Object?>(Widget child, RouteSettings settings) {
    return MaterialPageRoute<T>(
      builder: (BuildContext context) => child,
      settings: settings,
    );
  }
}

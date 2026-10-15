import 'package:flutter/material.dart';

/// Route names. Using constants (not raw strings at call sites) means a typo is
/// a compile error, and `AppRouter.onGenerateRoute` is the single place that
/// maps a name to a page.
abstract final class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String textbooks = '/textbooks';
  static const String textbookSubjects = '/textbooks/subjects';
  static const String papers = '/papers';
  static const String quiz = '/quiz';
  static const String quizSession = '/quiz/session';
  static const String quizResult = '/quiz/result';
  static const String leaderboard = '/quiz/leaderboard';
  static const String planner = '/planner';
  static const String library = '/library';
  static const String settings = '/settings';
  static const String officialSources = '/settings/sources';
  static const String licenses = '/settings/licenses';
  static const String pdfReader = '/reader';
}

/// Arguments passed between routes. Typed classes prevent the classic
/// `ModalRoute.of(context)!.settings.arguments as Map` crashes.
class TextbookSubjectsArgs {
  const TextbookSubjectsArgs({required this.grade, required this.mediumCode});

  final int grade;
  final String mediumCode;
}

class PaperListArgs {
  const PaperListArgs({this.examType});

  final String? examType;
}

class PdfReaderArgs {
  const PdfReaderArgs({
    required this.itemId,
    required this.title,
    required this.subtitle,
    required this.localPath,
    this.initialPage = 1,
    this.externalUrl,
  });

  final String itemId;
  final String title;
  final String subtitle;

  /// Local file for in-app reading. When null the page shows the
  /// "no offline copy" state with a button to the official source.
  final String? localPath;

  final int initialPage;
  final String? externalUrl;
}

extension RouteBuildContext on BuildContext {
  Future<T?> pushRoute<T extends Object?>(String name, {Object? arguments}) =>
      Navigator.of(this).pushNamed<T>(name, arguments: arguments);

  Future<T?> replaceRoute<T extends Object?>(String name, {Object? arguments}) =>
      Navigator.of(this).pushReplacementNamed<T, Object?>(name, arguments: arguments);
}

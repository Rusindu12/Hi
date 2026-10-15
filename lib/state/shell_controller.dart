import 'package:flutter/foundation.dart';

/// Tracks which bottom-navigation tab is active.
///
/// Hoisted out of `AppShell`'s own State so any screen can *switch tabs* instead
/// of pushing a second copy of a tab route. Without this, tapping "Past papers"
/// on the Home dashboard would push a new PapersPage on top of the shell, and
/// the back button would then walk through duplicates.
class ShellController extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  static const int homeTab = 0;
  static const int booksTab = 1;
  static const int papersTab = 2;
  static const int quizTab = 3;
  static const int libraryTab = 4;

  void go(int next) {
    if (next == _index || next < 0 || next > libraryTab) {
      return;
    }
    _index = next;
    notifyListeners();
  }

  void goHome() => go(homeTab);
}

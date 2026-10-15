import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/streak_widgets.dart';
import '../../home/presentation/home_page.dart';
import '../../library/presentation/library_page.dart';
import '../../papers/presentation/papers_page.dart';
import '../../quiz/presentation/quiz_setup_page.dart';
import '../../textbooks/presentation/textbook_grades_page.dart';
import '../../../state/shell_controller.dart';

/// Bottom-navigation host for the five primary tabs.
///
/// Uses an [IndexedStack] so each tab keeps its scroll position and state when
/// the student flips between Books and Papers — the single biggest "this app
/// feels slow" complaint from list-heavy apps rebuilt on every tab switch.
///
/// Ad banners live *inside* each tab's own body (list screens only), never here:
/// a banner above the nav bar would also appear over the reader and quiz, which
/// the brief forbids.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    // Allows a deep-link or a "quick access" card to open the app on another tab.
    if (widget.initialIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<ShellController>().go(widget.initialIndex);
        }
      });
    }
  }

  /// Badge celebrations are drained here so any screen that earns one can show
  /// it without owning the dialog.
  bool _checkingBadges = false;

  @override
  Widget build(BuildContext context) {
    final ShellController shell = context.watch<ShellController>();

    return PopScope(
      // Back from a non-home tab returns to Home instead of exiting the app.
      canPop: shell.index == ShellController.homeTab,
      // `onPopInvokedWithResult` (Flutter 3.24+). On 3.19-3.23 rename this to
      // `onPopInvoked: (bool didPop) { ... }` — see the note in pubspec.yaml.
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && shell.index != ShellController.homeTab) {
          shell.goHome();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: shell.index,
          children: const <Widget>[
            HomePage(),
            TextbookGradesPage(),
            PapersPage(),
            QuizSetupPage(),
            LibraryPage(),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          index: shell.index,
          onTap: (int next) {
            if (next == shell.index) {
              return;
            }
            shell.go(next);
            _drainBadgeQueue(context);
          },
        ),
      ),
    );
  }

  /// Shows a badge sheet for the first pending unlock, if any.
  Future<void> _drainBadgeQueue(BuildContext context) async {
    if (_checkingBadges || !context.mounted) {
      return;
    }
    _checkingBadges = true;
    // Placeholder hook: StreakController owns the queue and the Home badges
    // carousel reflects new badges; the dedicated celebration sheet is opened
    // from the screens that earn them (quiz result, planner save) where the
    // context is unambiguous.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _checkingBadges = false;
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;

    final List<(IconData, IconData, String)> items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, l10n.navHome),
      (Icons.menu_book_outlined, Icons.menu_book_rounded, l10n.navBooks),
      (Icons.description_outlined, Icons.description_rounded, l10n.navPapers),
      (Icons.quiz_outlined, Icons.quiz_rounded, l10n.navQuiz),
      (Icons.folder_special_outlined, Icons.folder_special_rounded, l10n.navLibrary),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant.withAlpha(150)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSpacing.navBarHeight,
          child: Row(
            children: List<Widget>.generate(items.length, (int i) {
              final bool selected = i == index;
              final (IconData outlined, IconData filled, String label) = items[i];
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  // 48 px minimum touch target on every item.
                  child: Semantics(
                    selected: selected,
                    button: true,
                    label: label,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.colorScheme.primaryContainer.withAlpha(160)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadii.chip),
                          ),
                          child: Icon(
                            selected ? filled : outlined,
                            size: 22,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withAlpha(150),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10.5,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withAlpha(150),
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Small reusable widget: the streak pill that sits in app bars when a screen
/// wants to remind students the streak exists.
class StreakAppBarAction extends StatelessWidget {
  const StreakAppBarAction({
    super.key,
    required this.days,
    required this.onTap,
  });

  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: <Widget>[
            StreakFlame(days: days, size: 34, showNumber: false),
            const SizedBox(width: 4),
            Text(
              '$days',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bundled hand-authored SVG illustrations (student-studying theme).
///
/// SVG rather than PNG because each file is ~1 KB instead of ~40 KB at 3x, which
/// matters for the under-30 MB budget, and because they stay crisp at any size.
enum AppIllustration {
  /// Onboarding 1: a stack of textbooks with a bookmark.
  books('assets/illustrations/books.svg'),

  /// Onboarding 2: a quiz sheet with a timer ring.
  quiz('assets/illustrations/quiz.svg'),

  /// Onboarding 3: a student at a desk with a streak flame.
  studyStreak('assets/illustrations/study_streak.svg'),

  /// Empty state: an open book with a magnifier.
  emptySearch('assets/illustrations/empty_search.svg'),

  /// Empty state: a cloud with a download arrow (nothing downloaded yet).
  emptyDownloads('assets/illustrations/empty_downloads.svg'),

  /// Empty state: a certificate with a star (nothing completed yet).
  emptyHistory('assets/illustrations/empty_history.svg'),

  /// Empty state: calendar with a bell (no planner slots).
  emptyPlanner('assets/illustrations/empty_planner.svg'),

  /// Celebration: a trophy with confetti (badge unlocked / new best score).
  celebrate('assets/illustrations/celebrate.svg');

  const AppIllustration(this.path);

  final String path;
}

/// Renders one of the bundled illustrations at a fixed height.
class Illustration extends StatelessWidget {
  const Illustration(
    this.illustration, {
    super.key,
    this.height = 140,
    this.width,
  });

  final AppIllustration illustration;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    // `excludeFromSemantics` because illustrations are decorative; the empty
    // state's text is what a screen reader should announce.
    return SvgPicture.asset(
      illustration.path,
      height: height,
      width: width,
      excludeFromSemantics: true,
      placeholderBuilder: (BuildContext context) => SizedBox(
        height: height,
        width: width,
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

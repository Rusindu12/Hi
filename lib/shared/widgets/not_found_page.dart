import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../core/utils/l10n_ext.dart';
import 'empty_state.dart';
import 'illustration.dart';

/// Fallback for an unknown route or a route pushed without its arguments.
///
/// Exists so a navigation bug shows a friendly screen with a way home instead of
/// a red error page — which matters for a student-facing app that is often the
/// first "software" a child uses seriously.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key, this.debugRoute});

  final String? debugRoute;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: EmptyState(
        illustration: AppIllustration.emptySearch,
        title: l10n.errNotFound,
        body: l10n.errGeneric,
        actionLabel: l10n.navHome,
        onAction: () => Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (Route<dynamic> route) => false),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';

/// Settings › Open-source licences.
///
/// Shows the bundled `assets/legal/LICENSES.txt` (font + illustration + library
/// attributions) and links to Flutter's own licence registry, which is mandatory
/// for an attribution-complete release.
class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setLicenses)),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(AssetPaths.licences),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || (snapshot.data ?? '').isEmpty) {
            return EmptyState(
              illustration: AppIllustration.emptySearch,
              title: l10n.setLicenses,
              body: l10n.errGeneric,
              compact: true,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              PrimaryButton(
                label: l10n.setLicenses,
                icon: Icons.description_outlined,
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: l10n.appName,
                  applicationVersion: '1.0.0',
                  applicationLegalese: l10n.setAboutBody,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SelectableText(
                snapshot.data!,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          );
        },
      ),
    );
  }
}

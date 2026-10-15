import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../data/models/official_source.dart';
import '../../../services/external_link_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../state/catalogue_controller.dart';

/// Settings › Official sources.
///
/// A transparency screen: it lists every publisher the app links to, with the
/// exact URL, so a parent, teacher or Play reviewer can verify that SriEdu does
/// not re-host copyrighted content. Everything opens in the user's browser.
class OfficialSourcesPage extends StatelessWidget {
  const OfficialSourcesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final CatalogueController catalogue = context.watch<CatalogueController>();
    final List<OfficialSource> sources = catalogue.officialSources;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setOfficialSources)),
      body: sources.isEmpty
          ? EmptyState(
              illustration: AppIllustration.emptySearch,
              title: l10n.setOfficialSources,
              body: l10n.errCatalogue,
              actionLabel: l10n.actionRetry,
              onAction: () => catalogue.load(forceRefresh: true),
              compact: true,
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: <Widget>[
                InfoBanner(
                  message: l10n.setAboutBody,
                  icon: Icons.verified_outlined,
                  tone: InfoTone.success,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...sources.map(
                  (OfficialSource source) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      onTap: () async {
                        final bool opened = await const ExternalLinkService()
                            .open(source.url, analyticsLabel: source.id);
                        if (!opened && context.mounted) {
                          AppSnackbar.error(context, l10n.tbCannotOpen);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  source.displayName(context.localeCode),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded, size: 16),
                            ],
                          ),
                          if (source.displayNote(context.localeCode).isNotEmpty) ...<Widget>[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              source.displayNote(context.localeCode),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            source.url,
                            style: Theme.of(context).textTheme.labelSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

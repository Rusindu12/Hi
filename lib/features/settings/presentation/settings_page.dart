import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/sources/local/hive_store.dart';
import '../../../services/notification_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/language_tile.dart';
import '../../../state/catalogue_controller.dart';
import '../../../state/library_controller.dart';
import '../../../state/planner_controller.dart';
import '../../../state/settings_controller.dart';

/// Screen 8 — Settings.
///
/// Grouped in the order a student actually changes things: language first (the
/// most common reason to open this screen), then how it looks, then reminders,
/// then data, then about.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((PackageInfo info) {
      if (mounted) {
        setState(() => _version = '${info.version}+${info.buildNumber}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SettingsController settings = context.watch<SettingsController>();
    final LibraryController library = context.watch<LibraryController>();
    final CatalogueController catalogue = context.read<CatalogueController>();
    final AppSettings prefs = settings.settings;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.setTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          // --- Language -----------------------------------------------------
          SectionHeader(title: l10n.setLanguage, icon: Icons.language_rounded),
          Padding(
            padding: AppSpacing.screen,
            child: LanguageSelector(
              selectedCode: prefs.localeCode ?? 'en',
              onSelected: (String code) async {
                await settings.setLocale(code);
                if (context.mounted) {
                  AppSnackbar.success(context, l10n.setSaved);
                }
              },
            ),
          ),

          // --- Appearance ---------------------------------------------------
          SectionHeader(
            title: l10n.setAppearance,
            icon: Icons.dark_mode_outlined,
          ),
          Padding(
            padding: AppSpacing.screen,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(l10n.setAppearance, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<ThemeMode>(
                    segments: <ButtonSegment<ThemeMode>>[
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                        label: Text(l10n.setThemeSystem),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded, size: 18),
                        label: Text(l10n.setThemeLight),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded, size: 18),
                        label: Text(l10n.setThemeDark),
                      ),
                    ],
                    selected: <ThemeMode>{prefs.themeMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<ThemeMode> selection) =>
                        settings.setThemeMode(selection.first),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(l10n.setFontSize, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: AppSpacing.sm),
                  SegmentedButton<double>(
                    segments: <ButtonSegment<double>>[
                      ButtonSegment<double>(
                        value: AppSettings.fontScalePresets[0],
                        label: Text(l10n.setFontSmall),
                      ),
                      ButtonSegment<double>(
                        value: AppSettings.fontScalePresets[1],
                        label: Text(l10n.setFontMedium),
                      ),
                      ButtonSegment<double>(
                        value: AppSettings.fontScalePresets[2],
                        label: Text(l10n.setFontLarge),
                      ),
                    ],
                    selected: <double>{
                      AppSettings.fontScalePresets.reduce(
                        (double a, double b) =>
                            (a - prefs.fontScale).abs() <= (b - prefs.fontScale).abs()
                                ? a
                                : b,
                      ),
                    },
                    showSelectedIcon: false,
                    onSelectionChanged: (Set<double> selection) =>
                        settings.setFontScale(selection.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Live preview in the active script, at the chosen scale.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withAlpha(90),
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                    child: Text(
                      l10n.setFontPreview,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Student name -------------------------------------------------
          SectionHeader(title: l10n.setStudentName, icon: Icons.person_outline),
          AppCard(
            margin: AppSpacing.screen,
            padding: EdgeInsets.zero,
            child: AppPickerTile<void>(
              label: l10n.setStudentName,
              helper: l10n.setStudentNameBody,
              valueLabel: prefs.hasName ? prefs.greetingName : l10n.labelOptional,
              icon: Icons.badge_outlined,
              onTap: () => _editName(settings, prefs),
            ),
          ),

          // --- Notifications ------------------------------------------------
          SectionHeader(
            title: l10n.setNotifications,
            icon: Icons.notifications_none_rounded,
          ),
          AppCard(
            margin: AppSpacing.screen,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                AppSwitchTile(
                  title: l10n.setNotifReminders,
                  subtitle: l10n.setNotifRemindersBody,
                  value: prefs.notifyReminders,
                  icon: Icons.event_available_outlined,
                  onChanged: (bool value) async {
                    await settings.setNotifyReminders(value);
                    if (!value) {
                      await NotificationService().cancelAll();
                    } else if (context.mounted) {
                      final bool granted =
                          await context.read<PlannerController>().ensurePermission();
                      if (!granted && context.mounted) {
                        AppSnackbar.info(context, l10n.plPermissionDenied);
                      }
                    }
                  },
                ),
                Divider(
                  height: 1,
                  indent: AppSpacing.lg,
                  endIndent: AppSpacing.lg,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                AppSwitchTile(
                  title: l10n.setNotifNews,
                  subtitle: l10n.setNotifNewsBody,
                  value: prefs.notifyAnnouncements,
                  icon: Icons.campaign_outlined,
                  onChanged: settings.setNotifyAnnouncements,
                ),
              ],
            ),
          ),

          // --- Data ---------------------------------------------------------
          SectionHeader(title: l10n.setData, icon: Icons.sd_storage_outlined),
          AppCard(
            margin: AppSpacing.screen,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                AppInfoRow(
                  label: l10n.libStorage,
                  value: Formatters.bytes(library.storageBytes),
                  icon: Icons.folder_outlined,
                ),
                AppPickerTile<void>(
                  label: l10n.libClearCache,
                  valueLabel: '${library.downloads.length}',
                  icon: Icons.cleaning_services_outlined,
                  onTap: () async {
                    final bool confirmed = await AppDialog.confirm(
                      context,
                      title: l10n.libClearCacheTitle,
                      body: l10n.libClearCacheBody,
                      confirmLabel: l10n.libClearCache,
                      cancelLabel: l10n.actionCancel,
                      destructive: true,
                      icon: Icons.cleaning_services_outlined,
                    );
                    if (!confirmed) {
                      return;
                    }
                    final int freed = await library.clearCache();
                    if (context.mounted) {
                      AppSnackbar.success(
                        context,
                        l10n.libCacheCleared(Formatters.bytes(freed)),
                      );
                    }
                  },
                ),
                AppPickerTile<void>(
                  label: l10n.setClearData,
                  helper: l10n.setClearDataBody,
                  valueLabel: '',
                  icon: Icons.delete_forever_outlined,
                  onTap: () => _eraseData(context, settings),
                ),
              ],
            ),
          ),

          // --- About --------------------------------------------------------
          SectionHeader(title: l10n.setAbout, icon: Icons.info_outline_rounded),
          AppCard(
            margin: AppSpacing.screen,
            padding: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                AppInfoRow(
                  label: l10n.setVersion(''),
                  value: _version.isEmpty ? '—' : _version,
                  icon: Icons.tag_rounded,
                ),
                AppInfoRow(
                  label: l10n.setTimezone,
                  value: DateTime.now().timeZoneName,
                  icon: Icons.schedule_outlined,
                ),
                AppInfoRow(
                  label: l10n.setOfficialSources,
                  value: '${catalogue.officialSources.length}',
                  icon: Icons.verified_outlined,
                ),
                AppPickerTile<void>(
                  label: l10n.setOfficialSources,
                  helper: l10n.setOfficialSourcesBody,
                  valueLabel: '',
                  icon: Icons.link_rounded,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.officialSources),
                ),
                AppPickerTile<void>(
                  label: l10n.setLicenses,
                  valueLabel: '',
                  icon: Icons.description_outlined,
                  onTap: () =>
                      Navigator.of(context).pushNamed(AppRoutes.licenses),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              '${l10n.setAboutBody}\n\n'
              'Firebase: ${AppConfig.useFirebase ? 'on' : 'off'} · '
              'ads: ${AppConfig.adsEnabled ? 'on' : 'off'}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(
    SettingsController settings,
    AppSettings prefs,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController controller =
        TextEditingController(text: prefs.studentName);

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(l10n.setStudentName),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: l10n.setNameHint),
          onSubmitted: (String value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );

    if (result == null) {
      return;
    }
    await settings.setStudentName(result);
    if (mounted) {
      AppSnackbar.success(context, l10n.setSaved);
    }
  }

  Future<void> _eraseData(
    BuildContext context,
    SettingsController settings,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await AppDialog.confirm(
      context,
      title: l10n.setClearData,
      body: l10n.setClearDataBody,
      confirmLabel: l10n.setClearDataConfirm,
      cancelLabel: l10n.actionCancel,
      destructive: true,
      icon: Icons.warning_amber_rounded,
    );
    if (!confirmed) {
      return;
    }
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final HiveStore store = context.read<HiveStore>();
    await settings.eraseAllData(
      notifications: NotificationService(),
      onErase: () async {
        // Deletes cached files first (needs the download records), then every
        // Hive box: favourites, streak, badges, quiz results, planner, settings.
        await context.read<LibraryController>().clearCache();
        await store.clearAll();
      },
    );

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.setDataCleared)));
    navigator.popUntil((Route<dynamic> route) => route.isFirst);
  }
}

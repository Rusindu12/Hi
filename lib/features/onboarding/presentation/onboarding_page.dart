import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../services/analytics_service.dart';
import '../../../shared/widgets/app_controls.dart';
import '../../../shared/widgets/illustration.dart';
import '../../../shared/widgets/language_tile.dart';
import '../../../state/settings_controller.dart';

/// Screen 1 — Onboarding.
///
/// Three skippable slides. Language selection is *inside* slide one (not a
/// blocking pre-screen), because a student who cannot read the default language
/// should reach the picker in a single tap and see the whole UI switch
/// instantly — no restart, no "apply" button.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= 2) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    final SettingsController settings = context.read<SettingsController>();
    await settings.completeOnboarding();
    await AnalyticsService.instance.logEvent(
      AnalyticsEvents.onboardingComplete,
      parameters: <String, Object?>{
        'language': settings.settings.localeCode ?? 'system',
      },
    );
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final List<_Slide> slides = <_Slide>[
      _Slide(
        illustration: AppIllustration.books,
        title: l10n.onboardTitle1,
        body: l10n.onboardBody1,
      ),
      _Slide(
        illustration: AppIllustration.quiz,
        title: l10n.onboardTitle2,
        body: l10n.onboardBody2,
      ),
      _Slide(
        illustration: AppIllustration.studyStreak,
        title: l10n.onboardTitle3,
        body: l10n.onboardBody3,
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Skip is always visible: never trap a returning student in setup.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(l10n.actionSkip),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (int index) => setState(() => _page = index),
                itemBuilder: (BuildContext context, int index) => _SlideView(
                  slide: slides[index],
                  showLanguagePicker: index == 0,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                children: <Widget>[
                  _Dots(count: slides.length, active: _page),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    label: _page == slides.length - 1
                        ? l10n.onboardGetStarted
                        : l10n.actionNext,
                    icon: _page == slides.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.appTagline,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final AppIllustration illustration;
  final String title;
  final String body;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide, required this.showLanguagePicker});

  final _Slide slide;
  final bool showLanguagePicker;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SettingsController settings = context.watch<SettingsController>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: <Widget>[
          const SizedBox(height: AppSpacing.lg),
          Illustration(slide.illustration, height: 176),
          const SizedBox(height: AppSpacing.xl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(180),
            ),
          ),
          if (showLanguagePicker) ...<Widget>[
            const SizedBox(height: AppSpacing.xl),
            LanguageSelector(
              selectedCode: settings.settings.localeCode ?? 'en',
              onSelected: (String code) async {
                await settings.setLocale(code, markOnboarded: false);
                await AnalyticsService.instance.logEvent(
                  AnalyticsEvents.languageChanged,
                  parameters: <String, Object?>{'language': code, 'from': 'onboarding'},
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.l10n.chooseLanguageSubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(count, (int i) {
        final bool selected = i == active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: selected ? 22 : 8,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.outlineVariant,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
        );
      }),
    );
  }
}

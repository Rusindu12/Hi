import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/theme/app_colors.dart';
import '../../services/ad_service.dart';

/// The **only** way to render an ad banner in this app.
///
/// It takes a `featureId` and refuses to render inside an ad-free feature (the
/// PDF reader, quiz and onboarding), throwing a loud [FlutterError] in debug so
/// a mistake is caught the first time it runs rather than shipping. A unit test
/// also greps those folders for ad imports, so CI fails before a build does.
///
/// Usage:
/// ```dart
/// const AdBanner(featureId: AppAdPolicy.featurePapers)
/// ```
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    required this.featureId,
    this.margin = const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.sm,
    ),
  });

  final String featureId;
  final EdgeInsetsGeometry margin;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    assert(
      AppAdPolicy.allowsBanner(widget.featureId),
      'AdBanner was placed in "${widget.featureId}", which is ad-free. '
      'Banners are only allowed in: ${AppAdPolicy.bannerAllowedFeatures.join(', ')}. '
      'See docs/ADS_POLICY.md.',
    );
    if (!AppAdPolicy.allowsBanner(widget.featureId)) {
      // Release builds must not crash: silently render nothing instead.
      return;
    }
    _load();
  }

  void _load() {
    final BannerAd? ad = AdService.instance.createBanner(
      featureId: widget.featureId,
      onLoaded: () {
        if (mounted) {
          setState(() => _loaded = true);
        }
      },
      onFailed: (LoadAdError error) {
        if (mounted) {
          setState(() {
            _loaded = false;
            _ad = null;
          });
        }
      },
    );
    if (ad == null) {
      return;
    }
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    // No ad slot reserved when nothing is loaded: an empty grey box looks broken,
    // and collapsing is the AdMob-recommended behaviour before fill.
    if (ad == null || !_loaded) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.margin,
      child: SizedBox(
        height: ad.size.height.toDouble(),
        width: ad.size.width.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}

/// Convenience flag for tests and golden checks.
bool get adsRenderInDebug => kDebugMode;

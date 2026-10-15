import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'analytics_service.dart';

/// Opens content on its official publisher site.
///
/// This is the core of the content policy: for copyrighted textbooks and papers
/// SriEdu never re-hosts or proxies a file — it hands the canonical URL to the
/// user's browser (or the site's own app), where the publisher's own terms,
/// counters and cookies apply.
class ExternalLinkService {
  const ExternalLinkService();

  static const Set<String> _allowedSchemes = <String>{'http', 'https'};

  /// Validates a URL without opening it. Used by the catalogue validator script
  /// and by the UI to grey out broken entries.
  static bool isOpenable(String url) {
    final Uri? uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return false;
    }
    return _allowedSchemes.contains(uri.scheme.toLowerCase());
  }

  /// Opens [url]. Returns false when the URL is malformed, uses a non-web scheme,
  /// or no browser is available — the caller shows a localised error instead of
  /// crashing.
  Future<bool> open(
    String url, {
    String? analyticsLabel,
    String? itemId,
  }) async {
    if (!isOpenable(url)) {
      debugPrint('[links] refused to open malformed url: $url');
      return false;
    }
    final Uri uri = Uri.parse(url.trim());
    try {
      final bool canOpen = await canLaunchUrl(uri);
      if (!canOpen) {
        debugPrint('[links] no handler for $uri');
        return false;
      }
      final bool opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) {
        AnalyticsService.instance.logEvent(
          AnalyticsEvents.externalSourceOpened,
          parameters: <String, Object?>{
            'host': uri.host,
            if (analyticsLabel != null) 'label': analyticsLabel,
            if (itemId != null) 'item_id': itemId,
          },
        );
      }
      return opened;
    } on Object catch (error) {
      debugPrint('[links] failed to open $uri: $error');
      return false;
    }
  }

  /// Opens the app's own listing on the Play Store (used by "rate the app").
  Future<bool> openPlayStoreListing(String packageId) => open(
        'https://play.google.com/store/apps/details?id=$packageId',
      );
}

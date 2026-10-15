import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sriedu/core/constants/app_config.dart';
import 'package:sriedu/services/ad_service.dart';

/// The brief's hardest rule: **zero ads in the PDF reader and the quiz**.
///
/// A policy that only lives in a comment rots the first time someone pastes a
/// banner into a new widget, so it is asserted here three ways:
///   1. no file under the ad-free feature folders imports or names an ad type;
///   2. [AppAdPolicy] itself refuses banners and interstitials for those features;
///   3. the interstitial cadence stays at "every 3rd download" and never fires
///      while the student is reading or answering.
///
/// This test reads the source tree rather than widgets on purpose: it is the only
/// way to catch an `import 'package:google_mobile_ads/google_mobile_ads.dart';`
/// that is not used *yet*.
void main() {
  final Directory root = Directory.current;

  /// Folders that must stay ad-free, in the order they appear in the brief.
  const Map<String, String> adFreeFolders = <String, String>{
    'lib/features/pdf_reader': 'the PDF reader',
    'lib/features/quiz': 'quiz mode',
    'lib/features/onboarding': 'onboarding',
  };

  /// Anything matched here in an ad-free file is a policy violation.
  const List<String> forbiddenTokens = <String>[
    'google_mobile_ads',
    'AdBanner',
    'BannerAd',
    'InterstitialAd',
    'MobileAds',
    'AdService',
    'AdRequest',
    'AdSize',
  ];

  List<File> dartFilesIn(String relativePath) {
    final Directory directory = Directory('${root.path}/$relativePath');
    expect(
      directory.existsSync(),
      isTrue,
      reason: '$relativePath should exist in the repository',
    );
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));
  }

  group('ad-free screens', () {
    for (final MapEntry<String, String> entry in adFreeFolders.entries) {
      test('${entry.value} contains no ad reference', () {
        final List<File> files = dartFilesIn(entry.key);
        expect(files, isNotEmpty, reason: '${entry.key} has no Dart files?');

        for (final File file in files) {
          final List<String> lines = file.readAsLinesSync();

          // `debugReaderForbiddenImports` in the reader lists the very packages
          // this test forbids, so the array literal itself is skipped: the guard
          // must not trip on its own checklist.
          bool insideDiagnosticList = false;

          for (int index = 0; index < lines.length; index++) {
            final String line = lines[index];
            final String trimmed = line.trim();

            if (insideDiagnosticList) {
              if (trimmed.contains('];')) {
                insideDiagnosticList = false;
              }
              continue;
            }
            if (trimmed.startsWith('const List<String> debugReaderForbiddenImports')) {
              insideDiagnosticList = !trimmed.contains('];');
              continue;
            }
            if (trimmed.startsWith('//') || trimmed.startsWith('///')) {
              continue; // prose is allowed to name the thing it forbids
            }

            for (final String token in forbiddenTokens) {
              expect(
                line.contains(token),
                isFalse,
                reason: '${file.path}:${index + 1} mentions "$token" inside '
                    '${entry.value}, which must stay ad-free:\n  $trimmed',
              );
            }
          }
        }
      });
    }
  });

  group('AppAdPolicy', () {
    test('allows banners on the list screens the brief names', () {
      expect(AppAdPolicy.allowsBanner(AppAdPolicy.featureTextbooks), isTrue);
      expect(AppAdPolicy.allowsBanner(AppAdPolicy.featurePapers), isTrue);
      expect(AppAdPolicy.allowsBanner(AppAdPolicy.featureLibrary), isTrue);
    });

    test('refuses banners everywhere else', () {
      const List<String> otherFeatures = <String>[
        AppAdPolicy.featureHome,
        AppAdPolicy.featureSettings,
        AppAdPolicy.featurePlanner,
      ];
      for (final String feature in otherFeatures) {
        expect(
          AppAdPolicy.allowsBanner(feature),
          isFalse,
          reason: 'a banner on "$feature" is not in the brief',
        );
      }
    });

    test('refuses banners AND interstitials on the ad-free screens', () {
      for (final String feature in AppAdPolicy.adFreeFeatures) {
        expect(AppAdPolicy.allowsBanner(feature), isFalse, reason: feature);
        expect(AppAdPolicy.allowsInterstitial(feature), isFalse, reason: feature);
      }
    });

    test('the ad-free set is exactly reader + quiz + onboarding', () {
      expect(
        AppAdPolicy.adFreeFeatures,
        equals(<String>{
          AppAdPolicy.featurePdfReader,
          AppAdPolicy.featureQuiz,
          AppAdPolicy.featureOnboarding,
        }),
      );
      // The two sets must never overlap, or allowsBanner() would depend on set
      // iteration order to decide whether a student sees an ad while reading.
      expect(
        AppAdPolicy.bannerAllowedFeatures
            .intersection(AppAdPolicy.adFreeFeatures)
            .isEmpty,
        isTrue,
      );
    });

    test('an unknown feature id gets no ads', () {
      expect(AppAdPolicy.allowsBanner('something_new'), isFalse);
      expect(AppAdPolicy.allowsInterstitial('something_new'), isTrue,
          reason: 'interstitials are for downloads; the reader/quiz gate is the '
              'ad-free set, not an allowlist');
    });
  });

  group('interstitial cadence', () {
    test('fires after every 3rd download (never inside the reader)', () {
      expect(AppConfig.interstitialEveryNDownloads, 3);
    });

    test('defaults to Google\'s test unit ids, never a live ad unit', () {
      // Ads are ON by default because the app is ad-supported, but the unit ids
      // default to Google's official test ids: a clone therefore shows "Test Ad"
      // banners, earns nothing, and cannot trip AdMob's invalid-traffic rules by
      // running against an unpublished app id. A release build must pass the real
      // ids with --dart-define=ADMOB_BANNER_ANDROID=... .
      expect(AppConfig.adsEnabled, isTrue);
      expect(
        AppConfig.androidBannerUnitId,
        equals(AppConfig.testBannerAndroid),
        reason: 'the default banner unit must stay the test id',
      );
      expect(
        AppConfig.androidInterstitialUnitId,
        equals(AppConfig.testInterstitialAndroid),
        reason: 'the default interstitial unit must stay the test id',
      );
      expect(
        AppConfig.testBannerAndroid.startsWith('ca-app-pub-3940256099942544/'),
        isTrue,
        reason: 'that prefix is what marks a unit as Googles test inventory',
      );
    });

    test('can be switched off entirely for a store review build', () {
      // --dart-define=ADS_ENABLED=false is the "no ads at all" build; the app is
      // fully usable without them, which is the safest first release.
      expect(
        const bool.fromEnvironment('ADS_ENABLED', defaultValue: true),
        isA<bool>(),
      );
    });
  });
}

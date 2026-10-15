import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the three-language promise: Sinhala, Tamil and English must stay in
/// lockstep. `flutter gen-l10n` fails the build on a missing key, but it happily
/// accepts a translated file that *lost* a placeholder — which is how you ship a
/// Sinhala "Day {count} of your streak" that prints a literal `{count}`.
void main() {
  final Directory root = Directory.current;

  /// Keys whose value is deliberately identical in every language: the brand
  /// name, and strings made only of placeholders/punctuation.
  const Set<String> identicalByDesign = <String>{
    'appName',
    'greetingWithName',
    'quizScoreValue',
  };

  Map<String, String> messages(String locale) {
    final File file = File('${root.path}/lib/l10n/app_$locale.arb');
    expect(file.existsSync(), isTrue, reason: 'app_$locale.arb is missing');
    final Map<String, dynamic> raw =
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return <String, String>{
      for (final MapEntry<String, dynamic> entry in raw.entries)
        if (!entry.key.startsWith('@')) entry.key: entry.value.toString(),
    };
  }

  /// `{count, plural, =1{…} other{…}}` yields `{count}` — the plural branches are
  /// not placeholders, so only names followed by `,` or `}` count.
  Set<String> placeholders(String message) => RegExp(r'\{([A-Za-z_]\w*)\s*[,}]')
      .allMatches(message)
      .map((RegExpMatch match) => match.group(1)!)
      .toSet();

  late Map<String, String> en;
  late Map<String, String> si;
  late Map<String, String> ta;

  setUpAll(() {
    en = messages('en');
    si = messages('si');
    ta = messages('ta');
  });

  group('translation parity', () {
    test('the three locales define exactly the same keys', () {
      expect(en.keys.toSet(), equals(si.keys.toSet()));
      expect(en.keys.toSet(), equals(ta.keys.toSet()));
      expect(en, isNotEmpty);
    });

    test('every placeholder survives translation', () {
      for (final String key in en.keys) {
        final Set<String> expected = placeholders(en[key]!);
        expect(placeholders(si[key]!), equals(expected),
            reason: 'si[$key] lost or renamed a placeholder');
        expect(placeholders(ta[key]!), equals(expected),
            reason: 'ta[$key] lost or renamed a placeholder');
      }
    });

    test('no message is empty or left as a key name', () {
      for (final Map<String, String> locale in <Map<String, String>>[en, si, ta]) {
        for (final MapEntry<String, String> entry in locale.entries) {
          expect(entry.value.trim(), isNotEmpty, reason: entry.key);
          // A value identical to its own key usually means a forgotten paste.
          expect(entry.value, isNot(equals(entry.key)), reason: entry.key);
        }
      }
    });

    test('Sinhala and Tamil are actually translated', () {
      final List<String> untranslatedSi = <String>[
        for (final String key in en.keys)
          if (si[key] == en[key] && !identicalByDesign.contains(key)) key,
      ];
      final List<String> untranslatedTa = <String>[
        for (final String key in en.keys)
          if (ta[key] == en[key] && !identicalByDesign.contains(key)) key,
      ];
      expect(untranslatedSi, isEmpty,
          reason: 'these Sinhala strings are still English: $untranslatedSi');
      expect(untranslatedTa, isEmpty,
          reason: 'these Tamil strings are still English: $untranslatedTa');
    });

    test('Sinhala and Tamil are not copies of each other', () {
      final List<String> suspicious = <String>[
        for (final String key in en.keys)
          if (si[key] == ta[key] && en[key] != si[key]) key,
      ];
      expect(suspicious, isEmpty,
          reason: 'these keys are identical in si and ta: $suspicious');
    });

    test('Sinhala and Tamil use their own scripts', () {
      // Sinhala block U+0D80-U+0DFF, Tamil block U+0B80-U+0BFF.
      bool hasCharIn(String value, int start, int end) => value.runes.any(
          (int rune) => rune >= start && rune <= end);

      final Iterable<MapEntry<String, String>> sinhalaCopy = si.entries.where(
          (MapEntry<String, String> entry) => entry.value.length > 8);
      final Iterable<MapEntry<String, String>> tamilCopy = ta.entries.where(
          (MapEntry<String, String> entry) => entry.value.length > 8);

      for (final MapEntry<String, String> entry in sinhalaCopy) {
        expect(hasCharIn(entry.value, 0x0D80, 0x0DFF), isTrue,
            reason: 'si[${entry.key}] has no Sinhala characters: ${entry.value}');
      }
      for (final MapEntry<String, String> entry in tamilCopy) {
        expect(hasCharIn(entry.value, 0x0B80, 0x0BFF), isTrue,
            reason: 'ta[${entry.key}] has no Tamil characters: ${entry.value}');
      }
    });
  });

  group('l10n.yaml', () {
    test('is configured for a checked-in-later generated directory', () {
      final File config = File('${root.path}/l10n.yaml');
      expect(config.existsSync(), isTrue);
      final String text = config.readAsStringSync();
      expect(text.contains('app_en.arb'), isTrue,
          reason: 'the template locale must be app_en.arb');
      expect(text.contains('lib/l10n/generated'), isTrue,
          reason: 'generated localisations must not be hand-edited');
    });
  });
}

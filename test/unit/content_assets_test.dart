import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates the bundled content assets the same way `tools/verify_project.py`
/// does, but from inside `flutter test` so a broken catalogue fails CI even if
/// nobody runs the Python scripts.
///
/// These assets ship inside the APK: if `catalogue.json` gains a duplicate id or
/// a subject code that does not exist, the Textbooks and Papers screens silently
/// lose rows and no compiler complains.
void main() {
  final Directory root = Directory.current;

  Map<String, dynamic> readJson(String relativePath) {
    final File file = File('${root.path}/$relativePath');
    expect(file.existsSync(), isTrue, reason: '$relativePath is missing');
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  }

  group('subjects.json', () {
    late Map<String, dynamic> payload;

    setUpAll(() => payload = readJson('assets/data/subjects.json'));

    test('every subject has a code, a name and a grade range', () {
      final List<dynamic> subjects = payload['subjects'] as List<dynamic>;
      expect(subjects.length, greaterThanOrEqualTo(20));

      final Set<String> codes = <String>{};
      for (final dynamic entry in subjects) {
        final Map<String, dynamic> subject = entry as Map<String, dynamic>;
        final String code = subject['code'] as String;
        expect(code, isNotEmpty);
        expect(codes.add(code), isTrue, reason: 'duplicate subject code $code');

        final Map<String, dynamic> names =
            subject['names'] as Map<String, dynamic>;
        for (final String locale in <String>['en', 'si', 'ta']) {
          expect(
            (names[locale] as String?)?.isNotEmpty,
            isTrue,
            reason: '$code is missing names.$locale',
          );
        }
        expect(subject['grades'], isA<List<dynamic>>());
      }
    });
  });

  group('catalogue.json', () {
    late List<dynamic> items;
    late Set<String> subjectCodes;
    late Set<String> officialHosts;

    setUpAll(() {
      items = readJson('assets/data/catalogue.json')['items'] as List<dynamic>;
      subjectCodes = (readJson('assets/data/subjects.json')['subjects']
              as List<dynamic>)
          .map((dynamic entry) =>
              (entry as Map<String, dynamic>)['code'] as String)
          .toSet();
      officialHosts = (readJson('assets/data/official_sources.json')['sources']
              as List<dynamic>)
          .expand((dynamic entry) =>
              ((entry as Map<String, dynamic>)['hosts'] as List<dynamic>)
                  .map((dynamic host) => host.toString().toLowerCase()))
          .toSet();
    });

    test('is big enough to feel like a real catalogue', () {
      expect(items.length, greaterThanOrEqualTo(500));
    });

    test('ids are unique and every reference resolves', () {
      final Set<String> ids = <String>{};
      for (final dynamic entry in items) {
        final Map<String, dynamic> item = entry as Map<String, dynamic>;
        final String id = item['id'] as String;
        expect(ids.add(id), isTrue, reason: 'duplicate catalogue id $id');
      }

      for (final dynamic entry in items) {
        final Map<String, dynamic> item = entry as Map<String, dynamic>;
        final String? scheme = item['markingSchemeId'] as String?;
        if (scheme != null) {
          expect(
            ids.contains(scheme),
            isTrue,
            reason: '${item['id']} points at a marking scheme that does not exist',
          );
        }
      }
    });

    test('every item is internally consistent', () {
      const Set<String> rights = <String>{
        'official_link',
        'open_license',
        'bundled',
      };
      const Set<String> kinds = <String>{
        'textbook',
        'paper',
        'term_test',
        'marking_scheme',
        'syllabus',
        'sample',
      };
      const Set<String> mediums = <String>{'en', 'si', 'ta'};

      for (final dynamic entry in items) {
        final Map<String, dynamic> item = entry as Map<String, dynamic>;
        final String id = item['id'] as String;

        expect(subjectCodes.contains(item['subject']), isTrue,
            reason: '$id has an unknown subject ${item['subject']}');
        expect(rights.contains(item['rights']), isTrue,
            reason: '$id has an unknown rights value ${item['rights']}');
        expect(kinds.contains(item['kind']), isTrue,
            reason: '$id has an unknown kind ${item['kind']}');
        expect(mediums.contains(item['medium']), isTrue,
            reason: '$id has an unknown medium ${item['medium']}');
        expect(item['fileSizeBytes'], greaterThan(0));
        expect(item['pageCount'], greaterThan(0));
        expect(item['downloadCount'], greaterThanOrEqualTo(0));
      }
    });

    test('official links stay on the declared official hosts', () {
      for (final dynamic entry in items) {
        final Map<String, dynamic> item = entry as Map<String, dynamic>;
        if (item['rights'] != 'official_link') {
          continue;
        }
        final String url = item['sourceUrl'] as String;
        expect(url.startsWith('https://'), isTrue, reason: '${item['id']} is not https');
        final String host =
            url.split('//').last.split('/').first.toLowerCase();
        expect(
          officialHosts.contains(host),
          isTrue,
          reason: '${item['id']} links to $host, which is not one of the official '
              'sources listed in Settings',
        );
      }
    });

    test('only the sample book is bundled, and it has a real asset path', () {
      final List<Map<String, dynamic>> bundled = items
          .cast<Map<String, dynamic>>()
          .where((Map<String, dynamic> item) => item['rights'] == 'bundled')
          .toList();

      expect(bundled.length, 1);
      final String storagePath = bundled.single['storagePath'] as String;
      expect(storagePath, startsWith('asset:'));
      final String assetPath = storagePath.substring('asset:'.length);
      expect(
        File('${root.path}/$assetPath').existsSync(),
        isTrue,
        reason: '$assetPath is referenced by the catalogue but not on disk',
      );
    });
  });

  group('sample_questions.json', () {
    late List<dynamic> banks;

    setUpAll(() {
      banks = readJson('assets/data/sample_questions.json')['banks'] as List<dynamic>;
    });

    test('bank keys follow subject_examType[_year]', () {
      final Set<String> keys = <String>{};
      for (final dynamic entry in banks) {
        final Map<String, dynamic> bank = entry as Map<String, dynamic>;
        final String expected = <String>[
          bank['subject'] as String,
          bank['examType'] as String,
          if (bank['year'] != null) '${bank['year']}',
        ].join('_');
        expect(bank['key'], equals(expected));
        expect(keys.add(expected), isTrue, reason: 'duplicate bank key $expected');
      }
    });

    test('a question never leaves its option range, and ids are unique', () {
      final Set<String> questionIds = <String>{};
      for (final dynamic entry in banks) {
        final Map<String, dynamic> bank = entry as Map<String, dynamic>;
        expect(bank['questions'], isNotEmpty);
        for (final dynamic raw in bank['questions'] as List<dynamic>) {
          final Map<String, dynamic> question = raw as Map<String, dynamic>;
          final String id = question['id'] as String;
          expect(questionIds.add(id), isTrue, reason: 'duplicate question id $id');

          final int correct = question['correctAnswer'] as int;
          final List<dynamic> options = question['options'] as List<dynamic>;
          expect(options.length, 4, reason: '$id should offer A-D');
          expect(correct, inInclusiveRange(0, options.length - 1));
          expect((question['explanation'] as Map<String, dynamic>)['en'], isNotEmpty);
        }
      }
    });

    test('medium matches the languages the questions actually carry', () {
      for (final dynamic entry in banks) {
        final Map<String, dynamic> bank = entry as Map<String, dynamic>;
        final String medium = bank['medium'] as String;
        for (final dynamic raw in bank['questions'] as List<dynamic>) {
          final Map<String, dynamic> question = raw as Map<String, dynamic>;
          final Map<String, dynamic> text =
              question['questionText'] as Map<String, dynamic>;
          if (medium == 'si' || medium == 'ta') {
            expect(
              text.containsKey(medium),
              isTrue,
              reason: '${question['id']} is in a $medium bank but has no $medium text',
            );
          }
          if (medium == 'en') {
            expect(text['en'], isNotEmpty);
          }
        }
      }
    });
  });

  group('official_sources.json', () {
    test('every source has a name and a note in all three languages', () {
      final List<dynamic> sources =
          readJson('assets/data/official_sources.json')['sources'] as List<dynamic>;
      expect(sources, isNotEmpty);

      for (final dynamic entry in sources) {
        final Map<String, dynamic> source = entry as Map<String, dynamic>;
        expect((source['url'] as String).startsWith('https://'), isTrue);
        for (final String locale in <String>['en', 'si', 'ta']) {
          expect(
            ((source['names'] as Map<String, dynamic>)[locale] as String?)
                ?.isNotEmpty,
            isTrue,
            reason: '${source['id']} has no name in $locale',
          );
          expect(
            ((source['note'] as Map<String, dynamic>)[locale] as String?)
                ?.isNotEmpty,
            isTrue,
            reason: '${source['id']} has no note in $locale',
          );
        }
      }
    });
  });

  group('bundled fonts', () {
    test('Sinhala and Tamil fonts are real TrueType files', () {
      for (final String path in <String>[
        'assets/fonts/NotoSansSinhala-Variable.ttf',
        'assets/fonts/NotoSansTamil-Variable.ttf',
      ]) {
        final File font = File('${root.path}/$path');
        expect(font.existsSync(), isTrue, reason: '$path is missing');

        final List<int> header = font.openSync().readSync(4).toList();
        final bool isTrueType = header[0] == 0x00 &&
            header[1] == 0x01 &&
            header[2] == 0x00 &&
            header[3] == 0x00;
        expect(isTrueType, isTrue, reason: '$path is not a TrueType font');
      }
    });

    test('the OFL licence text ships next to the fonts', () {
      final Directory fonts = Directory('${root.path}/assets/fonts');
      final bool hasOfl = fonts
          .listSync()
          .whereType<File>()
          .any((File file) => file.path.contains('OFL'));
      expect(hasOfl, isTrue, reason: 'the SIL OFL text must ship with the fonts');
    });
  });
}

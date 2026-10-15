/// Static identifiers and enums used across the data layer.
///
/// These are *codes*, never display strings. Every user-visible label is
/// resolved through `AppLocalizations` (see core/utils/locale_utils.dart).
library;

/// Grade levels offered by the Sri Lankan school system through to A/L.
abstract final class GradeLevels {
  const GradeLevels._();

  static const int min = 1;
  static const int max = 13;

  /// Grade 5 is the scholarship exam year, 11 is O/L, 13 is A/L.
  static const int scholarship = 5;
  static const int ordinaryLevel = 11;
  static const int advancedLevel = 13;

  static List<int> all() =>
      List<int>.generate(max - min + 1, (int i) => min + i);
}

/// Exam categories used by the Past Papers section and quiz metadata.
abstract final class ExamTypes {
  const ExamTypes._();

  static const String ol = 'ol';
  static const String al = 'al';
  static const String grade5 = 'grade5';
  static const String term = 'term';
  static const String textbook = 'textbook';

  static const List<String> values = <String>[ol, al, grade5, term];
}

/// Medium of instruction. Codes intentionally match ISO language codes so the
/// same value can drive both content filtering and UI localisation.
abstract final class Mediums {
  const Mediums._();

  static const String english = 'en';
  static const String sinhala = 'si';
  static const String tamil = 'ta';

  static const List<String> values = <String>[english, sinhala, tamil];

  static bool isSupported(String code) => values.contains(code);
}

/// Subject codes. Keys map to the `subjects` table in
/// `assets/data/subjects.json` and to the Firestore `subjects` collection.
abstract final class SubjectCodes {
  const SubjectCodes._();

  static const String mathematics = 'mathematics';
  static const String science = 'science';
  static const String sinhala = 'sinhala';
  static const String tamil = 'tamil';
  static const String english = 'english';
  static const String environment = 'environment';
  static const String history = 'history';
  static const String geography = 'geography';
  static const String ict = 'ict';
  static const String businessStudies = 'business_studies';
  static const String accounting = 'accounting';
  static const String economics = 'economics';
  static const String biology = 'biology';
  static const String chemistry = 'chemistry';
  static const String physics = 'physics';
  static const String agriculture = 'agriculture';
  static const String health = 'health';
  static const String religion = 'religion';
  static const String civic = 'civic';
  static const String arts = 'arts';
}

/// Content source classification, used for legal-safety decisions.
abstract final class ContentRights {
  const ContentRights._();

  /// Published by a government body and opens on their official site.
  static const String officialLink = 'official_link';

  /// Public domain / openly licensed: safe to mirror and cache offline.
  static const String openLicense = 'open_license';

  /// Bundled with the app (for example the generated sample textbook).
  static const String bundled = 'bundled';
}

/// Local storage / asset locations.
abstract final class AssetPaths {
  const AssetPaths._();

  static const String seedDirectory = 'assets/data';
  static const String catalogue = 'assets/data/catalogue.json';
  static const String subjects = 'assets/data/subjects.json';
  static const String officialSources = 'assets/data/official_sources.json';
  static const String sampleQuestions = 'assets/data/sample_questions.json';
  static const String sampleTextbook = 'assets/data/sample_textbook.pdf';
  static const String licences = 'assets/legal/LICENSES.txt';
}

import 'package:flutter/foundation.dart';

import 'localized_text.dart';

/// A school subject, e.g. Mathematics, Science, ICT.
///
/// Subject *names* are content, so they come from JSON/Firestore rather than
/// ARB. [codes] are what the catalogue, quizzes and planner store.
@immutable
class Subject {
  const Subject({
    required this.code,
    required this.names,
    this.grades = const <int>[],
    this.mediums = const <String>['en', 'si', 'ta'],
    this.iconKey,
    this.isExamSubject = false,
    this.sortOrder = 100,
  });

  factory Subject.fromJson(Map<String, Object?> json) {
    return Subject(
      code: (json['code'] ?? '').toString(),
      names: LocalizedText.fromJson(json['names'] ?? json['name']),
      grades: _intList(json['grades']),
      mediums: _stringList(json['mediums'], fallback: const <String>['en', 'si', 'ta']),
      iconKey: json['icon']?.toString(),
      isExamSubject: json['isExamSubject'] == true,
      sortOrder: _int(json['sortOrder'], 100),
    );
  }

  final String code;
  final LocalizedText names;

  /// Grade levels this subject is taught in. Empty means "all grades".
  final List<int> grades;

  /// Mediums in which this subject is published.
  final List<String> mediums;

  /// Key into the app's icon map (see shared/widgets/subject_icon.dart).
  final String? iconKey;

  /// True for subjects that appear in O/L or A/L exams.
  final bool isExamSubject;

  final int sortOrder;

  /// Display name for the active UI language, falling back through English.
  String displayName(String localeCode) => names.resolve(localeCode);

  bool teachesGrade(int grade) => grades.isEmpty || grades.contains(grade);

  bool availableInMedium(String medium) =>
      mediums.isEmpty || mediums.contains(medium);

  Map<String, Object?> toJson() => <String, Object?>{
        'code': code,
        'names': names.toJson(),
        'grades': grades,
        'mediums': mediums,
        if (iconKey != null) 'icon': iconKey,
        'isExamSubject': isExamSubject,
        'sortOrder': sortOrder,
      };

  Subject copyWith({
    String? code,
    LocalizedText? names,
    List<int>? grades,
    List<String>? mediums,
    String? iconKey,
    bool? isExamSubject,
    int? sortOrder,
  }) {
    return Subject(
      code: code ?? this.code,
      names: names ?? this.names,
      grades: grades ?? this.grades,
      mediums: mediums ?? this.mediums,
      iconKey: iconKey ?? this.iconKey,
      isExamSubject: isExamSubject ?? this.isExamSubject,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) => other is Subject && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Looks subjects up by code so any widget can render a label from an id.
class SubjectIndex {
  SubjectIndex(Iterable<Subject> subjects)
      : _byCode = <String, Subject>{
          for (final Subject subject in subjects) subject.code: subject,
        };

  final Map<String, Subject> _byCode;

  Subject? operator [](String? code) => code == null ? null : _byCode[code];

  Iterable<Subject> get all => _byCode.values;

  /// Sorted for display, using the catalogue's explicit ordering.
  List<Subject> sorted() {
    final List<Subject> list = _byCode.values.toList()
      ..sort((Subject a, Subject b) => a.sortOrder == b.sortOrder
          ? a.code.compareTo(b.code)
          : a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  List<Subject> forGrade(int grade) =>
      sorted().where((Subject s) => s.teachesGrade(grade)).toList();

  /// Resolves a label, degrading gracefully to a humanised code.
  String label(String? code, String localeCode, {String fallback = ''}) {
    final Subject? subject = this[code];
    if (subject == null) {
      if (code == null || code.isEmpty) {
        return fallback;
      }
      return code
          .split('_')
          .map((String p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}')
          .join(' ');
    }
    return subject.displayName(localeCode);
  }
}

List<int> _intList(Object? value) {
  if (value is List) {
    return value
        .map((Object? e) => e is int ? e : int.tryParse(e.toString()))
        .whereType<int>()
        .toList()
      ..sort();
  }
  return const <int>[];
}

List<String> _stringList(Object? value, {List<String> fallback = const <String>[]}) {
  if (value is List) {
    final List<String> out = value
        .map((Object? e) => e?.toString() ?? '')
        .where((String s) => s.isNotEmpty)
        .toList();
    return out.isEmpty ? fallback : out;
  }
  return fallback;
}

int _int(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

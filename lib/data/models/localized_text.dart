import 'package:flutter/foundation.dart';

/// A short piece of content that exists in several languages (subject names,
/// book titles, question text).
///
/// Content strings live in *data* (assets or Firestore), not in ARB files, so a
/// new textbook title never requires a code change. Resolution always falls
/// back to English so a missing Sinhala title still renders something useful.
@immutable
class LocalizedText {
  const LocalizedText({
    required this.en,
    this.si,
    this.ta,
  });

  final String en;
  final String? si;
  final String? ta;

  /// Builds from a raw map such as `{ "en": "...", "si": "...", "ta": "..." }`.
  /// A plain string is also accepted, which keeps hand-written seed JSON terse.
  factory LocalizedText.fromJson(Object? json) {
    if (json == null) {
      return const LocalizedText(en: '');
    }
    if (json is String) {
      return LocalizedText(en: json);
    }
    if (json is Map) {
      final Map<String, Object?> map = json.cast<String, Object?>();
      final String en = (map['en'] ?? map['name'] ?? '').toString();
      return LocalizedText(
        en: en,
        si: _emptyToNull(map['si']?.toString()),
        ta: _emptyToNull(map['ta']?.toString()),
      );
    }
    return LocalizedText(en: json.toString());
  }

  static String? _emptyToNull(String? value) =>
      (value == null || value.trim().isEmpty) ? null : value;

  /// Picks the best available string for [localeCode] ('en' | 'si' | 'ta').
  String resolve(String localeCode) {
    switch (localeCode) {
      case 'si':
        return si ?? en;
      case 'ta':
        return ta ?? en;
      default:
        return en;
    }
  }

  bool get isEmpty => en.trim().isEmpty && (si ?? '').isEmpty && (ta ?? '').isEmpty;

  bool get isNotEmpty => !isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
        'en': en,
        if (si != null) 'si': si,
        if (ta != null) 'ta': ta,
      };

  LocalizedText copyWith({String? en, String? si, String? ta}) => LocalizedText(
        en: en ?? this.en,
        si: si ?? this.si,
        ta: ta ?? this.ta,
      );

  static const LocalizedText empty = LocalizedText(en: '');

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.en == en && other.si == si && other.ta == ta;

  @override
  int get hashCode => Object.hash(en, si, ta);

  @override
  String toString() => 'LocalizedText(en: $en, si: $si, ta: $ta)';
}

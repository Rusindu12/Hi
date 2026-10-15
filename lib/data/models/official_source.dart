import 'package:flutter/foundation.dart';

import 'localized_text.dart';

/// A content partner the app links to (National Institute of Education,
/// Department of Examinations, and so on).
///
/// Surfaced in Settings › Official sources so a reviewer — or a parent — can see
/// exactly where content comes from. Nothing here is fetched silently: the app
/// only ever *opens* these URLs in the user's browser.
@immutable
class OfficialSource {
  const OfficialSource({
    required this.id,
    required this.names,
    required this.url,
    this.hosts = const <String>[],
    this.note = LocalizedText.empty,
    this.category,
  });

  factory OfficialSource.fromJson(Map<String, Object?> json) => OfficialSource(
        id: (json['id'] ?? '').toString(),
        names: LocalizedText.fromJson(json['names'] ?? json['name']),
        url: (json['url'] ?? '').toString(),
        hosts: _strings(json['hosts']),
        note: LocalizedText.fromJson(json['note']),
        category: json['category']?.toString(),
      );

  final String id;
  final LocalizedText names;
  final String url;

  /// Hosts that this source serves from; used by the content validator to
  /// confirm no catalogue item points somewhere unexpected.
  final List<String> hosts;

  final LocalizedText note;
  final String? category;

  String displayName(String localeCode) => names.resolve(localeCode);

  String displayNote(String localeCode) => note.resolve(localeCode);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'names': names.toJson(),
        'url': url,
        'hosts': hosts,
        if (note.isNotEmpty) 'note': note.toJson(),
        if (category != null) 'category': category,
      };
}

List<String> _strings(Object? value) {
  if (value is List) {
    return value.map((Object? e) => e.toString()).toList();
  }
  return const <String>[];
}

import 'package:flutter/foundation.dart';

import '../core/constants/app_config.dart';
import '../data/models/catalogue_item.dart';
import '../data/models/official_source.dart';
import '../data/models/paper_filter.dart';
import '../data/models/subject.dart';
import '../data/repositories/catalogue_repository.dart';

enum CatalogueStatus { idle, loading, ready, error }

/// Exposes catalogue data to the widget tree.
///
/// Keeps a coarse [CatalogueStatus] plus the last error so screens can render
/// loading / error / empty states without duplicating FutureBuilders.
class CatalogueController extends ChangeNotifier {
  CatalogueController(this._repository);

  final CatalogueRepository _repository;

  CatalogueStatus _status = CatalogueStatus.idle;
  Object? _error;
  bool _refreshing = false;

  CatalogueStatus get status => _status;

  Object? get error => _error;

  bool get isRefreshing => _refreshing;

  bool get isReady => _status == CatalogueStatus.ready;

  bool get usedRemote => _repository.isRemote;

  List<CatalogueItem> get items => _repository.items;

  SubjectIndex get subjects => _repository.subjects;

  List<OfficialSource> get officialSources => _repository.officialSources;

  int get itemCount => _repository.items.length;

  /// Human-readable data source, for the "offline copy" notice in Settings.
  String get sourceLabel => usedRemote ? 'firestore' : 'bundled';

  Future<void> load({bool forceRefresh = false}) async {
    if (_status == CatalogueStatus.loading) {
      return;
    }
    _status = CatalogueStatus.loading;
    notifyListeners();
    try {
      await _repository.load(forceRefresh: forceRefresh);
      await _repository.loadOfficialSources(forceRefresh: false);
      _status = CatalogueStatus.ready;
      _error = null;
    } on Object catch (error) {
      _status = CatalogueStatus.error;
      _error = error;
      debugPrint('[catalogue] load failed: $error');
    }
    notifyListeners();
  }

  /// Pull-to-refresh: keeps the current list on screen while re-fetching.
  Future<void> refresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    notifyListeners();
    try {
      await _repository.load(forceRefresh: true);
      _error = null;
    } on Object catch (error) {
      _error = error;
    } finally {
      _refreshing = false;
      _status = CatalogueStatus.ready;
      notifyListeners();
    }
  }

  // --- Queries used by screens -------------------------------------------

  CatalogueItem? byId(String? id) => _repository.byId(id);

  Set<int> get gradesWithContent => _repository.gradesWithContent();

  List<CatalogueItem> textbooks({
    required int grade,
    String? mediumCode,
    String? subjectCode,
    String query = '',
    required String localeCode,
  }) =>
      _repository.textbooks(
        grade: grade,
        mediumCode: mediumCode,
        subjectCode: subjectCode,
        query: query,
        localeCode: localeCode,
      );

  /// Mediums that actually have books for a grade, so the medium step never
  /// dead-ends the user.
  List<String> mediumsForGrade(int grade) {
    final Set<String> mediums = _repository
        .textbooks(grade: grade, localeCode: 'en')
        .map((CatalogueItem item) => item.medium)
        .toSet();
    return mediums.isEmpty ? const <String>[] : mediums.toList()..sort();
  }

  List<Subject> subjectsForGrade(int grade) =>
      _repository.subjectsWithContent(grade: grade, papersOnly: false);

  List<CatalogueItem> papers(
    PaperFilter filter, {
    required String localeCode,
    PaperSort sort = PaperSort.newest,
  }) =>
      _repository.papers(filter, localeCode: localeCode, sort: sort);

  List<int> availableYears({
    String? examType,
    String? subjectCode,
    String? mediumCode,
  }) =>
      _repository.availableYears(
        examType: examType,
        subjectCode: subjectCode,
        mediumCode: mediumCode,
      );

  List<Subject> subjectsForPapers({String? examType, String? mediumCode}) =>
      _repository.subjectsWithContent(
        examType: examType,
        papersOnly: true,
        mediumCode: mediumCode,
      );

  List<CatalogueItem> trending({int limit = 8}) =>
      _repository.trending(limit: limit);

  /// True when the app is showing bundled seed data rather than the cloud copy.
  bool get isOfflineSeed => AppConfig.useFirebase && !usedRemote;

  /// Resolves a subject label, falling back to a humanised code.
  String subjectLabel(String? code, String localeCode) =>
      subjects.label(code, localeCode);

  /// Convenience for the planner/quiz chips.
  List<Subject> allSubjects() => subjects.sorted();
}

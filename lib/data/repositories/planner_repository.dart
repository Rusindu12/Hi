import '../../core/constants/hive_keys.dart';
import '../models/study_slot.dart';
import '../sources/local/hive_store.dart';

/// Persists study planner slots.
class PlannerRepository {
  PlannerRepository(this._store);

  final HiveStore _store;

  /// Slots sorted by time of week (Monday first, daily slots last).
  List<StudySlot> slots() {
    final List<StudySlot> list =
        _store.readMapList(HiveBoxes.planner).map(StudySlot.fromJson).toList()
          ..sort((StudySlot a, StudySlot b) {
            final int byDay = _dayOrder(a.weekday).compareTo(_dayOrder(b.weekday));
            if (byDay != 0) {
              return byDay;
            }
            final int byHour = a.hour.compareTo(b.hour);
            if (byHour != 0) {
              return byHour;
            }
            return a.minute.compareTo(b.minute);
          });
    return list;
  }

  /// Daily slots (weekday 0) sort after specific days so the week reads first.
  int _dayOrder(int weekday) => weekday == 0 ? 8 : weekday;

  List<StudySlot> slotsForWeekday(int weekday) => slots()
      .where((StudySlot slot) => slot.enabled && (slot.isDaily || slot.weekday == weekday))
      .toList();

  StudySlot? byId(String id) {
    final Map<String, Object?>? raw = _store.readMap(HiveBoxes.planner, id);
    return raw == null ? null : StudySlot.fromJson(raw);
  }

  Future<void> save(StudySlot slot) =>
      _store.writeMap(HiveBoxes.planner, slot.id, slot.toJson());

  Future<void> delete(String id) => _store.delete(HiveBoxes.planner, id);

  int count() => slots().length;

  /// Next unused notification id. Android cancellation keys off this value, so
  /// ids must be unique for the lifetime of the install.
  int nextNotificationId() {
    int max = 1000;
    for (final StudySlot slot in slots()) {
      if (slot.notificationId > max) {
        max = slot.notificationId;
      }
    }
    return max + 1;
  }

  Future<void> clear() => _store.clearBox(HiveBoxes.planner);
}

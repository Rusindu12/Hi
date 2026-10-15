import '../../core/constants/hive_keys.dart';
import '../models/badge.dart';
import '../sources/local/hive_store.dart';

/// Persists unlocked badges.
class BadgeRepository {
  BadgeRepository(this._store);

  final HiveStore _store;

  BadgeCollection load() {
    final List<Object?> raw =
        _store.read<List<dynamic>>(HiveBoxes.badges, 'earned') ?? const <Object?>[];
    return BadgeCollection.fromJsonList(raw);
  }

  /// Adds a badge if it is not already earned. Returns true when newly unlocked,
  /// which the UI uses to decide whether to show the celebration snackbar.
  Future<bool> unlock(BadgeId id, {DateTime? at}) async {
    final BadgeCollection current = load();
    if (current.has(id)) {
      return false;
    }
    final BadgeRecord record = BadgeRecord(
      id: id,
      earnedAtMillis: (at ?? DateTime.now()).millisecondsSinceEpoch,
    );
    final List<BadgeRecord> next = <BadgeRecord>[...current.records, record];
    await _store.write(
      HiveBoxes.badges,
      'earned',
      BadgeCollection(next).toJsonList(),
    );
    return true;
  }

  Future<void> clear() => _store.clearBox(HiveBoxes.badges);
}

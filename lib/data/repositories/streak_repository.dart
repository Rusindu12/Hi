import '../../core/constants/hive_keys.dart';
import '../models/streak_state.dart';
import '../sources/local/hive_store.dart';

/// Persists [StreakState]. All *rules* live in `StreakService`; this class only
/// loads and saves, which keeps the interesting logic unit-testable without Hive.
class StreakRepository {
  StreakRepository(this._store);

  final HiveStore _store;

  StreakState load() {
    final Map<String, Object?>? raw =
        _store.readMap(HiveBoxes.streak, 'state');
    if (raw == null) {
      return StreakState.empty;
    }
    return StreakState.fromJson(raw);
  }

  Future<void> save(StreakState state) =>
      _store.writeMap(HiveBoxes.streak, 'state', state.toJson());

  Future<void> clear() => _store.clearBox(HiveBoxes.streak);
}

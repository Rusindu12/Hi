import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/hive_keys.dart';
import '../../../core/errors/app_exception.dart';

/// Thin typed wrapper over Hive.
///
/// Design choice: we store plain JSON maps (`Map<String, Object?>`) rather than
/// generated `TypeAdapter`s for every model. Benefits:
///   * no build_runner step, so `flutter run` works on a fresh clone;
///   * models stay hand-written and reviewable;
///   * records survive field additions (missing keys fall back to defaults).
/// The cost is a little serialisation work per read, which is negligible at the
/// data volumes this app handles (hundreds of rows).
class HiveStore {
  HiveStore._(this._boxes);

  final Map<String, Box<dynamic>> _boxes;

  /// Opens every box declared in [HiveBoxes.all]. Call once during startup.
  static Future<HiveStore> open() async {
    await Hive.initFlutter();
    final Map<String, Box<dynamic>> boxes = <String, Box<dynamic>>{};
    try {
      for (final String name in HiveBoxes.all) {
        boxes[name] = await Hive.openBox<dynamic>(name);
      }
    } on Object catch (error, stack) {
      throw StorageException(
        'Failed to open Hive boxes: $error',
        cause: error,
        stackTrace: stack,
      );
    }
    return HiveStore._(boxes);
  }

  Box<dynamic> box(String name) {
    final Box<dynamic>? box = _boxes[name];
    if (box == null) {
      throw StorageException('Hive box "$name" was not opened');
    }
    return box;
  }

  // --- Raw value access ----------------------------------------------------

  T? read<T>(String boxName, String key) {
    final Object? value = box(boxName).get(key);
    if (value is T) {
      return value;
    }
    return null;
  }

  Future<void> write(String boxName, String key, Object? value) =>
      box(boxName).put(key, value);

  Future<void> delete(String boxName, String key) => box(boxName).delete(key);

  Future<void> clearBox(String boxName) => box(boxName).clear();

  bool has(String boxName, String key) => box(boxName).containsKey(key);

  // --- JSON map helpers ----------------------------------------------------

  /// Reads a stored map. Accepts both a `Map` (native Hive) and a JSON string
  /// (used when a value was migrated from an older build).
  Map<String, Object?>? readMap(String boxName, String key) {
    final Object? value = box(boxName).get(key);
    if (value == null) {
      return null;
    }
    if (value is Map) {
      return value.cast<String, Object?>();
    }
    if (value is String && value.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.cast<String, Object?>();
        }
      } on FormatException {
        return null;
      }
    }
    return null;
  }

  Future<void> writeMap(
    String boxName,
    String key,
    Map<String, Object?> value,
  ) =>
      box(boxName).put(key, value);

  /// Reads every value in a box as a map list (order is insertion order).
  List<Map<String, Object?>> readMapList(String boxName) {
    final List<Map<String, Object?>> out = <Map<String, Object?>>[];
    for (final Object? value in box(boxName).values) {
      if (value is Map) {
        out.add(value.cast<String, Object?>());
      } else if (value is String && value.isNotEmpty) {
        try {
          final Object? decoded = jsonDecode(value);
          if (decoded is Map) {
            out.add(decoded.cast<String, Object?>());
          }
        } on FormatException {
          continue;
        }
      }
    }
    return out;
  }

  /// Writes a list of maps keyed by [keyOf], so callers can update one row
  /// without rewriting the box.
  Future<void> writeMapList(
    String boxName,
    Iterable<Map<String, Object?>> values,
    String Function(Map<String, Object?>) keyOf,
  ) async {
    final Box<dynamic> target = box(boxName);
    final Map<Object, Object?> entries = <Object, Object?>{
      for (final Map<String, Object?> value in values) keyOf(value): value,
    };
    await target.putAll(entries);
  }

  /// Wipes user data but keeps the app usable. Called from Settings and by the
  /// "clear cache" action (which excludes favourites/streak/quiz results).
  Future<void> clearAll() async {
    for (final String name in HiveBoxes.all) {
      await box(name).clear();
    }
  }

  /// Boxes that "clear cache" is allowed to touch. Deliberately excludes
  /// settings, favourites, streak, badges and quiz results.
  Future<void> clearCacheOnly() async {
    await box(HiveBoxes.cache).clear();
    await box(HiveBoxes.downloads).clear();
    await box(HiveBoxes.recents).clear();
  }

  Future<void> close() async {
    for (final Box<dynamic> box in _boxes.values) {
      await box.close();
    }
  }
}

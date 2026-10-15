import 'dart:async';
import 'dart:math';

import 'package:sembast/sembast.dart';

/// The collections kept on the device and synced with the server, parents
/// before children (transactions point at categories, logs at habits).
const syncedStores = [
  'categories',
  'tasks',
  'habits',
  'habit_logs',
  'transactions',
  'wishlist',
  'savings',
  'bills',
  'savings_goals',
];

/// A random UUID (v4) for records made on this device.
String newId() {
  final rnd = Random.secure();
  final b = List<int>.generate(16, (_) => rnd.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final hex = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

String _now() => DateTime.now().toUtc().toIso8601String();

/// All of the user's data, on the device. The app reads and writes here only;
/// [SyncService] trades changes with the server when there's a connection.
///
/// Everything is held in memory as well (a personal app's data is small), so
/// reads are instant and synchronous; writes go to disk (IndexedDB on the web)
/// straight after.
///
/// Records are JSON maps shaped like the API's, with string ids, plus
/// `created_at`, `updated_at` (last edit, UTC), `deleted_at` (deletes are kept
/// as tombstones until synced) and `_dirty` (edited here since the last sync).
class LocalDb {
  LocalDb._(this._db, this._cache, this._meta);

  final Database _db;
  final Map<String, Map<String, Map<String, dynamic>>> _cache;
  final Map<String, Object?> _meta;
  final _changes = StreamController<void>.broadcast();
  final _localEdits = StreamController<void>.broadcast();

  static final _metaStore = StoreRef<String, Object?>('meta');
  static StoreRef<String, Map<String, Object?>> _store(String name) =>
      stringMapStoreFactory.store(name);

  static Future<LocalDb> open(DatabaseFactory factory, String path) async {
    final db = await factory.openDatabase(path);
    final cache = <String, Map<String, Map<String, dynamic>>>{};
    for (final name in syncedStores) {
      final rows = await _store(name).find(db);
      cache[name] = {
        for (final row in rows) row.key: Map<String, dynamic>.from(row.value),
      };
    }
    final meta = {
      for (final row in await _metaStore.find(db)) row.key: row.value,
    };
    return LocalDb._(db, cache, meta);
  }

  /// Fires after any change, local or from a sync.
  Stream<void> get changes => _changes.stream;

  /// Fires after a change made on this device (something new to upload).
  Stream<void> get localEdits => _localEdits.stream;

  // ---------------------------------------------------------------- reading

  /// Live (not deleted) records. Treat them as read-only.
  List<Map<String, dynamic>> all(String store) => [
    for (final r in _cache[store]!.values)
      if (r['deleted_at'] == null) r,
  ];

  /// A live record, or null.
  Map<String, dynamic>? get(String store, String? id) {
    final r = id == null ? null : _cache[store]![id];
    return r == null || r['deleted_at'] != null ? null : r;
  }

  /// A record even if it was deleted (for undoing a check-in, say).
  Map<String, dynamic>? getAny(String store, String id) => _cache[store]![id];

  // ------------------------------------------------------------ local edits

  /// Creates or updates a record. [fields] are merged over the existing ones.
  Future<Map<String, dynamic>> save(
    String store,
    Map<String, dynamic> fields, {
    String? id,
  }) async {
    final record = _edited(store, fields, id: id);
    await _write([(store, record)]);
    return record;
  }

  /// Several edits at once (e.g. a new order for the whole wishlist).
  Future<void> saveAll(
    String store,
    Map<String, Map<String, dynamic>> fieldsById,
  ) async {
    await _write([
      for (final e in fieldsById.entries)
        (store, _edited(store, e.value, id: e.key)),
    ]);
  }

  Future<void> delete(String store, String id) async {
    final existing = _cache[store]![id];
    if (existing == null || existing['deleted_at'] != null) return;
    final now = _now();
    await _write([
      (
        store,
        {...existing, 'updated_at': now, 'deleted_at': now, '_dirty': true},
      ),
    ]);
  }

  Map<String, dynamic> _edited(
    String store,
    Map<String, dynamic> fields, {
    String? id,
  }) {
    final key = id ?? fields['id'] as String? ?? newId();
    final existing = _cache[store]![key];
    final now = _now();
    return {
      ...?existing,
      ...fields,
      'id': key,
      'created_at': existing?['created_at'] ?? now,
      'updated_at': now,
      'deleted_at': null,
      '_dirty': true,
    };
  }

  Future<void> _write(List<(String, Map<String, dynamic>)> records) async {
    for (final (store, record) in records) {
      _cache[store]![record['id'] as String] = record;
    }
    _changes.add(null);
    _localEdits.add(null);
    await _db.transaction((txn) async {
      for (final (store, record) in records) {
        await _store(store).record(record['id'] as String).put(txn, record);
      }
    });
  }

  // ------------------------------------------------------------------- sync

  /// Records edited here and not yet uploaded, oldest edits first.
  List<Map<String, dynamic>> dirty(String store, {int? limit}) {
    final list = [
      for (final r in _cache[store]!.values)
        if (r['_dirty'] == true) r,
    ]..sort((a, b) => (a['updated_at'] as String).compareTo(b['updated_at']));
    return limit == null ? list : list.take(limit).toList();
  }

  int get pendingCount => syncedStores.fold(0, (n, s) => n + dirty(s).length);

  /// After an upload: records not edited again since are now in sync.
  /// Tombstones the server has are dropped.
  Future<void> markSynced(
    String store,
    List<Map<String, dynamic>> uploaded,
  ) async {
    await _db.transaction((txn) async {
      for (final sent in uploaded) {
        final id = sent['id'] as String;
        final now = _cache[store]![id];
        if (now == null || now['updated_at'] != sent['updated_at']) continue;
        if (now['deleted_at'] != null) {
          _cache[store]!.remove(id);
          await _store(store).record(id).delete(txn);
        } else {
          final clean = {...now, '_dirty': false};
          _cache[store]![id] = clean;
          await _store(store).record(id).put(txn, clean);
        }
      }
    });
  }

  /// Takes the server's versions, unless this device has a newer edit that
  /// hasn't been uploaded yet. Returns whether anything changed.
  Future<bool> applyRemote(
    String store,
    List<Map<String, dynamic>> incoming,
  ) async {
    var changed = false;
    await _db.transaction((txn) async {
      for (final remote in incoming) {
        final id = remote['id'] as String;
        final local = _cache[store]![id];
        if (local != null &&
            local['_dirty'] == true &&
            _newer(local['updated_at'], remote['updated_at'])) {
          continue;
        }
        if (remote['deleted_at'] != null) {
          if (_cache[store]!.remove(id) != null) changed = true;
          await _store(store).record(id).delete(txn);
        } else {
          final record = {...remote, '_dirty': false};
          _cache[store]![id] = record;
          await _store(store).record(id).put(txn, record);
          changed = true;
        }
      }
    });
    if (changed) _changes.add(null);
    return changed;
  }

  static bool _newer(Object? a, Object? b) {
    final x = DateTime.tryParse('$a');
    final y = DateTime.tryParse('$b');
    if (x == null || y == null) return x != null;
    return x.isAfter(y);
  }

  Object? meta(String key) => _meta[key];

  Future<void> setMeta(String key, Object? value) async {
    _meta[key] = value;
    if (value == null) {
      await _metaStore.record(key).delete(_db);
    } else {
      await _metaStore.record(key).put(_db, value);
    }
  }

  /// Forget everything on this device (signing out).
  Future<void> clear() async {
    for (final s in syncedStores) {
      _cache[s]!.clear();
    }
    _meta.clear();
    await _db.transaction((txn) async {
      for (final s in syncedStores) {
        await _store(s).delete(txn);
      }
      await _metaStore.delete(txn);
    });
    _changes.add(null);
  }
}

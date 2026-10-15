import 'package:dio/dio.dart';

import '../local/local_db.dart';
import '../network/api_client.dart';

/// Trades changes between the device and the server (`POST /sync`).
///
/// Uploads records edited here (oldest edits first, in batches), takes the
/// server's changes since the last sync, and keeps the cursor it gets back.
/// The newest edit of a record wins, on either side.
class SyncService {
  final LocalDb _db;
  final ApiClient _api;

  SyncService(this._db, this._api);

  static const _cursorKey = 'sync_cursor';
  static const _batch = 500;

  /// Runs until nothing is left to upload (or 10 rounds). Throws
  /// [DioException] when the server can't be reached.
  Future<void> run() async {
    for (var round = 0; round < 10; round++) {
      final sent = {
        for (final s in syncedStores) s: _db.dirty(s, limit: _batch),
      };
      final response = await _api.dio.post(
        '/sync',
        data: {
          'since': _db.meta(_cursorKey),
          'changes': {
            for (final e in sent.entries)
              if (e.value.isNotEmpty) e.key: e.value.map(_wire).toList(),
          },
        },
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      final body = response.data as Map<String, dynamic>;
      final changes = body['changes'] as Map<String, dynamic>? ?? {};

      // Rejected records are marked synced too, so one bad record can't
      // block every later sync.
      for (final s in syncedStores) {
        await _db.markSynced(s, sent[s]!);
      }
      for (final s in syncedStores) {
        final incoming = (changes[s] as List? ?? const [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        if (incoming.isNotEmpty) await _db.applyRemote(s, incoming);
      }
      await _db.setMeta(_cursorKey, body['cursor']);

      if (_db.pendingCount == 0) return;
    }
  }

  /// What the server gets: the record without device-only bookkeeping.
  static Map<String, dynamic> _wire(Map<String, dynamic> r) =>
      Map.of(r)..remove('_dirty');
}

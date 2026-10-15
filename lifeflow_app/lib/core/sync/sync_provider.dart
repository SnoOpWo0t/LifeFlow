import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../local/local_providers.dart';
import 'sync_service.dart';

class SyncStatus {
  final bool syncing;
  final DateTime? lastSynced;

  /// The last attempt couldn't reach the server.
  final bool offline;

  /// The server answered with an error.
  final String? error;

  const SyncStatus({
    this.syncing = false,
    this.lastSynced,
    this.offline = false,
    this.error,
  });
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(localDbProvider), ref.watch(apiClientProvider));
});

/// Keeps a signed-in device in sync: shortly after each edit, every few
/// minutes, when the app comes back to the front, and on demand ("Sync now",
/// pull to refresh). Does nothing without an account.
final syncProvider = NotifierProvider<SyncController, SyncStatus>(
  SyncController.new,
);

class SyncController extends Notifier<SyncStatus> {
  static const _lastSyncedKey = 'last_synced';

  bool _enabled = false;
  Future<bool>? _running;

  @override
  SyncStatus build() {
    // The signed-in account's id; 0 or null when there's nothing to sync with.
    final accountId = ref.watch(
      authProvider.select((auth) {
        final user = auth.value;
        return user == null || user.isLocal ? null : user.id;
      }),
    );
    _enabled = accountId != null;
    if (!_enabled) return const SyncStatus();

    final db = ref.watch(localDbProvider);
    Timer? debounce;
    final edits = db.localEdits.listen((_) {
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 3), syncNow);
    });
    final periodic = Timer.periodic(
      const Duration(minutes: 5),
      (_) => syncNow(),
    );
    final lifecycle = AppLifecycleListener(onResume: syncNow);
    ref.onDispose(() {
      _enabled = false;
      edits.cancel();
      debounce?.cancel();
      periodic.cancel();
      lifecycle.dispose();
    });

    scheduleMicrotask(syncNow);
    final last = db.meta(_lastSyncedKey);
    return SyncStatus(
      lastSynced: last is String ? DateTime.tryParse(last)?.toLocal() : null,
    );
  }

  /// Returns whether it synced. Calls made while one runs share it.
  Future<bool> syncNow() {
    if (!_enabled) return Future.value(false);
    return _running ??= _sync().whenComplete(() => _running = null);
  }

  Future<bool> _sync() async {
    state = SyncStatus(syncing: true, lastSynced: state.lastSynced);
    try {
      await ref.read(syncServiceProvider).run();
      final now = DateTime.now();
      await ref
          .read(localDbProvider)
          .setMeta(_lastSyncedKey, now.toUtc().toIso8601String());
      if (ref.mounted) state = SyncStatus(lastSynced: now);
      return true;
    } on DioException catch (e) {
      final offline = e.response == null;
      if (ref.mounted) {
        state = SyncStatus(
          lastSynced: state.lastSynced,
          offline: offline,
          error: offline
              ? null
              : "Couldn't sync (server error ${e.response?.statusCode}).",
        );
      }
      return false;
    }
  }
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/local/local_providers.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/storage_service.dart';
import '../../data/auth_data_source.dart';
import '../../data/auth_repository.dart';
import '../../domain/user.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.watch(storageServiceProvider),
    onUnauthorized: () => ref.read(authProvider.notifier).sessionExpired(),
  );
});

final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  return AuthDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(authDataSourceProvider),
    ref.watch(storageServiceProvider),
  );
});

final authProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<User?> {
  @override
  Future<User?> build() async {
    final user = await ref.read(authRepositoryProvider).getUser();
    if (user != null) {
      // Signed in before this device kept data: it's this account's.
      final db = ref.read(localDbProvider);
      if (db.meta('owner') == null) await db.setMeta('owner', user.id);
      await _loadPreferences(user);
      return user;
    }
    return ref.read(storageServiceProvider).isLocalMode ? User.local() : null;
  }

  /// Use the app with no account; everything stays on this device.
  Future<void> useWithoutAccount() async {
    await ref.read(storageServiceProvider).setLocalMode(true);
    state = AsyncData(User.local());
  }

  /// From no-account mode to the sign-in screen. The data stays; signing in
  /// uploads it to the account.
  void showSignIn() {
    state = const AsyncData(null);
  }

  /// Whether someone can come back to their no-account data from sign-in.
  bool get hasLocalData => ref.read(storageServiceProvider).isLocalMode;

  /// The device's data belongs to whoever signed in last. A different account
  /// starts empty; no-account data is kept and uploaded to the new account.
  Future<void> _adoptDeviceData(User user) async {
    final db = ref.read(localDbProvider);
    final owner = db.meta('owner');
    if (owner != null && owner != user.id) await db.clear();
    await db.setMeta('owner', user.id);
    await ref.read(storageServiceProvider).setLocalMode(false);
  }

  /// Applies the account's saved settings before the user is emitted, so
  /// theme and weather providers rebuild with the right values.
  Future<void> _loadPreferences(User user) {
    return ref.read(settingsRepositoryProvider).applyRemote(user.preferences);
  }

  void updateAvatarUrl(String url) {
    if (state.value != null) {
      state = AsyncData(state.value!.copyWith(avatarUrl: url));
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.login(email, password);
      await _adoptDeviceData(user);
      await _loadPreferences(user);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.register(name, email, password);
      await _adoptDeviceData(user);
      await _loadPreferences(user);
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Permanently deletes the account. Returns an error message to show, or
  /// null on success (the user is then signed out).
  Future<String?> deleteAccount(String password) async {
    try {
      await ref.read(authRepositoryProvider).deleteAccount(password);
    } on DioException catch (e) {
      return e.response?.statusCode == 422
          ? 'That password is incorrect.'
          : "Couldn't delete the account. Check your connection and try again.";
    }
    await ref.read(settingsRepositoryProvider).clearLocal();
    await ref.read(localDbProvider).clear();
    state = const AsyncData(null);
    return null;
  }

  /// The server rejected our token: show the sign-in screen. The device's
  /// data is kept, so changes not yet synced upload after signing back in.
  Future<void> sessionExpired() async {
    if (state.value == null || state.value!.isLocal) return;
    await ref.read(authRepositoryProvider).logout(revoke: false);
    state = const AsyncData(null);
  }

  /// Signs out and removes this account's data from the device (it's on the
  /// server). Changes that haven't synced yet are lost, so the settings screen
  /// warns first.
  Future<void> logout({bool revoke = true}) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout(revoke: revoke);
    await ref.read(settingsRepositoryProvider).clearLocal();
    await ref.read(localDbProvider).clear();
    state = const AsyncData(null);
  }

  /// No-account mode: erase everything on this device and start over.
  Future<void> eraseLocalData() async {
    await ref.read(localDbProvider).clear();
    await ref.read(settingsRepositoryProvider).clearLocal();
    await ref.read(storageServiceProvider).setLocalMode(false);
    state = const AsyncData(null);
  }
}

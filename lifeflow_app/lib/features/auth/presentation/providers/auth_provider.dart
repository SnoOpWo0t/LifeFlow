import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    // Fetch current user if token exists on boot
    final repo = ref.read(authRepositoryProvider);
    final user = await repo.getUser();
    if (user != null) await _loadPreferences(user);
    return user;
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
    state = const AsyncData(null);
    return null;
  }

  /// The server rejected our token: drop it and show the sign-in screen.
  Future<void> sessionExpired() async {
    if (state.value == null) return;
    await logout(revoke: false);
  }

  Future<void> logout({bool revoke = true}) async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout(revoke: revoke);
    await ref.read(settingsRepositoryProvider).clearLocal();
    state = const AsyncData(null);
  }
}

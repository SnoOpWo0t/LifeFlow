import 'package:dio/dio.dart';

import '../../../core/storage/storage_service.dart';
import '../domain/user.dart';
import 'auth_data_source.dart';

class AuthRepository {
  final AuthDataSource _dataSource;
  final StorageService _storageService;

  AuthRepository(this._dataSource, this._storageService);

  Future<User> login(String email, String password) async {
    final data = await _dataSource.login(email, password);
    await _storageService.saveToken(data['access_token']);
    await _storageService.saveCachedUser(data['user']);
    return User.fromJson(data['user']);
  }

  Future<User> register(String name, String email, String password) async {
    final data = await _dataSource.register(name, email, password);
    await _storageService.saveToken(data['access_token']);
    await _storageService.saveCachedUser(data['user']);
    return User.fromJson(data['user']);
  }

  /// [revoke] also invalidates the token on the server, so a copied token
  /// stops working. Skipped when the server already rejected it.
  Future<void> logout({bool revoke = true}) async {
    if (revoke) {
      try {
        await _dataSource.logout();
      } catch (_) {
        // Offline or already invalid: still sign out locally.
      }
    }
    await _storageService.deleteToken();
  }

  Future<void> deleteAccount(String password) async {
    await _dataSource.deleteAccount(password);
    await _storageService.deleteToken();
  }

  /// The signed-in account. Without internet, the copy saved at sign-in, so
  /// the app still opens; only a rejected token signs the user out.
  Future<User?> getUser() async {
    final token = _storageService.getToken();
    if (token == null) return null;
    try {
      final data = await _dataSource.getUser();
      await _storageService.saveCachedUser(data);
      return User.fromJson(data);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await _storageService.deleteToken();
        return null;
      }
      final cached = _storageService.getCachedUser();
      return cached == null ? null : User.fromJson(cached);
    }
  }
}

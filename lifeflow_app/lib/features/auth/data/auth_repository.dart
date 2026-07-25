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
    return User.fromJson(data['user']);
  }

  Future<User> register(String name, String email, String password) async {
    final data = await _dataSource.register(name, email, password);
    await _storageService.saveToken(data['access_token']);
    return User.fromJson(data['user']);
  }

  Future<void> logout() async {
    await _storageService.deleteToken();
  }

  Future<User?> getUser() async {
    try {
      final token = _storageService.getToken();
      if (token == null) return null;
      final data = await _dataSource.getUser();
      return User.fromJson(data);
    } catch (e) {
      await _storageService.deleteToken();
      return null;
    }
  }
}

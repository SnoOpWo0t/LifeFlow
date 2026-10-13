import '../../../core/network/api_client.dart';
import '../../../core/network/api_constants.dart';

class AuthDataSource {
  final ApiClient _apiClient;
  AuthDataSource(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiClient.dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await _apiClient.dio.post(
      ApiConstants.register,
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getUser() async {
    final response = await _apiClient.dio.get('/user');
    return response.data;
  }

  Future<void> logout() async {
    await _apiClient.dio.post(ApiConstants.logout);
  }
}

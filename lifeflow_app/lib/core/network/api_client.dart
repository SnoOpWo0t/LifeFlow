import 'package:dio/dio.dart';
import 'api_constants.dart';
import '../storage/storage_service.dart';

class ApiClient {
  final Dio _dio;
  final StorageService _storageService;

  /// Called when an authenticated request comes back 401 (token expired or
  /// revoked), so the app can return to the sign-in screen.
  final void Function()? onUnauthorized;

  /// The device's IANA timezone (e.g. "Asia/Dhaka"), set once at startup.
  /// Sent as X-Timezone so the server's "today" matches the user's.
  static String? deviceTimezone;

  ApiClient(this._storageService, {this.onUnauthorized}) : _dio = Dio() {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _storageService.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (deviceTimezone != null) {
            options.headers['X-Timezone'] = deviceTimezone;
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          final hadToken = error.requestOptions.headers.containsKey(
            'Authorization',
          );
          if (error.response?.statusCode == 401 && hadToken) {
            onUnauthorized?.call();
          }
          return handler.next(error);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

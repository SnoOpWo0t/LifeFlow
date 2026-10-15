import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _serverKey = 'server_url';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  Future<void> saveToken(String token) async {
    await _prefs.setString(_tokenKey, token);
  }

  String? getToken() {
    return _prefs.getString(_tokenKey);
  }

  Future<void> deleteToken() async {
    await _prefs.remove(_tokenKey);
  }

  /// API base URL chosen on the sign-in screen, or null for the built-in one.
  String? getServerUrl() {
    return _prefs.getString(_serverKey);
  }

  Future<void> saveServerUrl(String? url) async {
    if (url == null) {
      await _prefs.remove(_serverKey);
    } else {
      await _prefs.setString(_serverKey, url);
    }
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _serverKey = 'server_url';
  static const String _userKey = 'cached_user';
  static const String _localModeKey = 'local_mode';

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
    await _prefs.remove(_userKey);
  }

  /// The signed-in account as last seen, so the app opens without internet.
  Map<String, dynamic>? getCachedUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCachedUser(Map<String, dynamic> json) async {
    await _prefs.setString(_userKey, jsonEncode(json));
  }

  /// Using the app without an account (data only on this device).
  bool get isLocalMode => _prefs.getBool(_localModeKey) ?? false;

  Future<void> setLocalMode(bool on) async {
    if (on) {
      await _prefs.setBool(_localModeKey, true);
    } else {
      await _prefs.remove(_localModeKey);
    }
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

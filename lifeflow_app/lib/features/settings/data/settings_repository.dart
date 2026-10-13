import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../domain/weather_location.dart';

class AvatarUploadException implements Exception {
  final String message;
  AvatarUploadException(this.message);
  @override
  String toString() => message;
}

class SettingsRepository {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  SettingsRepository(this._apiClient, this._prefs);

  static const _themeKey = 'theme_mode'; // 'system' | 'light' | 'dark'
  static const _legacyDarkModeKey = 'is_dark_mode'; // older on/off setting
  static const _pushKey = 'push_notifications';
  static const _cityKey = 'default_city';
  static const _locationKey = 'weather_location';
  static const _budgetKey = 'monthly_budget';

  /// Follows the device unless the user picked Light or Dark. Accounts that
  /// only have the old on/off setting keep their choice.
  ThemeMode get themeMode {
    final saved = _prefs.getString(_themeKey);
    if (saved != null) return _parseThemeMode(saved);
    return (_prefs.getBool(_legacyDarkModeKey) ?? false)
        ? ThemeMode.dark
        : ThemeMode.system;
  }

  static ThemeMode _parseThemeMode(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  bool get pushNotifications => _prefs.getBool(_pushKey) ?? true;
  String get defaultCity => weatherLocation.name;
  double get monthlyBudget => _prefs.getDouble(_budgetKey) ?? 0.0;

  WeatherLocation get weatherLocation {
    final raw = _prefs.getString(_locationKey);
    if (raw == null) return WeatherLocation.fallback;
    try {
      return WeatherLocation.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return WeatherLocation.fallback;
    }
  }

  Future<void> saveSettings({
    ThemeMode? themeMode,
    bool? pushNotifications,
    WeatherLocation? weatherLocation,
    double? monthlyBudget,
  }) async {
    // 1. Save locally for instant UI update
    if (themeMode != null) await _prefs.setString(_themeKey, themeMode.name);
    if (pushNotifications != null) {
      await _prefs.setBool(_pushKey, pushNotifications);
    }
    if (weatherLocation != null) {
      await _prefs.setString(
        _locationKey,
        jsonEncode(weatherLocation.toJson()),
      );
      await _prefs.setString(_cityKey, weatherLocation.name);
    }
    if (monthlyBudget != null)
      await _prefs.setDouble(_budgetKey, monthlyBudget);

    // 2. Sync silently to cloud
    try {
      await _apiClient.dio.put(
        '/profile/settings',
        data: {
          'preferences': {
            if (themeMode != null) _themeKey: themeMode.name,
            if (pushNotifications != null) _pushKey: pushNotifications,
            if (weatherLocation != null) ...{
              _cityKey: weatherLocation.name,
              _locationKey: weatherLocation.toJson(),
            },
            if (monthlyBudget != null) _budgetKey: monthlyBudget,
          },
        },
      );
    } catch (e) {
      // Sync failed, but local state remains intact
    }
  }

  /// Makes the account's saved preferences the local ones after sign-in, so
  /// settings follow the user across browsers and devices. An account with
  /// nothing saved yet adopts (and uploads) whatever this device has.
  Future<void> applyRemote(Map<String, dynamic>? remote) async {
    if (remote == null || remote.isEmpty) {
      await saveSettings(
        themeMode: themeMode,
        pushNotifications: pushNotifications,
        weatherLocation: weatherLocation,
        monthlyBudget: monthlyBudget,
      );
      return;
    }

    final theme = remote[_themeKey];
    final legacyDark = remote[_legacyDarkModeKey];
    if (theme is String) {
      await _prefs.setString(_themeKey, _parseThemeMode(theme).name);
    } else if (legacyDark is bool) {
      await _prefs.setString(
        _themeKey,
        legacyDark ? ThemeMode.dark.name : ThemeMode.system.name,
      );
    }
    final push = remote[_pushKey];
    if (push is bool) await _prefs.setBool(_pushKey, push);
    final budget = remote[_budgetKey];
    if (budget is num) await _prefs.setDouble(_budgetKey, budget.toDouble());
    final location = remote[_locationKey];
    if (location is Map) {
      await _prefs.setString(_locationKey, jsonEncode(location));
      await _prefs.setString(_cityKey, location['name'].toString());
    }
  }

  /// Forget the signed-out user's preferences so the next account starts clean.
  Future<void> clearLocal() async {
    for (final key in [
      _themeKey,
      _legacyDarkModeKey,
      _pushKey,
      _cityKey,
      _locationKey,
      _budgetKey,
    ]) {
      await _prefs.remove(key);
    }
  }

  /// Download all account data. [format]: 'json' (everything) or 'csv'
  /// (transactions only).
  Future<({List<int> bytes, String filename, String mimeType})> exportData(
    String format,
  ) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/profile/export',
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    final disposition = response.headers.value('content-disposition') ?? '';
    final match = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition);
    return (
      bytes: response.data ?? const [],
      filename: match?.group(1) ?? 'lifeflow-export.$format',
      mimeType: format == 'csv' ? 'text/csv' : 'application/json',
    );
  }

  Future<String> uploadAvatar(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    });

    try {
      final response = await _apiClient.dio.post(
        '/profile/avatar',
        data: formData,
      );
      return response.data['avatar_url'] as String;
    } on DioException catch (e) {
      final data = e.response?.data;
      final errors = data is Map ? data['errors'] : null;
      if (errors is Map && errors['avatar'] is List) {
        throw AvatarUploadException(
          (errors['avatar'] as List).first.toString(),
        );
      }
      if (data is Map && data['message'] is String) {
        throw AvatarUploadException(data['message'] as String);
      }
      throw AvatarUploadException(
        "Couldn't upload the photo. Check your connection and try again.",
      );
    }
  }
}

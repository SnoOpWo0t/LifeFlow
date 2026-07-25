import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';

class SettingsRepository {
  final ApiClient _apiClient;
  final SharedPreferences _prefs;

  SettingsRepository(this._apiClient, this._prefs);

  bool get isDarkMode => _prefs.getBool('is_dark_mode') ?? false;
  bool get pushNotifications => _prefs.getBool('push_notifications') ?? true;
  String get defaultCity => _prefs.getString('default_city') ?? 'London';
  double get monthlyBudget => _prefs.getDouble('monthly_budget') ?? 0.0;

  Future<void> saveSettings({
    bool? isDarkMode,
    bool? pushNotifications,
    String? defaultCity,
    double? monthlyBudget,
  }) async {
    // 1. Save locally for instant UI update
    if (isDarkMode != null) await _prefs.setBool('is_dark_mode', isDarkMode);
    if (pushNotifications != null)
      await _prefs.setBool('push_notifications', pushNotifications);
    if (defaultCity != null)
      await _prefs.setString('default_city', defaultCity);
    if (monthlyBudget != null)
      await _prefs.setDouble('monthly_budget', monthlyBudget);

    // 2. Sync silently to cloud
    try {
      await _apiClient.dio.put(
        '/profile/settings',
        data: {
          'preferences': {
            if (isDarkMode != null) 'is_dark_mode': isDarkMode,
            if (pushNotifications != null) 'push_notifications': pushNotifications,
            if (defaultCity != null) 'default_city': defaultCity,
            if (monthlyBudget != null) 'monthly_budget': monthlyBudget,
          },
        },
      );
    } catch (e) {
      // Sync failed, but local state remains intact
    }
  }

  Future<String?> uploadAvatar(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    });

    try {
      final response = await _apiClient.dio.post(
        '/profile/avatar',
        data: formData,
      );
      return response.data['avatar_url'];
    } catch (e) {
      return null;
    }
  }
}


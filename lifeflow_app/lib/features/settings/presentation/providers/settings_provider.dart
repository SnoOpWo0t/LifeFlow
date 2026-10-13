import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/location_service.dart';
import '../../data/settings_repository.dart';
import '../../domain/weather_location.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(apiClientProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

/// Re-reads local preferences whenever the signed-in user changes, since
/// AuthNotifier swaps in that account's saved settings before emitting it.
final _signedInUserIdProvider = Provider<int?>((ref) {
  return ref.watch(authProvider.select((auth) => auth.value?.id));
});

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    ref.watch(_signedInUserIdProvider);
    return ref.watch(settingsRepositoryProvider).themeMode;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsRepositoryProvider).saveSettings(themeMode: mode);
  }
}

final weatherLocationProvider =
    NotifierProvider<WeatherLocationNotifier, WeatherLocation>(
      WeatherLocationNotifier.new,
    );

class WeatherLocationNotifier extends Notifier<WeatherLocation> {
  @override
  WeatherLocation build() {
    ref.watch(_signedInUserIdProvider);
    return ref.watch(settingsRepositoryProvider).weatherLocation;
  }

  Future<void> set(WeatherLocation location) async {
    state = location;
    await ref
        .read(settingsRepositoryProvider)
        .saveSettings(weatherLocation: location);
  }
}

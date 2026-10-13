import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../settings/domain/weather_location.dart';
import '../../../settings/presentation/providers/settings_provider.dart';

class Weather {
  final WeatherLocation location;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int code;
  final bool isDay;

  const Weather({
    required this.location,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.code,
    required this.isDay,
  });

  /// WMO weather interpretation codes, as returned by Open-Meteo.
  String get description => switch (code) {
        0 => isDay ? 'Clear sky' : 'Clear night',
        1 => 'Mainly clear',
        2 => 'Partly cloudy',
        3 => 'Overcast',
        45 || 48 => 'Fog',
        51 || 53 || 55 => 'Drizzle',
        56 || 57 => 'Freezing drizzle',
        61 => 'Light rain',
        63 => 'Rain',
        65 => 'Heavy rain',
        66 || 67 => 'Freezing rain',
        71 || 73 || 75 || 77 => 'Snow',
        80 || 81 || 82 => 'Rain showers',
        85 || 86 => 'Snow showers',
        95 => 'Thunderstorm',
        96 || 99 => 'Thunderstorm with hail',
        _ => 'Unknown',
      };

  IconData get icon => switch (code) {
        0 => isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round,
        1 || 2 => Icons.wb_cloudy_rounded,
        3 => Icons.cloud_rounded,
        45 || 48 => Icons.foggy,
        51 || 53 || 55 || 56 || 57 => Icons.grain_rounded,
        61 || 63 || 65 || 66 || 67 || 80 || 81 || 82 => Icons.umbrella_rounded,
        71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit_rounded,
        95 || 96 || 99 => Icons.thunderstorm_rounded,
        _ => Icons.cloud_rounded,
      };

  Color get color => switch (code) {
        0 || 1 => isDay ? Colors.orangeAccent : Colors.indigoAccent,
        95 || 96 || 99 => Colors.deepPurpleAccent,
        71 || 73 || 75 || 77 || 85 || 86 => Colors.lightBlueAccent,
        _ => Colors.blueAccent,
      };
}

// Open-Meteo is free and key-less. Own client so the LifeFlow token stays home.
final _weatherDio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
);

final weatherProvider = FutureProvider.autoDispose<Weather>((ref) async {
  final location = ref.watch(weatherLocationProvider);

  final response = await _weatherDio.get(
    'https://api.open-meteo.com/v1/forecast',
    queryParameters: {
      'latitude': location.latitude,
      'longitude': location.longitude,
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day',
      'timezone': 'auto',
    },
  );
  final current = response.data['current'] as Map;

  return Weather(
    location: location,
    temperature: (current['temperature_2m'] as num).toDouble(),
    feelsLike: (current['apparent_temperature'] as num).toDouble(),
    humidity: (current['relative_humidity_2m'] as num).round(),
    windSpeed: (current['wind_speed_10m'] as num).toDouble(),
    code: (current['weather_code'] as num).toInt(),
    isDay: current['is_day'] == 1,
  );
});

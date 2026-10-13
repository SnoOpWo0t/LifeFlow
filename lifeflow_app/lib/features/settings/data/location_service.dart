import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../domain/weather_location.dart';

class LocationException implements Exception {
  final String message;
  LocationException(this.message);
  @override
  String toString() => message;
}

/// City search and "use my location", built on free, key-less APIs:
/// - Open-Meteo geocoding for searching cities by name
/// - BigDataCloud's client-side reverse geocoding for naming the device's position
class LocationService {
  // Separate client: these are third-party hosts and must not receive the
  // LifeFlow bearer token that ApiClient attaches.
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  Future<List<WeatherLocation>> search(String query) async {
    final name = query.trim();
    if (name.length < 2) return const [];

    final response = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': name,
        'count': 8,
        'language': 'en',
        'format': 'json',
      },
    );
    final results = (response.data['results'] as List?) ?? const [];
    return results
        .map(
          (r) => WeatherLocation(
            name: r['name'] as String,
            region: r['admin1'] as String?,
            country: r['country'] as String?,
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<WeatherLocation> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Location services are turned off.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw LocationException(
        'Location access was blocked. Allow it in your browser or search for your city instead.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      ),
    );

    var name = 'Current location';
    String? region;
    String? country;
    try {
      final response = await _dio.get(
        'https://api.bigdatacloud.net/data/reverse-geocode-client',
        queryParameters: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'localityLanguage': 'en',
        },
      );
      final data = response.data as Map;
      final city = (data['city'] as String?) ?? '';
      final locality = (data['locality'] as String?) ?? '';
      if (city.isNotEmpty) {
        name = city;
      } else if (locality.isNotEmpty) {
        name = locality;
      }
      region = data['principalSubdivision'] as String?;
      country = data['countryName'] as String?;
    } catch (_) {
      // Coordinates are enough for the forecast; the name is a nicety.
    }

    return WeatherLocation(
      name: name,
      region: region,
      country: country,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}

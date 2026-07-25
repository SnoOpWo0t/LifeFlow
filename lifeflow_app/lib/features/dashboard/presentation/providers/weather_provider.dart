import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../settings/presentation/providers/settings_provider.dart';

final weatherProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final city = settingsRepo.defaultCity;
  
  // Geocode city
  final geoResponse = await http.get(Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1'));
  if (geoResponse.statusCode == 200) {
    final geoData = jsonDecode(geoResponse.body);
    if (geoData['results'] != null && geoData['results'].isNotEmpty) {
      final lat = geoData['results'][0]['latitude'];
      final lon = geoData['results'][0]['longitude'];
      
      // Get Weather
      final weatherResponse = await http.get(Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'));
      if (weatherResponse.statusCode == 200) {
        final weatherData = jsonDecode(weatherResponse.body);
        return {
          'temp': weatherData['current_weather']['temperature'],
          'city': city,
        };
      }
    }
  }
  return {'temp': 18.0, 'city': city}; // Fallback
});


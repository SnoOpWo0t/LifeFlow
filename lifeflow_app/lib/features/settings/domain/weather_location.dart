class WeatherLocation {
  final String name;
  final String? region;
  final String? country;
  final double latitude;
  final double longitude;

  const WeatherLocation({
    required this.name,
    this.region,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  static const fallback = WeatherLocation(
    name: 'London',
    region: 'England',
    country: 'United Kingdom',
    latitude: 51.50853,
    longitude: -0.12574,
  );

  /// "Dhaka, Bangladesh"
  String get label => [
    name,
    country,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  /// "Dhaka Division, Bangladesh"
  String get detail => [
    region,
    country,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      name: json['name'] as String,
      region: json['region'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'region': region,
      'country': country,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

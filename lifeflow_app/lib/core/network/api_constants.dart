class ApiConstants {
  // Override at build time for deployment:
  //   flutter build web --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
  // The Android app can also point at another server from the sign-in screen
  // (see StorageService.getServerUrl), which wins over this value.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1',
  );

  /// Turns what a person types ("192.168.0.105:8000", "https://x.com/") into
  /// a full API base URL, or null when it isn't a usable address.
  static String? normalizeServer(String input) {
    var value = input.trim();
    if (value.isEmpty) return null;
    if (!value.contains('://')) value = 'http://$value';
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return value.endsWith('/api/v1') ? value : '$value/api/v1';
  }

  // Auth endpoints
  static const String login = '/login';
  static const String register = '/register';
  static const String logout = '/logout';
  static const String user = '/user';
}

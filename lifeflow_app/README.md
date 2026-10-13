# LifeFlow App (Flutter)

The web, Android and iOS client for [LifeFlow](../README.md).

- **Stack:** Flutter (Dart 3), Riverpod, Dio, fl_chart, geolocator
- **Talks to:** the Laravel API at `http://127.0.0.1:8000/api/v1` by default

## Run

```bash
flutter pub get
flutter run -d web-server --web-port 8080      # → http://localhost:8080 (hot reload)
```

Low on memory? Build once and serve the files instead:

```bash
flutter build web --release --no-wasm-dry-run
cd build/web && python3 -m http.server 8080 --bind 127.0.0.1
```

Point a build at another API (e.g. production):

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

## Tests

```bash
flutter analyze
flutter test        # 6 tests in test/app_test.dart
```

## Structure

`lib/core/` holds shared code (API client, storage, theme, formatters). `lib/features/<feature>/` holds each feature, split into `data/` (API calls), `domain/` (models) and `presentation/` (providers and screens). `lib/main_screen.dart` switches between a bottom navigation bar (phones) and a side rail (≥800px).

See [HOW_TO_RUN.md](../HOW_TO_RUN.md) for full setup and troubleshooting.

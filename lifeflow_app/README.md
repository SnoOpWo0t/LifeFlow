# LifeFlow App (Flutter)

The web, Android and iOS client for [LifeFlow](../README.md): tasks, multi-wallet expenses, wishlist target purchases, habits, calendar, dashboard, analytics with AI summaries, and the AI photo scanner.

- **Stack:** Flutter (Dart 3), Riverpod, Dio, fl_chart, geolocator, flutter_timezone
- **Data:** stored on the device (sembast; IndexedDB on the web), so the app works offline and without an account; synced through `POST /sync` when signed in
- **Talks to:** the Laravel API at `http://127.0.0.1:8000/api/v1` by default (on phones, change it with **Server: …** under the Sign in button)

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

## Android APK

Download the latest: [LifeFlow.apk](https://github.com/SnoOpWo0t/LifeFlow/releases/latest/download/LifeFlow.apk). GitHub builds it: **Actions → Android APK → Run workflow** (or push a `v*` tag for a release), then download it from the run's *Artifacts* (`.github/workflows/android.yml`). App id `com.lifeflow.app`; icons in `android/app/src/main/res/mipmap-*`; optional release signing via `android/key.properties` (see `key.properties.example`). Step by step, including testing against your laptop over Wi-Fi: [HOW_TO_RUN.md, section 5](../HOW_TO_RUN.md#5--android-app-apk).

## Tests

```bash
flutter analyze
flutter test        # 41 tests: test/app_test.dart, test/offline_test.dart (device database, sync, offline sign-in)
```

## Structure

`lib/core/` holds shared code: `local/` (the on-device database), `sync/` (sync service and status), API client, storage, theme, formatters. `lib/features/<feature>/` holds each feature (auth, dashboard, calendar, tasks, expenses, wishlist with custom categories & filters, scan, insights, habits, analytics, settings), split into `data/` (repositories over the device database; API calls for the scanner, AI summaries and account), `domain/` (models) and `presentation/` (providers and screens). `lib/main_screen.dart` provides responsive navigation (ergonomic 6-destination bottom bar with a Material 3 "More" bottom sheet on phones, side rail on ≥800px) and keeps tab state active via `IndexedStack`.

See [HOW_TO_RUN.md](../HOW_TO_RUN.md) for full setup and troubleshooting.

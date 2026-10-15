# How to Run LifeFlow Locally

LifeFlow has two parts that run side by side:

| Part | Folder | Address |
|---|---|---|
| Laravel API (backend) | `lifeflow-api/` | `http://127.0.0.1:8000` |
| Flutter web app (frontend) | `lifeflow_app/` | `http://127.0.0.1:8080` |
| Android app (optional) | `lifeflow_app/android/` | APK built on GitHub, see [section 5](#5--android-app-apk) |

Start the API first. The app expects it at `http://127.0.0.1:8000/api/v1`.

---

## 1. One-time setup

### Install the tools

**Linux (Ubuntu / Zorin / Debian)**

```bash
sudo apt install php8.3-cli php8.3-curl php8.3-xml php8.3-mbstring php8.3-sqlite3 php8.3-zip php8.3-bcmath php8.3-intl

# Flutter (no root needed)
mkdir -p ~/development && cd ~/development
git clone --depth 1 -b stable https://github.com/flutter/flutter.git
echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
flutter --version
```

**Windows**

- PHP 8.3+, e.g. via [Laragon](https://laragon.org/) (the `C:\laragon\bin\php\...` path used by `start.ps1`)
- Flutter SDK, e.g. unzipped to `F:\LifeFlow\flutter`
- If they aren't on your `PATH`, add them in each new PowerShell window:
  ```powershell
  $env:Path += ";C:\laragon\bin\php\php-8.3.30-Win32-vs16-x64"
  $env:Path += ";F:\LifeFlow\flutter\bin"
  ```

You don't need to install Composer: a copy is included at `php/composer.phar`.

### Set up the API

```bash
cd lifeflow-api
php ../php/composer.phar install
cp .env.example .env              # Windows: copy .env.example .env
php artisan key:generate
touch database/database.sqlite    # Windows: type nul > database\database.sqlite
php artisan migrate
php artisan storage:link          # needed for profile photos
```

`.env` contains `APP_TIMEZONE=Asia/Dhaka`. Each user's "today" normally follows the timezone their device reports (the app sends it automatically); `APP_TIMEZONE` is only the fallback until it does.

After pulling new code, run `php artisan migrate` again: new versions can add database columns.

### Optional: turn on the AI features (photo scanner and AI summaries)

The **Scan** buttons (Expenses and Wishlist) and the **AI summary** card (Analytics) need a Google Gemini API key. A free one works:

1. Go to **https://aistudio.google.com/app/apikey**, sign in with a Google account and click **Create API key**.
2. Put it in `lifeflow-api/.env`:
   ```
   GEMINI_API_KEY=your-key-here
   GEMINI_DAILY_SCANS=40          # photos per user per day
   GEMINI_DAILY_SUMMARIES=20      # AI summaries written per user per day
   ```
3. Restart the API (`php artisan serve`, or `systemctl --user restart lifeflow-api`).

The key stays on the server; the app only sends the photo (or, for summaries, just asks for "this week" or "this month" and the server builds the numbers from your own data). Saved summaries are shown again without calling the AI. Without a key, the app says these features aren't set up and everything else works normally. Free-tier limits change, and Google may use free-tier requests to improve its models, so don't scan anything you'd consider private.

### Set up the Flutter app

```bash
cd lifeflow_app
flutter pub get
```

---

## 2. Run it

### Option A: development mode (hot reload)

Terminal 1:
```bash
cd lifeflow-api
php artisan serve
```

Terminal 2:
```bash
cd lifeflow_app
flutter run -d web-server --web-port 8080
```

Open **http://localhost:8080**. Press `r` in terminal 2 to hot-reload after editing code.

On Windows, `.\start.ps1` opens both terminals for you.

### Option B: release build (fast, low memory)

The development compiler needs about 1 GB of RAM. On a laptop with 8 GB that's also running a browser and VS Code, the system can run out of memory and kill it. A release build is compiled once and then served as plain files:

```bash
cd lifeflow_app
flutter build web --release --no-wasm-dry-run
cd build/web
python3 -m http.server 8080 --bind 127.0.0.1
```

(`--no-wasm-dry-run` skips an optional extra compile pass that uses a lot of memory.) Rebuild after changing Flutter code; there is no hot reload in this mode.

### Option C (Linux): run both as background services

These keep running after you close the terminal, and a crash elsewhere won't take them down:

```bash
systemd-run --user --unit=lifeflow-api --working-directory=$HOME/Projects/LifeFlow/lifeflow-api \
  php artisan serve --host=127.0.0.1 --port=8000
systemd-run --user --unit=lifeflow-web --working-directory=$HOME/Projects/LifeFlow/lifeflow_app/build/web \
  python3 -m http.server 8080 --bind 127.0.0.1
```

Manage them with:
```bash
systemctl --user status  lifeflow-api lifeflow-web
systemctl --user restart lifeflow-api lifeflow-web
systemctl --user stop    lifeflow-api lifeflow-web
journalctl --user -u lifeflow-api -f       # live API log
```

They don't start automatically after a reboot; run the two `systemd-run` lines again.

---

## 3. Run the tests

```bash
cd lifeflow-api && php artisan test                  # 68 backend tests
cd lifeflow_app && flutter analyze && flutter test   # static checks + 41 Flutter tests
```

The same checks run automatically on GitHub for every push (`.github/workflows/ci.yml`).

---

## 4. Deploying (pointing the app at another API)

The API address is set at build time:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

Free hosting options are covered in [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md).

### Using the Neon (PostgreSQL) database

Your laptop keeps SQLite for development. To run the API against Neon (to try it, or on the server):

1. PHP needs its PostgreSQL driver: `sudo apt install php8.3-pgsql` (on Render this is part of the deploy setup).
2. In `lifeflow-api/.env` (never commit it), switch the connection, using the connection string from Neon's **Connect** dialog:
   ```
   DB_CONNECTION=pgsql
   DB_URL="postgresql://USER:PASSWORD@HOST/neondb?sslmode=require&channel_binding=require"
   ```
3. Create the tables: `php artisan migrate --force`.

Switch back to `DB_CONNECTION=sqlite` (and remove `DB_URL`) for everyday development.

### Offline use and sync

The app keeps all data on the device and works without internet. With an account, it syncs with the API through `POST /api/v1/sync` a few seconds after each change, every 5 minutes, when the app comes back to the front, and on pull-to-refresh. Without an account (**Continue without an account** on the sign-in screen) nothing is sent anywhere; signing in later uploads it. Only the AI photo scanner and AI summaries need the server.

After pulling this version, run `php artisan migrate` once: it adds the sync columns (`uuid`, `client_updated_at`, `deleted_at`) and gives existing rows their ids.

---

## 5. 📱 Android app (APK)

You don't need Android Studio or Java: GitHub builds the APK for free (`.github/workflows/android.yml`).

### Build and install

1. Push the code to GitHub (the workflow file has to be on GitHub).
2. On GitHub, open **Actions → Android APK → Run workflow**. Leave *API base URL* empty for now and click **Run workflow**.
3. After about 10 minutes, open the finished run and download **LifeFlow-android** under *Artifacts*. The zip has two files:
   - `LifeFlow-1.0.0.apk`: works on every Android phone.
   - `LifeFlow-1.0.0-arm64.apk`: smaller, for almost every phone made since 2017.
4. Copy one to your phone (Google Drive, USB, Telegram…) and open it. Android asks you to allow **Install unknown apps** for the app you opened it from; allow it once.

To publish a download link for others, bump `version:` in `lifeflow_app/pubspec.yaml`, then push a tag: `git tag v1.0.1 && git push origin v1.0.1`. The APK is attached to a new **GitHub Release**.

### Use it without any server

Tap **Continue without an account**: everything works offline and is saved on the phone. Sign in later (Profile & Settings → **Sign in**) to back it up and sync; the scanner and AI summaries need that.

### Use it with the API on your laptop (before you deploy)

The phone can't reach `127.0.0.1` on your laptop, so point it at the laptop's Wi-Fi address:

1. Phone and laptop on the **same Wi-Fi**.
2. Find the laptop's address: `hostname -I` (Linux, first number) or `ipconfig` (Windows, "IPv4 Address"), e.g. `192.168.0.105`.
3. Start the API so other devices can reach it:
   ```bash
   cd lifeflow-api
   php artisan serve --host=0.0.0.0 --port=8000
   ```
   (If it runs as the `lifeflow-api` service: `systemctl --user stop lifeflow-api`, then run the line above, or re-create the service with `--host=0.0.0.0`.) If you use a firewall: `sudo ufw allow 8000`.
4. In the app, tap **Server: …** under the Sign in button, enter `192.168.0.105:8000` and tap **Save**. Then sign in or create an account.

Only do this on a Wi-Fi you trust: plain `http://` isn't encrypted. Once the API is deployed with `https://`, use that address instead.

### After you deploy the API

Either type the public address into **Server: …** in the app, or bake it in so nobody has to: run the workflow again with *API base URL* set to e.g. `https://lifeflow-api.onrender.com/api/v1` (or save it once as a repository variable named `API_BASE_URL` under *Settings → Secrets and variables → Actions → Variables*).

### Your own signing key (recommended before sharing)

Without one, each GitHub build is signed with a new throw-away debug key, so a newer APK **won't install over an older one** ("App not installed"): uninstall first. To fix that for good, create a key once and store it as GitHub secrets:

```bash
keytool -genkey -v -keystore lifeflow-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lifeflow
base64 -w0 lifeflow-release.jks     # copy the output
```

Add the repository secrets `ANDROID_KEYSTORE_BASE64` (that output), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`lifeflow`) and `ANDROID_KEY_PASSWORD`. Keep the `.jks` file and passwords safe and **never commit them**: losing them means you can't update the app. (`keytool` comes with Java; if you don't have Java, any online guide for "create Android keystore" works, or skip this until you need it.) For local builds, copy `lifeflow_app/android/key.properties.example` to `key.properties` (gitignored).

### Building locally instead (optional)

If you install Android Studio (or the Android SDK command-line tools and Java 17), run `flutter doctor --android-licenses` once, then:

```bash
cd lifeflow_app
flutter build apk --release --split-per-abi
# → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 💡 Troubleshooting

| Problem | Fix |
|---|---|
| `php` / `flutter` not recognised | The tool isn't on your `PATH`. See "Install the tools" above |
| Laravel error about a missing extension (`mbstring`, `dom`, `pdo_sqlite`…) | Linux: `sudo apt install php8.3-<name>`. Windows: enable it in `php.ini` |
| **"Address already in use"** on port 8000 | Another server (e.g. a FastAPI project) is using it. Find it with `ss -ltnp \| grep 8000` (Linux) or `netstat -ano \| findstr 8000` (Windows) and stop it |
| App shows **`ERR_CONNECTION_REFUSED`** or "Couldn't load…" | The API isn't running. Start it (step 2) and reload |
| Sent back to the sign-in screen unexpectedly | Your session expired or the API was reset. Sign in again |
| Servers or the compiler **stop on their own** (Linux) | The machine ran out of memory. Check with `journalctl -k \| grep -i "out of memory"`. Use Option B or C and close unused apps |
| `flutter run -d chrome` can't find Chrome (Flatpak Chrome on Linux) | Use `-d web-server` and open the link yourself, or create a wrapper: `printf '#!/bin/sh\nexec flatpak run com.google.Chrome "$@"\n' > ~/.local/bin/chrome && chmod +x ~/.local/bin/chrome && export CHROME_EXECUTABLE=~/.local/bin/chrome` |
| Profile photo upload fails | Run `php artisan storage:link`. Photos are resized to 512px before upload, so PHP's 2 MB limit isn't an issue |
| Old version of the app, icon or title after rebuilding | The release build caches itself in the browser (a Flutter service worker). Hard reload with **Ctrl+Shift+R**, or close and reopen the tab |
| Scan says "isn't set up on the server yet" | Add `GEMINI_API_KEY` to `lifeflow-api/.env` and restart the API (see "Turn on the AI photo scanner") |
| Scan says the reader is busy | Gemini's free tier is rate-limited. Wait a minute and try again |
| AI summary says "busy" or takes long | Writing a summary takes 10–30 seconds; on the free tier Gemini is sometimes overloaded. Wait a minute and tap **Write my summary** / **Refresh** again |
| Android app: "Can't reach the LifeFlow server" | Check the **Server: …** address under Sign in, that the API was started with `--host=0.0.0.0`, and that the phone is on the same Wi-Fi. Opening `http://<laptop-ip>:8000/up` in the phone's browser should show a page |
| Android: "App not installed" when updating | The new APK was signed with a different key. Uninstall the old one first, or set up your own signing key (section 5) |

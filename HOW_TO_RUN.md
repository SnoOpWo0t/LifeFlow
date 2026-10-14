# How to Run LifeFlow Locally

LifeFlow has two parts that run side by side:

| Part | Folder | Address |
|---|---|---|
| Laravel API (backend) | `lifeflow-api/` | `http://127.0.0.1:8000` |
| Flutter web app (frontend) | `lifeflow_app/` | `http://127.0.0.1:8080` |

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
cd lifeflow-api && php artisan test                  # 44 backend tests
cd lifeflow_app && flutter analyze && flutter test   # static checks + 19 Flutter tests
```

The same checks run automatically on GitHub for every push (`.github/workflows/ci.yml`).

---

## 4. Deploying (pointing the app at another API)

The API address is set at build time:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
```

Free hosting options are covered in [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md).

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

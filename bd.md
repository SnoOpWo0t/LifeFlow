# Database: where LifeFlow keeps data

LifeFlow has three places data can live. The app always uses the first; the server copy is for backup and for sharing between devices.

| Where | What | Used for |
|---|---|---|
| **On the device** | sembast (a file in the app's private folder on Android; IndexedDB in the browser) | Everything you see and edit. Works with no internet, with or without an account |
| **Your laptop** | SQLite file `lifeflow-api/database/database.sqlite` | Development. Tests use a separate in-memory SQLite database, so they never touch it |
| **Production** | **Neon PostgreSQL** (free tier) | The shared copy your phone and the web app sync with, once the API is online |

## On the device (offline-first)

All tasks, transactions, categories, habits, check-ins and wishlist items are stored on the device first. The dashboard, calendar, charts and streaks are worked out there too, so nothing needs the internet except the AI scanner, AI summaries, weather and profile photos.

With an account, the app syncs through `POST /api/v1/sync`: records get UUIDs on the device, the newest edit wins, and deletes travel as tombstones. Without an account nothing leaves the device. Logging out clears the account's data from the device (it's on the server).

## Neon PostgreSQL (production) ✅ set up

The Neon project ("Lifeflow App", branch `production`, AWS US East 2) has all 16 migrations applied. It was checked end to end by running the API against it and writing and reading back tasks, transactions (with Bengali text and decimals), categories, habits, check-ins and wishlist items through the sync and REST endpoints: everything came back exactly, older edits were ignored, deletes applied, and the test account was removed afterwards.

Things to know:

- **Two addresses:** Neon's connection string with `-pooler` in the host goes through a connection pooler (good for the running API). Use the **direct** address (the same string without `-pooler`) for `php artisan migrate`; the Docker start script does this automatically.
- **Pooler fix:** behind the pooler, PostgreSQL forgot PDO's prepared statements between queries and transactions failed ("current transaction is aborted"). `config/database.php` now lets PDO fill in values itself (`PDO::ATTR_EMULATE_PREPARES`, on by default for PostgreSQL; turn off with `DB_EMULATE_PREPARES=false`).
- **Free tier:** about 0.5 GB, and a short wake-up delay on the first query after it has been idle. It never needs un-pausing by hand.
- **The password:** the connection string contains it. Keep it only in `lifeflow-api/.env` (ignored by git) and in Render's settings, never in code or chat. If it has been shared anywhere, use **Reset password** in Neon's *Connect* dialog and update those two places.

## Using Neon from the laptop

PHP needs its PostgreSQL driver (`sudo apt install php8.3-pgsql`; a no-sudo way is in [HOW_TO_RUN.md](HOW_TO_RUN.md#using-the-neon-postgresql-database)). Then, in `lifeflow-api/.env`:

```
DB_CONNECTION=pgsql
DB_URL="postgresql://USER:PASSWORD@HOST/neondb?sslmode=require&channel_binding=require"
```

and run `php artisan migrate`. Switch back to `DB_CONNECTION=sqlite` for everyday development. Never run `php artisan test` against Neon: the tests wipe the database they run on. CI runs them on a throwaway PostgreSQL instead.

## Putting it online

| Part | Service | Catch |
|---|---|---|
| Database | **Neon** ✅ | Short wake-up delay after idling |
| Laravel API | **Render** (free web service, `Dockerfile` + `render.yaml` ready) | Sleeps when idle; first request after that takes ~30–60 s (the app doesn't mind: it works offline and syncs later) |
| Flutter web app | **Cloudflare Pages**, Netlify, Vercel or GitHub Pages | None that matters |
| Android APK | GitHub Releases ([direct link](https://github.com/SnoOpWo0t/LifeFlow/releases/latest/download/LifeFlow.apk)) | Set up your own signing key before sharing updates |
| AI (scanner + summaries) | Google Gemini free tier, key in the API's environment (`GEMINI_API_KEY`) | Rate-limited; free-tier prompts may be used by Google |

On Render: **New → Blueprint**, pick the repository, and paste `APP_KEY`, `APP_URL`, `DB_URL` (Neon's pooled string) and optionally `GEMINI_API_KEY`. Then put `https://<your-api>.onrender.com/api/v1` into the app's **Server: …** setting, or rebuild the APK with it. Full steps: [HOW_TO_RUN.md](HOW_TO_RUN.md#putting-the-api-online-render-free) and [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md).

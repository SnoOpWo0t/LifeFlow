# LifeFlow API (Laravel)

The REST backend for [LifeFlow](../README.md): authentication, tasks, habits, expenses, wishlist, calendar, dashboard, analytics, the AI photo scanner and AI summaries.

- **Stack:** Laravel 13, PHP 8.3+, Laravel Sanctum (API tokens)
- **Database:** SQLite locally (`database/database.sqlite`), **Neon PostgreSQL** in production (see [PROJECT_BLUEPRINT.md, section 1](../PROJECT_BLUEPRINT.md#1-database-and-data-storage))
- **Deploy:** `Dockerfile` + `docker-start.sh` (migrates, then serves) and the root `render.yaml`
- **Endpoints:** 43, all under `/api/v1` (including `POST /sync` for the offline-first app), listed in [PROJECT_BLUEPRINT.md](../PROJECT_BLUEPRINT.md)

## Setup

```bash
php ../php/composer.phar install     # or: composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan storage:link
php artisan serve                    # → http://127.0.0.1:8000
```

Optional: set `GEMINI_API_KEY` in `.env` (free key from https://aistudio.google.com/app/apikey) to turn on the photo scanner (`POST /api/v1/scan`) and AI summaries (`GET`/`POST /api/v1/insights`). Daily per-user limits: `GEMINI_DAILY_SCANS` (default 40) and `GEMINI_DAILY_SUMMARIES` (default 20). Without a key, both answer 503 (saved summaries can still be read) and everything else works.

Each user's "today" (habits, dashboard, weekly analytics) follows the timezone the app reports in its `X-Timezone` header, stored per user. `APP_TIMEZONE` in `.env` (default `Asia/Dhaka`) is only the fallback.

## Tests

```bash
php artisan test
```

68 tests (`tests/Feature/ApiTest.php`, `SyncTest.php`, `WishlistTest.php`, `ScanTest.php` and `InsightTest.php`, plus Laravel's examples), on an in-memory SQLite database (and on PostgreSQL in CI). They cover sync (newest edit wins, tombstones, one check-in per habit and day, rejecting other users' records), auth, rate limiting, token revocation, account deletion, data export, wishlist CRUD, custom category tagging & filtering, custom ordering, per-user data isolation (tasks, habits, transactions, categories, wishlist), per-user timezones, pagination, signed avatar links, the calendar, the wishlist, the AI photo scanner and AI summaries (with Gemini faked: only the user's own data is used, saved summaries are reused, daily limits), validation, habit streaks and the dashboard summary. They also run on every push via GitHub Actions.

## Where things are

| Path | What |
|---|---|
| `routes/api.php` | All routes; login/register are rate-limited |
| `app/Http/Controllers/` | One controller per area |
| `app/Http/Requests/` | Validation rules, one Form Request per action |
| `app/Http/Resources/` | API Resources: the exact JSON returned for each model |
| `app/Http/Middleware/UseClientTimezone.php` | Saves the user's timezone from the `X-Timezone` header |
| `app/Services/Gemini.php` | Gemini client (key from `GEMINI_API_KEY`, model fallback) |
| `app/Services/PhotoReader.php` | Photo scanner prompts, response schemas and output cleaning |
| `app/Services/InsightWriter.php` | AI summaries: the per-user digest, prompt, schema and output cleaning |
| `app/Policies/` | "Only the owner may update/delete" rules for tasks, habits, transactions, categories and wishlist |
| `app/Models/` | Eloquent models |
| `database/migrations/` | Schema (15 migrations) |

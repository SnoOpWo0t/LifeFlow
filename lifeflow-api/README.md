# LifeFlow API (Laravel)

The REST backend for [LifeFlow](../README.md): authentication, tasks, habits, expenses, dashboard and analytics.

- **Stack:** Laravel 13, PHP 8.3+, Laravel Sanctum (API tokens)
- **Database:** SQLite locally (`database/database.sqlite`), PostgreSQL in production
- **Endpoints:** 39, all under `/api/v1`, listed in [PROJECT_BLUEPRINT.md](../PROJECT_BLUEPRINT.md)

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

Each user's "today" (habits, dashboard, weekly analytics) follows the timezone the app reports in its `X-Timezone` header, stored per user. `APP_TIMEZONE` in `.env` (default `Asia/Dhaka`) is only the fallback.

## Tests

```bash
php artisan test
```

44 tests (`tests/Feature/ApiTest.php` and `tests/Feature/WishlistTest.php` plus Laravel's examples), on an in-memory SQLite database. They cover auth, rate limiting, token revocation, account deletion, data export, wishlist CRUD, custom category tagging & filtering, custom ordering, per-user data isolation (tasks, habits, transactions, categories, wishlist), per-user timezones, pagination, signed avatar links, the calendar, validation, habit streaks and the dashboard summary. They also run on every push via GitHub Actions.

## Where things are

| Path | What |
|---|---|
| `routes/api.php` | All routes; login/register are rate-limited |
| `app/Http/Controllers/` | One controller per area |
| `app/Http/Requests/` | Validation rules, one Form Request per action |
| `app/Http/Resources/` | API Resources: the exact JSON returned for each model |
| `app/Http/Middleware/UseClientTimezone.php` | Saves the user's timezone from the `X-Timezone` header |
| `app/Policies/` | "Only the owner may update/delete" rules for tasks, habits, transactions, categories and wishlist |
| `app/Models/` | Eloquent models |
| `database/migrations/` | Schema (13 migrations) |

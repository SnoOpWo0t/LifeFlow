# LifeFlow API (Laravel)

The REST backend for [LifeFlow](../README.md): authentication, tasks, habits, expenses, dashboard and analytics.

- **Stack:** Laravel 13, PHP 8.3+, Laravel Sanctum (API tokens)
- **Database:** SQLite locally (`database/database.sqlite`), PostgreSQL in production
- **Endpoints:** 26, all under `/api/v1`, listed in [PROJECT_BLUEPRINT.md](../PROJECT_BLUEPRINT.md)

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

`APP_TIMEZONE` in `.env` decides when "today" starts for habits and the dashboard (default `Asia/Dhaka`).

## Tests

```bash
php artisan test
```

19 tests (`tests/Feature/ApiTest.php` plus Laravel's examples), on an in-memory SQLite database. They cover auth, rate limiting, token revocation, per-user data isolation, validation, habit streaks and the dashboard summary. They also run on every push via GitHub Actions.

## Where things are

| Path | What |
|---|---|
| `routes/api.php` | All routes; login/register are rate-limited |
| `app/Http/Controllers/` | One controller per area |
| `app/Policies/` | "Only the owner may update/delete" rules for tasks, habits and transactions |
| `app/Models/` | Eloquent models |
| `database/migrations/` | Schema (9 migrations) |

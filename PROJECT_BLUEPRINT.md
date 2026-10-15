# LifeFlow: Project Blueprint

How LifeFlow is built today: the database, the API and the Flutter app.
Ideas that aren't built yet are listed separately at the end, under [Planned](#4-planned-not-built-yet).

---

## 1. Database schema

Laravel Eloquent on **SQLite** in development and **PostgreSQL** in production. Every user-owned table has a `user_id` foreign key with `ON DELETE CASCADE`, so deleting a user removes all their data.

**Synced tables** (`tasks`, `expense_categories`, `transactions`, `habits`, `habit_logs`, `wishlist_items`) also have `uuid` (unique; the id the app gave the record on the device), `client_updated_at` (when it was last edited, which decides which edit wins) and `deleted_at` (soft deletes, so a delete reaches other devices). A habit log's uuid is `<habit uuid>_<YYYY-MM-DD>`, so one day's check-in is one row whichever device made it. The `Syncable` model trait (`app/Models/Concerns/`) fills these in for normal API writes too.

### users
`id`, `name`, `email` (unique), `password` (hashed), `avatar_path` (file name only; the API hands out signed, expiring links), `preferences` (JSON), `timezone` (IANA name reported by the app, e.g. `Asia/Dhaka`), `provider`, `provider_id` (reserved for Google sign-in), `email_verified_at`, timestamps

`preferences` holds per-user settings that follow the account across devices:
`theme_mode` (`system` | `light` | `dark`; older accounts may still have the previous on/off `is_dark_mode`, which the app converts), `push_notifications`, `monthly_budget`, `default_city`, `weather_location` (`name`, `region`, `country`, `latitude`, `longitude`).

### tasks
`id`, `user_id`, `title`, `description`, `status` (`todo` | `in_progress` | `done`), `priority` (`low` | `medium` | `high`), `due_date`, `recurrence_rule` (`daily` | `weekly` | `monthly`; when a recurring task is marked done, its due date moves forward and it returns to `todo`), timestamps
Index: `(user_id, status)`

### habits
`id`, `user_id`, `name`, `color_hex`, `current_streak`, `longest_streak`, timestamps

### habit_logs
`id`, `habit_id`, `completed_date`, timestamps
Unique: `(habit_id, completed_date)`: a habit can be checked at most once per day.
Streaks are **recalculated from these logs**, not incremented, so they can't drift.

### expense_categories
`id`, `user_id`, `name`, `type` (`income` | `expense`), `color_hex`, timestamps

### transactions
`id`, `user_id`, `category_id` (nullable, `ON DELETE SET NULL`), `amount` (decimal 12,2), `type` (`income` | `expense`), `account` (`cash` | `bkash` | `nagad` | `bank`), `transaction_date`, `note`, timestamps
Index: `(user_id, transaction_date)`

### wishlist_items
`id`, `user_id` (foreign key, `ON DELETE CASCADE`), `title`, `note` (nullable), `estimated_price` (decimal 12,2, nullable), `priority` (`low` | `normal` | `high`), `category` (string 60, nullable), `is_purchased` (boolean), `link` (nullable), `sort_order` (integer), timestamps

### ai_insights
`id`, `user_id` (`ON DELETE CASCADE`), `period` (`week` | `month`), `period_start` (date: the Monday, or the 1st of the month), `content` (JSON: `headline`, `summary`, `highlights[]`, `suggestions[{title, detail, area}]`), timestamps (`updated_at` = when it was written)
Unique: `(user_id, period, period_start)`: one saved summary per week or month; writing again replaces it.

### Framework tables
`personal_access_tokens` (Sanctum API tokens), `sessions`, `cache`, `jobs`, `password_reset_tokens`

---

## 2. API endpoints

All under `/api/v1`. Everything except register, login and (signed) avatar links needs an `Authorization: Bearer <token>` header (Laravel Sanctum). The app also sends `X-Timezone: <IANA name>`, which the server stores on the user.
**43 endpoints** in total. Responses are built by API Resources (`app/Http/Resources/`); single objects are returned unwrapped.

### Authentication
| Method | Path | What it does |
|---|---|---|
| POST | `/register` | Create an account, returns a token. Rate-limited to 10/min per IP |
| POST | `/login` | Returns a token. Rate-limited to 10/min per IP |
| POST | `/logout` | Revokes the current token on the server |
| GET | `/user` | The signed-in user: `id`, `name`, `email`, `avatar_url` (signed link), `preferences`, `timezone`, `created_at` |

### Profile
| Method | Path | What it does |
|---|---|---|
| POST | `/profile/avatar` | Upload a profile photo (image, max 5 MB; the app resizes to 512px first) |
| PUT | `/profile/settings` | Merge new values into `preferences` |
| DELETE | `/profile` | Permanently delete the account and all its data (requires the current `password`) |
| GET | `/profile/export` | Download all account data: `?format=json` (default; everything) or `?format=csv` (transactions) |
| GET | `/avatar/{filename}` | Serve a profile photo. Requires a valid signature (links come from `/user`; they expire after about a week) |

### Dashboard & analytics
| Method | Path | What it does |
|---|---|---|
| GET | `/calendar?month=YYYY-MM` | Per-day activity for a month (defaults to the user's current month): `tasks_due`, `tasks_done`, `habits_done`, `spent`, `earned`, plus `habits_total`. Only days with activity are listed |
| GET | `/calendar/day?date=YYYY-MM-DD` | Everything on one day: tasks due, each habit with `done`, and transactions |
| GET | `/dashboard/summary` | Today's tasks (due today, overdue and open, or finished today), today's habits, this month's income/spending/budget, productivity score, recent activity, and `account_balances` (net balance per wallet: cash, bkash, nagad, bank) |
| GET | `/analytics/weekly` | Last 7 days: income, expenses and productivity per day, weekly savings, best day |

### Tasks
| Method | Path | What it does |
|---|---|---|
| GET | `/tasks` | Your tasks, ordered by due date |
| POST | `/tasks` | Create |
| GET | `/tasks/{id}` | One task (owner only; this route existed before but crashed) |
| PUT/PATCH | `/tasks/{id}` | Update (status, priority, etc.) |
| DELETE | `/tasks/{id}` | Delete |

### Habits
| Method | Path | What it does |
|---|---|---|
| GET | `/habits` | Your habits with streaks and the last 7 days of check-ins |
| POST | `/habits` | Create |
| PUT/PATCH | `/habits/{id}` | Rename / recolour |
| DELETE | `/habits/{id}` | Delete (with its history) |
| POST | `/habits/{id}/toggle` | Check or uncheck today; returns updated streaks |

### Expenses
| Method | Path | What it does |
|---|---|---|
| GET | `/categories` | Your categories |
| POST | `/categories` | Create a category |
| PUT | `/categories/{id}` | Rename / recolour / change type |
| DELETE | `/categories/{id}` | Delete; its transactions are kept without a category |
| GET | `/transactions` | Your transactions, newest first, **30 per page** (`?page=2`…): `{"data": [...], "links": {...}, "meta": {"current_page", "last_page", "total", …}}` |
| POST | `/transactions` | Create (the category must be yours; `account` is optional and a missing or `null` account means `cash`) |
| PUT | `/transactions/{id}` | Edit |
| DELETE | `/transactions/{id}` | Delete |
| GET | `/transactions/chart` | Daily income/expense totals for the last 7 days (bar chart) |
| GET | `/transactions/by-category` | This month's spending per category, largest first (donut chart) |

### AI photo scanner
| Method | Path | What it does |
|---|---|---|
| POST | `/scan` | Read a photo with Gemini and return entries to review (nothing is saved). Body: `image` (base64), `mime_type` (jpeg/png/webp/heic), `target`: `money` or `wishlist`. Returns `{"kind": "receipt", "receipt": {merchant, date, items[], extras[], discount, total}}`, `{"kind": "notes", "notes": {date, entries[{type, name, amount, category, new_category, date}]}}` or `{"kind": "wishlist", "wishlist": {items[{title, note, price, priority, category, link}]}}`. 422 when the photo isn't a receipt, note or list; 429 after the daily limit (`GEMINI_DAILY_SCANS`, default 40); 503 when no `GEMINI_API_KEY` is set |

### AI summaries
| Method | Path | What it does |
|---|---|---|
| GET | `/insights?period=week\|month` | The saved summary for the current week (Mon–Sun) or month, **without calling the AI**: `{period, from, to, configured, insight: {headline, summary, highlights[], suggestions[], generated_at} \| null, stale}`. `stale` is true when tasks, transactions, check-ins or wishlist items changed after it was written. Optional `date=YYYY-MM-DD` picks another period |
| POST | `/insights` | Write (or rewrite) that summary with Gemini from a digest of the user's own data (money vs the previous period, top categories and expenses, wallets, budget, tasks, habit check-ins, wishlist) and save it. Same body as above. 429 after the daily limit (`GEMINI_DAILY_SUMMARIES`, default 20); 503 when no key is set or the AI is busy; 502 when it fails |

### Wishlist
| Method | Path | What it does |
|---|---|---|
| GET | `/wishlist` | Your wishlist items (optional `?category=...` query filter; unpurchased first, then by sort order and creation date) |
| POST | `/wishlist` | Create item (`title`, `estimated_price`, `priority`, `category`, `note`, `link`). New items go to the top (lowest `sort_order`), matching where the app shows them |
| GET | `/wishlist/{id}` | Single item |
| PUT | `/wishlist/{id}` | Edit item (change details/category or toggle `is_purchased`) |
| DELETE | `/wishlist/{id}` | Delete item |
| POST | `/wishlist/reorder` | Bulk reorder (`{"order": [id1, id2, ...]}`) |

### Sync (offline-first)
| Method | Path | What it does |
|---|---|---|
| POST | `/sync` | Body `{"since": <cursor or null>, "changes": {"categories": [...], "tasks": [...], "habits": [...], "habit_logs": [...], "transactions": [...], "wishlist": [...]}}`. Each record is `{"id": "<uuid>", ...fields, "updated_at", "deleted_at", "created_at"}`, foreign keys as uuids (`transactions.category_id`, `habit_logs.habit_id`). The server keeps the newer edit (by `updated_at`), skips records created and deleted offline, and rejects invalid records or someone else's uuid. Reply: `{"cursor", "changes": {...every record changed since `since`, deletes included...}, "rejected": {"tasks": ["<uuid>"]}}`; an older edit that lost comes back with the server's version. Up to 1000 records per collection per call; limited to 60 calls a minute |

### Rules that apply everywhere
- **Ownership:** updates and deletes go through Laravel Policies (`app/Policies/`). Another user's record returns **403**. Lists only ever query the signed-in user's rows.
- **Validation:** every write is validated on the server by a Form Request (one class per action, `app/Http/Requests/`); failures return **422** with per-field messages, which the app shows under the matching field.
- **Time zone:** "today", "this week" and "this month" use the user's own timezone (`User::localNow()`), falling back to `APP_TIMEZONE` from `.env`. Timestamps are stored in `APP_TIMEZONE`.

---

## 3. Flutter app structure

Organised by feature. Each feature has `data/` (repositories over the on-device database, or API calls for online-only features), `domain/` (models) and `presentation/` (Riverpod providers and screens).

**Offline-first:** tasks, money, habits and the wishlist are read and written only through `LocalDb` (`core/local/`, sembast: a file on Android/desktop, IndexedDB on the web). It keeps everything in memory too, so reads are instant and providers return synchronously; every change bumps `dataVersionProvider`, which the providers watch. The dashboard, calendar, analytics, charts and streaks are calculated on the device. `SyncService` (`core/sync/`) uploads records marked `_dirty` and applies the server's changes when signed in; `syncProvider` runs it 3 s after edits, every 5 min, on resume and on pull-to-refresh. Without an account (`User.local()`, id 0) nothing is synced. The device's data belongs to the account that signed in (`owner` in the database's meta): signing in with a different account clears it, no-account data is uploaded to the new account, and logging out clears it. The AI scanner, AI summaries, profile photo and account deletion call the API directly.

```text
lifeflow_app/lib/
├── core/
│   ├── local/          # LocalDb: on-device database, in-memory copy, tombstones, change stream; open_local_db (IO / web)
│   ├── sync/           # SyncService (POST /sync) and syncProvider (when to sync, status for Settings)
│   ├── files/          # Save downloaded files (browser download on web, Downloads folder on mobile)
│   ├── network/        # Dio client: adds the token and X-Timezone, signs out on 401; API base URL (--dart-define, or the server address chosen on the phone)
│   ├── storage/        # Token, cached account (for opening offline), no-account flag, server address (SharedPreferences)
│   ├── theme/          # Material 3 light/dark themes (Outfit font)
│   └── utils/          # formatMoney(), dateKey() etc.
├── features/
│   ├── auth/           # Sign in / sign up / "Continue without an account" (plus "Server: …" on phones); AuthNotifier (account settings, device data ownership)
│   ├── dashboard/      # Summary screen, live weather provider (Open-Meteo)
│   ├── calendar/       # Dashboard calendar: month grid / week strip, dots per day, day details
│   ├── tasks/          # Kanban board (lanes on desktop, lane switcher on phones)
│   ├── expenses/       # Transactions and categories (add/edit/delete), budget, bar + category charts
│   ├── wishlist/       # Dream & plan purchases: targets, priorities, custom reordering, convert to expense
│   ├── scan/           # AI photo scanner: camera/gallery picker, review sheet (edit, untick, categories, wallet), save
│   ├── habits/         # Habit cards, check-ins, rename/delete
│   ├── analytics/      # AI summary card + weekly charts
│   ├── insights/       # AI summaries: repository (GET/POST /insights), models, summary card
│   └── settings/       # Sync status card, profile photo, appearance, weather location, export (built on the device), log out / delete account / erase device data
├── main.dart           # Providers, theme, signed-in vs signed-out routing
└── main_screen.dart    # Bottom navigation (phones) / navigation rail (≥800px)
```

**Hosting:** `lifeflow-api/Dockerfile` (PHP 8.3 + `pdo_pgsql`), `docker-start.sh` (migrates over Neon's direct address, then serves) and `render.yaml` (Render Blueprint; secrets entered in Render, never in git). The database is Neon PostgreSQL; `config/database.php` turns on PDO prepare emulation for PostgreSQL so Neon's pooled (PgBouncer) address works. CI runs the backend tests on SQLite and on PostgreSQL 16.

**Android:** `lifeflow_app/android/` (app id `com.lifeflow.app`, label "LifeFlow", adaptive launcher icons, navy launch screen, `usesCleartextTraffic` so a phone can reach an `http://` API on the local Wi-Fi while testing, release signing from `key.properties` or the debug key). The APK is built by `.github/workflows/android.yml` (universal + arm64, uploaded as artifacts, attached to a GitHub Release on `v*` tags together with a fixed-name `LifeFlow.apk`, so `releases/latest/download/LifeFlow.apk` is a permanent download link; optional `API_BASE_URL` and signing secrets).

**Responsive breakpoints:** one-lane Kanban below 700px; navigation rail from 800px; two-column dashboard from 960px; habits grid and desktop "Add" buttons from 1000px; side-by-side charts and expense list from 1100px. Page content is capped at 1200px wide.

**External services (free, no API keys):** Open-Meteo (forecast and city search), BigDataCloud (reverse geocoding for "use my location").

**AI (optional, free tier with a key):** Google Gemini, called only by the API (`app/Services/Gemini.php`, models tried in order with fallback on busy/retired models). `app/Services/InsightWriter.php` builds the summary digest (only the signed-in user's rows), the prompt and schema, and trims the reply. `app/Services/PhotoReader.php` holds the scanner's prompts, the JSON response schemas and the cleaning of every returned field (amounts, dates not after today, lengths, http(s) links only). Design adapted from the [Catalyst](https://github.com/HAVIC-47/catalyst-app) app.

---

## 4. Planned (not built yet)

These were in the original plan or came up later. See [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md) for priorities.

- Reminders / push notifications (the setting is shown as "Coming soon")
- Sign in with Google (`provider` columns already exist)
- Password reset and email verification
- PDF reports of transactions (CSV/JSON export already exists)
- Receipt photos on transactions
- Custom/unlimited user-created wallet accounts (standard Cash/bKash/Nagad/Bank already built)
- Your own calendar events and reminders (the dashboard calendar currently shows tasks, habits and money)
- Multi-currency
- AI assistant (natural-language task entry); AI summaries of the week/month are already built
- More ideas adapted from Catalyst (mood tracking, category budgets, bills, savings goals…): checklist in [NEXT_LEVEL_ROADMAP.md, section 6](NEXT_LEVEL_ROADMAP.md#6-ideas-from-catalyst-a-friends-money-and-mood-app-checklist)

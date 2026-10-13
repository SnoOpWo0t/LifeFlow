# LifeFlow: Project Blueprint

How LifeFlow is built today: the database, the API and the Flutter app.
Ideas that aren't built yet are listed separately at the end, under [Planned](#4-planned-not-built-yet).

---

## 1. Database schema

Laravel Eloquent on **SQLite** in development and **PostgreSQL** in production. Every user-owned table has a `user_id` foreign key with `ON DELETE CASCADE`, so deleting a user removes all their data.

### users
`id`, `name`, `email` (unique), `password` (hashed), `avatar_url`, `preferences` (JSON), `provider`, `provider_id` (reserved for Google sign-in), `email_verified_at`, timestamps

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
`id`, `user_id`, `category_id` (nullable, `ON DELETE SET NULL`), `amount` (decimal 12,2), `type` (`income` | `expense`), `transaction_date`, `note`, timestamps
Index: `(user_id, transaction_date)`

### Framework tables
`personal_access_tokens` (Sanctum API tokens), `sessions`, `cache`, `jobs`, `password_reset_tokens`

---

## 2. API endpoints

All under `/api/v1`. Everything except register, login and avatar images needs a `Authorization: Bearer <token>` header (Laravel Sanctum).
**29 endpoints** in total.

### Authentication
| Method | Path | What it does |
|---|---|---|
| POST | `/register` | Create an account, returns a token. Rate-limited to 10/min per IP |
| POST | `/login` | Returns a token. Rate-limited to 10/min per IP |
| POST | `/logout` | Revokes the current token on the server |
| GET | `/user` | The signed-in user, including `preferences` |

### Profile
| Method | Path | What it does |
|---|---|---|
| POST | `/profile/avatar` | Upload a profile photo (image, max 5 MB; the app resizes to 512px first) |
| PUT | `/profile/settings` | Merge new values into `preferences` |
| DELETE | `/profile` | Permanently delete the account and all its data (requires the current `password`) |
| GET | `/avatar/{filename}` | Serve a profile photo (public, CORS-enabled) |

### Dashboard & analytics
| Method | Path | What it does |
|---|---|---|
| GET | `/dashboard/summary` | Today's tasks (due today, overdue and open, or finished today), today's habits, this month's income/spending/budget, productivity score, recent activity |
| GET | `/analytics/weekly` | Last 7 days: income, expenses and productivity per day, weekly savings, best day |

### Tasks
| Method | Path | What it does |
|---|---|---|
| GET | `/tasks` | Your tasks, ordered by due date |
| POST | `/tasks` | Create |
| GET | `/tasks/{id}` | One task |
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
| GET | `/transactions` | Your transactions, newest first |
| POST | `/transactions` | Create (the category must be yours) |
| PUT | `/transactions/{id}` | Edit |
| DELETE | `/transactions/{id}` | Delete |
| GET | `/transactions/chart` | Daily income/expense totals for the chart |

### Rules that apply everywhere
- **Ownership:** updates and deletes go through Laravel Policies (`app/Policies/`). Another user's record returns **403**. Lists only ever query the signed-in user's rows.
- **Validation:** every write is validated on the server; failures return **422** with per-field messages, which the app shows under the matching field.
- **Time zone:** "today" uses `APP_TIMEZONE` from `.env`.

---

## 3. Flutter app structure

Organised by feature. Each feature has `data/` (API calls), `domain/` (models) and `presentation/` (Riverpod providers and screens).

```text
lifeflow_app/lib/
├── core/
│   ├── network/        # Dio client: adds the token, signs out on 401; API base URL (--dart-define)
│   ├── storage/        # Token storage (SharedPreferences)
│   ├── theme/          # Material 3 light/dark themes (Outfit font)
│   └── utils/          # formatMoney() etc.
├── features/
│   ├── auth/           # Sign in / sign up screen, AuthNotifier (loads account settings on sign-in)
│   ├── dashboard/      # Summary screen, live weather provider (Open-Meteo)
│   ├── tasks/          # Kanban board (lanes on desktop, lane switcher on phones)
│   ├── expenses/       # Transactions and categories (add/edit/delete), budget, bar + category charts
│   ├── habits/         # Habit cards, check-ins, rename/delete
│   ├── analytics/      # Weekly charts
│   └── settings/       # Profile photo, appearance (System/Light/Dark), weather location, delete account
├── main.dart           # Providers, theme, signed-in vs signed-out routing
└── main_screen.dart    # Bottom navigation (phones) / navigation rail (≥800px)
```

**Responsive breakpoints:** one-lane Kanban below 700px; navigation rail from 800px; two-column dashboard from 960px; habits grid and desktop "Add" buttons from 1000px; side-by-side charts and expense list from 1100px. Page content is capped at 1200px wide.

**External services (free, no API keys):** Open-Meteo (forecast and city search), BigDataCloud (reverse geocoding for "use my location").

---

## 4. Planned (not built yet)

These were in the original plan or came up later. See [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md) for priorities.

- Reminders / push notifications (the setting is shown as "Coming soon")
- Sign in with Google (`provider` columns already exist)
- Password reset and email verification
- CSV / PDF export of transactions
- Receipt photos on transactions
- Payment methods (cash / card / bank)
- Calendar and events
- Multi-currency
- AI assistant (natural-language task entry, spending insights)
- Data export (CSV / JSON)

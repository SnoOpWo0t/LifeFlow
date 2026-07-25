# LifeFlow - Project Blueprint

## 1. Database Schema (Supabase PostgreSQL)

We will use Laravel Eloquent to interact with the database. The tables will include appropriate foreign keys, timestamps, and indexes for performance.

### Core Tables

* **users**: `id`, `name`, `email`, `password`, `profile_photo_path`, `email_verified_at`, `remember_token`, `created_at`, `updated_at`

### Task Manager

* **task_categories**: `id`, `user_id`, `name`, `color_code`, `icon`, `created_at`, `updated_at`
* **tasks**: `id`, `user_id`, `category_id`, `title`, `description`, `priority` (low, medium, high), `deadline`, `status` (pending, in_progress, completed), `created_at`, `updated_at`

### Habit Tracker

* **habits**: `id`, `user_id`, `title`, `description`, `frequency` (daily, weekly, specific_days), `created_at`, `updated_at`
* **habit_completions**: `id`, `habit_id`, `completed_at`

### Expense Manager

* **payment_methods**: `id`, `user_id`, `name` (cash, card, bank), `type`, `created_at`, `updated_at`
* **expense_categories**: `id`, `user_id`, `name`, `color_code`, `icon`, `created_at`, `updated_at`
* **expenses**: `id`, `user_id`, `category_id`, `payment_method_id`, `type` (income, expense), `amount`, `description`, `date`, `receipt_path`, `is_recurring`, `recurrence_interval`, `created_at`, `updated_at`

### Calendar

* **events**: `id`, `user_id`, `title`, `description`, `start_time`, `end_time`, `is_all_day`, `type` (event, birthday, reminder), `created_at`, `updated_at`

---

## 2. API Endpoints (Laravel)

All endpoints will be prefixed with `/api/v1/` and protected by Sanctum middleware (except public auth routes).

### Authentication (`/auth`)

* `POST /register`: Create a new user account
* `POST /login`: Authenticate and return Sanctum token
* `POST /logout`: Revoke token (Auth required)
* `GET /user`: Get current authenticated user
* `PUT /user/profile`: Update profile info & picture
* `POST /password/forgot`: Request password reset link

### Dashboard (`/dashboard`)

* `GET /summary`: Returns aggregated data for today's tasks, habits, expenses, and weather.

### Tasks (`/tasks`)

* `GET /`: List tasks (with filters: status, priority, category)
* `POST /`: Create task
* `GET /{id}`: Get specific task
* `PUT /{id}`: Update task
* `DELETE /{id}`: Delete task
* `GET /categories`: List task categories
* `POST /categories`: Create task category

### Habits (`/habits`)

* `GET /`: List habits with streak/progress stats
* `POST /`: Create habit
* `PUT /{id}`: Update habit
* `DELETE /{id}`: Delete habit
* `POST /{id}/toggle`: Toggle habit completion for a specific date

### Expenses (`/expenses`)

* `GET /`: List expenses/income (with date range & category filters)
* `POST /`: Create expense (handles receipt upload to Supabase Storage)
* `PUT /{id}`: Update expense
* `DELETE /{id}`: Delete expense
* `GET /statistics`: Get monthly budget and spending charts data
* `GET /export`: Generate and return a PDF report
* `GET /categories`: List expense categories
* `GET /methods`: List payment methods

### Calendar (`/calendar`)

* `GET /events`: List events within a date range
* `POST /events`: Create event
* `PUT /events/{id}`: Update event
* `DELETE /events/{id}`: Delete event

### Weather (`/weather`)

* `GET /current`: Get current weather for user's location
* `GET /forecast`: Get 7-day forecast

### AI Assistant (`/ai`)

* `GET /insights`: Sends user's recent data (tasks, habits, expenses) to LLM and returns personalized productivity insights.

---

## 3. Flutter Folder Structure (Clean Architecture)

The Flutter application (`lifeflow-app`) will be organized by feature to maintain strict boundaries.

```text
lifeflow-app/
├── lib/
│   ├── core/                      # App-wide configurations and utilities
│   │   ├── constants/             # Colors, text styles, API keys
│   │   ├── error/                 # Failure classes, exceptions
│   │   ├── network/               # Dio client setup, interceptors
│   │   ├── routing/               # GoRouter configuration & ShellRoute
│   │   ├── storage/               # Hive/SharedPreferences local storage wrapper
│   │   ├── theme/                 # Material 3 Light/Dark theme definitions
│   │   └── utils/                 # Helpers (date formatting, validators)
│   │
│   ├── features/                  # Feature modules
│   │   ├── auth/                  # Authentication module
│   │   │   ├── data/              # Repositories, models, data sources
│   │   │   ├── domain/            # Entities, repository interfaces
│   │   │   └── presentation/      # Riverpod providers, UI screens, widgets
│   │   ├── dashboard/
│   │   ├── tasks/
│   │   ├── expenses/
│   │   ├── calendar/
│   │   ├── weather/
│   │   ├── habits/
│   │   ├── statistics/
│   │   └── ai_assistant/
│   │
│   ├── shared/                    # Reusable widgets across multiple features
│   │   └── widgets/               # Custom buttons, text fields, loaders, error states
│   │
│   └── main.dart                  # App entry point, ProviderScope initialization
```

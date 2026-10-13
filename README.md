<div align="center">
  <img src="Life%20Flow%20LOGO/LF%202.png" alt="LifeFlow Logo" width="850" height="auto">

# LifeFlow 🌱

**Your All-In-One Life Management Platform for Phone and Desktop** 📱💻

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Laravel Version](https://img.shields.io/badge/Laravel-13.x-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)](https://laravel.com)
[![CI](https://img.shields.io/github/actions/workflow/status/SnoOpWo0t/LifeFlow/ci.yml?style=for-the-badge&label=CI)](https://github.com/SnoOpWo0t/LifeFlow/actions)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

</div>

<br />

<div align="center">
  <i>LifeFlow brings your tasks, money and habits under one roof: one Flutter app for web, Android and iOS, backed by a secure Laravel API.</i>
</div>

---

## 📑 Table of Contents

- [About the Project](#-about-the-project)
- [Key Features](#-key-features)
- [Visuals & Demos](#-visuals--demos)
- [Architecture & Code Structure](#️-architecture--code-structure)
- [Tech Stack](#-tech-stack)
- [Quality & Security](#-quality--security)
- [Roadmap](#️-roadmap)
- [Getting Started](#️-getting-started)
- [License](#-license)
- [Contact](#-contact)

---

## 🚀 About the Project

Managing tasks, tracking habits and budgeting usually means juggling several apps that don't talk to each other. **LifeFlow** puts all three in one place.

The UI adapts to the screen. Phones get a bottom navigation bar, a one-lane-at-a-time Kanban board and thumb-reachable buttons. Desktops get a side navigation rail, multi-column layouts and side-by-side charts. Everything is stored per user on the server, so your data and settings follow you to any device.

---

## ✨ Key Features

- **📊 Dashboard:** live weather, a productivity score, **today's tasks** (due today, overdue, or finished today), habit progress, a monthly budget overview with overspend warnings, and a recent-activity feed. Two columns on desktop, one on phones.
- **📋 Kanban Task Manager:** *To Do*, *In Progress* and *Done* lanes with priorities and due dates. Drag and drop on desktop; a lane switcher and a "Move to…" menu on phones. Deleting asks for confirmation.
- **💰 Expense Tracker:** income and expenses with colour-coded categories (create, edit, delete), a monthly budget, an income-vs-expense bar chart and a **spending-by-category donut** for the month. **Tap any transaction to edit or delete it.** Amounts are shown with thousands separators (`৳ 124,123`).
- **🔥 Habit Tracker:** daily check-ins with a small animation (and a vibration on phones), a 7-day view and streaks **calculated from your check-in history**, so they're always accurate. Rename or delete habits from the card menu.
- **📈 Weekly Analytics:** an income-vs-expenses line chart and a daily productivity bar chart, with clean round-number axes.
- **🌦️ Live Weather:** search any city, or tap **"Use my current location"**. Powered by free, key-less APIs (Open-Meteo, BigDataCloud).
- **🔐 Accounts & Settings:** token login with server-side logout, profile photos (automatically resized before upload, shown on the dashboard), **appearance that follows your device** or a fixed Light/Dark choice, settings saved to your account, and **Delete account** (password-confirmed, removes all data).

---

## 📱 Visuals & Demos

### Phone

<div align="center">
  <img src="Screenshots/phone-dashboard.png" alt="Dashboard on a phone" width="24%">
  <img src="Screenshots/phone-tasks.png" alt="Task manager on a phone" width="24%">
  <img src="Screenshots/phone-expenses.png" alt="Expenses on a phone" width="24%">
  <img src="Screenshots/phone-habits.png" alt="Habits on a phone" width="24%">
</div>

### Desktop

<div align="center">
  <img src="Screenshots/desktop-dashboard.png" alt="Dashboard on desktop" width="49%">
  <img src="Screenshots/desktop-tasks.png" alt="Task manager on desktop" width="49%">
  <img src="Screenshots/desktop-expenses.png" alt="Expenses on desktop" width="49%">
  <img src="Screenshots/desktop-analytics.png" alt="Analytics on desktop" width="49%">
</div>

### Dark mode

<div align="center">
  <img src="Screenshots/phone-dashboard-dark.png" alt="Dashboard in dark mode on a phone" width="24%">
  <img src="Screenshots/phone-habits-dark.png" alt="Habits in dark mode on a phone" width="24%">
  <img src="Screenshots/desktop-dashboard-dark.png" alt="Dashboard in dark mode on desktop" width="49%">
</div>

### Sign in

<div align="center">
  <img src="Screenshots/shot-1280.png" alt="Sign-in page" width="70%">
</div>

### Video Walkthrough

Watch the walkthrough on YouTube:

[![LifeFlow YouTube Demo](https://img.youtube.com/vi/EQXaW4yCKzU/0.jpg)](https://www.youtube.com/shorts/EQXaW4yCKzU)

*Or the quick highlight reel (recorded on an earlier version of the UI):*

<div align="center">
  <img src="Life%20Flow%20github.gif" alt="App Demo GIF" width="80%" style="border-radius: 12px;">
</div>

---

## 🏗️ Architecture & Code Structure

The project is split into two apps that talk over HTTP: a **Laravel REST API** and a **Flutter client**.

* 🛡️ **Security:** the database and business rules (validation, ownership checks, streak calculation) live on the server. The Flutter app never touches the database directly.
* 🚀 **Scalability:** the API and the web app can be hosted separately; the same Flutter code builds for web, Android and iOS.
* 🔄 **Reusability:** any future client (another website, a desktop app) can use the same API.

```text
LifeFlow/
├── .github/workflows/ci.yml       # Automatic tests on every push (GitHub Actions)
├── lifeflow-api/                  # Backend REST API (Laravel)
│   ├── app/Http/Controllers/      # Auth, Dashboard, Tasks, Expenses, Habits, Analytics, Profile
│   ├── app/Policies/              # "Only the owner may edit/delete" rules
│   ├── app/Models/                # Eloquent models
│   ├── routes/api.php             # 29 endpoints under /api/v1
│   ├── database/migrations/       # Database schema
│   └── tests/Feature/ApiTest.php  # API tests
│
└── lifeflow_app/                  # Frontend (Flutter)
    ├── lib/
    │   ├── core/                  # API client, storage, theme, formatters
    │   ├── features/              # One folder per feature: data / domain / presentation
    │   │   ├── auth/              # Sign in / sign up
    │   │   ├── dashboard/         # Summary + live weather
    │   │   ├── tasks/             # Kanban board
    │   │   ├── expenses/          # Transactions, categories, budget
    │   │   ├── habits/            # Habit cards and streaks
    │   │   ├── analytics/         # Weekly charts
    │   │   └── settings/          # Profile, preferences, weather location
    │   ├── main.dart              # App entry point
    │   └── main_screen.dart       # Responsive navigation (bottom bar / side rail)
    └── test/app_test.dart         # Flutter unit and widget tests
```

More detail (database tables, every endpoint) is in [PROJECT_BLUEPRINT.md](PROJECT_BLUEPRINT.md).

---

## 💻 Tech Stack

**Frontend (web, Android, iOS)**

- **Framework:** [Flutter](https://flutter.dev/) (Dart 3)
- **State management:** [Riverpod](https://riverpod.dev/)
- **Networking:** Dio
- **Charts:** fl_chart
- **Other:** google_fonts, image_picker, geolocator, shared_preferences

**Backend (REST API)**

- **Framework:** [Laravel 13](https://laravel.com/) on PHP 8.3+
- **Authentication:** Laravel Sanctum (revocable API tokens)

**Database**

- **Development:** SQLite (a single local file)
- **Production:** PostgreSQL (e.g. Neon's free tier); see [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md)

**Free external APIs (no keys needed)**

- [Open-Meteo](https://open-meteo.com/): weather forecasts and city search
- [BigDataCloud](https://www.bigdatacloud.com/): turning your location into a city name

---

## ✅ Quality & Security

- **Automated tests:** 21 backend tests (PHPUnit) and 10 Flutter tests, run on every push by GitHub Actions.
- **Data isolation:** every write goes through Laravel Policies; users can't read or change each other's data (covered by tests).
- **Login protection:** passwords are hashed, login/register are limited to 10 attempts per minute, logout revokes the token on the server, and an expired session returns you to the sign-in screen.
- **Validation:** on the server for every request, and in the forms before anything is sent.

---

## 🛣️ Roadmap

- [x] Appearance: follow the device, or always Light / Dark
- [x] Live weather with city search and geolocation
- [x] Edit and delete transactions and categories; rename and delete habits
- [x] Spending-by-category chart
- [x] Delete account (with all data)
- [x] Responsive layouts for phone and desktop
- [x] Automated tests and CI
- [ ] Reminders / push notifications for habits and overdue tasks
- [ ] Sign in with Google
- [ ] Data export (CSV / PDF)
- [ ] Multi-currency support
- [ ] AI assistant for adding tasks in plain language
- [ ] Public deployment (free hosting)

The full prioritised list, all of it doable for free, is in [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md).

---

## 🛠️ Getting Started

Step-by-step instructions for **Linux and Windows**, including troubleshooting, are in **[HOW_TO_RUN.md](HOW_TO_RUN.md)**. Short version:

### Prerequisites

- PHP 8.3+ with the `mbstring`, `xml`, `curl`, `sqlite3`, `zip`, `bcmath` and `intl` extensions
- [Composer](https://getcomposer.org/) (a copy is included at `php/composer.phar`)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)

### 1. Backend (Laravel)

```bash
cd lifeflow-api
composer install                      # or: php ../php/composer.phar install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan storage:link
php artisan serve                     # → http://127.0.0.1:8000
```

### 2. Frontend (Flutter)

```bash
cd lifeflow_app
flutter pub get
flutter run -d web-server --web-port 8080     # → http://localhost:8080
```

### 3. Run the tests

```bash
cd lifeflow-api && php artisan test
cd lifeflow_app && flutter analyze && flutter test
```

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

## 📬 Contact

**Afrin Sultana Akhi**, Creator & Lead Developer

- **Portfolio:** [afrinsultana-akhi.vercel.app](https://afrinsultana-akhi.vercel.app/)
- **LinkedIn:** [afrin-sultana-akhi](https://www.linkedin.com/in/afrin-sultana-akhi-1ab3a4422/)
- **GitHub:** [@SnoOpWo0t](https://github.com/SnoOpWo0t)

<p align="right"><a href="#lifeflow-">⬆️ Back to top</a></p>

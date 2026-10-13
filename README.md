<div align="center">
  <img src="Life%20Flow%20LOGO/LF%202.png" alt="LifeFlow Logo" width="850" height="auto">

# LifeFlow 🌱

**Your Intelligent All-In-One Mobile-First Life Management Platform** 📱✨

[![Flutter Version](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Laravel Version](https://img.shields.io/badge/Laravel-11.x-FF2D20?style=for-the-badge&logo=laravel&logoColor=white)](https://laravel.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg?style=for-the-badge)](LICENSE)

</div>

<br />

<div align="center">
  <i>LifeFlow brings your tasks, finances, and habits under one roof with a stunning glassmorphism interface, backed by a powerful AI assistant. 🤖💎</i>
</div>

---

## 📑 Table of Contents

- [About the Project](#-about-the-project)
- [Key Features](#-key-features)
- [Visuals &amp; Demos](#-visuals--demos)
  - [Screenshots](#screenshots)
  - [Video Walkthrough](#video-walkthrough)
- [Architecture &amp; Code Structure](#-architecture--code-structure)
- [Tech Stack](#-tech-stack)
- [Future Roadmap](#-future-roadmap)
- [Getting Started](#-getting-started)
- [License](#-license)
- [Contact](#-contact)

---

## 🚀 About the Project

In today's fast-paced world, managing tasks, tracking habits, and budgeting finances often requires juggling multiple disjointed apps. **LifeFlow** is designed to solve this by providing a single, unified ecosystem.

Designed with a **mobile-first approach**, LifeFlow delivers a premium, native-app feel across all devices. The UI is fully responsive, working seamlessly across both PC Web browsers and Mobile devices. Featuring rich glassmorphism elements, dynamic charts, and micro-animations, it offers a seamless user experience. Furthermore, an integrated AI Assistant helps you analyze your spending habits and prioritize your day.

---

## ✨ Key Features

- **📊 Comprehensive Dashboard:** Real-time budget overviews, dynamic productivity scores, weather integrations, and a live recent activity feed—all at a glance.
- **📋 Kanban Task Manager:** Effortlessly organize your work with intuitive *To-Do*, *In Progress*, and *Done* lanes. Includes task priorities and due dates.
- **💰 Smart Expense Tracker:** Track income and expenses, set strict monthly budgets (with alerts), and visualize your spending patterns with interactive Donut and Bar charts.
- **🔥 Habit Tracker:** Build lasting routines with a visual streak system, daily check-ins, and weekly progress overviews.
- **📈 Weekly Analytics:** A dedicated analytics page featuring interactive line charts for task tracking and grouped bar charts for income vs. expense tracking.
- **🤖 Integrated AI Assistant:** Receive intelligent, data-driven suggestions on your financial health and task prioritization (Coming soon).
- **🔐 Secure & Persistent Auth:** Robust token-based authentication with seamless session persistence and profile image uploads.

---

## 📱 Visuals & Demos

### Screenshots

<div align="center">
  <img src="Screenshots/home%20Dark.png" alt="Dashboard Dark" width="30%">
   
  <img src="Screenshots/Expense%20Manager.png" alt="Expense Manager" width="30%">
   
  <img src="Screenshots/Habit%20Tracker.png" alt="Habits Tracker" width="30%">
</div>

<br>

<div align="center">
  <img src="Screenshots/Task%20manager.png" alt="Task Manager" width="30%">
   
  <img src="Screenshots/Weekly%20analytics.png" alt="Weekly Analytics" width="30%">
   
  <img src="Screenshots/Home%20Light.png" alt="Dashboard Light Mode" width="30%">
</div>

### Video Walkthrough

Watch the full 1080p deep-dive walkthrough on YouTube!

[![LifeFlow YouTube Demo](https://img.youtube.com/vi/EQXaW4yCKzU/0.jpg)](https://www.youtube.com/shorts/EQXaW4yCKzU)

*Or watch the quick highlight reel below:*

<div align="center">
  <img src="Life%20Flow%20github.gif" alt="App Demo GIF" width="80%" style="border-radius: 12px;">
</div>

## 🏗️ Architecture & Code Structure

LifeFlow utilizes **Clean Architecture** to ensure the codebase remains maintainable, testable, and highly scalable.

### Why Two Separate Folders?

You will notice the project is split into two main directories: `lifeflow-api` and `lifeflow_app`. This is a professional industry standard known as **Frontend/Backend Decoupling (or Headless Architecture)**.

* 🛡️ **Security:** The database and business logic (Laravel) live in the API folder. The Flutter app never talks to the database directly, preventing malicious attacks.
* 🚀 **Scalability:** You can host the Laravel API on a powerful cloud server (like AWS or DigitalOcean) while the Flutter app can be compiled to Web, iOS, and Android seamlessly.
* 🔄 **Reusability:** If you ever want to build a React website or a desktop app in the future, they can all securely connect to the exact same `lifeflow-api` without rewriting any logic!

```text
LifeFlow/
├── lifeflow-api/                  # Backend REST API
│   ├── app/Http/Controllers/      # API Controllers (Dashboard, Expenses, Tasks)
│   ├── app/Models/                # Eloquent Models
│   ├── routes/api.php             # API routing
│   └── database/migrations/       # Database schemas
│
└── lifeflow_app/                  # Frontend Application
    └── lib/
        ├── core/                  # Network client, theme, storage
        ├── features/              # Feature-based folder structure
        │   ├── auth/              # Authentication UI & Logic
        │   ├── dashboard/         # Dashboard & Summary API Logic
        │   ├── analytics/         # Weekly Analytics & Charts
        │   ├── expenses/          # Transaction tracking & Charts
        │   ├── habits/            # Habit trackers & logs
        │   ├── tasks/             # Task manager & Kanban board
        │   └── settings/          # User preferences & Profile
        └── main.dart              # App entry point
```

---

## 💻 Tech Stack

**Frontend (Mobile & Web)**

- **Framework:** [Flutter 3.x](https://flutter.dev/)
- **State Management:** [Riverpod](https://riverpod.dev/)
- **Networking:** Dio
- **Data Visualization:** FL Chart

**Backend (REST API)**

- **Framework:** [Laravel 11.x](https://laravel.com/)
- **Language:** PHP 8.2+
- **Authentication:** Laravel Sanctum

**Database**

- **Development:** SQLite
- **Production:** MySQL / PostgreSQL

---

## 🛣️ Future Roadmap

- [ ]  **Dark/Light Mode Toggle:** User-customizable UI themes.
- [ ]  **Push Notifications:** Reminders for habits and overdue tasks.
- [ ]  **Data Export:** Export expense reports to CSV/PDF.
- [ ]  **Multi-Currency Support:** For international users.
- [ ]  **Proactive AI Chatbot:** Conversational AI interface for adding tasks via natural language.

---

## 🛠️ Getting Started

Follow these instructions to set up the LifeFlow development environment locally.

### Prerequisites

- [PHP 8.2+](https://www.php.net/) & [Composer](https://getcomposer.org/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- SQLite (or your preferred SQL database)

### 1. Backend Setup (Laravel)

Navigate to the API directory:

```bash
cd lifeflow-api
```

Install dependencies and copy environment variables:

```bash
composer install
cp .env.example .env
php artisan key:generate
```

Run database migrations to build the tables:

```bash
php artisan migrate
```

Start the local server:

```bash
php artisan serve
```

*The API will run securely at `http://localhost:8000`.*

### 2. Frontend Setup (Flutter)

In a new terminal window, navigate to the Flutter app directory:

```bash
cd lifeflow_app
```

Install packages:

```bash
flutter pub get
```

Run the application (for Web):

```bash
flutter run -d web-server --web-port 8080
```

*The application will be accessible at `http://localhost:8080`.*

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.

---

## 📬 Contact

**Afrin Sultana Akhi**Creator & Lead Developer

- **Portfolio:** [afrinsultana-akhi.vercel.app](https://afrinsultana-akhi.vercel.app/)
- **LinkedIn:** [afrin-sultana-akhi](https://www.linkedin.com/in/afrin-sultana-akhi-1ab3a4422/)
- **GitHub:** [@SnoOpWo0t](https://github.com/SnoOpWo0t)

<p align="right"><a href="#lifeflow-">⬆️ Back to top</a></p>

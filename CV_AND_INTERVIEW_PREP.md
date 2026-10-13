# LifeFlow: CV Entry & Interview Prep

Prep notes for presenting **LifeFlow** on a CV and talking about it in interviews.
Every fact below comes from the actual codebase, so you can defend each one.

---

## 1. The project in one breath

**One-liner (for the CV):**
> A cross-platform life-management app (Flutter + Laravel) that combines a Kanban task manager, expense and budget tracker, habit tracker, and weekly analytics behind one secure REST API.

**30-second pitch (for "tell me about a project"):**
> "LifeFlow is a full-stack app I designed and built on my own. People usually juggle separate apps for tasks, money and habits, so I put all three in one place. The frontend is Flutter, so a single codebase runs on web, Android and iOS. It uses Riverpod for state management and fl_chart for the charts. The backend is a Laravel REST API with token authentication through Sanctum. Each user's data is isolated on the server, and the dashboard combines everything into a productivity score, budget overview and recent-activity feed. I also added live weather using a free API, with city search and 'use my location'."

---

## 2. CV entry

### Option A: Full-stack focus (recommended)

**LifeFlow: Personal Productivity & Finance Platform** | *Flutter, Dart, Riverpod, Laravel, PHP, REST API, SQLite/PostgreSQL*
*Personal project · Sole developer* · [github.com/your-username/LifeFlow](#)

- Designed and built a full-stack, cross-platform app (web, Android, iOS) from one **Flutter** codebase, combining task management, expense tracking, habit tracking and analytics.
- Built a versioned **Laravel REST API** with **23 endpoints**, secured by **Laravel Sanctum** token authentication, with server-side checks so users can only access their own data.
- Modelled a relational schema with **8 migrations**: foreign keys with cascade deletes, enum-constrained status fields, and a composite unique index that stops a habit being logged twice in one day.
- Built a **Kanban task board** (To-Do / In Progress / Done) with priorities and due dates, and a **habit tracker** that calculates current and longest streaks on the server.
- Built an **expense tracker** with custom categories, monthly budgets and over-budget warnings, and visualised spending with **fl_chart** donut, bar and line charts.
- Combined data from every module into one dashboard endpoint: a **productivity score** from task and habit completion, plus a budget overview and a recent-activity feed.
- Organised the Flutter app by feature (`data / domain / presentation`), using **Riverpod** for reactive state and **Dio** with an interceptor that attaches the auth token to every request.
- Integrated free, key-less APIs (**Open-Meteo** weather and geocoding, **BigDataCloud** reverse geocoding) for live weather, with city search and device geolocation.
- Made the layout adapt to the screen: a navigation rail on desktop, a bottom navigation bar on mobile, plus light and dark themes.

### Option B: Shorter version (when space is tight, 3–4 bullets)

- Built a cross-platform productivity app in **Flutter** (web/Android/iOS) with a **Laravel REST API** (23 endpoints) and **Sanctum** token authentication.
- Built Kanban tasks, expense and budget tracking with charts, and habit streaks, each scoped to the signed-in user.
- Designed a relational schema with foreign keys, cascades and unique constraints; SQLite in development, PostgreSQL-ready for production.
- Added live weather with city search and geolocation through free public APIs; responsive UI with light and dark themes.

### How to write good bullets (the formula)

**Action verb + what you built + technology + why it matters / result**

| ❌ Weak | ✅ Strong |
|---|---|
| "Made a to-do app" | "Built a Kanban task board with priorities and due dates in Flutter, backed by a Laravel REST API" |
| "Used Laravel" | "Secured the API with Sanctum token auth and server-side ownership checks on every resource" |
| "Worked on the database" | "Designed a relational schema with cascading foreign keys and a unique index preventing duplicate daily habit logs" |

**Strong verbs:** Designed, Built, Engineered, Implemented, Integrated, Architected, Optimised, Secured, Modelled, Diagnosed, Deployed.

**Rules:**
- **Never invent numbers.** "23 endpoints" and "8 migrations" are real, so use them. Don't write "10,000 users" or "40% faster" unless you measured it.
- **Add real metrics later** if you can: users after deployment, Lighthouse score, API response time, test coverage %.
- **Always include links:** GitHub repo, live demo (once deployed), and the demo video (`Life Flow github.mp4`).
- **Put it high on the CV** if you're a student or junior. A complete full-stack project is a strong signal.

### Skills section keywords (from this project)

**Languages:** Dart, PHP, SQL
**Frontend:** Flutter, Riverpod, Material 3, fl_chart, responsive design
**Backend:** Laravel, REST API design, Laravel Sanctum, Eloquent ORM, migrations
**Databases:** SQLite, PostgreSQL / MySQL (relational design)
**Tools:** Git, Dio, Composer, Postman/cURL, Open-Meteo API

---

## 3. Quick facts cheat sheet (memorise these)

| Fact | Value |
|---|---|
| Frontend | Flutter (Dart 3), Riverpod 3, Dio, fl_chart, google_fonts, image_picker, geolocator |
| Backend | Laravel 13 (PHP 8.3+), Laravel Sanctum |
| Database | SQLite in development; PostgreSQL/MySQL for production |
| API | 23 endpoints under `/api/v1` |
| Tables | users, tasks, expense_categories, transactions, habits, habit_logs, personal_access_tokens (+ Laravel cache/jobs) |
| Size | ~4,900 lines of Dart, ~1,200 lines of PHP (app code, routes, migrations) |
| Modules | Auth, Dashboard, Tasks, Expenses, Habits, Analytics, Settings/Profile |
| Platforms | Web, Android, iOS (plus desktop scaffolding) |
| Free APIs | Open-Meteo (weather + geocoding), BigDataCloud (reverse geocoding) |

> Note: the README says "Laravel 11.x / PHP 8.2+", but `composer.json` actually requires **Laravel 13 and PHP 8.3**. Fix the README so an interviewer doesn't spot the mismatch.

---

## 4. Interview questions & model answers

Answer in your own words. Interviewers can tell when someone is reciting, so use these to understand the reasoning, not to memorise text.

### A. Project overview

**Q1. Tell me about this project.**
> Use the 30-second pitch from section 1. Then stop and let them choose what to dig into.

**Q2. Why did you build it?**
> "I was using separate apps for to-dos, budgeting and habits, and none of them talked to each other. I wanted one place, and I wanted a project that covered the full stack: mobile UI, API design, authentication and database design."

**Q3. What was the hardest part?**
> Pick one real story and tell it with **STAR** (Situation, Task, Action, Result). Good candidates:
> - **Avatar uploads failing inconsistently.** Small images worked and large ones didn't. I traced it to PHP's default `upload_max_filesize` of 2 MB, while the app sent full-resolution photos and ignored the error. The fix: resize to 512px on the client before uploading (smaller, faster uploads) and show the real validation error to the user.
> - **Settings not following the user.** Preferences were saved to the server but never read back, so they were lost on a new browser. I made the server the source of truth: load preferences on login, upload local ones if the account has none, clear them on logout.

**Q4. What would you do differently?**
> "I'd write automated tests from the start. Right now there are only the framework's example tests. I'd also move ownership checks into Laravel Policies instead of repeating `if ($task->user_id !== ...)` in each controller, and I'd deploy earlier so I could get feedback from real users."

### B. Architecture

**Q5. Why separate the Flutter app and the Laravel API instead of connecting Flutter straight to a database?**
> "Security and flexibility. The client never holds database credentials, and all business rules (validation, ownership, streak calculation) run on the server where users can't tamper with them. It also means I can add another client, like a separate web frontend, without touching the backend."

**Q6. How is the Flutter code organised?**
> "By feature: `features/tasks`, `features/expenses` and so on. Each feature has three layers: `data` (repositories and API calls), `domain` (models) and `presentation` (screens and Riverpod providers). Shared code like the API client, storage and theme lives in `core/`. A feature is self-contained, and the UI never calls HTTP directly."

**Q7. Why Riverpod for state management?**
> "It's compile-time safe, doesn't depend on `BuildContext`, and providers can depend on other providers. For example, the weather provider watches the location provider and refetches automatically when the city changes. `AsyncValue` gives me loading, error and data states, so every screen handles all three."

**Q8. How does a request travel from a button tap to the database?**
> "The widget calls a Riverpod notifier, the notifier calls a repository, and the repository uses Dio to call the Laravel API. A Dio interceptor adds the `Authorization: Bearer <token>` header. In Laravel, the Sanctum middleware authenticates the token, the controller validates the input and checks ownership, and Eloquent writes to the database. The JSON response is parsed into a Dart model and the provider updates its state, which rebuilds the UI."

### C. Backend & API

**Q9. How does authentication work?**
> "On register or login, Laravel checks the credentials (passwords are hashed with bcrypt) and creates a **Sanctum personal access token**. The app stores the token locally with SharedPreferences, and the Dio interceptor attaches it to every request. Protected routes sit behind `auth:sanctum` middleware. On app start, the app calls `/user`; if the token is invalid it's deleted and the user sees the login screen."

**Q10. Why Sanctum and not JWT?**
> "Sanctum is Laravel's built-in, lightweight option for SPAs and mobile apps. Tokens are stored in the database, so I can revoke them, for example on logout or for a stolen device. A JWT can't be revoked before it expires without extra infrastructure. For an app this size, Sanctum is simpler and safer."

**Q11. How do you stop one user from reading or editing another user's data?**
> "Two ways. Lists are always queried through the authenticated user, e.g. `$request->user()->tasks()`, so they can only return your own rows. For update and delete, I check that `$task->user_id` matches the current user and return **403** otherwise. As an improvement, I'd move that into Laravel Policies."

**Q12. Walk me through the database design.**
> "`users` has many `tasks`, `habits`, `expense_categories` and `transactions`. Each `habit` has many `habit_logs`, one per completed day, and a `transaction` optionally belongs to a category. Foreign keys use `cascade` on delete, so deleting a user removes their data. Deleting a category uses `set null`, so the transactions stay. Status, priority and type are enums, and `habit_logs` has a **composite unique index on (habit_id, completed_date)**, so a habit can't be checked twice in one day, even if two requests arrive at once."

**Q13. How is the productivity score calculated?**
> "It's the average of two ratios: completed tasks over total tasks, and habits completed today over total habits. A ratio only counts if that category has items, so a user with no habits isn't penalised. The result is scaled to 0–100."

**Q14. How do habit streaks work?**
> "When a habit is checked off, the server looks for a log from yesterday. If there is one, the streak continues and increments; if not, it resets to 1. Unchecking decrements it, and `longest_streak` keeps the best run. A limitation: streaks are stored as counters, so editing past days could make them drift. A more robust version would calculate the streak from the logs."

**Q15. Why SQLite? Would it work in production?**
> "SQLite needs no setup, so it's great for development. In production you want a managed server database like **PostgreSQL**, because hosting platforms often wipe the local disk on redeploy, and Postgres handles concurrent writes better. Laravel abstracts the database, so switching is mostly a `.env` change plus running migrations. I'd use Supabase's free Postgres."

### D. Flutter / frontend

**Q16. How did you make it work on both phone and desktop?**
> "I check the screen width. At 800px and above the app uses a `NavigationRail` on the side; below that it uses a bottom `NavigationBar`. The login screen uses a `LayoutBuilder`: a two-column layout on wide screens and a single centred card with a max width on phones, so the form never stretches across a big monitor."

**Q17. How do you handle loading and errors?**
> "Network-backed state is an `AsyncValue`, so screens render `loading`, `error` and `data` explicitly. One bug I fixed: the root widget swapped the whole app for a spinner during login, and for a dead-end error page when login failed. I changed it so only the first token check shows a splash. Login errors now stay on the form, where Laravel's validation messages appear next to the right field."

**Q18. How does the weather feature work, and why those APIs?**
> "The user searches for a city (Open-Meteo geocoding) or taps 'use my location'. That reads GPS or browser coordinates through `geolocator`, and BigDataCloud turns them into a city name. I save the coordinates, so the forecast call doesn't need to geocode again. All of these APIs are free, need no key, and support CORS for the web build. I use a separate HTTP client for them so the user's LifeFlow token is never sent to a third party."

**Q19. How are profile pictures handled?**
> "The image is picked and resized to 512px on the client, then sent as multipart form data. Laravel validates that it's an image under 5 MB, deletes the old file, stores the new one and returns its URL. If the image fails to load, the app shows the user's initials."

### E. Security

**Q20. What security measures did you take?**
> - Passwords hashed (bcrypt via Laravel's `hashed` cast)
> - Token auth with revocable Sanctum tokens
> - Server-side validation on every write endpoint
> - Ownership checks returning 403
> - Mass-assignment protection through validated input
> - The auth token is never sent to third-party APIs
> - No database credentials in the client

**Q21. Any security weaknesses you know of?**
> Admitting these shows maturity:
> - "On the web build, the token sits in `localStorage`, which an XSS bug could read. HttpOnly cookies (Sanctum's SPA mode) would be safer for web."
> - "The login endpoint has no rate limiting yet. I'd add Laravel's `throttle` middleware to slow down brute-force attempts."
> - "Avatar URLs are public: anyone with the exact URL can see the image."

### F. Testing & quality

**Q22. How did you test it?**
> Be honest:
> "Mostly manual and end-to-end testing: running the app, and hitting the API with cURL to check status codes and error shapes, for example confirming the API returns 401 for wrong credentials and 422 with field errors for invalid sign-ups. Automated tests are the next step: Laravel feature tests with `Sanctum::actingAs()` for every endpoint, including 'user A can't edit user B's task', and Flutter widget tests for the login form's validation."

### G. Deployment & scaling

**Q23. How would you deploy it for free?**
> "Database and file storage on **Supabase** (free Postgres plus S3-compatible storage for avatars), the Laravel API on **Render**'s free tier, and the Flutter web build on **Netlify** or **Cloudflare Pages**. The catches: free servers sleep when idle, so the first request is slow, and inactive Supabase projects get paused."

**Q24. What if it had 100,000 users?**
> "Add database indexes on the columns I filter by (`user_id`, `transaction_date`), cache the dashboard summary briefly, paginate transaction lists, move avatars to object storage behind a CDN, and run multiple API instances behind a load balancer. The API is stateless (tokens live in the database), so horizontal scaling is straightforward."

### H. Behavioural

**Q25. Did you use AI tools?**
> Answer honestly. Interviewers ask this a lot now, and honesty wins:
> "Yes, as an assistant. I used AI for things like debugging, UI polish and reviewing my code. I made the design decisions and I understand every part, and I'm happy to walk through any file. What I learned is that AI speeds up writing code, but I still have to verify the result. For example, I confirmed the avatar bug by testing the upload limit myself."

**Q26. What did you learn?**
> "How the pieces of a real app fit together: API contracts between frontend and backend, why validation and authorisation must live on the server, and how to manage async state cleanly. I also learned to debug across layers. A 'frontend' bug like a vanishing avatar turned out to be a PHP server setting."

**Q27. What's next for LifeFlow?**
> From the roadmap: push notifications for habit reminders and overdue tasks, CSV/PDF export of expenses, multi-currency support, an AI assistant for adding tasks in natural language, automated tests, and deploying publicly.

---

## 5. Known limitations: know these before they ask

| Area | Limitation | What you'd say |
|---|---|---|
| Tests | Only the framework's example tests | "Feature tests per endpoint are next" |
| Auth checks | Ownership checks repeated in controllers | "I'd refactor to Laravel Policies" |
| Dashboard | "Tasks today" counts **all** tasks, not just today's | "I'd filter by `due_date = today`" |
| Streaks | Stored counters, not derived from logs | "Calculate from `habit_logs` for accuracy" |
| Notifications | Toggle exists, but `notification_service.dart` depends on a package that isn't installed | "Planned with flutter_local_notifications / FCM" |
| Rate limiting | None on login | "Add `throttle:5,1` middleware" |
| Web token storage | `localStorage` | "Use Sanctum's cookie-based SPA auth on web" |

Fixing two or three of these before an interview gives you good extra stories. Policies and the "tasks today" filter are quick wins.

---

## 6. Before you send the CV: checklist

- [ ] Replace the GitHub link placeholder with your real repo URL
- [ ] Fix the README's Laravel/PHP versions (it says 11 / 8.2; the code uses 13 / 8.3)
- [ ] Add a live demo link once it's deployed
- [ ] Link the demo video or GIF from the README
- [ ] Re-read every bullet and make sure you can explain it for two minutes
- [ ] Practise the 30-second pitch out loud

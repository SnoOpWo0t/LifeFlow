# LifeFlow: CV Entry & Interview Prep

Prep notes for presenting **LifeFlow** on a CV and talking about it in interviews.
Every fact below comes from the actual codebase, so you can defend each one.

---

## 1. The project in one breath

**One-liner (for the CV):**
> A cross-platform life-management app (Flutter + Laravel) that combines a Kanban task manager, expense and budget tracker, habit tracker, and weekly analytics behind one secure, tested REST API.

**30-second pitch (for "tell me about a project"):**
> "LifeFlow is a full-stack app I designed and built on my own. People usually juggle separate apps for tasks, money and habits, so I put all three in one place. The frontend is Flutter, so a single codebase runs on web, Android and iOS, and the layout adapts from phone to desktop. It uses Riverpod for state management and fl_chart for the charts. The backend is a Laravel REST API with Sanctum token authentication and Laravel Policies, so each user can only touch their own data. It's covered by automated tests that run on every push through GitHub Actions. I also added live weather from a free API, with city search and 'use my location'."

---

## 2. CV entry

### Option A: Full-stack focus (recommended)

**LifeFlow: Personal Productivity & Finance Platform** | *Flutter, Dart, Riverpod, Laravel, PHP, REST API, SQLite/PostgreSQL*
*Personal project · Sole developer* · [github.com/SnoOpWo0t/LifeFlow](https://github.com/SnoOpWo0t/LifeFlow)

- Designed and built a full-stack, cross-platform app (web, Android, iOS) from one **Flutter** codebase, combining task management, multi-wallet expense tracking, wishlist targets, habit tracking and analytics.
- Built a versioned **Laravel REST API** with **40 endpoints**, secured by **Sanctum** token authentication, **Laravel Policies** for ownership checks, and rate limiting on login.
- Wrote **56 backend tests (PHPUnit)** and **24 Flutter tests**, run automatically on every push with **GitHub Actions** CI. They cover authentication, data isolation between users, per-user timezones, pagination, data export, wishlist CRUD, custom categories & reordering, signed links, account deletion, streak logic and validation.
- Modelled a relational schema with **14 migrations**: cascading foreign keys, enum-constrained fields, a composite unique index that prevents duplicate daily habit check-ins, and indexes on the dashboard's hot queries.
- Built a **Kanban task board** with drag-and-drop on desktop and a lane switcher on phones, and a **habit tracker** whose streaks are recalculated on the server from the check-in history.
- Built an **expense tracker** with multi-wallet account support (Cash, bKash, Nagad, Bank), editable colour-coded categories and transactions, monthly budgets with over-budget warnings, and **fl_chart** bar, line and donut charts.
- Built a **Wishlist & target purchase manager** with customizable categories (e.g. Perfume, Tech, Fashion, Books), priority tiers, estimated costs, custom drag-and-drop ordering, category filtering, and 1-tap conversion into recorded wallet expenses.
- Designed an adaptive, state-preserving UI: 6-destination bottom navigation with a Material 3 hamburger bottom sheet on phones, a desktop navigation rail, and **IndexedStack** state preservation across tabs.
- Structured the API with **Form Requests** for validation and **API Resources** for responses, **paginated** the transaction list (infinite scroll in the app), and served profile photos through **signed, expiring URLs**.
- Made "today" **timezone-aware per user**: the app reports its IANA timezone and the server computes days, weeks and months in it.
- Built a **dashboard calendar** that ties the modules together: per-day dots for tasks due, habits checked and spending (from one month-summary endpoint), with the selected day's details below.
- Integrated **Google Gemini** to turn photos of receipts, money notes and shopping lists into reviewable entries: structured JSON output via response schemas, prompts that include the user's own categories, server-side validation of every field, model fallback, a per-user daily limit, and tests that fake the AI so CI needs no key.
- Combined data from every module into one dashboard endpoint: a **productivity score**, today's tasks, live multi-wallet balances, a budget overview and a recent-activity feed.
- Integrated free, key-less APIs (**Open-Meteo**, **BigDataCloud**) for live weather, with city search and device geolocation.
- Made the UI responsive: bottom navigation and single-column layouts on phones; a navigation rail and multi-column layouts on desktop; a theme that follows the device (or a fixed Light/Dark choice).
- Added privacy controls: server-side logout that revokes the token, and password-confirmed **account deletion** that cascades through all user data.

### Option B: Shorter version (when space is tight, 3–4 bullets)

- Built a cross-platform productivity app in **Flutter** (web/Android/iOS) with a **Laravel REST API** (40 endpoints), **Sanctum** auth and **Policies** for per-user data isolation.
- Built Kanban tasks, multi-wallet expense tracking with charts and budgets, wishlist purchase planning with custom categories and filters, and habit streaks derived from check-in history; responsive phone and desktop layouts with state preservation.
- Added **56 PHPUnit + 24 Flutter tests** with **GitHub Actions** CI; found and fixed a dashboard crash and a cross-user data leak through tests.
- Added an **AI photo scanner** (Google Gemini) that turns receipts and notes screenshots into transactions after user review.
- Integrated free public APIs for live weather with city search and geolocation.

### How to write good bullets (the formula)

**Action verb + what you built + technology + why it matters / result**

| ❌ Weak | ✅ Strong |
|---|---|
| "Made a to-do app" | "Built a Kanban task board with priorities and due dates in Flutter, backed by a Laravel REST API" |
| "Used Laravel" | "Secured the API with Sanctum token auth and Laravel Policies so users can only modify their own records" |
| "Wrote some tests" | "Added 56 PHPUnit tests in GitHub Actions CI, which caught a dashboard crash for users without transactions" |

**Strong verbs:** Designed, Built, Engineered, Implemented, Integrated, Architected, Optimised, Secured, Modelled, Diagnosed, Tested, Deployed.

**Rules:**
- **Never invent numbers.** "40 endpoints", "14 migrations" and "56 tests" are real, so use them. Don't write "10,000 users" or "40% faster" unless you measured it.
- **Add real metrics later** if you can: users after deployment, Lighthouse score, API response time, test coverage %.
- **Always include links:** GitHub repo, live demo (once deployed), and the demo video.
- **Put it high on the CV** if you're a student or junior. A complete, tested full-stack project is a strong signal.

### Skills section keywords (from this project)

**Languages:** Dart, PHP, SQL
**Frontend:** Flutter, Riverpod, Material 3, fl_chart, responsive design
**Backend:** Laravel, REST API design, Laravel Sanctum, Policies, Form Requests, API Resources, pagination, signed URLs, Eloquent ORM, migrations
**AI:** Google Gemini API (vision, structured JSON output), prompt design, output validation
**Testing & DevOps:** PHPUnit, flutter_test, GitHub Actions CI
**Databases:** SQLite, PostgreSQL (relational design, indexing)
**Tools:** Git, Dio, Composer, cURL, Open-Meteo API

---

## 3. Quick facts cheat sheet (memorise these)

| Fact | Value |
|---|---|
| Frontend | Flutter (Dart 3), Riverpod 3, Dio, fl_chart, google_fonts, image_picker, geolocator, flutter_timezone |
| Backend | Laravel 13 (PHP 8.3+), Laravel Sanctum, Policies, Form Requests, API Resources |
| Database | SQLite in development; PostgreSQL for production |
| API | 40 endpoints under `/api/v1` |
| Tables | users, tasks, habits, habit_logs, expense_categories, transactions, wishlist_items, personal_access_tokens (+ Laravel cache/jobs/sessions) |
| Migrations | 14 |
| Tests | 56 backend (PHPUnit) + 24 Flutter; GitHub Actions on every push |
| Size | ~8,400 lines of Dart, ~2,500 lines of PHP (app code, routes, migrations) |
| Modules | Auth, Dashboard, Calendar, Tasks, Expenses, Wishlist, Habits, Analytics, Settings/Profile |
| Platforms | Web, Android, iOS (plus desktop scaffolding) |
| Free APIs | Open-Meteo (weather + geocoding), BigDataCloud (reverse geocoding) |

---

## 4. Interview questions & model answers

Answer in your own words. Interviewers can tell when someone is reciting, so use these to understand the reasoning, not to memorise text.

### A. Project overview

**Q1. Tell me about this project.**
> Use the 30-second pitch from section 1. Then stop and let them choose what to dig into.

**Q2. Why did you build it?**
> "I was using separate apps for to-dos, budgeting and habits, and none of them talked to each other. I wanted one place, and I wanted a project that covered the full stack: mobile UI, API design, authentication, testing and database design."

**Q3. What was the hardest part?** *(pick one story, tell it with STAR: Situation, Task, Action, Result)*
> - **A crash only some users hit.** While writing tests, the dashboard returned a 500 for a user with completed tasks but no transactions. An empty Eloquent collection's `merge()` expects models, and I was merging plain arrays into it. I converted it with `toBase()` first and kept the test so it can't come back.
> - **A cross-user data leak.** Transaction validation used `exists:expense_categories,id`, which accepts *any* user's category ID. So a request could attach someone else's category and see its name. I scoped the rule to the current user and added a test.
> - **Habit streaks drifting.** Streaks were counters incremented on each check-in, so missing a day or unchecking left them wrong. I made the server recalculate them from the check-in history. The data was already there; I just stopped duplicating it.
> - **A setting that silently did nothing.** Picking a colour for a category never saved: the dialog always sent `"#"`. Nothing crashed, so nobody noticed until I built a donut chart that uses those colours. Lesson: build features that *use* your data, and bugs in how it's stored show up.
> - **Profile photos failing "randomly".** Small images worked and large ones didn't. PHP's default `upload_max_filesize` is 2 MB and the app sent full-resolution photos while ignoring the error. I resized to 512px on the client and showed the real error.

**Q4. What would you do differently?**
> "Write tests from day one. When I added them later, they found real bugs straight away. I'd also deploy earlier to get real-user feedback, and set up a design system before building screens, so colours and spacing stay consistent."

### B. Architecture

**Q5. Why separate the Flutter app and the Laravel API instead of connecting Flutter straight to a database?**
> "Security and flexibility. The client never holds database credentials, and all business rules (validation, ownership, streak calculation) run on the server where users can't tamper with them. Any future client can reuse the same API."

**Q6. How is the Flutter code organised?**
> "By feature: `features/tasks`, `features/expenses` and so on. Each feature has `data` (API calls), `domain` (models) and `presentation` (screens and Riverpod providers). Shared code like the API client, storage, theme and formatters lives in `core/`. The UI never calls HTTP directly."

**Q7. Why Riverpod for state management?**
> "It's compile-time safe, doesn't depend on `BuildContext`, and providers can depend on other providers. For example, the weather provider watches the location provider and refetches automatically when the city changes. `AsyncValue` makes every screen handle loading, error and data explicitly."

**Q8. How does a request travel from a button tap to the database?**
> "The widget calls a Riverpod notifier, which calls a repository, which uses Dio. A Dio interceptor adds the `Authorization: Bearer` header. In Laravel, Sanctum authenticates the token, the controller validates the input, a Policy checks ownership, and Eloquent writes to the database. The JSON response becomes a Dart model, the provider updates its state, and the UI rebuilds."

### C. Backend & API

**Q9. How does authentication work?**
> "On register or login, Laravel checks the credentials (bcrypt-hashed passwords) and issues a **Sanctum personal access token**. The app stores it and the interceptor attaches it to every request. Logout calls the API, which deletes the token on the server. If any request comes back 401, for example because the token was revoked, the interceptor signs the user out and returns them to the login screen."

**Q10. Why Sanctum and not JWT?**
> "Sanctum is Laravel's built-in, lightweight option for SPAs and mobile apps. Tokens live in the database, so they can be revoked instantly, which I rely on for logout. A JWT can't be revoked before it expires without extra infrastructure."

**Q11. How do you stop one user from reading or editing another user's data?**
> "Lists are always queried through the authenticated user, so they only return your rows. Every update and delete goes through a **Laravel Policy** (`Gate::authorize('update', $task)`), which returns 403 for someone else's record. Validation is scoped too: a transaction's category must belong to the same user. All of this is covered by tests that log in as user A and try to touch user B's data."

**Q12. Walk me through the database design.**
> "`users` has many `tasks`, `habits`, `expense_categories` and `transactions`. Each habit has many `habit_logs`, one per completed day, with a **composite unique index on (habit_id, completed_date)** so double check-ins are impossible even with concurrent requests. Foreign keys cascade on user delete; deleting a category sets its transactions' category to null so the money history stays. Status, priority and type are enums, and I added composite indexes on `(user_id, transaction_date)` and `(user_id, status)` for the dashboard's queries."

**Q12b. Why Form Requests and API Resources instead of validating and returning models in the controller?**
> "Separation of concerns. A Form Request holds the validation rules for one action, so controllers only do the work, and the rules are reusable: the update request extends the create request and just makes every field optional. API Resources decide exactly which fields leave the server. Returning raw models leaked internal columns like `user_id` and `provider`, and any new column would have leaked automatically. Resources also gave me pagination metadata for free when I paginated transactions. I set `withoutWrapping()` so the JSON shape stayed the same and the app didn't need changes."

**Q12c. How does the AI photo scanner work, and how do you stop the AI from writing bad data?**
> "The app resizes the photo to about 1600px and sends it as base64 to `POST /scan`. The API calls Gemini with a system prompt that includes the user's own category names, and a **response schema**, so Gemini must answer in a fixed JSON shape (receipt, notes or wishlist items). It never trusts that answer: amounts must be positive numbers, dates must be real dates and not after the user's today, text is trimmed and length-limited, links must be http(s), and unknown categories are flagged as new. Nothing is saved on the server. The app shows every line for review: the user can fix names and amounts, untick lines, change categories or the wallet, and a receipt's discount is shared across items in whole paisa. The Gemini key lives only in the server's `.env`; each user has a daily photo limit, and if one model is busy the next is tried. Tests fake Gemini with Laravel's `Http::fake`, so CI runs without a key or network. I adapted the design from a friend's app, Catalyst, and credited it."

**Q13. How is the productivity score calculated?**
> "It averages two ratios: today's tasks done over today's tasks, and habits checked today over total habits. 'Today's tasks' means due today, overdue and still open, or finished today, where 'today' is the user's own day: the app sends its timezone and the server stores it. A ratio only counts if that category has items, so someone with no habits isn't penalised. The result is scaled to 0–100."

**Q14. How do habit streaks work?**
> "They're derived, not counted. On every load and toggle, the server reads the habit's check-in dates. The current streak is the run of consecutive days ending today, or ending yesterday if today isn't checked yet, because the streak is still alive until midnight. The longest streak is the longest run in the history. Earlier I incremented counters, and they drifted whenever a day was missed or a check-in undone."

**Q15. Why SQLite? Would it work in production?**
> "SQLite needs no setup, so it's great for development and tests (they run on an in-memory SQLite database). In production I'd use **PostgreSQL**, because hosting platforms wipe local disks on redeploy and Postgres handles concurrent writes better. Laravel abstracts the database, so switching is a `.env` change plus migrations. I also made the app parse decimal amounts that Postgres returns as strings."

### D. Flutter / frontend

**Q16. How did you make it work on both phone and desktop?**
> "I use breakpoints. Below 700px, the Kanban board shows one lane at a time with a switcher, and tasks move between lanes through a menu, because dragging fights with scrolling on touch screens. From 800px a `NavigationRail` replaces the bottom bar. Wider screens get a two-column dashboard, a habit grid and side-by-side charts. Content is capped at 1200px so it doesn't stretch across big monitors."

**Q17. How do you handle loading and errors?**
> "Network-backed state is an `AsyncValue`, so screens render loading, error (with a Retry button) and data explicitly, and lists support pull-to-refresh. One bug I fixed: during login, the root widget used to swap the whole app for a spinner, and then for a dead-end error page if login failed. Now errors stay on the form, and Laravel's validation messages appear next to the right field."

**Q18. How does the weather feature work, and why those APIs?**
> "The user searches for a city (Open-Meteo geocoding) or taps 'use my location', which gets coordinates through `geolocator` and turns them into a city name with BigDataCloud. I store the coordinates so the forecast call doesn't need to geocode again. All of these are free, need no key and support CORS. They use a separate HTTP client, so the user's LifeFlow token is never sent to a third party."

**Q19. How are profile pictures handled?**
> "The image is resized to 512px on the client and uploaded as multipart form data. A Form Request checks it's an image under 5 MB, the old file is deleted, and only the file name is stored. The API never returns a permanent URL: `/user` returns a **signed link that expires** (rounded to the day, so the browser can still cache it), and the image route rejects anything without a valid signature. If the image fails to load, the app shows the user's initials."

### E. Security

**Q20. What security and privacy measures did you take?**
> - bcrypt password hashing
> - revocable Sanctum tokens with server-side logout
> - **rate limiting** on login and register (10 per minute per IP)
> - Policies on every write, plus user-scoped validation rules
> - server-side validation on every request
> - no database credentials in the client
> - the auth token is never sent to third-party APIs
> - password-confirmed account deletion that removes all of the user's data, and a full data export
> - profile photos served only through signed, expiring links
> - API Resources, so responses never include internal columns

**Q21. Any security weaknesses you know of?**
> Admitting these shows maturity:
> - "On the web build, the token sits in `localStorage`, which an XSS bug could read. Sanctum's cookie-based SPA mode would be safer, but it needs the app and API on the same site, so it depends on where I deploy. That's a hosting decision I'd make first."
> - "There's no email verification or password reset yet."

### F. Testing & quality

**Q22. How did you test it?**
> "There are 56 backend tests in PHPUnit using an in-memory SQLite database and `Sanctum::actingAs()`. They cover registration and login, the rate limit, token revocation on logout, account deletion and data export, cross-user access returning 403 for tasks, habits, transactions, wishlist items and categories, scoped category validation, habit streaks, per-user timezones (for example a user at UTC+14 checking a habit gets *their* date), pagination, signed avatar links, wishlist CRUD, custom category tagging & query filtering, custom drag-and-drop reordering, the calendar's month summary and day details, the exact fields the user endpoint returns, and the dashboard's task counts. The 24 Flutter tests cover money formatting, the weather models, colour parsing, parsing a page of transactions, wishlist custom categories, category filter providers, category icon and color styling utilities, item conversion to wallet expenses, the calendar grid, the appearance setting's migration from the old on/off switch, and a widget test of the sign-in form's validation. GitHub Actions runs all of them, plus `flutter analyze` and a web build, on every push. The tests paid off immediately: they found a dashboard crash for users with no transactions."

### G. Deployment & scaling

**Q23. How would you deploy it for free?**
> "PostgreSQL on **Neon** (its free tier wakes up automatically), the API on **Render**'s free tier with UptimeRobot pinging it to keep it awake, and the Flutter web build on **Cloudflare Pages**. The API URL is a build-time setting (`--dart-define=API_BASE_URL`), so the same code points at local or production."

**Q24. What if it had 100,000 users?**
> "The indexes are there and the transaction list is already paginated. Next I'd briefly cache the dashboard summary, paginate the other lists, move avatars to object storage behind a CDN, and run several API instances behind a load balancer. The API is stateless (tokens live in the database), so it scales horizontally."

### H. Behavioural

**Q25. Did you use AI tools?**
> Answer honestly. Interviewers ask this a lot now:
> "Yes, as an assistant, for debugging, UI polish and reviewing my code. I made the design decisions and I understand every part, and I'm happy to walk through any file. The lesson was that AI speeds up writing code, but I still have to verify everything. That's one reason I added automated tests."

**Q26. What did you learn?**
> "How the pieces of a real app fit together: API contracts between frontend and backend, why validation and authorisation belong on the server, and how valuable tests are. They found bugs I'd never have spotted by clicking around. I also learned to debug across layers: a 'frontend' bug like a vanishing avatar turned out to be a PHP server setting."

**Q27. What's next for LifeFlow?**
> Reminders and notifications, AI summaries of spending (reusing the scanner's Gemini service), budgets per category, bills, Google sign-in, password reset, PDF reports, multi-currency, an AI assistant for adding tasks in plain language, and a public deployment. See `NEXT_LEVEL_ROADMAP.md`.

---

## 5. Known limitations: know these before they ask

| Area | Limitation | What you'd say |
|---|---|---|
| Reminders | Not implemented yet (shown as "Coming soon") | "Planned with local notifications on mobile and FCM for server push" |
| Web auth | Token in `localStorage` | "Switch to Sanctum's cookie-based SPA auth once the app and API are hosted on the same site" |
| Other lists | Tasks and habits aren't paginated (transactions are) | "Same pattern as transactions once lists get long" |
| Accounts | No password reset or email verification | "Add with Laravel's built-ins and a free email provider" |

Fixing one or two of these before an interview gives you extra stories. Password reset is a good next one.

---

## 6. Before you send the CV: checklist

- [x] GitHub link: github.com/SnoOpWo0t/LifeFlow
- [x] README versions are correct (Laravel 13, PHP 8.3)
- [x] Automated tests + CI badge in the README
- [ ] Push to GitHub and check the CI badge turns green
- [ ] Add a live demo link once it's deployed
- [ ] Record a fresh demo video (the current GIF shows an older UI)
- [ ] Re-read every bullet and make sure you can explain it for two minutes
- [ ] Practise the 30-second pitch out loud

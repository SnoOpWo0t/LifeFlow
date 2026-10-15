# LifeFlow: Next-Level Roadmap (100% free)

A prioritised list of what's done and what to improve next. Everything here can be done **without paying for anything**.

**Effort:** 🟢 under 1 hour · 🟡 half a day · 🔴 a day or more
**Impact:** ⭐ nice · ⭐⭐ noticeable · ⭐⭐⭐ big

> Free tiers change. The limits below were correct as far as I know. Check each provider's pricing page before relying on it.

---

## ✅ Done so far

### Bugs fixed
| Bug | Fix |
|---|---|
| Large profile photos failed silently (PHP's 2 MB upload limit) | Photos are resized to 512px before upload, and failures show a message |
| Settings stayed in one browser; the server copy was never read | Preferences load from the account on sign-in |
| Dashboard weather was hard-coded ("London, 18°C") | Live Open-Meteo weather, city search, "use my location" |
| A failed login replaced the whole app with an error page | The form stays on screen and shows the server's message |
| Dashboard "Tasks" counted every task ever created | Counts tasks due today, overdue and open, or finished today |
| **Dashboard crashed (500) for users with tasks but no transactions** | Fixed the collection merge; covered by a test |
| Recent Activity showed the entry date, not the transaction date | Uses the transaction's own date |
| Habit streaks drifted (counters, not history) | Recalculated from check-in history on every load and toggle |
| **Transactions could use another user's category** (and expose its name) | Category must belong to the same user; covered by a test |
| Logout didn't revoke the token on the server | Logout calls `/logout`; covered by a test |
| An expired or revoked session left every screen showing errors | Any 401 while signed in returns to the sign-in screen |
| Invalid amounts such as `1,000` crashed the transaction dialog | Commas accepted; invalid input shows a field error |
| Adding a transaction didn't refresh the dashboard | Dashboard, list and chart all refresh |
| A malformed habit colour crashed the habit card | Safe parsing with a default colour |
| Habits couldn't be deleted from the app | Delete (with confirmation) in the card menu |
| Push Notifications switch did nothing | Shown honestly as "Reminders · Coming soon" until implemented |
| Habits checked after midnight were logged on the previous day (server used UTC) | Each user's own timezone, reported by the app (`APP_TIMEZONE` is only the fallback) |
| The Flutter test file referenced a non-existent `MyApp` | Replaced with real tests |
| `notification_service.dart` didn't compile (package never installed) | Removed; reminders will be rebuilt properly (see below) |
| **Category colours were never saved** (the dialog always sent `"#"`) | The picked colour is saved; malformed colours fall back to grey |
| `GET /tasks/{id}` was routed but the controller had no `show` method (crashed) | Implemented, owner-only |
| Sending `"account": null` with a transaction crashed the API (500): the column is NOT NULL | Missing or null account now means cash; covered by a test |
| New wishlist items appeared at the top, then jumped to the bottom after a reload (server gave them the *highest* sort order) | The server puts new items first too; covered by a test |
| After tabs started staying alive (`IndexedStack`), Dashboard, Calendar and Analytics showed stale data until pulled to refresh | They reload whenever their tab is opened |
| The selected tab survived logout, so the next user opened on the previous user's last tab | The tab resets to Dashboard for every sign-in |
| Wishlist drag handles on desktop were drawn over the card's edge; "1 items" | Handle moved inside the card; correct singular/plural |
| **Scanning a shopping list: "Add to wishlist" stayed disabled ("0 of 32 selected")** even with every line ticked, because items without a price were treated as empty | Wishlist lines only need a title (the price is optional); covered by a widget test |

### Features & quality
- Login page redesign with the LifeFlow logo and brand colours
- **Edit and delete transactions** (tap a transaction); **rename and delete habits** (card menu); **edit and delete categories** (with colour picker)
- **Delete account** in Settings: password-confirmed, removes all of the user's data
- **Appearance: System / Light / Dark**. Follows the device by default; older "dark mode on" settings carry over
- **Spending-by-category donut** for the current month on the Expenses page
- Avatar (or initials) next to the greeting on the dashboard
- **Empty states** with a clear next step for tasks, transactions and habits
- Calmer habit cards (plain surface + colour strip), a pop-in tick and a vibration (phones) when checking in
- **Per-user timezone:** the app sends its IANA timezone (`X-Timezone`); "today", "this week" and "this month" follow each user's own midnight
- **Form Requests** for every write and **API Resources** for every response (no internal fields leak)
- **Paginated transactions** (30 per page) with infinite scroll; the category donut is totalled on the server
- **Export my data:** everything as JSON, or transactions as CSV
- **Private profile photos:** signed, expiring links instead of permanent public URLs
- **Dashboard calendar:** month at a glance (dots for tasks due, habits checked, spending) with the selected day's details; month grid on desktop, expandable week strip on phones
- **AI photo scanner (Gemini):** take a photo or choose a screenshot of a receipt, your money notes or a shopping list; the API reads it and you review every line (edit, untick, change category, income/expense, date, wallet) before anything is saved. Receipt discounts are shared across items, missing categories are created, the key stays on the server, and each user has a daily limit. Adapted from the Catalyst app (section 6)
- **AI summaries (Gemini):** an *AI summary* card on Analytics writes a short read of this week or this month: a headline, money (compared with the previous period), tasks and habits, highlights and 2–4 suggestions. The server builds a digest from the user's own rows only (the app never sends free text), saves the summary so re-opening it is free, shows "New data since" when it's out of date, and limits writes per user per day (`GEMINI_DAILY_SUMMARIES`). Included in *Export my data*. Adapted from Catalyst (K1)
- **Installable Android app:** `.github/workflows/android.yml` builds the APK on GitHub (no Android Studio needed): a universal APK and a smaller arm64 one as downloadable artifacts, and a GitHub Release on every `v*` tag. Real app id (`com.lifeflow.app`), the name "LifeFlow", launcher and adaptive icons from the logo, a branded launch screen, and optional release signing from GitHub secrets. A **Server address** setting on the phone's sign-in screen lets the same APK use your laptop over Wi-Fi or the deployed API. Adapted from Catalyst (K15)
- **Wishlist & target purchases:** customizable categories (e.g. Perfume, Tech, Fashion, Books), priority tiers (Low, Normal, High), estimated costs, custom drag-and-drop reordering, store link copy, target savings summary banner, category filter chips with live counts, and 1-tap conversion to recorded wallet expenses
- **Multi-wallet accounting:** support for account/wallet types (`cash`, `bkash`, `nagad`, `bank`) on transactions with live per-wallet balances on the dashboard
- **Decluttered mobile navigation:** ergonomic 6-destination bottom bar with a Material 3 hamburger "More" bottom sheet housing Wishlist and Settings
- **Tab state preservation across navigation:** views remain mounted and preserve scroll and form state via `IndexedStack`; summary tabs (Dashboard, Analytics) refresh their data each time they're opened
- **Responsive UI:** one-lane Kanban with "Move to…" on phones; two-column dashboard, side-by-side charts, habit grid and expense layout on desktop
- Pull-to-refresh on every list; Retry buttons on error screens; confirmation before deletes
- Money with thousands separators; chart axes in round numbers; chart dates like "7 Oct"
- Logout moved to Settings (with confirmation); logo in the desktop navigation
- Real app name, description and icons for the browser tab and installed app
- Login/register rate limit (10/min per IP); Laravel **Policies** for every edit/delete
- Database indexes for dashboard and analytics queries
- Configurable API address (`--dart-define=API_BASE_URL=...`)
- **61 backend tests + 29 Flutter tests**, run on every push by **GitHub Actions** (`.github/workflows/ci.yml`)
- Dead code removed (old login screen, an old unused chart function, deprecated `withOpacity`)

---

## 1. Free & permanent hosting (put it online)

The goal is a public link that keeps working without paying or babysitting it.

| Part | Use this (free) | Why | Catch |
|---|---|---|---|
| **Flutter web app** | **Cloudflare Pages** (or GitHub Pages / Netlify) | Static hosting, global CDN, free HTTPS, never sleeps | None that matters |
| **Database** | **Neon** (serverless PostgreSQL) | Free tier with no expiry; it suspends when idle and **wakes up automatically** on the next request | ~0.5 GB storage; a short delay on the first query after idling |
| **Laravel API** | **Render** (free web service, Docker) | Free, deploys from GitHub on every push | **Sleeps after ~15 min idle**, so the first request takes 30–60 s. Its disk is wiped on redeploy, so don't store files on it |
| **Keep the API awake** | **UptimeRobot** (free, checks every 5 min) | Pinging `/up` stops Render sleeping and also alerts you if the site goes down | Check Render's monthly free-hours limit covers being always on |
| **Profile photos** | **Store them in Postgres** (small, since they're resized to 512px) or **Cloudinary** free plan | No extra service needed if stored in the database; Cloudinary also resizes and serves them from a CDN | Cloudinary's free plan has monthly credits |
| **CI** | **GitHub Actions** ✅ *already set up* | Free for public repos | None |
| **Domain** | `yourapp.pages.dev` + `yourapi.onrender.com` (free subdomains) | Free and permanent | A custom `.com` costs money, so skip it |

**Why Neon and not Supabase:** Supabase's free projects **pause after about a week without activity**, and you have to un-pause them by hand. Neon wakes up by itself. Use Supabase only if you also want its file storage and don't mind the pausing.

**If you have a debit/credit card for identity verification only (never charged):** **Oracle Cloud Always Free** gives you real always-on virtual machines. That means no sleeping, and you could run the API, database and files on one server.

### Deployment steps (🔴 ⭐⭐⭐)
1. Create a Neon project and copy the connection string.
2. Add a `Dockerfile` for `lifeflow-api` (PHP 8.3 + `pdo_pgsql`), and set `DB_CONNECTION=pgsql`, `DB_URL=...`, `APP_KEY`, `APP_URL`, `APP_TIMEZONE` as Render environment variables.
3. Deploy the API on Render; run `php artisan migrate --force` as the release command.
4. `flutter build web --release --dart-define=API_BASE_URL=https://<your-api>.onrender.com/api/v1`, then deploy `build/web` to Cloudflare Pages.
5. Restrict CORS to your Pages domain (`config/cors.php`, `allowed_origins`).
6. Add an UptimeRobot monitor on `https://<your-api>.onrender.com/up`.

---

## 2. Free services that add real features

| Feature | Free service | Effort | Impact |
|---|---|---|---|
| **Habit and overdue-task reminders** | `flutter_local_notifications` (Android/iOS, on device); browser notifications for web; **Firebase Cloud Messaging** for server-sent push (free) | 🟡 | ⭐⭐⭐ |
| **Sign in with Google** | Laravel Socialite + Google OAuth (free). The `users` table already has `provider` / `provider_id` columns | 🟡 | ⭐⭐⭐ |
| **Password reset & email verification** | **Brevo** (~300 emails/day free) or **Resend** (free tier; Laravel ships a `resend` mail driver) | 🟡 | ⭐⭐ |
| **Multi-currency** | **Frankfurter API** (free, no key, European Central Bank exchange rates) | 🟡 | ⭐⭐ |
| **AI assistant** | **Google Gemini API** free tier (the photo scanner and AI summaries already use it, so `App\Services\Gemini` can be reused), called from Laravel so the key stays on the server. "Add 'pay rent' tomorrow, high priority" → creates a task. *(Weekly/monthly summaries are done.)* | 🔴 | ⭐⭐⭐ |
| **Error tracking** | **Sentry** free developer plan (Laravel + Flutter SDKs) | 🟢 | ⭐⭐ |
| **Weather forecast** (next days) | Open-Meteo (already used): add `daily=` to the same request | 🟢 | ⭐ |

> Gemini's free tier is rate-limited, and Google may use free-tier prompts to improve its products. Don't send sensitive financial details, and say so in your privacy note.

---

## 3. Remaining code improvements

| # | Item | Why it's still open | Effort | Impact |
|---|---|---|---|---|
| 1 | Web build stores the login token in `localStorage` (readable by any XSS bug) | The fix, Sanctum's cookie-based SPA login, only works when the app and API share a site (e.g. `app.example.com` + `api.example.com`). The free hosting plan in section 1 puts them on different sites (`*.pages.dev` + `*.onrender.com`), where browsers block those cookies. Decide on hosting first, then switch. Until then, Flutter's renderer and the strict server-side validation keep the XSS risk low | 🔴 | ⭐⭐ (security) |

**Resolved by design:** *habit "longest streak" counts only the stored history.* Check-ins are only ever removed by unchecking *today*, or by deleting the whole habit, so the stored history is the full history and the derived longest streak is exact. The data export also includes every check-in.


---

## 4. Remaining UI / frontend improvements

| # | Change | Effort | Impact |
|---|---|---|---|
| A1 | **One design system.** The login page uses navy + cyan→violet (from the logo); the rest of the app uses an indigo theme with ad-hoc colours. Create `AppColors`/`AppSpacing` tokens and use them everywhere | 🟡 | ⭐⭐⭐ |
| C1 | Tap a chart bar to see that day's transactions | 🟡 | ⭐⭐ |
| D2 | Skeleton loaders instead of spinners | 🟡 | ⭐⭐ |
| D3 | **Undo** snackbar after delete or habit uncheck | 🟡 | ⭐⭐ |
| E1 | Semantic labels for screen readers on the remaining icon-only controls (charts, habit day squares) | 🟢 | ⭐ |
| E2 | "Install app" hint in Settings (icons and manifest are ready) | 🟢 | ⭐⭐ |
| E3 | Celebration on a 7-day streak (confetti) | 🟢 | ⭐⭐ |
| E4 | ~~Keep each tab's state when switching (`IndexedStack`), so screens don't reload~~ ✅ *Implemented* | 🟢 | ⭐⭐ |

---

## 5. Suggested order

1. **Next:** K3 undo after a scan and D3 undo after delete, K2 to-do scanning, D2 skeleton loaders. All quick and visible.
2. **Then:** reminders (section 2), A1 design tokens; once hosting is decided, cookie-based login (section 3).
3. **Deploy:** section 1 (Neon + Render + Cloudflare Pages + UptimeRobot), then rebuild the Android APK with the public API address and set up your own signing key ([HOW_TO_RUN.md, section 5](HOW_TO_RUN.md#5--android-app-apk)). **A live link and a downloadable APK on your CV beat any single feature.**
4. **Stand-out features:** Google sign-in, AI assistant (Gemini free tier), multi-currency.

---

## 6. Ideas from Catalyst (a friend's money-and-mood app): checklist

[Catalyst](https://github.com/HAVIC-47/catalyst-app) (Flutter app + [web app](https://github.com/HAVIC-47/catalyst)) by a friend solves similar problems. These are its features that fit LifeFlow, with what's already been brought over.

**Progress: 5 of 19 done** (✅ done · 🟨 partly · ⬜ to do)

### ✅ Done

| # | Idea | What it does in Catalyst | What LifeFlow has now |
|---|---|---|---|
| S1 | ✅ **Receipt / memo scanner** | A photo of a receipt or memo becomes reviewable entries | **Scan** on Expenses: receipts become line items with categories, shared discounts, extras (VAT), date and wallet; review everything before saving; missing categories are created |
| S2 | ✅ **Money-notes scanner** | Screenshots of notes become income and expense entries | The same Scan button reads notes, chats and handwriting (English or Bengali) into income/expense lines |
| S3 | ✅ **Shopping-list scanner** | A list or product screenshot becomes wishlist items | **Scan** on Wishlist: titles, notes, prices, priority, category and store links; unpriced items can be added too |
| K1 | ✅ **AI summaries & suggestions** | A weekly, monthly or yearly read of the user's data, with suggestions, built from a digest, saved, capped per day | *AI summary* card on Analytics for this week / this month: money vs the previous period, tasks, habits, wishlist; saved, "New data since" hint, daily limit, in the data export |
| K15 | ✅ **Downloadable Android app** | Signed APKs attached to every GitHub release, with a small arm64 build | GitHub Actions builds a universal and an arm64 APK (artifacts, and a Release on `v*` tags), with LifeFlow icons and an in-app server address. *Left:* create your own signing key (optional until you share updates) and code obfuscation |

### ⬜ Still to do

| # | Idea | What it does in Catalyst | How it would fit LifeFlow | Effort | Impact |
|---|---|---|---|---|---|
| K1+ | 🟨 **More summaries** | Yearly summaries; a summary on the home screen; goals, bills, journal and mood in the digest | Add a *year* period and a small summary card on the dashboard; include K4–K7 data once they exist | 🟢 | ⭐⭐ |
| K2 | ⬜ **Scan a to-do list** | A screenshot of a list becomes tickets on the board (ticked lines as done), with Undo | Add a `tasks` target to `POST /scan` and drop the items onto the Kanban board | 🟢 | ⭐⭐ |
| K3 | ⬜ **Undo after bulk adds** | A scan's items can be removed in one tap | An "Undo" action on the "Added N transactions" message | 🟢 | ⭐⭐ |
| K4 | ⬜ **Mood tracking × money** | Log a daily mood (five faces) with tags; calendar days are tinted by mood; a chart compares mood with net cash flow, with correlation | A mood row on the dashboard calendar and a chart in Analytics | 🟡 | ⭐⭐⭐ |
| K5 | ⬜ **Budgets per category** | A monthly limit per category that fills up and turns red when exceeded | LifeFlow has one overall budget; add limits per category beside the donut chart | 🟡 | ⭐⭐⭐ |
| K6 | ⬜ **Bills & recurring payments** | Due dates, recurrence, overdue / due-soon warnings, one-tap "paid" | Show bills as calendar dots; "paid" creates the expense | 🟡 | ⭐⭐⭐ |
| K7 | ⬜ **Savings goals** | Targets with progress bars and quick additions | Similar to the wishlist target, but for saving money | 🟢 | ⭐⭐ |
| K8 | ⬜ **Search & filters for transactions** | Search note, category, place and amount (even "october" or "monday"); filter by type, period, category and amount | A search bar and filter chips on Expenses (the list is already paginated server-side) | 🟡 | ⭐⭐ |
| K9 | ⬜ **Year heatmap & week view** | A 12-month heatmap of spending/income and a week view | Extra views for the dashboard calendar | 🟡 | ⭐⭐ |
| K10 | ⬜ **Customisable dashboard** | Choose which dashboard sections to show; the choice syncs | A "Dashboard sections" setting stored in `preferences` | 🟢 | ⭐⭐ |
| K11 | ⬜ **Time & place on transactions** | Each entry can have a time and a place | Two optional fields; the scanner already reads the shop name | 🟢 | ⭐ |
| K12 | ⬜ **One "+" for everything** | A centre "+" in the bottom bar opens quick entry or the scanner | A single add button on phones: transaction, task, habit or scan | 🟡 | ⭐⭐ |
| K13 | ⬜ **Board column editing** | Custom columns, drag columns left/right, numbered tickets | Let users rename and reorder Kanban columns | 🟡 | ⭐ |
| K14 | ⬜ **Encrypted token storage on phones** | The login session lives in Keystore-encrypted storage | Now that there's an Android app, use `flutter_secure_storage` on Android/iOS instead of SharedPreferences | 🟢 | ⭐⭐ (security) |
| K16 | ⬜ **Journal** | A daily log with a mood, next to custom habits | A short daily note on the Habits page | 🟢 | ⭐ |

**Suggested picks next:** K3 Undo and K2 to-do scanning (small, reuse the scanner), K14 secure token storage (small, matters now that there's an APK), then K5 category budgets and K6 bills (big everyday value).

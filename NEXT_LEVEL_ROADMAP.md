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
| Habits checked after midnight were logged on the previous day (UTC) | `APP_TIMEZONE=Asia/Dhaka` |
| The Flutter test file referenced a non-existent `MyApp` | Replaced with real tests |
| `notification_service.dart` didn't compile (package never installed) | Removed; reminders will be rebuilt properly (see below) |

### Features & quality
- Login page redesign with the LifeFlow logo and brand colours
- **Edit and delete transactions** (tap a transaction); **rename and delete habits** (card menu)
- **Responsive UI:** one-lane Kanban with "Move to…" on phones; two-column dashboard, side-by-side charts, habit grid and expense layout on desktop
- Pull-to-refresh on every list; Retry buttons on error screens; confirmation before deletes
- Money with thousands separators; chart axes in round numbers; chart dates like "7 Oct"
- Logout moved to Settings (with confirmation); logo in the desktop navigation
- Real app name, description and icons for the browser tab and installed app
- Login/register rate limit (10/min per IP); Laravel **Policies** for every edit/delete
- Database indexes for dashboard and analytics queries
- Configurable API address (`--dart-define=API_BASE_URL=...`)
- **19 backend tests + 6 Flutter tests**, run on every push by **GitHub Actions** (`.github/workflows/ci.yml`)
- Dead code removed (old login screen, unused donut chart, deprecated `withOpacity`)

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
| **AI assistant** | **Google Gemini API** free tier, called from Laravel so the key stays on the server. "Add 'pay rent' tomorrow, high priority" → creates a task; a weekly spending summary | 🔴 | ⭐⭐⭐ |
| **Error tracking** | **Sentry** free developer plan (Laravel + Flutter SDKs) | 🟢 | ⭐⭐ |
| **Weather forecast** (next days) | Open-Meteo (already used): add `daily=` to the same request | 🟢 | ⭐ |

> Gemini's free tier is rate-limited, and Google may use free-tier prompts to improve its products. Don't send sensitive financial details, and say so in your privacy note.

---

## 3. Remaining code improvements

| # | Item | Fix | Effort | Impact |
|---|---|---|---|---|
| 1 | Timezone is one fixed zone for every user | Store a `timezone` per user (sent from the device) and use it for "today" | 🟡 | ⭐⭐ |
| 2 | Inline `$request->validate()` in controllers | Move to **Form Requests** (auth already uses them), for consistency | 🟢 | ⭐ |
| 3 | Raw models returned as JSON | **API Resources**: a consistent shape that never leaks fields | 🟡 | ⭐⭐ |
| 4 | Transaction list isn't paginated | `->paginate(30)` + infinite scroll | 🟡 | ⭐⭐ |
| 5 | Categories can't be edited or deleted | Add `PUT`/`DELETE /categories/{id}` with a policy | 🟢 | ⭐⭐ |
| 6 | No account deletion or data export | "Delete my account" + "Export my data (CSV)", good privacy practice | 🟡 | ⭐⭐ |
| 7 | Web build stores the token in `localStorage` | For web, use Sanctum's cookie-based SPA auth | 🔴 | ⭐⭐ (security) |
| 8 | Avatar images are public to anyone with the exact URL | Signed URLs, or serve them through an authenticated route | 🟡 | ⭐ |
| 9 | Habit "longest streak" counts only the history still stored | Fine for now; keep logs forever, or store a best-ever value alongside | 🟢 | ⭐ |

---

## 4. Remaining UI / frontend improvements

| # | Change | Effort | Impact |
|---|---|---|---|
| A1 | **One design system.** The login page uses navy + cyan→violet (from the logo); the rest of the app uses an indigo theme with ad-hoc colours. Create `AppColors`/`AppSpacing` tokens and use them everywhere | 🟡 | ⭐⭐⭐ |
| A2 | Theme follows the device by default (`ThemeMode.system`), with the toggle as an override | 🟢 | ⭐⭐ |
| A3 | Show the user's avatar in the dashboard header | 🟢 | ⭐ |
| C1 | Spending **by category** donut chart on the expense page | 🟢 | ⭐⭐ |
| C2 | Tap a chart bar to see that day's transactions | 🟡 | ⭐⭐ |
| D1 | **Empty states** with an "Add your first…" button for tasks and transactions (habits already have one) | 🟢 | ⭐⭐⭐ |
| D2 | Skeleton loaders instead of spinners | 🟡 | ⭐⭐ |
| D3 | **Undo** snackbar after delete or habit uncheck | 🟡 | ⭐⭐ |
| E1 | Habit cards: tone down the saturated gradients for better contrast | 🟡 | ⭐⭐ |
| E2 | Tooltips/semantic labels on remaining icon-only buttons; 48×48 tap targets on habit day squares | 🟢 | ⭐ |
| E3 | "Install app" hint in Settings (icons and manifest are ready) | 🟢 | ⭐⭐ |
| E4 | Micro-interactions: haptic tick + small animation on habit check; celebration on a 7-day streak | 🟢 | ⭐⭐ |
| E5 | Keep each tab's state when switching (`IndexedStack`), so screens don't reload | 🟢 | ⭐⭐ |

---

## 5. Suggested order

1. **Next:** D1 empty states, #5 edit/delete categories, A2 system theme, E5 keep tab state. All quick and visible.
2. **Then:** reminders (section 2), A1 design tokens, E1 habit card colours.
3. **Deploy:** section 1 (Neon + Render + Cloudflare Pages + UptimeRobot). **A live link on your CV beats any single feature.**
4. **Stand-out features:** Google sign-in, AI assistant (Gemini free tier), multi-currency.

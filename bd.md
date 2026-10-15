# Database: what LifeFlow uses and what to use online

## Today: SQLite (local file)

LifeFlow doesn't use a hosted database service. The API stores everything in **SQLite**, a database kept in a single file: `lifeflow-api/database/database.sqlite`. Profile photos are stored on disk in `lifeflow-api/storage/app/public/avatars/`. The automated tests use a separate in-memory SQLite database, so they never touch your data.

That's ideal on your own computer. It stops working once the app is online, because free hosting services wipe their disk on every restart or redeploy, so users, tasks and photos would vanish.

## Online: Neon PostgreSQL (free, recommended)

**Neon** gives you a free PostgreSQL database that **pauses when idle and wakes up automatically** on the next request. You never have to un-pause it by hand, which makes it the best "free and permanent" choice.

- Laravel supports PostgreSQL out of the box; the existing migrations run unchanged.
- The app already handles PostgreSQL's habit of returning money amounts as text.
- Catches (free tiers change, so check before signing up): about 0.5 GB of storage, and a short delay on the first query after it has been idle.

**Alternatives**
- **Supabase**: PostgreSQL plus file storage, but free projects **pause after about a week without activity** and must be resumed by hand from the dashboard.
- **Aiven**: free MySQL or PostgreSQL.

## App first or database first?

**The app can be built first; the database doesn't block it.** The Android APK doesn't contain a database or the API address it must use: it asks for the server address on the sign-in screen (or has it baked in at build time). So:

1. **Now:** build the APK on GitHub ([HOW_TO_RUN.md, section 5](HOW_TO_RUN.md#5--android-app-apk)) and test it against your laptop over Wi-Fi. Your laptop's SQLite file is the database.
2. **Later:** set up Neon + Render (below). Nothing in the app changes.
3. **Then:** type the public API address into **Server: …** in the app, or run the Android workflow again with *API base URL* set, so the APK points there by default.

The only thing a phone needs that the database setup provides is **an API that's always online**, so other people can use the APK when your laptop is off.

## Profile photos online

Photos are now resized to 512px (tens of KB each), so they're small enough to store **in the database itself**. That avoids needing a separate file-storage service. Alternatively, use **Cloudinary**'s free plan. Either way needs a small code change in `ProfileController`.

## The full free setup

| Part | Free option | Catch |
|---|---|---|
| Database | **Neon** | Short wake-up delay after idling |
| Laravel API | **Render** (free web service) | Sleeps when idle; first request after that takes ~30–60 s (UptimeRobot pings can keep it awake) |
| Flutter web app | **Cloudflare Pages**, Netlify, Vercel or GitHub Pages | None that matters |
| Weather | Open-Meteo + BigDataCloud (already done) | None |
| Tests on every push | GitHub Actions (already set up) | None |
| Android APK | GitHub Actions (already set up) | Set up your own signing key before sharing updates |
| AI (scanner + summaries) | Google Gemini free tier, key in the API's environment variables (`GEMINI_API_KEY`) | Rate-limited; free-tier prompts may be used by Google |

## What switching takes

1. Create a free Neon project and copy its connection string.
2. Install PHP's PostgreSQL extension: `sudo apt install php8.3-pgsql`
3. In `lifeflow-api/.env` (on the server, or locally to try it):
   ```
   DB_CONNECTION=pgsql
   DB_URL=postgresql://USER:PASSWORD@HOST/DBNAME?sslmode=require
   ```
4. Run `php artisan migrate`.

On Render, add `GEMINI_API_KEY` (and the other `.env` values) as environment variables, never in the code. Keep using SQLite on your laptop for development. The connection string contains your database password, so keep it in `.env` (which git ignores) and never commit it or paste it anywhere public.

Full deployment steps are in [NEXT_LEVEL_ROADMAP.md](NEXT_LEVEL_ROADMAP.md).

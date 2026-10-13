No, you aren't using a database service. The app uses **SQLite**, a database stored as a single local file: [lifeflow-api/database/database.sqlite](lifeflow-api/database/database.sqlite), currently 147 KB. Uploaded avatars are also stored on your disk, in `lifeflow-api/storage/app/public/avatars/`.

That's fine while the app runs only on your computer. It stops working once you put the app online, because free hosting services usually wipe their disk on every restart or redeploy. Your users, tasks and photos would vanish each time.

## What I recommend: Supabase (free)

Your [PROJECT_BLUEPRINT.md](PROJECT_BLUEPRINT.md) already planned for "Supabase PostgreSQL" and "Supabase Storage", so it fits what you intended. One free account gives you:

- **A PostgreSQL database.** Laravel supports it out of the box, and your existing migrations should run without changes.
- **File storage for avatars.** Laravel can upload to it like Amazon S3, so photos survive restarts.
- **No credit card needed.**

**Free-tier catches**, as of my last information (free tiers change, so check before signing up):

- About 500 MB of database space and 1 GB of file storage, plenty for a personal or student project.
- A project with no activity for about a week gets paused. You can resume it from the Supabase dashboard.

## The full free setup, if you deploy


| Part              | Free option                                                       | Catch                                                          |
| ----------------- | ----------------------------------------------------------------- | -------------------------------------------------------------- |
| Database + photos | **Supabase**                                                      | Pauses when inactive                                           |
| Laravel API       | **Render** (free web service)                                     | Sleeps when idle; the first request after that takes ~30–60 s |
| Flutter web app   | **Netlify**, **Vercel**, **Cloudflare Pages** or **GitHub Pages** | None that matters                                              |
| Weather           | Open-Meteo + BigDataCloud (already done)                          | None                                                           |

Alternatives to Supabase are **Neon** (free PostgreSQL only) or **Aiven** (free MySQL or PostgreSQL). They have no file storage, though, so you'd still need somewhere else for avatars.

## What switching takes

1. Create a free Supabase project and copy its database connection string.
2. Install PHP's PostgreSQL extension: `sudo apt install php8.3-pgsql`
3. Change `lifeflow-api/.env`:
   ```
   DB_CONNECTION=pgsql
   DB_URL=postgresql://postgres.xxxx:PASSWORD@aws-0-xx.pooler.supabase.com:5432/postgres
   ```
4. Run `php artisan migrate`.
5. Optionally, point avatar uploads at Supabase Storage. That needs a small code change, which I'd make.

Keep using SQLite for development on your laptop and switch to Supabase when you put the app online. Do you want me to set this up once you've created the Supabase project? Paste the connection string into `.env` yourself rather than into this chat, since it contains your database password.

#!/bin/sh
# Container start: update the database schema, then serve the API.
set -e

# Values pasted into Render's settings can carry a stray newline, space or
# tab, which breaks Laravel ("A URI cannot contain CR/LF/TAB characters").
for name in APP_KEY APP_URL DB_URL DB_URL_DIRECT GEMINI_API_KEY; do
    eval "value=\${$name:-}"
    if [ -n "$value" ]; then
        export "$name=$(printf '%s' "$value" | tr -d ' \t\r\n')"
    fi
done

# Schema changes go over Neon's direct address; the app itself uses the
# pooled one ("-pooler" in the host). DB_URL_DIRECT overrides the guess.
DB_URL="${DB_URL_DIRECT:-$(echo "$DB_URL" | sed 's/-pooler//')}" php artisan migrate --force

php artisan config:cache
php artisan route:cache
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8000}"

#!/bin/sh
# Container start: update the database schema, then serve the API.
set -e

# Schema changes go over Neon's direct address; the app itself uses the
# pooled one ("-pooler" in the host). DB_URL_DIRECT overrides the guess.
DB_URL="${DB_URL_DIRECT:-$(echo "$DB_URL" | sed 's/-pooler//')}" php artisan migrate --force

php artisan config:cache
php artisan route:cache
exec php artisan serve --host=0.0.0.0 --port="${PORT:-8000}"

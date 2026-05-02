#!/usr/bin/env sh
set -eu

cd /app/backend

if [ "${RUN_MIGRATIONS_ON_STARTUP:-false}" = "true" ]; then
  alembic upgrade head
fi

exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --proxy-headers --forwarded-allow-ips "${FORWARDED_ALLOW_IPS:-*}"

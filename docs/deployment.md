# Deployment

Plant Buddy is designed to run as one app container connected to an external Postgres database and a mounted image-storage volume.

## Production Environment

Recommended production values:

```env
APP_ENV=production
APP_SECRET_KEY=<long-random-secret>
APP_USERNAME=<your-login>
APP_PASSWORD=<strong-password>
JWT_EXPIRE_MINUTES=120
REFRESH_TOKEN_EXPIRE_DAYS=30
DOCS_ENABLED=false
SECURE_HEADERS_ENABLED=true
RUN_MIGRATIONS_ON_STARTUP=true
FORWARDED_ALLOW_IPS=*

DATABASE_URL=postgresql+psycopg://plantbuddy:<encoded-password>@<postgres-host>:5432/<database>
DATABASE_SCHEMA=plantbuddy

OPENAI_API_KEY=<openai-key>
OPENAI_MODEL=gpt-4o-mini
DEEP_ANALYSIS_MODEL=gpt-5.2-chat-latest
BACKGROUND_WORKER_ENABLED=true
BACKGROUND_WORKER_INTERVAL_SECONDS=15

PLANTBUDDY_STORAGE_PATH=/data/plantbuddy
MAX_UPLOAD_MB=25

CORS_ALLOWED_ORIGINS=https://plantbuddy.a42.casa
PUBLIC_BASE_URL=https://plantbuddy.a42.casa
TRUSTED_HOSTS=plantbuddy.a42.casa,localhost,127.0.0.1
```

If nginx or Cloudflare Tunnel forwards requests to the container, keep TLS termination there and forward to the app over the private Docker/network path.
The container starts uvicorn with proxy-header support so `X-Forwarded-Proto` is honored for HTTPS-aware behavior such as HSTS. If the app port is reachable from anything other than your trusted proxy, replace `FORWARDED_ALLOW_IPS=*` with the proxy container or tunnel IP/CIDR.

## Build And Run

```powershell
docker build -t plantbuddy:latest .
docker compose -f docker-compose.example.yml up -d
```

The Dockerfile defaults to the current stable Flutter builder image. To pin a specific builder image after testing:

```powershell
docker build --build-arg FLUTTER_IMAGE=ghcr.io/cirruslabs/flutter:<tag> -t plantbuddy:latest .
```

The container exposes port `8000`. In production, route `https://plantbuddy.a42.casa` to that container through nginx or Cloudflare Tunnel.

## Migrations

The container can run migrations automatically when:

```env
RUN_MIGRATIONS_ON_STARTUP=true
```

Manual migration command:

```powershell
docker exec -it plantbuddy sh -lc "cd /app/backend && alembic upgrade head"
```

## Health Checks

- `GET /api/health` returns basic process health.
- `GET /api/ready` checks database connectivity and storage writability.

Use `/api/ready` for container readiness monitoring.

## Storage

Mount your NAS-backed path to:

```text
/data/plantbuddy
```

The app stores images below:

```text
/data/plantbuddy/plants/{plant_id}/originals/
/data/plantbuddy/plants/{plant_id}/thumbs/
```

The app must be able to create, read, and delete files below this path.

## Backup

Back up both:

- Postgres database or at least the configured `plantbuddy` schema.
- Mounted image storage volume.

Example Postgres schema backup:

```bash
pg_dump --schema=plantbuddy --format=custom --file=plantbuddy-schema.dump "$DATABASE_URL"
```

Restore with:

```bash
pg_restore --dbname "$DATABASE_URL" plantbuddy-schema.dump
```

Keep the DB backup and image volume backup from roughly the same point in time so photo metadata and stored files stay aligned.

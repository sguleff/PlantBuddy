# Pre-Deploy Test Plan

Run this checklist before the first public deployment and after any release that changes authentication, storage, AI calls, migrations, or Docker packaging.

## Local Backend

From `backend`:

```powershell
.\.venv\Scripts\python.exe -m compileall -q .
.\.venv\Scripts\python.exe -m alembic heads
.\.venv\Scripts\python.exe -c "from app.main import app; app.openapi(); print('runtime ok')"
uvicorn app.main:app --reload
```

Expected:

- Alembic reports one head.
- App import/OpenAPI generation prints `runtime ok`.
- `GET http://127.0.0.1:8000/api/health` returns `{"status":"ok","service":"plant-buddy"}`.
- `GET http://127.0.0.1:8000/api/ready` returns database and storage checks as `ok`.

## Local Frontend

From `frontend`:

```powershell
flutter analyze --no-pub
flutter build web --no-pub
flutter run -d chrome --web-hostname localhost --web-port 8080
```

Expected:

- Analyze has no release-blocking errors.
- Web build completes.
- Login defaults to `http://127.0.0.1:8000/api` when served from the Flutter dev server.
- Login succeeds with the configured household username and password.

## Browser Flow

Test in Chrome desktop and on iPhone Safari:

- Log in, log out, and log back in.
- Add a plant with metadata only.
- Upload a registration photo.
- Confirm the plant appears in inventory with a thumbnail.
- Run or wait for AI analysis.
- Confirm species/common name, health score, care plan, and generated tasks appear.
- Complete a task and confirm it moves to the next due date.
- Confirm overdue tasks render as overdue.
- Use calendar month navigation and ICS export.
- Open plant detail and confirm latest photo, photo timeline, task history, and health chart.
- Ask the plant chat a question, confirm Markdown renders, streaming text appears below the request, scrolling works, and clearing chat removes messages.
- Re-analyze a photo and confirm a new health point appears.

## Container Smoke Test

On the server:

```bash
docker build -t plantbuddy:latest .
docker compose -f docker-compose.example.yml up -d
docker logs -f plantbuddy
```

Expected:

- Container starts without migration errors.
- Healthcheck becomes healthy.
- `GET /api/ready` succeeds through the reverse proxy.
- Hosted login page defaults to `https://plantbuddy.a42.casa/api`.
- Uploaded originals and thumbnails are written under the mounted storage path.

## Production Configuration

Before exposing the app:

- Set `APP_ENV=production`.
- Set a strong `APP_SECRET_KEY`.
- Set a strong `APP_PASSWORD`.
- Set `DOCS_ENABLED=false` unless you intentionally want hosted API docs.
- Set `BACKGROUND_WORKER_ENABLED=true`.
- Set `CORS_ALLOWED_ORIGINS=https://plantbuddy.a42.casa`.
- Set `PUBLIC_BASE_URL=https://plantbuddy.a42.casa`.
- Set `TRUSTED_HOSTS=plantbuddy.a42.casa,localhost,127.0.0.1`.
- Keep `RUN_MIGRATIONS_ON_STARTUP=true` for the first deploy, or run Alembic manually.
- Confirm Postgres schema backup and image storage backup are configured.

## Rollback Checks

Before deploying a new image, keep:

- The previous image tag.
- A Postgres backup of the `plantbuddy` schema.
- A backup or snapshot of the mounted image storage.

If rollback is needed, restore the previous image first. Restore database/storage backups together only when schema or data changes require it.

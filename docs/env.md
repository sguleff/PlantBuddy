# Environment Variables

| Name | Purpose |
| --- | --- |
| `APP_ENV` | Runtime environment label. |
| `APP_SECRET_KEY` | Secret used for signing application tokens. |
| `APP_USERNAME` | Single household login username. |
| `APP_PASSWORD` | Single household login password. |
| `JWT_EXPIRE_MINUTES` | Access token lifetime. |
| `REFRESH_TOKEN_EXPIRE_DAYS` | Refresh token lifetime for seamless long sessions. |
| `DOCS_ENABLED` | Enables FastAPI docs/openapi endpoints. Disable in production if desired. |
| `SECURE_HEADERS_ENABLED` | Adds baseline security headers. |
| `RUN_MIGRATIONS_ON_STARTUP` | Runs `alembic upgrade head` before app startup in the container. |
| `FORWARDED_ALLOW_IPS` | Uvicorn proxy-header trust list. Use the private proxy IP/CIDR in production, or `*` when the container is only reachable through your trusted reverse proxy. |
| `DATABASE_URL` | SQLAlchemy Postgres URL. |
| `DATABASE_SCHEMA` | Dedicated Postgres schema for Plant Buddy tables. |
| `OPENAI_API_KEY` | OpenAI API key for plant analysis and chat. |
| `OPENAI_MODEL` | OpenAI model used for regular plant photo analysis and chat. |
| `DEEP_ANALYSIS_MODEL` | Standard OpenAI model used for Deep Analysis. This should not be a Deep Research model. |
| `BACKGROUND_WORKER_ENABLED` | Enables automatic queued job processing in the FastAPI process. |
| `BACKGROUND_WORKER_INTERVAL_SECONDS` | Poll interval for the optional background worker. |
| `PLANTBUDDY_STORAGE_PATH` | Mounted filesystem path for plant photos. |
| `MAX_UPLOAD_MB` | Maximum accepted image upload size. |
| `CORS_ALLOWED_ORIGINS` | Comma-separated trusted browser origins. |
| `PUBLIC_BASE_URL` | Public app URL, for generated links and calendar export. |
| `TRUSTED_HOSTS` | Comma-separated hostnames accepted by the app. |

## Local Backend Check

After setting `.env`, run:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
alembic upgrade head
uvicorn app.main:app --reload
```

If migration fails with `password authentication failed`, update `DATABASE_URL` with a Postgres username/password that can create tables in the target database.

For local backend testing, `PLANTBUDDY_STORAGE_PATH` must point to a directory writable by the Python process. In a container, use the mounted NAS path, for example `/data/plantbuddy`.

Queued AI analysis jobs are processed automatically when:

```env
BACKGROUND_WORKER_ENABLED=true
```

For normal use, keep this enabled so registration photo uploads are analyzed without a manual action.

For local Flutter testing, include the Flutter web origin in `CORS_ALLOWED_ORIGINS`, for example:

```env
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080,http://localhost:8000,http://127.0.0.1:8000
```

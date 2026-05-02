# Plant Buddy

Plant Buddy is a single-household plant care PWA with a FastAPI backend, Flutter web frontend, Postgres state store, local mounted photo storage, and OpenAI-assisted plant analysis.

## Phase 1 Status

This repository currently contains the foundation scaffold plus the first backend domain/API layer:

- `backend/` FastAPI app skeleton
- JWT auth for a single env-configured user
- SQLAlchemy models and Alembic migration scaffolding
- protected plant, task, and calendar API routes
- authenticated plant photo upload and image serving
- full-resolution compressed JPEG storage plus 256px and 768px thumbnails
- OpenAI-backed analysis job processing with persisted care plans and generated tasks
- task creation, editing, completion, history, month calendar, and `.ics` export
- photo timeline, re-analysis flow, analysis history, and health score trend chart
- plant-specific streaming AI chat with Markdown rendering and persisted message history
- expanded care plan details for watering amount/checks, fertilizer type/amount, repotting assessment, pruning, and watch-outs
- responsive polish for iPhone-first use, desktop navigation, validation, loading, and error states
- `frontend/` Flutter web PWA shell
- `docker/` container entrypoint
- `Dockerfile` for a single deployable app image
- `docker-compose.example.yml` for local orchestration reference
- `docs/` architecture, environment, deployment, and pre-deploy test notes

## Local Development

Backend:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Apply database migrations:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
alembic upgrade head
```

Frontend:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-hostname localhost --web-port 8080
```

Use `http://localhost:8000/api` as the API base URL on the login screen when the backend is running locally.

The backend serves API routes under `/api` and is structured to serve the built Flutter app from `frontend/build/web` in container deployments.

## Initial API Routes

- `GET /api/health`
- `POST /api/auth/login`
- `GET /api/auth/me`
- `GET /api/plants`
- `POST /api/plants`
- `GET /api/plants/{id}`
- `PATCH /api/plants/{id}`
- `DELETE /api/plants/{id}`
- `GET /api/plants/{id}/photos`
- `POST /api/plants/{id}/photos`
- `GET /api/photos/{id}/image?variant=original|thumb_256|thumb_768`
- `GET /api/plants/{id}/analysis/latest`
- `GET /api/plants/{id}/analysis`
- `GET /api/plants/{id}/care-plan`
- `POST /api/photos/{id}/analyze`
- `GET /api/jobs`
- `GET /api/jobs/{id}`
- `POST /api/jobs/{id}/retry`
- `GET /api/tasks`
- `POST /api/tasks`
- `PATCH /api/tasks/{id}`
- `POST /api/tasks/{id}/complete`
- `GET /api/tasks/{id}/events`
- `GET /api/plants/{id}/task-events`
- `GET /api/calendar?start=YYYY-MM-DD&end=YYYY-MM-DD`
- `GET /api/calendar.ics?start=YYYY-MM-DD&end=YYYY-MM-DD`
- `GET /api/plants/{id}/chat/sessions`
- `POST /api/plants/{id}/chat/sessions`
- `GET /api/chat/sessions/{id}/messages`
- `DELETE /api/chat/sessions/{id}/messages`
- `POST /api/chat/sessions/{id}/messages`
- `POST /api/chat/sessions/{id}/messages/stream`

## Browser Test Flow

1. Start the backend with `uvicorn app.main:app --reload`.
2. Start Flutter with `flutter run -d chrome --web-hostname localhost --web-port 8080`.
3. Log in with the single-user credentials from `.env`.
4. Add a plant from the Plants tab.
5. Upload a registration photo from the plant detail view.
6. Confirm a queued analysis job appears.
7. Wait for the background analysis job to finish.
8. Confirm the plant shows common name, scientific name, health score, care plan, and generated tasks.
9. Open Calendar, move between months, select days with task counts, and export the month as `.ics`.
10. Upload another photo, analyze it from the photo timeline, and confirm health history updates after the job succeeds.
11. Ask a question in Plant Chat and confirm the assistant streams a Markdown-formatted response with plant-specific context.

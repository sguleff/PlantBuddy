# Plant Buddy

Plant Buddy is a single-household plant care PWA with a FastAPI backend, Flutter web frontend, Postgres state store, local mounted photo storage, and OpenAI-assisted plant analysis.

## Phase 1 Status

This repository currently contains the foundation scaffold:

- `backend/` FastAPI app skeleton
- `frontend/` Flutter web PWA shell
- `docker/` container entrypoint
- `Dockerfile` for a single deployable app image
- `docker-compose.example.yml` for local orchestration reference
- `docs/` architecture and environment notes

## Local Development

Backend:

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload
```

Frontend:

```powershell
cd frontend
flutter pub get
flutter run -d chrome
```

The backend serves API routes under `/api` and is structured to serve the built Flutter app from `frontend/build/web` in container deployments.

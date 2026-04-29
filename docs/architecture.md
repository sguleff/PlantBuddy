# Architecture

Plant Buddy is structured as a single deployable app container:

- FastAPI serves `/api/*`.
- FastAPI serves the built Flutter web app for browser routes.
- Postgres is external and isolated with a configurable schema.
- Plant photos live on a mounted filesystem volume.
- OpenAI integration will be added behind backend endpoints so keys never reach the browser.

## Initial Runtime Shape

```text
Browser/PWA -> FastAPI container -> External Postgres
                         |
                         -> Mounted photo storage
                         |
                         -> OpenAI API
```

## Phase Boundaries

Phase 1 creates the foundation only. Auth, DB models, upload handling, AI analysis, tasks, calendar export, and polish are intentionally left for later phases.

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

Phase 2 adds the first backend domain layer:

- single-user JWT authentication
- SQLAlchemy session setup
- Alembic migration metadata wiring
- initial tables for plants, photos, analysis, care plans, tasks, task history, chat history, and background jobs
- protected starter routes for plants, tasks, and calendar data
- authenticated image upload and serving
- local mounted image storage with compressed originals and generated thumbnails
- OpenAI Responses API plant analysis using image input and structured JSON output
- analysis job processing with persisted plant analysis, active care plan, and generated care tasks
- optional in-process background worker for queued jobs
- task creation, editing, completion, recurrence advancement, and task history
- monthly calendar occurrence expansion and authenticated `.ics` export
- photo timeline, background re-analysis jobs, analysis history, and health trend chart
- plant-specific streaming AI chat with persisted sessions/messages, Markdown responses, and contextual OpenAI prompts
- expanded structured care-plan guidance for watering, fertilizing, repotting, grooming, and watch-outs

Deployment hardening and polish are intentionally left for later phases.

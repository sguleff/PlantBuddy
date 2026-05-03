import json
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import FileResponse, Response
from fastapi.staticfiles import StaticFiles

from app.api.health import router as health_router
from app.api.auth import router as auth_router
from app.api.calendar import router as calendar_router
from app.api.chat import router as chat_router
from app.api.jobs import router as jobs_router
from app.api.photos import router as photos_router
from app.api.plants import router as plants_router
from app.api.tasks import router as tasks_router
from app.core.config import get_settings
from app.core.middleware import SecurityHeadersMiddleware
from app.services.worker import start_background_worker, stop_background_worker


settings = get_settings()

app = FastAPI(
    title="Plant Buddy API",
    version="0.1.0",
    docs_url="/docs" if settings.docs_enabled else None,
    redoc_url="/redoc" if settings.docs_enabled else None,
    openapi_url="/openapi.json" if settings.docs_enabled else None,
)

if settings.trusted_host_patterns:
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.trusted_host_patterns)

if settings.secure_headers_enabled:
    app.add_middleware(SecurityHeadersMiddleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix="/api")
app.include_router(auth_router, prefix="/api")
app.include_router(plants_router, prefix="/api")
app.include_router(photos_router, prefix="/api")
app.include_router(tasks_router, prefix="/api")
app.include_router(calendar_router, prefix="/api")
app.include_router(chat_router, prefix="/api")
app.include_router(jobs_router, prefix="/api")


@app.on_event("startup")
async def startup_event():
    await start_background_worker()


@app.on_event("shutdown")
async def shutdown_event():
    await stop_background_worker()


frontend_dist = Path(__file__).resolve().parents[2] / "frontend" / "build" / "web"

if frontend_dist.exists():
    assets_path = frontend_dist / "assets"
    if assets_path.exists():
        app.mount("/assets", StaticFiles(directory=assets_path), name="assets")

    for static_name in ("canvaskit", "icons"):
        static_path = frontend_dist / static_name
        if static_path.exists():
            app.mount(f"/{static_name}", StaticFiles(directory=static_path), name=static_name)


@app.get("/plantbuddy_config.js", include_in_schema=False)
def serve_frontend_config():
    config = {"apiBaseUrl": settings.frontend_api_base_url}
    content = f"window.PLANTBUDDY_CONFIG = {json.dumps(config)};"
    return Response(content=content, media_type="application/javascript")


@app.get("/{full_path:path}", include_in_schema=False)
def serve_frontend(full_path: str):
    if full_path.startswith("api/"):
        raise HTTPException(status_code=404, detail="Not Found")

    requested = frontend_dist / full_path
    if frontend_dist.exists() and requested.is_file():
        return FileResponse(requested)

    index = frontend_dist / "index.html"
    if index.exists():
        return FileResponse(index)

    return {
        "service": "Plant Buddy API",
        "frontend": "not built",
        "docs": "/docs",
        "health": "/api/health",
    }

from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.api.health import router as health_router
from app.core.config import get_settings


settings = get_settings()

app = FastAPI(title="Plant Buddy API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix="/api")


frontend_dist = Path(__file__).resolve().parents[2] / "frontend" / "build" / "web"

if frontend_dist.exists():
    assets_path = frontend_dist / "assets"
    if assets_path.exists():
        app.mount("/assets", StaticFiles(directory=assets_path), name="assets")

    for static_name in ("canvaskit", "icons"):
        static_path = frontend_dist / static_name
        if static_path.exists():
            app.mount(f"/{static_name}", StaticFiles(directory=static_path), name=static_name)


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

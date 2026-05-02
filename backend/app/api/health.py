from pathlib import Path

from fastapi import APIRouter, HTTPException
from sqlalchemy import text

from app.db import engine
from app.services.images import storage_root

router = APIRouter(tags=["health"])


@router.get("/health")
def health_check():
    return {"status": "ok", "service": "plant-buddy"}


@router.get("/ready")
def readiness_check():
    checks = {"database": "ok", "storage": "ok"}
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception as exc:
        checks["database"] = str(exc)

    try:
        root = storage_root()
        root.mkdir(parents=True, exist_ok=True)
        probe = Path(root) / ".plantbuddy_ready"
        probe.write_text("ok", encoding="utf-8")
        probe.unlink(missing_ok=True)
    except Exception as exc:
        checks["storage"] = str(exc)

    if any(value != "ok" for value in checks.values()):
        raise HTTPException(status_code=503, detail={"status": "not_ready", "checks": checks})
    return {"status": "ready", "checks": checks}

import asyncio
from typing import Optional

from app.core.config import get_settings
from app.db import SessionLocal
from app.services.jobs import run_next_job


worker_task: Optional[asyncio.Task] = None


async def start_background_worker() -> None:
    global worker_task
    settings = get_settings()
    if not settings.background_worker_enabled or worker_task is not None:
        return
    worker_task = asyncio.create_task(_worker_loop())


async def stop_background_worker() -> None:
    global worker_task
    if worker_task is None:
        return
    worker_task.cancel()
    try:
        await worker_task
    except asyncio.CancelledError:
        pass
    worker_task = None


async def _worker_loop() -> None:
    settings = get_settings()
    while True:
        await asyncio.to_thread(_run_once)
        await asyncio.sleep(settings.background_worker_interval_seconds)


def _run_once() -> None:
    db = SessionLocal()
    try:
        run_next_job(db)
    finally:
        db.close()

from typing import List, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_db
from app.models import BackgroundJob
from app.schemas import BackgroundJobResponse
from app.services.jobs import run_job_by_id, run_next_job, run_queued_jobs, retry_job


router = APIRouter(prefix="/jobs", tags=["jobs"])


@router.get("", response_model=List[BackgroundJobResponse])
def list_jobs(
    background_tasks: BackgroundTasks,
    plant_id: Optional[str] = Query(default=None),
    status_filter: Optional[str] = Query(default=None, alias="status"),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_current_db),
):
    statement = select(BackgroundJob).order_by(BackgroundJob.created_at.desc()).limit(limit)
    if plant_id is not None:
        statement = statement.where(BackgroundJob.plant_id == plant_id)
    if status_filter is not None:
        statement = statement.where(BackgroundJob.status == status_filter)
    jobs = db.scalars(statement).all()
    if any(job.status == "queued" for job in jobs):
        background_tasks.add_task(run_queued_jobs)
    return jobs


@router.get("/{job_id}", response_model=BackgroundJobResponse)
def get_job(job_id: str, db: Session = Depends(get_current_db)):
    job = db.get(BackgroundJob, job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@router.post("/run-next", response_model=BackgroundJobResponse)
def run_next_queued_job(db: Session = Depends(get_current_db)):
    job = run_next_job(db)
    if job is None:
        raise HTTPException(status_code=404, detail="No queued jobs")
    return job


@router.post("/{job_id}/run", response_model=BackgroundJobResponse)
def run_specific_job(job_id: str, db: Session = Depends(get_current_db)):
    job = run_job_by_id(db, job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job


@router.post("/{job_id}/retry", response_model=BackgroundJobResponse)
def retry_specific_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_current_db),
):
    job = db.get(BackgroundJob, job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    if job.status not in {"failed", "succeeded"}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Only failed or succeeded jobs can be queued for retry",
        )
    retried = retry_job(db, job)
    background_tasks.add_task(run_queued_jobs)
    return retried

from datetime import date, datetime, timezone, timedelta
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import SessionLocal
from app.models import BackgroundJob, CarePlan, CareTask, Plant, PlantAnalysis, PlantPhoto
from app.services.openai_analysis import OpenAIAnalysisError, analyze_plant_photo


ANALYZE_PLANT_PHOTO = "analyze_plant_photo"


def run_next_job(db: Session) -> Optional[BackgroundJob]:
    job = db.scalars(
        select(BackgroundJob)
        .where(BackgroundJob.status == "queued")
        .order_by(BackgroundJob.created_at.asc())
        .with_for_update(skip_locked=True)
        .limit(1)
    ).first()
    if job is None:
        return None
    return run_job(db, job)


def run_queued_jobs(max_jobs: int = 10) -> int:
    db = SessionLocal()
    processed = 0
    try:
        while processed < max_jobs:
            job = run_next_job(db)
            if job is None:
                break
            processed += 1
    finally:
        db.close()
    return processed


def run_job_by_id(db: Session, job_id: str) -> Optional[BackgroundJob]:
    job = db.get(BackgroundJob, job_id)
    if job is None:
        return None
    return run_job(db, job)


def run_job(db: Session, job: BackgroundJob) -> BackgroundJob:
    job.status = "running"
    job.started_at = datetime.now(timezone.utc)
    job.attempts = (job.attempts or 0) + 1
    job.last_error = None
    db.commit()
    db.refresh(job)

    try:
        if job.job_type != ANALYZE_PLANT_PHOTO:
            raise ValueError(f"Unsupported job type: {job.job_type}")
        _run_plant_photo_analysis(db, job)
        job.status = "succeeded"
        job.finished_at = datetime.now(timezone.utc)
    except Exception as exc:
        db.rollback()
        job = db.get(BackgroundJob, job.id)
        job.status = "failed"
        job.last_error = str(exc)
        job.finished_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(job)
    return job


def retry_job(db: Session, job: BackgroundJob) -> BackgroundJob:
    if job.status not in {"failed", "succeeded"}:
        return job
    job.status = "queued"
    job.last_error = None
    job.started_at = None
    job.finished_at = None
    db.commit()
    db.refresh(job)
    return job


def _run_plant_photo_analysis(db: Session, job: BackgroundJob) -> None:
    if not job.plant_id or not job.photo_id:
        raise ValueError("Analysis job is missing plant_id or photo_id")

    plant = db.get(Plant, job.plant_id)
    photo = db.get(PlantPhoto, job.photo_id)
    if plant is None:
        raise ValueError("Plant not found for analysis job")
    if photo is None:
        raise ValueError("Photo not found for analysis job")

    result = analyze_plant_photo(plant, photo)

    analysis = PlantAnalysis(
        plant_id=plant.id,
        photo_id=photo.id,
        status="succeeded",
        common_name=result.common_name,
        scientific_name=result.scientific_name,
        confidence=result.confidence,
        health_score=result.health_score,
        health_notes=result.health_notes,
        raw_response=result.model_dump(),
    )
    db.add(analysis)
    db.flush()

    plant.common_name = result.common_name
    plant.scientific_name = result.scientific_name
    plant.health_score = result.health_score

    db.query(CarePlan).filter(CarePlan.plant_id == plant.id, CarePlan.active.is_(True)).update(
        {"active": False},
        synchronize_session=False,
    )
    care_plan = CarePlan(
        plant_id=plant.id,
        analysis_id=analysis.id,
        watering=result.care_plan.watering,
        watering_amount=result.care_plan.watering_amount,
        watering_check=result.care_plan.watering_check,
        fertilizing=result.care_plan.fertilizing,
        fertilizer_type=result.care_plan.fertilizer_type,
        fertilizer_amount=result.care_plan.fertilizer_amount,
        sunlight=result.care_plan.sunlight,
        repotting=result.care_plan.repotting,
        repotting_assessment=result.care_plan.repotting_assessment,
        soil=result.care_plan.soil,
        pruning=result.care_plan.pruning,
        watch_outs=result.care_plan.watch_outs,
        raw_plan=result.care_plan.model_dump(),
        active=True,
    )
    db.add(care_plan)
    db.flush()

    db.query(CareTask).filter(CareTask.plant_id == plant.id, CareTask.user_override.is_(False)).update(
        {"enabled": False},
        synchronize_session=False,
    )
    today = date.today()
    for suggestion in result.care_plan.task_suggestions:
        db.add(
            CareTask(
                plant_id=plant.id,
                care_plan_id=care_plan.id,
                task_type=suggestion.task_type,
                title=suggestion.title,
                notes=suggestion.notes,
                frequency_days=suggestion.frequency_days,
                next_due_date=today + timedelta(days=suggestion.next_due_days),
                enabled=True,
                user_override=False,
            )
        )

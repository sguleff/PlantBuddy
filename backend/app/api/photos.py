from pathlib import Path
from typing import Literal

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_db
from app.models import BackgroundJob, CarePlan, CareTask, Plant, PlantAnalysis, PlantPhoto
from app.schemas import BackgroundJobResponse
from app.services.images import delete_photo_files, resolve_storage_path
from app.services.jobs import run_queued_jobs


router = APIRouter(prefix="/photos", tags=["photos"])


@router.get("/{photo_id}/image")
def get_photo_image(
    photo_id: str,
    variant: Literal["original", "thumb_256", "thumb_768"] = Query(default="original"),
    db: Session = Depends(get_current_db),
):
    photo = db.get(PlantPhoto, photo_id)
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")

    relative_path = {
        "original": photo.original_path,
        "thumb_256": photo.thumb_256_path,
        "thumb_768": photo.thumb_768_path,
    }[variant]

    if not relative_path:
        raise HTTPException(status_code=404, detail="Requested image variant is not available")

    image_path = resolve_storage_path(relative_path)
    if not image_path.is_file():
        raise HTTPException(status_code=404, detail="Image file not found")

    return FileResponse(Path(image_path), media_type="image/jpeg")


@router.post("/{photo_id}/analyze", response_model=BackgroundJobResponse, status_code=status.HTTP_201_CREATED)
def analyze_photo(
    photo_id: str,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_current_db),
):
    photo = db.get(PlantPhoto, photo_id)
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")

    job = BackgroundJob(
        job_type="analyze_plant_photo",
        status="queued",
        plant_id=photo.plant_id,
        photo_id=photo.id,
        payload={"source": "manual_reanalysis"},
    )
    db.add(job)
    db.commit()
    background_tasks.add_task(run_queued_jobs)
    db.refresh(job)
    return job


@router.delete("/{photo_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_photo(photo_id: str, db: Session = Depends(get_current_db)):
    photo = db.get(PlantPhoto, photo_id)
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")

    plant = db.get(Plant, photo.plant_id)
    analyses = db.scalars(select(PlantAnalysis).where(PlantAnalysis.photo_id == photo.id)).all()
    analysis_ids = [analysis.id for analysis in analyses]
    if analysis_ids:
        care_plans = db.scalars(select(CarePlan).where(CarePlan.analysis_id.in_(analysis_ids))).all()
        care_plan_ids = [care_plan.id for care_plan in care_plans]
        if care_plan_ids:
            db.query(CareTask).filter(
                CareTask.care_plan_id.in_(care_plan_ids),
                CareTask.user_override.is_(False),
            ).delete(synchronize_session=False)
        for care_plan in care_plans:
            db.delete(care_plan)
        for analysis in analyses:
            db.delete(analysis)

    db.query(BackgroundJob).filter(BackgroundJob.photo_id == photo.id).update(
        {"photo_id": None},
        synchronize_session=False,
    )
    if plant and plant.latest_photo_id == photo.id:
        latest_photo = db.scalars(
            select(PlantPhoto)
            .where(PlantPhoto.plant_id == plant.id)
            .where(PlantPhoto.id != photo.id)
            .order_by(PlantPhoto.created_at.desc())
            .limit(1)
        ).first()
        plant.latest_photo_id = latest_photo.id if latest_photo else None

    delete_photo_files(photo)
    db.delete(photo)
    db.flush()
    if plant:
        _refresh_plant_analysis_summary(db, plant)
    db.commit()
    return None


def _refresh_plant_analysis_summary(db: Session, plant: Plant) -> None:
    latest_analysis = db.scalars(
        select(PlantAnalysis)
        .where(PlantAnalysis.plant_id == plant.id)
        .order_by(PlantAnalysis.created_at.desc())
        .limit(1)
    ).first()
    if latest_analysis is None:
        plant.common_name = None
        plant.scientific_name = None
        plant.health_score = None
        return
    plant.common_name = latest_analysis.common_name
    plant.scientific_name = latest_analysis.scientific_name
    plant.health_score = latest_analysis.health_score
    db.query(CarePlan).filter(CarePlan.plant_id == plant.id).update(
        {"active": False},
        synchronize_session=False,
    )
    latest_care_plan = db.scalars(
        select(CarePlan)
        .where(CarePlan.plant_id == plant.id)
        .order_by(CarePlan.created_at.desc())
        .limit(1)
    ).first()
    if latest_care_plan is not None:
        latest_care_plan.active = True

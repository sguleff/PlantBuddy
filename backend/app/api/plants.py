from typing import List

from pathlib import Path
from fastapi import APIRouter, BackgroundTasks, Depends, File, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_db
from app.models import BackgroundJob, CarePlan, Plant, PlantAnalysis, PlantDeepAnalysis, PlantPhoto, TaskEvent, new_id
from app.schemas import (
    CarePlanResponse,
    DeepAnalysisResponse,
    PlantAnalysisResponse,
    PlantCreate,
    PlantDetail,
    PlantPhotoResponse,
    PlantSummary,
    PlantUpdate,
    TaskEventResponse,
)
from app.services.images import delete_plant_images, delete_stored_image, resolve_storage_path, store_plant_icon, store_plant_image
from app.services.jobs import run_queued_jobs
from app.services.deep_analysis import DeepAnalysisError, apply_deep_analysis, run_deep_analysis


router = APIRouter(prefix="/plants", tags=["plants"])


@router.get("", response_model=List[PlantSummary])
def list_plants(
    include_archived: bool = Query(default=False),
    db: Session = Depends(get_current_db),
):
    statement = select(Plant).order_by(Plant.created_at.desc())
    if not include_archived:
        statement = statement.where(Plant.archived.is_(False))
    return db.scalars(statement).all()


@router.post("", response_model=PlantDetail, status_code=status.HTTP_201_CREATED)
def create_plant(payload: PlantCreate, db: Session = Depends(get_current_db)):
    plant = Plant(**payload.model_dump())
    db.add(plant)
    db.commit()
    db.refresh(plant)
    return plant


@router.get("/{plant_id}", response_model=PlantDetail)
def get_plant(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    return plant


@router.get("/{plant_id}/photos", response_model=List[PlantPhotoResponse])
def list_plant_photos(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    return db.scalars(
        select(PlantPhoto)
        .where(PlantPhoto.plant_id == plant_id)
        .order_by(PlantPhoto.created_at.desc())
    ).all()


@router.get("/{plant_id}/analysis/latest", response_model=PlantAnalysisResponse)
def get_latest_plant_analysis(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    analysis = db.scalars(
        select(PlantAnalysis)
        .where(PlantAnalysis.plant_id == plant_id)
        .order_by(PlantAnalysis.created_at.desc())
        .limit(1)
    ).first()
    if analysis is None:
        raise HTTPException(status_code=404, detail="Plant analysis not found")
    return analysis


@router.get("/{plant_id}/analysis", response_model=List[PlantAnalysisResponse])
def list_plant_analyses(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    return db.scalars(
        select(PlantAnalysis)
        .where(PlantAnalysis.plant_id == plant_id)
        .order_by(PlantAnalysis.created_at.asc())
    ).all()


@router.get("/{plant_id}/deep-analysis/latest", response_model=DeepAnalysisResponse)
def get_latest_deep_analysis(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    deep_analysis = db.scalars(
        select(PlantDeepAnalysis)
        .where(PlantDeepAnalysis.plant_id == plant_id)
        .order_by(PlantDeepAnalysis.created_at.desc())
        .limit(1)
    ).first()
    if deep_analysis is None:
        raise HTTPException(status_code=404, detail="Deep analysis not found")
    return deep_analysis


@router.post("/{plant_id}/deep-analysis", response_model=DeepAnalysisResponse, status_code=status.HTTP_201_CREATED)
def create_deep_analysis(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    try:
        return run_deep_analysis(db, plant)
    except DeepAnalysisError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/{plant_id}/deep-analysis/{analysis_id}/apply", response_model=DeepAnalysisResponse)
def apply_deep_analysis_result(
    plant_id: str,
    analysis_id: str,
    db: Session = Depends(get_current_db),
):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    deep_analysis = db.get(PlantDeepAnalysis, analysis_id)
    if deep_analysis is None or deep_analysis.plant_id != plant_id:
        raise HTTPException(status_code=404, detail="Deep analysis not found")
    try:
        return apply_deep_analysis(db, deep_analysis)
    except DeepAnalysisError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/{plant_id}/care-plan", response_model=CarePlanResponse)
def get_active_care_plan(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    care_plan = db.scalars(
        select(CarePlan)
        .where(CarePlan.plant_id == plant_id)
        .where(CarePlan.active.is_(True))
        .order_by(CarePlan.created_at.desc())
        .limit(1)
    ).first()
    if care_plan is None:
        raise HTTPException(status_code=404, detail="Care plan not found")
    return care_plan


@router.get("/{plant_id}/task-events", response_model=List[TaskEventResponse])
def list_plant_task_events(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    return db.scalars(
        select(TaskEvent)
        .where(TaskEvent.plant_id == plant_id)
        .order_by(TaskEvent.completed_at.desc())
    ).all()


@router.get("/{plant_id}/icon")
def get_plant_icon(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    if not plant.icon_path:
        raise HTTPException(status_code=404, detail="Plant icon not found")
    icon_path = resolve_storage_path(plant.icon_path)
    if not icon_path.is_file():
        raise HTTPException(status_code=404, detail="Plant icon file not found")
    return FileResponse(Path(icon_path), media_type="image/jpeg")


@router.post("/{plant_id}/icon", response_model=PlantDetail)
async def upload_plant_icon(
    plant_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_current_db),
):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    plant.icon_path = await store_plant_icon(plant_id=plant.id, upload=file)
    db.commit()
    db.refresh(plant)
    return plant


@router.delete("/{plant_id}/icon", response_model=PlantDetail)
def delete_plant_icon(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    delete_stored_image(plant.icon_path)
    plant.icon_path = None
    db.commit()
    db.refresh(plant)
    return plant


@router.post("/{plant_id}/photos", response_model=PlantPhotoResponse, status_code=status.HTTP_201_CREATED)
async def upload_plant_photo(
    plant_id: str,
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    is_registration_photo: bool = Query(default=False),
    db: Session = Depends(get_current_db),
):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    photo_id = new_id()
    stored = await store_plant_image(plant_id=plant_id, photo_id=photo_id, upload=file)
    photo = PlantPhoto(
        id=photo_id,
        plant_id=plant_id,
        original_path=stored.original_path,
        thumb_256_path=stored.thumb_256_path,
        thumb_768_path=stored.thumb_768_path,
        mime_type=stored.mime_type,
        width=stored.width,
        height=stored.height,
        file_size_bytes=stored.file_size_bytes,
        checksum_sha256=stored.checksum_sha256,
        is_registration_photo=is_registration_photo,
        captured_at=stored.captured_at,
    )
    db.add(photo)
    db.flush()
    plant.latest_photo_id = photo.id

    if is_registration_photo:
        job_id = new_id()
        db.add(
            BackgroundJob(
                id=job_id,
                job_type="analyze_plant_photo",
                status="queued",
                plant_id=plant.id,
                photo_id=photo.id,
                payload={"source": "registration_photo"},
            )
        )

    db.commit()
    if is_registration_photo:
        background_tasks.add_task(run_queued_jobs)
    db.refresh(photo)
    return photo


@router.patch("/{plant_id}", response_model=PlantDetail)
def update_plant(plant_id: str, payload: PlantUpdate, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(plant, field, value)

    db.commit()
    db.refresh(plant)
    return plant


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_plant(plant_id: str, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    db.delete(plant)
    db.commit()
    delete_plant_images(plant_id)
    return None

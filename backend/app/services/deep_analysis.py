import json
from datetime import date, timedelta
from typing import Any, Dict, List, Optional

import httpx
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import CarePlan, CareTask, Plant, PlantDeepAnalysis, PlantPhoto
from app.services.openai_analysis import (
    CareTaskSuggestion,
    PlantCarePlanResult,
    _extract_output_json,
    _image_to_data_url,
)
from app.services.images import resolve_storage_path


class DeepAnalysisResult(BaseModel):
    review: str
    trajectory: str
    recommendations: str
    care_plan: PlantCarePlanResult
    special_tasks: List[CareTaskSuggestion] = Field(default_factory=list, max_length=8)


class DeepAnalysisError(Exception):
    pass


def run_deep_analysis(db: Session, plant: Plant) -> PlantDeepAnalysis:
    settings = get_settings()
    if not settings.openai_api_key:
        raise DeepAnalysisError("OPENAI_API_KEY is not configured")

    photos = db.scalars(
        select(PlantPhoto)
        .where(PlantPhoto.plant_id == plant.id)
        .order_by(PlantPhoto.created_at.asc())
    ).all()
    selected_photos = _select_representative_photos(photos)
    if not selected_photos:
        raise DeepAnalysisError("At least one plant photo is required for deep analysis")

    payload = _build_deep_analysis_payload(settings.deep_analysis_model, plant, selected_photos)
    try:
        with httpx.Client(timeout=180) as client:
            response = client.post(
                "https://api.openai.com/v1/responses",
                headers={
                    "Authorization": f"Bearer {settings.openai_api_key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise DeepAnalysisError(f"OpenAI deep analysis request failed: {exc}") from exc

    data = response.json()
    parsed = _extract_output_json(data)
    try:
        result = DeepAnalysisResult.model_validate(parsed)
    except ValidationError as exc:
        raise DeepAnalysisError(f"OpenAI deep analysis response did not match schema: {exc}") from exc

    deep_analysis = PlantDeepAnalysis(
        plant_id=plant.id,
        status="succeeded",
        selected_photos={"photos": [_photo_context(photo) for photo in selected_photos]},
        review=result.review,
        trajectory=result.trajectory,
        recommendations=result.recommendations,
        care_plan=result.care_plan.model_dump(),
        special_tasks={"tasks": [task.model_dump() for task in result.special_tasks]},
        raw_response=parsed,
        applied=False,
    )
    db.add(deep_analysis)
    db.commit()
    db.refresh(deep_analysis)
    return deep_analysis


def apply_deep_analysis(db: Session, deep_analysis: PlantDeepAnalysis) -> PlantDeepAnalysis:
    plant = db.get(Plant, deep_analysis.plant_id)
    if plant is None:
        raise DeepAnalysisError("Plant not found")
    if not deep_analysis.care_plan:
        raise DeepAnalysisError("Deep analysis does not include a care plan")

    care_plan = PlantCarePlanResult.model_validate(deep_analysis.care_plan)
    db.query(CarePlan).filter(
        CarePlan.plant_id == plant.id,
        CarePlan.active.is_(True),
    ).update({"active": False}, synchronize_session=False)

    new_care_plan = CarePlan(
        plant_id=plant.id,
        watering=care_plan.watering,
        watering_amount=care_plan.watering_amount,
        watering_check=care_plan.watering_check,
        fertilizing=care_plan.fertilizing,
        fertilizer_type=care_plan.fertilizer_type,
        fertilizer_amount=care_plan.fertilizer_amount,
        sunlight=care_plan.sunlight,
        repotting=care_plan.repotting,
        repotting_assessment=care_plan.repotting_assessment,
        soil=care_plan.soil,
        pruning=care_plan.pruning,
        watch_outs=care_plan.watch_outs,
        raw_plan=care_plan.model_dump(),
        active=True,
    )
    db.add(new_care_plan)
    db.flush()

    today = date.today()
    tasks = (deep_analysis.special_tasks or {}).get("tasks", [])
    for item in tasks:
        suggestion = CareTaskSuggestion.model_validate(item)
        db.add(
            CareTask(
                plant_id=plant.id,
                care_plan_id=new_care_plan.id,
                task_type=suggestion.task_type,
                title=suggestion.title,
                notes=suggestion.notes,
                frequency_days=suggestion.frequency_days,
                next_due_date=today + timedelta(days=suggestion.next_due_days),
                enabled=True,
                user_override=True,
            )
        )

    deep_analysis.applied = True
    db.commit()
    db.refresh(deep_analysis)
    return deep_analysis


def _select_representative_photos(photos: List[PlantPhoto]) -> List[PlantPhoto]:
    if not photos:
        return []
    selected = []
    selected_ids = set()

    def add(photo: Optional[PlantPhoto]) -> None:
        if photo is None or photo.id in selected_ids:
            return
        selected.append(photo)
        selected_ids.add(photo.id)

    first = photos[0]
    newest = photos[-1]
    add(first)
    for days_back in (183, 365, 730, 1095):
        target = _photo_timestamp(newest) - timedelta(days=days_back)
        add(_closest_photo(photos, target, selected_ids))
    for photo in reversed(photos):
        add(photo)
        if len([item for item in selected if item.id in selected_ids]) >= 9:
            break
    return selected


def _closest_photo(photos: List[PlantPhoto], target, selected_ids: set) -> Optional[PlantPhoto]:
    available = [photo for photo in photos if photo.id not in selected_ids]
    if not available:
        return None
    return min(available, key=lambda photo: abs(_photo_timestamp(photo) - target))


def _build_deep_analysis_payload(model: str, plant: Plant, photos: List[PlantPhoto]) -> Dict[str, Any]:
    content = [
        {
            "type": "input_text",
            "text": (
                "Deep plant review request. Act as a professional botanist reviewing a household plant over time. "
                "Use the dated photos to evaluate trajectory, visible health, possible stress patterns, and care adjustments. "
                "Skip any uncertainty rather than overclaiming. Return an updated treatment schedule and special tasks. "
                "Plant metadata JSON: "
                f"{json.dumps(_plant_context(plant), ensure_ascii=True)}"
            ),
        }
    ]
    for index, photo in enumerate(photos, start=1):
        path = resolve_storage_path(photo.original_path)
        if not path.is_file():
            continue
        content.append(
            {
                "type": "input_text",
                "text": f"Photo {index}: id={photo.id}, date={_photo_timestamp_text(photo)}",
            }
        )
        content.append({"type": "input_image", "image_url": _image_to_data_url(path.read_bytes()), "detail": "high"})

    return {
        "model": model,
        "instructions": (
            "You are Plant Buddy's deep-analysis botanist. Be practical, image-grounded, and household-care focused. "
            "Use concise but complete Markdown-compatible prose in review, trajectory, and recommendations. "
            "Return only JSON matching the schema."
        ),
        "input": [{"role": "user", "content": content}],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "plant_deep_analysis",
                "strict": True,
                "schema": _deep_analysis_schema(),
            }
        },
    }


def _plant_context(plant: Plant) -> Dict[str, Any]:
    return {
        "id": plant.id,
        "pet_name": plant.pet_name,
        "location": plant.location,
        "room_location": plant.room_location,
        "notes": plant.notes,
        "common_name": plant.common_name,
        "scientific_name": plant.scientific_name,
        "health_score": plant.health_score,
    }


def _photo_context(photo: PlantPhoto) -> Dict[str, Any]:
    return {
        "id": photo.id,
        "created_at": photo.created_at.isoformat() if photo.created_at else None,
        "captured_at": photo.captured_at.isoformat() if photo.captured_at else None,
        "analysis_photo_date": _photo_timestamp_text(photo),
        "is_registration_photo": photo.is_registration_photo,
    }


def _photo_timestamp(photo: PlantPhoto):
    return photo.captured_at or photo.created_at


def _photo_timestamp_text(photo: PlantPhoto) -> str:
    timestamp = _photo_timestamp(photo)
    return timestamp.isoformat() if timestamp else "unknown"


def _deep_analysis_schema() -> Dict[str, Any]:
    care_plan_schema = _care_plan_schema()
    task_schema = _task_schema()
    return {
        "type": "object",
        "additionalProperties": False,
        "required": ["review", "trajectory", "recommendations", "care_plan", "special_tasks"],
        "properties": {
            "review": {"type": "string"},
            "trajectory": {"type": "string"},
            "recommendations": {"type": "string"},
            "care_plan": care_plan_schema,
            "special_tasks": {"type": "array", "maxItems": 8, "items": task_schema},
        },
    }


def _care_plan_schema() -> Dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "watering",
            "watering_amount",
            "watering_check",
            "fertilizing",
            "fertilizer_type",
            "fertilizer_amount",
            "sunlight",
            "repotting",
            "repotting_assessment",
            "soil",
            "pruning",
            "watch_outs",
            "task_suggestions",
        ],
        "properties": {
            "watering": {"type": "string"},
            "watering_amount": {"type": "string"},
            "watering_check": {"type": "string"},
            "fertilizing": {"type": "string"},
            "fertilizer_type": {"type": "string"},
            "fertilizer_amount": {"type": "string"},
            "sunlight": {"type": "string"},
            "repotting": {"type": "string"},
            "repotting_assessment": {"type": "string"},
            "soil": {"type": "string"},
            "pruning": {"type": "string"},
            "watch_outs": {"type": "string"},
            "task_suggestions": {"type": "array", "maxItems": 6, "items": _task_schema()},
        },
    }


def _task_schema() -> Dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": ["task_type", "title", "notes", "frequency_days", "next_due_days"],
        "properties": {
            "task_type": {"type": "string", "enum": ["watering", "fertilizing", "repotting", "inspection", "custom"]},
            "title": {"type": "string"},
            "notes": {"type": ["string", "null"]},
            "frequency_days": {"type": ["integer", "null"], "minimum": 1, "maximum": 730},
            "next_due_days": {"type": "integer", "minimum": 0, "maximum": 365},
        },
    }

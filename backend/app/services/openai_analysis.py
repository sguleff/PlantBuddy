import base64
import json
from typing import Any, Dict, List, Optional

import httpx
from pydantic import BaseModel, Field, ValidationError

from app.core.config import get_settings
from app.models import Plant, PlantPhoto
from app.services.images import resolve_storage_path


class CareTaskSuggestion(BaseModel):
    task_type: str = Field(pattern="^(watering|fertilizing|repotting|inspection|custom)$")
    title: str = Field(min_length=1, max_length=160)
    notes: Optional[str] = None
    frequency_days: Optional[int] = Field(default=None, ge=1, le=730)
    next_due_days: int = Field(default=0, ge=0, le=365)


class PlantCarePlanResult(BaseModel):
    watering: str
    watering_amount: str
    watering_check: str
    fertilizing: str
    fertilizer_type: str
    fertilizer_amount: str
    sunlight: str
    repotting: str
    repotting_assessment: str
    soil: str
    pruning: str
    watch_outs: str
    task_suggestions: List[CareTaskSuggestion]


class PlantAnalysisResult(BaseModel):
    common_name: str
    scientific_name: str
    confidence: float = Field(ge=0, le=1)
    health_score: int = Field(ge=1, le=10)
    health_notes: str
    care_plan: PlantCarePlanResult
    caution_notes: Optional[str] = None


class OpenAIAnalysisError(Exception):
    pass


def analyze_plant_photo(plant: Plant, photo: PlantPhoto) -> PlantAnalysisResult:
    settings = get_settings()
    if not settings.openai_api_key:
        raise OpenAIAnalysisError("OPENAI_API_KEY is not configured")

    image_path = resolve_storage_path(photo.original_path)
    if not image_path.is_file():
        raise OpenAIAnalysisError("Plant photo file is missing from storage")

    image_data_url = _image_to_data_url(image_path.read_bytes())
    payload = _build_response_payload(settings.openai_model, plant, photo, image_data_url)

    try:
        with httpx.Client(timeout=90) as client:
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
        raise OpenAIAnalysisError(f"OpenAI analysis request failed: {exc}") from exc

    data = response.json()
    parsed = _extract_output_json(data)
    try:
        return PlantAnalysisResult.model_validate(parsed)
    except ValidationError as exc:
        raise OpenAIAnalysisError(f"OpenAI analysis response did not match schema: {exc}") from exc


def _image_to_data_url(image_bytes: bytes) -> str:
    encoded = base64.b64encode(image_bytes).decode("ascii")
    return f"data:image/jpeg;base64,{encoded}"


def _build_response_payload(model: str, plant: Plant, photo: PlantPhoto, image_data_url: str) -> Dict[str, Any]:
    metadata = {
        "pet_name": plant.pet_name,
        "location": plant.location,
        "room_location": plant.room_location,
        "notes": plant.notes,
        "photo_captured_at": photo.captured_at.isoformat() if photo.captured_at else None,
        "photo_uploaded_at": photo.created_at.isoformat() if photo.created_at else None,
        "is_registration_photo": photo.is_registration_photo,
    }
    return {
        "model": model,
        "instructions": (
            "You are Plant Buddy's plant-care analysis engine. Identify the plant from the image, "
            "estimate visible health, and return practical household care guidance. If the image is "
            "unclear, lower confidence and explain visible uncertainty in health_notes. Do not claim "
            "certainty beyond what the image supports."
        ),
        "input": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_text",
                        "text": (
                            "Analyze this houseplant photo and metadata. Use the photo date when considering "
                            "seasonal growth, dormancy, watering stress, and urgency of any recommendations. "
                            f"Metadata JSON: {json.dumps(metadata, ensure_ascii=True)}"
                        ),
                    },
                    {"type": "input_image", "image_url": image_data_url, "detail": "high"},
                ],
            }
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": "plant_analysis",
                "strict": True,
                "schema": _analysis_json_schema(),
            }
        },
    }


def _analysis_json_schema() -> Dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": [
            "common_name",
            "scientific_name",
            "confidence",
            "health_score",
            "health_notes",
            "care_plan",
            "caution_notes",
        ],
        "properties": {
            "common_name": {"type": "string"},
            "scientific_name": {"type": "string"},
            "confidence": {"type": "number", "minimum": 0, "maximum": 1},
            "health_score": {"type": "integer", "minimum": 1, "maximum": 10},
            "health_notes": {"type": "string"},
            "caution_notes": {"type": ["string", "null"]},
            "care_plan": {
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
                    "watering": {"type": "string", "description": "Watering frequency and seasonal adjustment."},
                    "watering_amount": {"type": "string", "description": "Approximate amount to water based on visible plant/pot size."},
                    "watering_check": {"type": "string", "description": "How to check soil/drainage and know watering was sufficient."},
                    "fertilizing": {"type": "string", "description": "Fertilizing frequency and seasonal timing."},
                    "fertilizer_type": {"type": "string", "description": "Specific fertilizer type/formulation appropriate for this plant."},
                    "fertilizer_amount": {"type": "string", "description": "Approximate dilution or amount based on visible plant/pot size."},
                    "sunlight": {"type": "string"},
                    "repotting": {"type": "string", "description": "Repotting frequency and general guidance."},
                    "repotting_assessment": {"type": "string", "description": "Whether the current visible pot appears appropriate or immediate repotting is recommended."},
                    "soil": {"type": "string"},
                    "pruning": {"type": "string", "description": "Pruning, grooming, cleaning, or rotation guidance."},
                    "watch_outs": {"type": "string", "description": "Pests, disease, stress signs, overwatering/underwatering symptoms to monitor."},
                    "task_suggestions": {
                        "type": "array",
                        "minItems": 1,
                        "maxItems": 6,
                        "items": {
                            "type": "object",
                            "additionalProperties": False,
                            "required": ["task_type", "title", "notes", "frequency_days", "next_due_days"],
                            "properties": {
                                "task_type": {
                                    "type": "string",
                                    "enum": ["watering", "fertilizing", "repotting", "inspection", "custom"],
                                },
                                "title": {"type": "string"},
                                "notes": {"type": ["string", "null"]},
                                "frequency_days": {"type": ["integer", "null"], "minimum": 1, "maximum": 730},
                                "next_due_days": {"type": "integer", "minimum": 0, "maximum": 365},
                            },
                        },
                    },
                },
            },
        },
    }


def _extract_output_json(response_data: Dict[str, Any]) -> Dict[str, Any]:
    for output_item in response_data.get("output", []):
        for content_item in output_item.get("content", []):
            if content_item.get("type") == "output_text":
                return json.loads(content_item["text"])
            if content_item.get("type") == "refusal":
                raise OpenAIAnalysisError(f"OpenAI refused analysis: {content_item.get('refusal')}")
    raise OpenAIAnalysisError("OpenAI response did not include output text")

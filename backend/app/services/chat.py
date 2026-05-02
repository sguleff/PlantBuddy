import json
from dataclasses import dataclass
from typing import Any, Dict, Iterator, List

import httpx
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models import AiChatMessage, CarePlan, CareTask, Plant, PlantAnalysis, PlantPhoto, TaskEvent


class OpenAIChatError(Exception):
    pass


@dataclass(frozen=True)
class ChatHistoryItem:
    role: str
    content: str


def build_plant_chat_context(db: Session, plant: Plant) -> Dict[str, Any]:
    latest_analysis = db.scalars(
        select(PlantAnalysis).where(PlantAnalysis.plant_id == plant.id).order_by(PlantAnalysis.created_at.desc()).limit(1)
    ).first()
    care_plan = db.scalars(
        select(CarePlan)
        .where(CarePlan.plant_id == plant.id)
        .where(CarePlan.active.is_(True))
        .order_by(CarePlan.created_at.desc())
        .limit(1)
    ).first()
    tasks = db.scalars(
        select(CareTask).where(CareTask.plant_id == plant.id).where(CareTask.enabled.is_(True)).order_by(CareTask.next_due_date.asc())
    ).all()
    events = db.scalars(
        select(TaskEvent).where(TaskEvent.plant_id == plant.id).order_by(TaskEvent.completed_at.desc()).limit(12)
    ).all()
    photos = db.scalars(
        select(PlantPhoto).where(PlantPhoto.plant_id == plant.id).order_by(PlantPhoto.created_at.desc()).limit(8)
    ).all()
    analyses = db.scalars(
        select(PlantAnalysis).where(PlantAnalysis.plant_id == plant.id).order_by(PlantAnalysis.created_at.desc()).limit(8)
    ).all()
    return {
        "plant": {
            "id": plant.id,
            "pet_name": plant.pet_name,
            "location": plant.location,
            "room_location": plant.room_location,
            "notes": plant.notes,
            "common_name": plant.common_name,
            "scientific_name": plant.scientific_name,
            "health_score": plant.health_score,
        },
        "latest_analysis": _analysis_context(latest_analysis) if latest_analysis else None,
        "analysis_history": [_analysis_context(item) for item in analyses],
        "care_plan": {
            "watering": care_plan.watering,
            "watering_amount": care_plan.watering_amount,
            "watering_check": care_plan.watering_check,
            "fertilizing": care_plan.fertilizing,
            "fertilizer_type": care_plan.fertilizer_type,
            "fertilizer_amount": care_plan.fertilizer_amount,
            "sunlight": care_plan.sunlight,
            "repotting": care_plan.repotting,
            "repotting_assessment": care_plan.repotting_assessment,
            "soil": care_plan.soil,
            "pruning": care_plan.pruning,
            "watch_outs": care_plan.watch_outs,
        }
        if care_plan
        else None,
        "current_tasks": [
            {
                "task_type": task.task_type,
                "title": task.title,
                "notes": task.notes,
                "frequency_days": task.frequency_days,
                "next_due_date": task.next_due_date.isoformat() if task.next_due_date else None,
            }
            for task in tasks
        ],
        "recent_task_events": [
            {
                "completed_at": event.completed_at.isoformat() if event.completed_at else None,
                "due_date": event.due_date.isoformat() if event.due_date else None,
                "was_late": event.was_late,
                "notes": event.notes,
            }
            for event in events
        ],
        "photos": [
            {
                "id": photo.id,
                "created_at": photo.created_at.isoformat() if photo.created_at else None,
                "captured_at": photo.captured_at.isoformat() if photo.captured_at else None,
                "is_registration_photo": photo.is_registration_photo,
                "width": photo.width,
                "height": photo.height,
            }
            for photo in photos
        ],
    }


def generate_chat_reply(context: Dict[str, Any], history: List[ChatHistoryItem], user_message: str) -> str:
    settings = get_settings()
    if not settings.openai_api_key:
        raise OpenAIChatError("OPENAI_API_KEY is not configured")

    payload = _chat_payload(settings.openai_model, context, history, user_message)
    try:
        with httpx.Client(timeout=90) as client:
            response = client.post(
                "https://api.openai.com/v1/responses",
                headers={"Authorization": f"Bearer {settings.openai_api_key}", "Content-Type": "application/json"},
                json=payload,
            )
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise OpenAIChatError(f"OpenAI chat request failed: {exc}") from exc

    return _extract_text(response.json())


def stream_chat_reply(context: Dict[str, Any], history: List[ChatHistoryItem], user_message: str) -> Iterator[str]:
    settings = get_settings()
    if not settings.openai_api_key:
        raise OpenAIChatError("OPENAI_API_KEY is not configured")

    payload = _chat_payload(settings.openai_model, context, history, user_message)
    payload["stream"] = True
    try:
        with httpx.stream(
            "POST",
            "https://api.openai.com/v1/responses",
            headers={"Authorization": f"Bearer {settings.openai_api_key}", "Content-Type": "application/json"},
            json=payload,
            timeout=90,
        ) as response:
            response.raise_for_status()
            for line in response.iter_lines():
                if not line or not line.startswith("data: "):
                    continue
                data = line[len("data: ") :].strip()
                if data == "[DONE]":
                    break
                event = json.loads(data)
                event_type = event.get("type")
                if event_type == "response.output_text.delta":
                    yield event.get("delta", "")
                elif event_type == "response.refusal.delta":
                    yield event.get("delta", "")
                elif event_type in {"response.failed", "response.incomplete"}:
                    raise OpenAIChatError(f"OpenAI streaming response ended with {event_type}")
    except httpx.HTTPError as exc:
        raise OpenAIChatError(f"OpenAI chat stream failed: {exc}") from exc


def chat_history_snapshot(messages: List[AiChatMessage]) -> List[ChatHistoryItem]:
    return [ChatHistoryItem(role=message.role, content=message.content) for message in messages]


def _chat_payload(model: str, context: Dict[str, Any], history: List[ChatHistoryItem], user_message: str) -> Dict[str, Any]:
    content = [
        {
            "type": "input_text",
            "text": (
                "Plant context JSON:\n"
                f"{json.dumps(context, ensure_ascii=True)}\n\n"
                "Answer the user's plant-care question using this context. Use concise Markdown formatting: "
                "short paragraphs, bullets when helpful, and bold labels for key recommendations. "
                "If the context is insufficient, say what photo or observation would help. "
                "Do not invent facts not supported by the plant context."
            ),
        }
    ]
    for message in history[-12:]:
        content.append({"type": "input_text", "text": f"{message.role}: {message.content}"})
    content.append({"type": "input_text", "text": f"user: {user_message}"})

    return {
        "model": model,
        "instructions": (
            "You are Plant Buddy's plant-care chat assistant. You help a household user care for their plants. "
            "Use Markdown for readability. Do not provide medical, veterinary, or human/animal toxicity advice beyond "
            "advising the user to consult authoritative sources."
        ),
        "input": [{"role": "user", "content": content}],
    }


def _analysis_context(analysis: PlantAnalysis) -> Dict[str, Any]:
    return {
        "created_at": analysis.created_at.isoformat() if analysis.created_at else None,
        "photo_id": analysis.photo_id,
        "common_name": analysis.common_name,
        "scientific_name": analysis.scientific_name,
        "confidence": analysis.confidence,
        "health_score": analysis.health_score,
        "health_notes": analysis.health_notes,
    }


def _extract_text(response_data: Dict[str, Any]) -> str:
    chunks = []
    for output_item in response_data.get("output", []):
        for content_item in output_item.get("content", []):
            if content_item.get("type") == "output_text":
                chunks.append(content_item.get("text", ""))
            if content_item.get("type") == "refusal":
                raise OpenAIChatError(f"OpenAI refused chat response: {content_item.get('refusal')}")
    text = "\n".join(chunk for chunk in chunks if chunk).strip()
    if not text:
        raise OpenAIChatError("OpenAI response did not include output text")
    return text

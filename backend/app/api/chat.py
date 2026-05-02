from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_db
from app.models import AiChatMessage, AiChatSession, Plant
from app.schemas import ChatMessageCreate, ChatMessageResponse, ChatSessionCreate, ChatSessionResponse
from app.db import SessionLocal
from app.services.chat import ChatHistoryItem, build_plant_chat_context, chat_history_snapshot, generate_chat_reply, stream_chat_reply


router = APIRouter(tags=["chat"])


@router.get("/plants/{plant_id}/chat/sessions", response_model=List[ChatSessionResponse])
def list_chat_sessions(plant_id: str, db: Session = Depends(get_current_db)):
    _get_plant(db, plant_id)
    return db.scalars(
        select(AiChatSession).where(AiChatSession.plant_id == plant_id).order_by(AiChatSession.updated_at.desc())
    ).all()


@router.post("/plants/{plant_id}/chat/sessions", response_model=ChatSessionResponse, status_code=status.HTTP_201_CREATED)
def create_chat_session(plant_id: str, payload: ChatSessionCreate, db: Session = Depends(get_current_db)):
    plant = _get_plant(db, plant_id)
    session = AiChatSession(plant_id=plant.id, title=payload.title or f"Chat with {plant.pet_name}")
    db.add(session)
    db.commit()
    db.refresh(session)
    return session


@router.get("/chat/sessions/{session_id}/messages", response_model=List[ChatMessageResponse])
def list_chat_messages(session_id: str, db: Session = Depends(get_current_db)):
    _get_session(db, session_id)
    return db.scalars(
        select(AiChatMessage).where(AiChatMessage.session_id == session_id).order_by(AiChatMessage.created_at.asc())
    ).all()


@router.delete("/chat/sessions/{session_id}/messages", status_code=status.HTTP_204_NO_CONTENT)
def clear_chat_messages(session_id: str, db: Session = Depends(get_current_db)):
    _get_session(db, session_id)
    db.query(AiChatMessage).filter(AiChatMessage.session_id == session_id).delete(synchronize_session=False)
    db.commit()
    return None


@router.post("/chat/sessions/{session_id}/messages", response_model=List[ChatMessageResponse], status_code=status.HTTP_201_CREATED)
def create_chat_message(session_id: str, payload: ChatMessageCreate, db: Session = Depends(get_current_db)):
    session = _get_session(db, session_id)
    plant = _get_plant(db, session.plant_id)
    context = build_plant_chat_context(db, plant)
    history = chat_history_snapshot(db.scalars(
        select(AiChatMessage).where(AiChatMessage.session_id == session_id).order_by(AiChatMessage.created_at.asc())
    ).all())

    user_message = AiChatMessage(session_id=session.id, role="user", content=payload.content, prompt_context=None)
    db.add(user_message)
    db.flush()

    reply = generate_chat_reply(context, history, payload.content)
    assistant_message = AiChatMessage(session_id=session.id, role="assistant", content=reply, prompt_context=context)
    db.add(assistant_message)
    db.commit()
    db.refresh(user_message)
    db.refresh(assistant_message)
    return [user_message, assistant_message]


@router.post("/chat/sessions/{session_id}/messages/stream")
def stream_chat_message(session_id: str, payload: ChatMessageCreate, db: Session = Depends(get_current_db)):
    session = _get_session(db, session_id)
    plant = _get_plant(db, session.plant_id)
    context = build_plant_chat_context(db, plant)
    history = chat_history_snapshot(db.scalars(
        select(AiChatMessage).where(AiChatMessage.session_id == session_id).order_by(AiChatMessage.created_at.asc())
    ).all())
    user_message = AiChatMessage(session_id=session.id, role="user", content=payload.content, prompt_context=None)
    db.add(user_message)
    db.commit()

    return StreamingResponse(
        _stream_and_persist(session.id, context, history, payload.content),
        media_type="text/plain; charset=utf-8",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


def _stream_and_persist(session_id: str, context: dict, history: List[ChatHistoryItem], user_content: str):
    chunks = []
    try:
        for chunk in stream_chat_reply(context, history, user_content):
            chunks.append(chunk)
            yield chunk
    except Exception as exc:
        error_text = f"\n\n**Chat failed:** {exc}"
        chunks.append(error_text)
        yield error_text
    finally:
        assistant_text = "".join(chunks).strip()
        if assistant_text:
            db = SessionLocal()
            try:
                db.add(AiChatMessage(session_id=session_id, role="assistant", content=assistant_text, prompt_context=context))
                db.commit()
            finally:
                db.close()


def _get_plant(db: Session, plant_id: str) -> Plant:
    plant = db.get(Plant, plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    return plant


def _get_session(db: Session, session_id: str) -> AiChatSession:
    session = db.get(AiChatSession, session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="Chat session not found")
    return session

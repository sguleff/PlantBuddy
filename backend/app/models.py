from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base, settings


def new_id() -> str:
    return str(uuid4())


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
    )


class Plant(Base, TimestampMixin):
    __tablename__ = "plants"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    pet_name: Mapped[str] = mapped_column(String(120), nullable=False)
    location: Mapped[str] = mapped_column(String(24), nullable=False, default="indoor")
    room_location: Mapped[str] = mapped_column(String(120), nullable=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    common_name: Mapped[str] = mapped_column(String(160), nullable=True)
    scientific_name: Mapped[str] = mapped_column(String(180), nullable=True)
    health_score: Mapped[int] = mapped_column(Integer, nullable=True)
    icon_path: Mapped[str] = mapped_column(Text, nullable=True)
    latest_photo_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plant_photos.id", ondelete="SET NULL"),
        nullable=True,
    )
    archived: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    photos = relationship(
        "PlantPhoto",
        back_populates="plant",
        foreign_keys="PlantPhoto.plant_id",
        cascade="all, delete-orphan",
    )
    latest_photo = relationship("PlantPhoto", foreign_keys=[latest_photo_id], post_update=True)
    analyses = relationship("PlantAnalysis", back_populates="plant", cascade="all, delete-orphan")
    care_plans = relationship("CarePlan", back_populates="plant", cascade="all, delete-orphan")
    tasks = relationship("CareTask", back_populates="plant", cascade="all, delete-orphan")
    chat_sessions = relationship("AiChatSession", back_populates="plant", cascade="all, delete-orphan")
    deep_analyses = relationship("PlantDeepAnalysis", back_populates="plant", cascade="all, delete-orphan")


class PlantPhoto(Base, TimestampMixin):
    __tablename__ = "plant_photos"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    original_path: Mapped[str] = mapped_column(Text, nullable=False)
    thumb_256_path: Mapped[str] = mapped_column(Text, nullable=True)
    thumb_768_path: Mapped[str] = mapped_column(Text, nullable=True)
    mime_type: Mapped[str] = mapped_column(String(80), nullable=False)
    width: Mapped[int] = mapped_column(Integer, nullable=True)
    height: Mapped[int] = mapped_column(Integer, nullable=True)
    file_size_bytes: Mapped[int] = mapped_column(Integer, nullable=True)
    checksum_sha256: Mapped[str] = mapped_column(String(64), nullable=True, index=True)
    is_registration_photo: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    captured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)

    plant = relationship("Plant", back_populates="photos", foreign_keys=[plant_id])
    analyses = relationship("PlantAnalysis", back_populates="photo")


class PlantAnalysis(Base, TimestampMixin):
    __tablename__ = "plant_analysis"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    photo_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plant_photos.id", ondelete="SET NULL"),
        nullable=True,
    )
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="pending")
    common_name: Mapped[str] = mapped_column(String(160), nullable=True)
    scientific_name: Mapped[str] = mapped_column(String(180), nullable=True)
    confidence: Mapped[float] = mapped_column(Float, nullable=True)
    health_score: Mapped[int] = mapped_column(Integer, nullable=True)
    health_notes: Mapped[str] = mapped_column(Text, nullable=True)
    raw_response: Mapped[dict] = mapped_column(JSONB, nullable=True)

    plant = relationship("Plant", back_populates="analyses")
    photo = relationship("PlantPhoto", back_populates="analyses")

    @property
    def photo_captured_at(self):
        if self.photo is None:
            return None
        return self.photo.captured_at or self.photo.created_at

    @property
    def photo_created_at(self):
        if self.photo is None:
            return None
        return self.photo.created_at

    @property
    def photo_is_registration_photo(self):
        if self.photo is None:
            return None
        return self.photo.is_registration_photo

    @property
    def photo_width(self):
        if self.photo is None:
            return None
        return self.photo.width

    @property
    def photo_height(self):
        if self.photo is None:
            return None
        return self.photo.height


class CarePlan(Base, TimestampMixin):
    __tablename__ = "care_plans"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    analysis_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plant_analysis.id", ondelete="SET NULL"),
        nullable=True,
    )
    watering: Mapped[str] = mapped_column(Text, nullable=True)
    watering_amount: Mapped[str] = mapped_column(Text, nullable=True)
    watering_check: Mapped[str] = mapped_column(Text, nullable=True)
    fertilizing: Mapped[str] = mapped_column(Text, nullable=True)
    fertilizer_type: Mapped[str] = mapped_column(Text, nullable=True)
    fertilizer_amount: Mapped[str] = mapped_column(Text, nullable=True)
    sunlight: Mapped[str] = mapped_column(Text, nullable=True)
    repotting: Mapped[str] = mapped_column(Text, nullable=True)
    repotting_assessment: Mapped[str] = mapped_column(Text, nullable=True)
    soil: Mapped[str] = mapped_column(Text, nullable=True)
    pruning: Mapped[str] = mapped_column(Text, nullable=True)
    watch_outs: Mapped[str] = mapped_column(Text, nullable=True)
    raw_plan: Mapped[dict] = mapped_column(JSONB, nullable=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    plant = relationship("Plant", back_populates="care_plans")


class PlantDeepAnalysis(Base, TimestampMixin):
    __tablename__ = "plant_deep_analysis"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="succeeded", index=True)
    selected_photos: Mapped[dict] = mapped_column(JSONB, nullable=True)
    review: Mapped[str] = mapped_column(Text, nullable=True)
    trajectory: Mapped[str] = mapped_column(Text, nullable=True)
    recommendations: Mapped[str] = mapped_column(Text, nullable=True)
    care_plan: Mapped[dict] = mapped_column(JSONB, nullable=True)
    special_tasks: Mapped[dict] = mapped_column(JSONB, nullable=True)
    raw_response: Mapped[dict] = mapped_column(JSONB, nullable=True)
    applied: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    last_error: Mapped[str] = mapped_column(Text, nullable=True)

    plant = relationship("Plant", back_populates="deep_analyses")


class CareTask(Base, TimestampMixin):
    __tablename__ = "care_tasks"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    care_plan_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.care_plans.id", ondelete="SET NULL"),
        nullable=True,
    )
    task_type: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    frequency_days: Mapped[int] = mapped_column(Integer, nullable=True)
    next_due_date: Mapped[date] = mapped_column(Date, nullable=True, index=True)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    user_override: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    plant = relationship("Plant", back_populates="tasks")
    events = relationship("TaskEvent", back_populates="task", cascade="all, delete-orphan")


class TaskEvent(Base, TimestampMixin):
    __tablename__ = "task_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    task_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.care_tasks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    due_date: Mapped[date] = mapped_column(Date, nullable=True)
    was_late: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    notes: Mapped[str] = mapped_column(Text, nullable=True)

    task = relationship("CareTask", back_populates="events")


class AiChatSession(Base, TimestampMixin):
    __tablename__ = "ai_chat_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    title: Mapped[str] = mapped_column(String(160), nullable=True)

    plant = relationship("Plant", back_populates="chat_sessions")
    messages = relationship("AiChatMessage", back_populates="session", cascade="all, delete-orphan")


class AiChatMessage(Base, TimestampMixin):
    __tablename__ = "ai_chat_messages"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    session_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.ai_chat_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    role: Mapped[str] = mapped_column(String(24), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    prompt_context: Mapped[dict] = mapped_column(JSONB, nullable=True)

    session = relationship("AiChatSession", back_populates="messages")


class BackgroundJob(Base, TimestampMixin):
    __tablename__ = "background_jobs"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    job_type: Mapped[str] = mapped_column(String(60), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(24), nullable=False, default="queued", index=True)
    plant_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plants.id", ondelete="CASCADE"),
        nullable=True,
        index=True,
    )
    photo_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{settings.database_schema}.plant_photos.id", ondelete="SET NULL"),
        nullable=True,
    )
    attempts: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    last_error: Mapped[str] = mapped_column(Text, nullable=True)
    payload: Mapped[dict] = mapped_column(JSONB, nullable=True)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    finished_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)

from datetime import date, datetime
from typing import List, Optional

from pydantic import BaseModel, Field


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in_minutes: int
    refresh_expires_in_days: int


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class CurrentUserResponse(BaseModel):
    username: str


class PlantBase(BaseModel):
    pet_name: str = Field(min_length=1, max_length=120)
    location: str = Field(default="indoor", pattern="^(indoor|outdoor)$")
    room_location: Optional[str] = Field(default=None, max_length=120)
    notes: Optional[str] = None


class PlantCreate(PlantBase):
    pass


class PlantUpdate(BaseModel):
    pet_name: Optional[str] = Field(default=None, min_length=1, max_length=120)
    location: Optional[str] = Field(default=None, pattern="^(indoor|outdoor)$")
    room_location: Optional[str] = Field(default=None, max_length=120)
    notes: Optional[str] = None
    archived: Optional[bool] = None


class PlantSummary(BaseModel):
    id: str
    pet_name: str
    location: str
    room_location: Optional[str]
    common_name: Optional[str]
    scientific_name: Optional[str]
    health_score: Optional[int]
    icon_path: Optional[str]
    latest_photo_id: Optional[str]
    archived: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PlantPhotoResponse(BaseModel):
    id: str
    plant_id: str
    original_path: str
    thumb_256_path: Optional[str]
    thumb_768_path: Optional[str]
    mime_type: str
    width: Optional[int]
    height: Optional[int]
    file_size_bytes: Optional[int]
    checksum_sha256: Optional[str]
    is_registration_photo: bool
    captured_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PlantDetail(PlantSummary):
    notes: Optional[str]


class PlantAnalysisResponse(BaseModel):
    id: str
    plant_id: str
    photo_id: Optional[str]
    status: str
    common_name: Optional[str]
    scientific_name: Optional[str]
    confidence: Optional[float]
    health_score: Optional[int]
    health_notes: Optional[str]
    raw_response: Optional[dict]
    photo_captured_at: Optional[datetime]
    photo_created_at: Optional[datetime]
    photo_is_registration_photo: Optional[bool]
    photo_width: Optional[int]
    photo_height: Optional[int]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CarePlanResponse(BaseModel):
    id: str
    plant_id: str
    analysis_id: Optional[str]
    watering: Optional[str]
    watering_amount: Optional[str]
    watering_check: Optional[str]
    fertilizing: Optional[str]
    fertilizer_type: Optional[str]
    fertilizer_amount: Optional[str]
    sunlight: Optional[str]
    repotting: Optional[str]
    repotting_assessment: Optional[str]
    soil: Optional[str]
    pruning: Optional[str]
    watch_outs: Optional[str]
    raw_plan: Optional[dict]
    active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class DeepAnalysisResponse(BaseModel):
    id: str
    plant_id: str
    status: str
    selected_photos: Optional[dict]
    review: Optional[str]
    trajectory: Optional[str]
    recommendations: Optional[str]
    care_plan: Optional[dict]
    special_tasks: Optional[dict]
    raw_response: Optional[dict]
    applied: bool
    last_error: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BackgroundJobResponse(BaseModel):
    id: str
    job_type: str
    status: str
    plant_id: Optional[str]
    photo_id: Optional[str]
    attempts: int
    last_error: Optional[str]
    payload: Optional[dict]
    started_at: Optional[datetime]
    finished_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class TaskUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=160)
    notes: Optional[str] = None
    frequency_days: Optional[int] = Field(default=None, ge=1)
    next_due_date: Optional[date] = None
    enabled: Optional[bool] = None


class TaskCreate(BaseModel):
    plant_id: str
    task_type: str = Field(default="custom", pattern="^(watering|fertilizing|repotting|inspection|custom)$")
    title: str = Field(min_length=1, max_length=160)
    notes: Optional[str] = None
    frequency_days: Optional[int] = Field(default=None, ge=1)
    next_due_date: Optional[date] = None


class TaskCompleteRequest(BaseModel):
    notes: Optional[str] = None


class TaskEventResponse(BaseModel):
    id: str
    task_id: str
    plant_id: str
    completed_at: datetime
    due_date: Optional[date]
    was_late: bool
    notes: Optional[str]

    model_config = {"from_attributes": True}


class CareTaskResponse(BaseModel):
    id: str
    plant_id: str
    task_type: str
    title: str
    notes: Optional[str]
    frequency_days: Optional[int]
    next_due_date: Optional[date]
    enabled: bool
    user_override: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CalendarTaskOccurrence(BaseModel):
    task_id: str
    plant_id: str
    task_type: str
    title: str
    notes: Optional[str]
    frequency_days: Optional[int]
    due_date: date


class CalendarDay(BaseModel):
    day: date
    tasks: List[CalendarTaskOccurrence]


class ChatSessionCreate(BaseModel):
    title: Optional[str] = Field(default=None, max_length=160)


class ChatSessionResponse(BaseModel):
    id: str
    plant_id: str
    title: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ChatMessageCreate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class ChatMessageResponse(BaseModel):
    id: str
    session_id: str
    role: str
    content: str
    prompt_context: Optional[dict]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

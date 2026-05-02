from datetime import date, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_db
from app.models import CareTask, Plant, TaskEvent
from app.schemas import CareTaskResponse, TaskCompleteRequest, TaskCreate, TaskEventResponse, TaskUpdate


router = APIRouter(prefix="/tasks", tags=["tasks"])


@router.get("", response_model=List[CareTaskResponse])
def list_tasks(
    plant_id: Optional[str] = Query(default=None),
    include_disabled: bool = Query(default=False),
    db: Session = Depends(get_current_db),
):
    statement = select(CareTask).order_by(CareTask.next_due_date.asc().nullslast(), CareTask.created_at.desc())
    if plant_id is not None:
        statement = statement.where(CareTask.plant_id == plant_id)
    if not include_disabled:
        statement = statement.where(CareTask.enabled.is_(True))
    return db.scalars(statement).all()


@router.post("", response_model=CareTaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: Session = Depends(get_current_db)):
    plant = db.get(Plant, payload.plant_id)
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")

    task = CareTask(**payload.model_dump(), enabled=True, user_override=True)
    db.add(task)
    db.commit()
    db.refresh(task)
    return task


@router.get("/{task_id}/events", response_model=List[TaskEventResponse])
def list_task_events(task_id: str, db: Session = Depends(get_current_db)):
    task = db.get(CareTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return db.scalars(
        select(TaskEvent)
        .where(TaskEvent.task_id == task_id)
        .order_by(TaskEvent.completed_at.desc())
    ).all()


@router.patch("/{task_id}", response_model=CareTaskResponse)
def update_task(task_id: str, payload: TaskUpdate, db: Session = Depends(get_current_db)):
    task = db.get(CareTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(task, field, value)
    task.user_override = True

    db.commit()
    db.refresh(task)
    return task


@router.post("/{task_id}/complete", response_model=TaskEventResponse, status_code=status.HTTP_201_CREATED)
def complete_task(
    task_id: str,
    payload: TaskCompleteRequest,
    db: Session = Depends(get_current_db),
):
    task = db.get(CareTask, task_id)
    if task is None:
        raise HTTPException(status_code=404, detail="Task not found")

    today = date.today()
    was_late = task.next_due_date is not None and task.next_due_date < today
    event = TaskEvent(
        task_id=task.id,
        plant_id=task.plant_id,
        due_date=task.next_due_date,
        was_late=was_late,
        notes=payload.notes,
    )
    db.add(event)

    if task.frequency_days:
        base_date = task.next_due_date if task.next_due_date and task.next_due_date > today else today
        task.next_due_date = base_date + timedelta(days=task.frequency_days)
    else:
        task.enabled = False

    db.commit()
    db.refresh(event)
    return event

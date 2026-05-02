from datetime import date, timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_db
from app.models import CareTask
from app.schemas import CalendarDay, CalendarTaskOccurrence


router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("", response_model=List[CalendarDay])
def get_calendar(
    start: date = Query(...),
    end: date = Query(...),
    db: Session = Depends(get_current_db),
):
    _validate_range(start, end)
    occurrences = _calendar_occurrences(db, start, end)
    days = {}
    for occurrence in occurrences:
        days.setdefault(occurrence.due_date, []).append(occurrence)

    return [CalendarDay(day=day, tasks=day_tasks) for day, day_tasks in sorted(days.items())]


@router.get(".ics")
def get_calendar_ics(
    start: date = Query(...),
    end: date = Query(...),
    db: Session = Depends(get_current_db),
):
    _validate_range(start, end)
    occurrences = _calendar_occurrences(db, start, end)
    lines = [
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//Plant Buddy//Plant Care Calendar//EN",
        "CALSCALE:GREGORIAN",
        "METHOD:PUBLISH",
        "X-WR-CALNAME:Plant Buddy",
    ]
    for occurrence in occurrences:
        due = occurrence.due_date.strftime("%Y%m%d")
        uid = f"{occurrence.task_id}-{due}@plantbuddy"
        lines.extend(
            [
                "BEGIN:VEVENT",
                f"UID:{_ics_escape(uid)}",
                f"DTSTAMP:{date.today().strftime('%Y%m%d')}T000000Z",
                f"DTSTART;VALUE=DATE:{due}",
                f"SUMMARY:{_ics_escape(occurrence.title)}",
                f"DESCRIPTION:{_ics_escape(occurrence.notes or '')}",
                f"CATEGORIES:{_ics_escape(occurrence.task_type)}",
                "END:VEVENT",
            ]
        )
    lines.append("END:VCALENDAR")
    return Response(
        content="\r\n".join(lines) + "\r\n",
        media_type="text/calendar",
        headers={"Content-Disposition": 'attachment; filename="plant-buddy-calendar.ics"'},
    )


def _calendar_occurrences(db: Session, start: date, end: date) -> List[CalendarTaskOccurrence]:
    tasks = db.scalars(
        select(CareTask)
        .where(CareTask.enabled.is_(True))
        .where(CareTask.next_due_date <= end)
        .order_by(CareTask.next_due_date.asc(), CareTask.title.asc())
    ).all()

    occurrences = []
    for task in tasks:
        if task.next_due_date is None:
            continue
        due_date = task.next_due_date
        if task.frequency_days:
            while due_date < start:
                due_date = due_date + timedelta(days=task.frequency_days)
            while due_date <= end:
                occurrences.append(_occurrence_from_task(task, due_date))
                due_date = due_date + timedelta(days=task.frequency_days)
        elif start <= due_date <= end:
            occurrences.append(_occurrence_from_task(task, due_date))
    return sorted(occurrences, key=lambda item: (item.due_date, item.title))


def _occurrence_from_task(task: CareTask, due_date: date) -> CalendarTaskOccurrence:
    return CalendarTaskOccurrence(
        task_id=task.id,
        plant_id=task.plant_id,
        task_type=task.task_type,
        title=task.title,
        notes=task.notes,
        frequency_days=task.frequency_days,
        due_date=due_date,
    )


def _validate_range(start: date, end: date) -> None:
    if end < start:
        raise HTTPException(status_code=400, detail="Calendar end date must be on or after start date")
    if (end - start).days > 366:
        raise HTTPException(status_code=400, detail="Calendar range cannot exceed 366 days")


def _ics_escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace(",", "\\,").replace(";", "\\;").replace("\n", "\\n")

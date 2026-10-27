from datetime import date, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import require_role
from ..models import AttendanceSession, Role, Student, User
from ..schemas import AttendanceSummary, HomeResponse, SessionItem, StudentProfile
from ..services import attendance as svc

router = APIRouter(prefix="/students", tags=["students"])


def get_student(user: User = Depends(require_role(Role.STUDENT.value)), db: Session = Depends(get_db)) -> Student:
    student = db.scalar(select(Student).where(Student.user_id == user.id))
    if student is None:
        raise HTTPException(404, "Student profile not found")
    return student


@router.get("/me", response_model=StudentProfile)
def my_profile(student: Student = Depends(get_student)):
    return StudentProfile(
        id=student.id,
        roll_no=student.roll_no,
        full_name=student.full_name,
        email=student.user.email,
        batch=student.batch.name if student.batch else None,
    )


@router.get("/me/home", response_model=HomeResponse)
def home(student: Student = Depends(get_student), db: Session = Depends(get_db)):
    summary = svc.compute_summary(db, student)
    today = svc.campus_now().date()
    return HomeResponse(
        full_name=student.full_name,
        roll_no=student.roll_no,
        batch=student.batch.name if student.batch else None,
        overall=summary.overall,
        warning=summary.warning,
        warning_message=summary.warning_message,
        todays_classes=svc.sessions_between(db, student, today, today),
        next_class=svc.next_class(db, student),
        recent=svc.history(db, student, None, None, None, None, limit=5, offset=0),
    )


@router.get("/me/attendance", response_model=AttendanceSummary)
def my_attendance(student: Student = Depends(get_student), db: Session = Depends(get_db)):
    return svc.compute_summary(db, student)


@router.get("/me/attendance/history", response_model=list[SessionItem])
def my_history(
    subject_id: int | None = None,
    status: Literal["PRESENT", "ABSENT"] | None = None,
    from_date: date | None = None,
    to_date: date | None = None,
    limit: int = Query(100, ge=1, le=200),
    offset: int = Query(0, ge=0),
    student: Student = Depends(get_student),
    db: Session = Depends(get_db),
):
    return svc.history(db, student, subject_id, status, from_date, to_date, limit, offset)


@router.get("/me/schedule", response_model=list[SessionItem])
def my_schedule(
    range: Literal["today", "tomorrow", "week"] = "today",
    student: Student = Depends(get_student),
    db: Session = Depends(get_db),
):
    today = svc.campus_now().date()
    if range == "today":
        start = end = today
    elif range == "tomorrow":
        start = end = today + timedelta(days=1)
    else:
        start, end = today, today + timedelta(days=6)
    return svc.sessions_between(db, student, start, end)


@router.get("/me/sessions/{session_id}", response_model=SessionItem)
def my_session(session_id: int, student: Student = Depends(get_student), db: Session = Depends(get_db)):
    session = db.get(AttendanceSession, session_id)
    # 404 (not 403) for other batches' sessions so ids can't be probed.
    if session is None or session.batch_id != student.batch_id:
        raise HTTPException(404, "Session not found")
    record = svc.records_for(db, student, [session.id]).get(session.id)
    return svc.build_item(session, record, svc.campus_now())

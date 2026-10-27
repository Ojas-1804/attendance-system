"""All attendance calculation lives here (backend only; the client never computes or sends percentages)."""
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import (
    AttendanceRecord,
    AttendanceSession,
    AttendanceStatus,
    SessionStatus,
    Student,
    Subject,
    SystemSetting,
)
from ..schemas import AttendanceSummary, SessionItem, Stat, SubjectStat, Thresholds

KEY_MIN = "min_required_attendance"
KEY_HEALTHY = "healthy_attendance"
DEFAULT_MIN = 75.0
DEFAULT_HEALTHY = 85.0
COUNTED = (AttendanceStatus.PRESENT.value, AttendanceStatus.ABSENT.value)


def campus_now() -> datetime:
    return datetime.now(ZoneInfo(settings.timezone)).replace(tzinfo=None)


def get_thresholds(db: Session) -> Thresholds:
    rows = {s.key: s.value for s in db.scalars(select(SystemSetting).where(SystemSetting.key.in_([KEY_MIN, KEY_HEALTHY])))}

    def read(key: str, default: float) -> float:
        try:
            return float(rows[key])
        except (KeyError, ValueError):
            return default

    return Thresholds(min_required=read(KEY_MIN, DEFAULT_MIN), healthy=read(KEY_HEALTHY, DEFAULT_HEALTHY))


def make_stat(present: int, total: int, t: Thresholds) -> Stat:
    if total == 0:
        return Stat(present=0, total=0, percentage=None, level="NO_DATA")
    raw = present / total * 100
    if raw >= t.healthy:
        level = "HEALTHY"
    elif raw >= t.min_required:
        level = "WARNING"
    else:
        level = "LOW"
    return Stat(present=present, total=total, percentage=round(raw, 1), level=level)


def compute_summary(db: Session, student: Student) -> AttendanceSummary:
    """Only FINALIZED sessions with a PRESENT/ABSENT final status count.
    Future, cancelled, and not-yet-finalized sessions are excluded."""
    t = get_thresholds(db)
    rows = db.execute(
        select(AttendanceSession.subject_id, AttendanceRecord.final_status)
        .join(AttendanceRecord, AttendanceRecord.session_id == AttendanceSession.id)
        .where(
            AttendanceRecord.student_id == student.id,
            AttendanceSession.status == SessionStatus.FINALIZED.value,
            AttendanceRecord.final_status.in_(COUNTED),
        )
    ).all()

    per_subject: dict[int, list[int]] = {}
    for subject_id, final_status in rows:
        counts = per_subject.setdefault(subject_id, [0, 0])  # [present, total]
        counts[1] += 1
        if final_status == AttendanceStatus.PRESENT.value:
            counts[0] += 1

    # Also list subjects the student's batch has classes in, even with no finalized session yet.
    subject_ids = set(per_subject)
    if student.batch_id is not None:
        subject_ids |= set(
            db.scalars(select(AttendanceSession.subject_id).where(AttendanceSession.batch_id == student.batch_id).distinct())
        )
    subjects = db.scalars(select(Subject).where(Subject.id.in_(subject_ids)).order_by(Subject.name)).all() if subject_ids else []

    subject_stats = []
    for sub in subjects:
        present, total = per_subject.get(sub.id, [0, 0])
        stat = make_stat(present, total, t)
        subject_stats.append(SubjectStat(subject_id=sub.id, subject_name=sub.name, subject_code=sub.code, **stat.model_dump()))

    overall = make_stat(sum(c[0] for c in per_subject.values()), sum(c[1] for c in per_subject.values()), t)
    warning = overall.percentage is not None and overall.percentage < t.min_required and overall.level == "LOW"
    message = (
        f"Your attendance is below the required threshold ({t.min_required:g}%)." if warning else None
    )
    return AttendanceSummary(overall=overall, subjects=subject_stats, thresholds=t, warning=warning, warning_message=message)


def display_status(session: AttendanceSession, record: AttendanceRecord | None, now: datetime) -> str:
    if session.status == SessionStatus.CANCELLED.value:
        return "CANCELLED"
    if session.status == SessionStatus.FINALIZED.value and record and record.final_status in COUNTED:
        return record.final_status
    if now < datetime.combine(session.date, session.start_time):
        return "UPCOMING"
    return "PENDING"  # class has started but attendance is not finalized yet


def build_item(session: AttendanceSession, record: AttendanceRecord | None, now: datetime) -> SessionItem:
    return SessionItem(
        id=session.id,
        date=session.date,
        start_time=session.start_time.strftime("%H:%M"),
        end_time=session.end_time.strftime("%H:%M"),
        subject_id=session.subject_id,
        subject_name=session.subject.name,
        subject_code=session.subject.code,
        teacher_name=session.teacher.full_name,
        room=session.classroom.name if session.classroom else None,
        batch=session.batch.name,
        status=display_status(session, record, now),
    )


def records_for(db: Session, student: Student, session_ids: list[int]) -> dict[int, AttendanceRecord]:
    if not session_ids:
        return {}
    rows = db.scalars(
        select(AttendanceRecord).where(AttendanceRecord.student_id == student.id, AttendanceRecord.session_id.in_(session_ids))
    )
    return {r.session_id: r for r in rows}


def sessions_between(db: Session, student: Student, start: date, end: date) -> list[SessionItem]:
    if student.batch_id is None:
        return []
    sessions = db.scalars(
        select(AttendanceSession)
        .where(AttendanceSession.batch_id == student.batch_id, AttendanceSession.date >= start, AttendanceSession.date <= end)
        .order_by(AttendanceSession.date, AttendanceSession.start_time)
    ).all()
    records = records_for(db, student, [s.id for s in sessions])
    now = campus_now()
    return [build_item(s, records.get(s.id), now) for s in sessions]


def history(
    db: Session,
    student: Student,
    subject_id: int | None,
    status: str | None,
    from_date: date | None,
    to_date: date | None,
    limit: int,
    offset: int,
) -> list[SessionItem]:
    query = (
        select(AttendanceSession, AttendanceRecord)
        .join(AttendanceRecord, AttendanceRecord.session_id == AttendanceSession.id)
        .where(
            AttendanceRecord.student_id == student.id,
            AttendanceSession.status == SessionStatus.FINALIZED.value,
            AttendanceRecord.final_status.in_(COUNTED),
        )
    )
    if subject_id is not None:
        query = query.where(AttendanceSession.subject_id == subject_id)
    if status is not None:
        query = query.where(AttendanceRecord.final_status == status)
    if from_date is not None:
        query = query.where(AttendanceSession.date >= from_date)
    if to_date is not None:
        query = query.where(AttendanceSession.date <= to_date)
    query = query.order_by(AttendanceSession.date.desc(), AttendanceSession.start_time.desc()).limit(limit).offset(offset)
    now = campus_now()
    return [build_item(s, r, now) for s, r in db.execute(query).all()]


def next_class(db: Session, student: Student) -> SessionItem | None:
    now = campus_now()
    for item in sessions_between(db, student, now.date(), now.date() + timedelta(days=14)):
        start = datetime.combine(item.date, datetime.strptime(item.start_time, "%H:%M").time())
        if item.status != "CANCELLED" and start > now:
            return item
    return None

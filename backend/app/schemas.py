from datetime import date

from pydantic import BaseModel, EmailStr


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str


class StudentProfile(BaseModel):
    id: int
    roll_no: str
    full_name: str
    email: EmailStr
    batch: str | None


class Thresholds(BaseModel):
    min_required: float
    healthy: float


class Stat(BaseModel):
    present: int
    total: int
    percentage: float | None
    level: str  # HEALTHY | WARNING | LOW | NO_DATA


class SubjectStat(Stat):
    subject_id: int
    subject_name: str
    subject_code: str


class AttendanceSummary(BaseModel):
    overall: Stat
    subjects: list[SubjectStat]
    thresholds: Thresholds
    warning: bool
    warning_message: str | None


class SessionItem(BaseModel):
    id: int
    date: date
    start_time: str
    end_time: str
    subject_id: int
    subject_name: str
    subject_code: str
    teacher_name: str
    room: str | None
    batch: str
    # PRESENT | ABSENT | UPCOMING | PENDING | CANCELLED
    status: str


class HomeResponse(BaseModel):
    full_name: str
    roll_no: str
    batch: str | None
    overall: Stat
    warning: bool
    warning_message: str | None
    todays_classes: list[SessionItem]
    next_class: SessionItem | None
    recent: list[SessionItem]

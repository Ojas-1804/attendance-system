from datetime import date, time, timedelta

import pytest

from app.database import SessionLocal
from app.models import (
    AttendanceRecord, AttendanceSession, Batch, Role, SessionStatus, Student, Subject, SystemSetting, Teacher, User,
)
from app.security import hash_password
from app.services.attendance import KEY_MIN, campus_now

from .conftest import login

TODAY = lambda: campus_now().date()  # noqa: E731


def _headers(client, email="s@test.com"):
    return {"Authorization": f"Bearer {login(client, email).json()['access_token']}"}


@pytest.fixture()
def data(client):
    """CS: 3 present + 1 absent (75%). MATH: 1 present + 1 absent (50%). Overall 4/6.
    Also: a cancelled session, a future session, a not-yet-finalized session, and another student's records
    -- none of which may affect Test Student's numbers."""
    db = SessionLocal()
    batch = db.query(Batch).one()
    teacher = db.query(Teacher).one()
    me = db.query(Student).filter_by(roll_no="R1").one()
    other_user = User(email="o@test.com", role=Role.STUDENT.value, password_hash=hash_password("pass1234"))
    db.add(other_user)
    db.flush()
    other = Student(user_id=other_user.id, roll_no="R2", full_name="Other", batch_id=batch.id)
    other_batch = Batch(name="ECE-B")
    cs, math = Subject(name="Computer Science", code="CS"), Subject(name="Mathematics", code="MATH")
    db.add_all([other, other_batch, cs, math])
    db.flush()

    def add(subject, days_ago, status, me_status=None, other_status=None, batch_id=None, start=time(10, 0)):
        s = AttendanceSession(
            subject_id=subject.id, teacher_id=teacher.id, batch_id=batch_id or batch.id,
            date=TODAY() - timedelta(days=days_ago), start_time=start, end_time=time(11, 0), status=status,
        )
        db.add(s)
        db.flush()
        for student, st in ((me, me_status), (other, other_status)):
            if st:
                db.add(AttendanceRecord(session_id=s.id, student_id=student.id, final_status=st))
        return s

    F = SessionStatus.FINALIZED.value
    for i, st in enumerate(["PRESENT", "PRESENT", "PRESENT", "ABSENT"], start=1):
        add(cs, i, F, me_status=st, other_status="ABSENT")
    add(math, 5, F, me_status="PRESENT", other_status="PRESENT")
    add(math, 6, F, me_status="ABSENT", other_status="PRESENT")
    add(cs, 7, SessionStatus.CANCELLED.value)
    add(cs, 8, SessionStatus.REVIEW_REQUIRED.value, me_status="PRESENT")  # not finalized: ignored
    add(cs, -3, SessionStatus.SCHEDULED.value)  # future: ignored
    foreign = add(cs, 9, F, batch_id=other_batch.id)
    db.commit()
    ids = {"foreign": foreign.id}
    db.close()
    return ids


def test_overall_and_subject_percentages(client, data):
    r = client.get("/students/me/attendance", headers=_headers(client))
    assert r.status_code == 200
    body = r.json()
    assert body["overall"]["present"] == 4 and body["overall"]["total"] == 6
    assert body["overall"]["percentage"] == 66.7
    subjects = {s["subject_code"]: s for s in body["subjects"]}
    assert (subjects["CS"]["present"], subjects["CS"]["total"], subjects["CS"]["percentage"]) == (3, 4, 75.0)
    assert (subjects["MATH"]["present"], subjects["MATH"]["total"], subjects["MATH"]["percentage"]) == (1, 2, 50.0)


def test_levels_use_default_thresholds(client, data):
    body = client.get("/students/me/attendance", headers=_headers(client)).json()
    subjects = {s["subject_code"]: s for s in body["subjects"]}
    assert subjects["CS"]["level"] == "WARNING"  # exactly 75% meets the minimum but is not healthy
    assert subjects["MATH"]["level"] == "LOW"
    assert body["overall"]["level"] == "LOW"
    assert body["warning"] is True
    assert "below the required threshold" in body["warning_message"]


def test_thresholds_are_read_from_settings_not_hardcoded(client, data):
    db = SessionLocal()
    db.add(SystemSetting(key=KEY_MIN, value="60"))
    db.commit()
    db.close()
    body = client.get("/students/me/attendance", headers=_headers(client)).json()
    assert body["thresholds"]["min_required"] == 60.0
    assert body["overall"]["level"] == "WARNING"  # 66.7% is now above the minimum
    assert body["warning"] is False


def test_student_with_no_sessions_has_no_data(client):
    body = client.get("/students/me/attendance", headers=_headers(client)).json()
    assert body["overall"]["percentage"] is None
    assert body["overall"]["level"] == "NO_DATA"
    assert body["warning"] is False


def test_history_excludes_other_students_cancelled_and_unfinalized(client, data):
    r = client.get("/students/me/attendance/history", headers=_headers(client))
    assert r.status_code == 200
    assert len(r.json()) == 6
    dates = [x["date"] for x in r.json()]
    assert dates == sorted(dates, reverse=True)


def test_history_filters(client, data):
    h = _headers(client)
    assert len(client.get("/students/me/attendance/history?status=ABSENT", headers=h).json()) == 2
    subject_id = client.get("/students/me/attendance", headers=h).json()["subjects"][0]["subject_id"]
    by_subject = client.get(f"/students/me/attendance/history?subject_id={subject_id}", headers=h).json()
    assert len(by_subject) in (2, 4)
    recent = (TODAY() - timedelta(days=2)).isoformat()
    assert len(client.get(f"/students/me/attendance/history?from_date={recent}", headers=h).json()) == 2
    assert client.get("/students/me/attendance/history?status=MAYBE", headers=h).status_code == 422


def test_schedule_today_tomorrow_week(client, data):
    h = _headers(client)
    db = SessionLocal()
    batch, teacher, subject = db.query(Batch).filter_by(name="CSE-A").one(), db.query(Teacher).one(), db.query(Subject).first()
    for delta in (0, 1, 3):
        db.add(AttendanceSession(
            subject_id=subject.id, teacher_id=teacher.id, batch_id=batch.id,
            date=TODAY() + timedelta(days=delta), start_time=time(23, 59), end_time=time(23, 59),
        ))
    db.commit()
    db.close()
    today = client.get("/students/me/schedule?range=today", headers=h).json()
    assert len(today) == 1 and today[0]["status"] in ("UPCOMING", "PENDING")
    assert len(client.get("/students/me/schedule?range=tomorrow", headers=h).json()) == 1
    # 3 added here + 1 future session from the shared fixture (cancelled/past ones are outside the window)
    assert len(client.get("/students/me/schedule?range=week", headers=h).json()) == 4
    assert client.get("/students/me/schedule?range=year", headers=h).status_code == 422


def test_session_detail_shows_my_status_and_hides_other_batches(client, data):
    h = _headers(client)
    first = client.get("/students/me/attendance/history", headers=h).json()[0]
    r = client.get(f"/students/me/sessions/{first['id']}", headers=h)
    assert r.status_code == 200 and r.json()["status"] == first["status"]
    assert client.get(f"/students/me/sessions/{data['foreign']}", headers=h).status_code == 404


def test_home_endpoint(client, data):
    body = client.get("/students/me/home", headers=_headers(client)).json()
    assert body["full_name"] == "Test Student"
    assert body["overall"]["total"] == 6
    assert len(body["recent"]) == 5


def test_teacher_cannot_use_student_endpoints(client, data):
    h = _headers(client, "t@test.com")
    for path in ("/students/me/home", "/students/me/attendance", "/students/me/schedule", "/students/me/attendance/history"):
        assert client.get(path, headers=h).status_code == 403


def test_student_endpoints_require_login(client):
    assert client.get("/students/me/attendance").status_code == 401

"""Create demo data for local development and the Mid-term 1 demo.  Run: python seed.py

Creates: admin/teacher/2 students, batch CSE-A, 3 subjects, ~6 weeks of timetable.
Past sessions are finalized so the student app shows real percentages:
  Computer Science ~90% (green), Mathematics ~80% (yellow), Physics ~67% (red).
"""
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.database import Base, SessionLocal, engine
from app.models import (
    Admin, AttendanceRecord, AttendanceSession, Batch, Classroom, Role, SessionStatus,
    Student, Subject, SystemSetting, Teacher, User,
)
from app.security import hash_password
from app.services.attendance import KEY_HEALTHY, KEY_MIN, campus_now

Base.metadata.create_all(bind=engine)
db = SessionLocal()


def get_or_create_user(email, role, pw):
    u = db.scalar(select(User).where(User.email == email))
    if u:
        return u
    u = User(email=email, role=role.value, password_hash=hash_password(pw))
    db.add(u)
    db.flush()
    return u


def one(model, **where):
    return db.scalar(select(model).filter_by(**where))


batch = one(Batch, name="CSE-A") or Batch(name="CSE-A")
db.add(batch)
db.flush()

admin_u = get_or_create_user("admin@demo.edu", Role.ADMIN, "Admin@12345")
teacher_u = get_or_create_user("teacher@demo.edu", Role.TEACHER, "Teacher@12345")
rahul_u = get_or_create_user("student@demo.edu", Role.STUDENT, "Student@12345")
priya_u = get_or_create_user("priya@demo.edu", Role.STUDENT, "Student@12345")

if not one(Admin, user_id=admin_u.id):
    db.add(Admin(user_id=admin_u.id, full_name="Demo Admin"))
teacher = one(Teacher, user_id=teacher_u.id) or Teacher(user_id=teacher_u.id, full_name="Mr. Sharma")
db.add(teacher)
rahul = one(Student, user_id=rahul_u.id) or Student(user_id=rahul_u.id, roll_no="CSE001", full_name="Rahul Demo", batch_id=batch.id)
priya = one(Student, user_id=priya_u.id) or Student(user_id=priya_u.id, roll_no="CSE002", full_name="Priya Demo", batch_id=batch.id)
db.add_all([rahul, priya])

subjects = {}
for code, name in [("CS", "Computer Science"), ("MATH", "Mathematics"), ("PHY", "Physics")]:
    subjects[code] = one(Subject, code=code) or Subject(code=code, name=name)
    db.add(subjects[code])
rooms = {}
for name in ["Room 204", "Room 301"]:
    rooms[name] = one(Classroom, name=name) or Classroom(name=name)
    db.add(rooms[name])
for key, value in [(KEY_MIN, "75"), (KEY_HEALTHY, "85")]:
    if not db.get(SystemSetting, key):
        db.add(SystemSetting(key=key, value=value))
db.flush()

if db.scalar(select(AttendanceSession).limit(1)):
    db.commit()
    print("Sessions already exist - skipped timetable creation.")
    raise SystemExit

# weekday (Mon=0) -> [(subject, start, end, room)]
TEMPLATE = {
    0: [("MATH", "09:00", "10:00", "Room 204"), ("CS", "10:00", "11:00", "Room 204"), ("PHY", "12:00", "13:00", "Room 301")],
    1: [("CS", "09:00", "10:00", "Room 204"), ("PHY", "10:00", "11:00", "Room 301"), ("MATH", "12:00", "13:00", "Room 204")],
    2: [("MATH", "09:00", "10:00", "Room 204"), ("CS", "10:00", "11:00", "Room 204"), ("PHY", "12:00", "13:00", "Room 301")],
    3: [("PHY", "09:00", "10:00", "Room 301"), ("MATH", "10:00", "11:00", "Room 204"), ("CS", "12:00", "13:00", "Room 204")],
    4: [("CS", "09:00", "10:00", "Room 204"), ("MATH", "10:00", "11:00", "Room 204"), ("PHY", "12:00", "13:00", "Room 301")],
    5: [("CS", "10:00", "11:00", "Room 204"), ("MATH", "11:00", "12:00", "Room 204")],
}
ABSENT_EVERY = {"CS": 10, "MATH": 5, "PHY": 3}  # Rahul absent when counter % n == n-1
now = campus_now()
counters = {"CS": 0, "MATH": 0, "PHY": 0}
past_index = 0
for offset in range(-42, 15):
    day = now.date() + timedelta(days=offset)
    for code, start, end, room in TEMPLATE.get(day.weekday(), []):
        s_time = datetime.strptime(start, "%H:%M").time()
        e_time = datetime.strptime(end, "%H:%M").time()
        ended = datetime.combine(day, e_time) <= now
        session = AttendanceSession(
            subject_id=subjects[code].id, teacher_id=teacher.id, batch_id=batch.id,
            classroom_id=rooms[room].id, date=day, start_time=s_time, end_time=e_time,
            status=SessionStatus.FINALIZED.value if ended else SessionStatus.SCHEDULED.value,
        )
        if ended:
            past_index += 1
            if past_index == 12:  # one cancelled class (not counted in attendance)
                session.status = SessionStatus.CANCELLED.value
        db.add(session)
        db.flush()
        if session.status == SessionStatus.FINALIZED.value:
            n = ABSENT_EVERY[code]
            rahul_present = counters[code] % n != n - 1
            priya_present = counters[code] % 7 != 3
            counters[code] += 1
            for student, present in ((rahul, rahul_present), (priya, priya_present)):
                status = "PRESENT" if present else "ABSENT"
                db.add(AttendanceRecord(
                    session_id=session.id, student_id=student.id, ai_status=None,
                    final_status=status, marked_by=teacher_u.id, marked_at=datetime.now(timezone.utc),
                ))
db.commit()
print("Seed complete. Logins: student@demo.edu / Student@12345, teacher@demo.edu / Teacher@12345, admin@demo.edu / Admin@12345")

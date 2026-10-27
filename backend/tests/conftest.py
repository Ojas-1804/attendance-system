import os

os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["JWT_SECRET"] = "test-secret-test-secret-test-secret"

import pytest
from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.models import Batch, Role, Student, Teacher, User
from app.security import hash_password


@pytest.fixture()
def client():
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    batch = Batch(name="CSE-A")
    db.add(batch)
    db.flush()
    s = User(email="s@test.com", role=Role.STUDENT.value, password_hash=hash_password("pass1234"))
    t = User(email="t@test.com", role=Role.TEACHER.value, password_hash=hash_password("pass1234"))
    db.add_all([s, t])
    db.flush()
    db.add(Student(user_id=s.id, roll_no="R1", full_name="Test Student", batch_id=batch.id))
    db.add(Teacher(user_id=t.id, full_name="Test Teacher"))
    db.commit()
    db.close()
    yield TestClient(app)


def login(client, email, password="pass1234"):
    return client.post("/auth/login", json={"email": email, "password": password})

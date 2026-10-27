from .conftest import login


def test_health(client):
    assert client.get("/health").json() == {"status": "ok"}


def test_login_success(client):
    r = login(client, "s@test.com")
    assert r.status_code == 200
    assert r.json()["role"] == "STUDENT"


def test_login_wrong_password(client):
    assert login(client, "s@test.com", "wrong").status_code == 401


def test_login_unknown_user(client):
    assert login(client, "nobody@test.com").status_code == 401


def test_refresh_flow(client):
    tokens = login(client, "s@test.com").json()
    r = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert r.status_code == 200


def test_access_token_cannot_be_used_as_refresh(client):
    tokens = login(client, "s@test.com").json()
    r = client.post("/auth/refresh", json={"refresh_token": tokens["access_token"]})
    assert r.status_code == 401


def test_refresh_token_cannot_be_used_as_access(client):
    tokens = login(client, "s@test.com").json()
    r = client.get("/students/me", headers={"Authorization": f"Bearer {tokens['refresh_token']}"})
    assert r.status_code == 401


def test_student_profile(client):
    token = login(client, "s@test.com").json()["access_token"]
    r = client.get("/students/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 200
    assert r.json()["roll_no"] == "R1"
    assert r.json()["batch"] == "CSE-A"


def test_no_token_is_401(client):
    assert client.get("/students/me").status_code == 401


def test_teacher_cannot_access_student_endpoint(client):
    token = login(client, "t@test.com").json()["access_token"]
    r = client.get("/students/me", headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 403


def test_student_web_app_is_served(client):
    r = client.get("/app/")
    assert r.status_code == 200 and "Student Login" in r.text

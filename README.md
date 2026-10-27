# AI-Enabled Attendance Management System

A multi-semester B.Tech TDP project: teachers photograph a classroom, AI proposes attendance,
the teacher reviews and finalizes, and students see their attendance in their own app.

> The AI is an assistant, not the final authority: **AI result -> human review -> final result.**

## Status

| Phase | Description | Status |
|---|---|---|
| 1 | Foundation: backend, DB, auth, roles | Done (Mid-term 1) |
| 2 | Student system (API + Flutter student app) | Done (Mid-term 1) |
| 3 | Teacher system | Planned (Sem 4) |
| 4 | AI engine | Planned (Sem 5) |
| 5-6 | Manual review, finalize, student sync | Planned (Sem 6) |
| 7-8 | Admin dashboard, production hardening | Planned (Sem 7) |

## Repository layout
```
backend/       FastAPI + SQLAlchemy + PostgreSQL (auth, student APIs, attendance calculation, tests)
student_app/   Flutter student app
docs/          decision log, demo script
```

## Run the backend
```bash
cp .env.example .env                       # edit JWT_SECRET and the DB password
docker compose up --build                  # PostgreSQL + API on http://localhost:8000
docker compose exec api python seed.py     # demo data
```
Interactive API docs: http://localhost:8000/docs

Without Docker (needs your own PostgreSQL):
```bash
cd backend
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp ../.env.example .env                               # set DATABASE_URL and JWT_SECRET
python seed.py
uvicorn app.main:app --reload
```

Demo logins (created by `seed.py`; demo-only passwords):
`student@demo.edu / Student@12345`, `teacher@demo.edu / Teacher@12345`, `admin@demo.edu / Admin@12345`

## Run the student app
- **Web version (no extra tools):** start the backend, then open http://localhost:8000/app/ (served from `backend/static/`).
- **Flutter version:** see [student_app/README.md](student_app/README.md) (needs a Flutter-compatible macOS/Windows/Linux machine).

## Student API (all require a STUDENT access token)
| Endpoint | Purpose |
|---|---|
| `POST /auth/login`, `POST /auth/refresh` | Authentication |
| `GET /students/me` | Profile |
| `GET /students/me/home` | Home screen data (overall %, today's classes, next class, recent) |
| `GET /students/me/attendance` | Overall + subject-wise attendance, thresholds, warning |
| `GET /students/me/attendance/history` | History; filters: `subject_id`, `status`, `from_date`, `to_date` |
| `GET /students/me/schedule?range=today\|tomorrow\|week` | Timetable |
| `GET /students/me/sessions/{id}` | One session with my status |

## Attendance calculation (backend only)
`percentage = present / counted * 100`, where *counted* = FINALIZED sessions with a PRESENT/ABSENT final status.
Future, cancelled, and not-yet-finalized sessions are never counted. Green/yellow/red levels come from the
`system_settings` table (`min_required_attendance`, `healthy_attendance`) - nothing is hard-coded.

## Tests
```bash
cd backend && pytest        # 21 tests: auth, role checks, attendance maths, filters, schedule, isolation
```

## Privacy
Face data is biometric data. Only consenting people are used for testing, embeddings are never exposed to
the student app, and deletion of a person's face data will be supported.

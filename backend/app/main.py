from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import Base, engine
from .routers import auth, students

# Phase 1/2: create tables directly. Alembic migrations are planned (see docs/decisions.md).
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Attendance Management API", version="0.2.0")

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(CORSMiddleware, allow_origins=origins, allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router)
app.include_router(students.router)


@app.get("/health", tags=["system"])
def health():
    return {"status": "ok"}


@app.get("/", include_in_schema=False)
def root():
    return RedirectResponse("/app/")


# Simple web version of the student app, served by the API itself (same origin, no extra tooling).
app.mount("/app", StaticFiles(directory=Path(__file__).resolve().parent.parent / "static", html=True), name="web")

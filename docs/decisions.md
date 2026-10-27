# Decision log

## 2026-10 - Stateless JWT access + refresh tokens
Simple to build and test. Trade-off: refresh tokens cannot be revoked individually yet.
Planned: store refresh token IDs in the database in Phase 8 to allow logout/revocation.

## 2026-10 - bcrypt used directly (not passlib)
passlib is unmaintained and has compatibility issues with newer bcrypt versions.

## 2026-10 - Tables created with create_all in Phase 1
Fastest way to start. Alembic migrations will be added before the schema gets large (Phase 2/3).

## 2026-10 - Tests use SQLite, runtime uses PostgreSQL
Keeps tests fast with no setup. Before Phase 8, run tests against PostgreSQL in CI too.

## 2026-10 - Same error for wrong email and wrong password
Prevents revealing which emails exist.

## 2026-10 - Session times stored as campus-local wall-clock time
One campus, one timezone (`TIMEZONE` setting, default Asia/Kolkata). Avoids timezone bugs in "today" / "next class".
Revisit if multiple campuses are ever supported.

## 2026-10 - No separate timetable table yet
Concrete dated `attendance_sessions` rows serve as the schedule (today/tomorrow/week are just date queries).
A recurring-timetable generator can be added in the admin phase to create these rows automatically.

## 2026-10 - Only FINALIZED sessions count toward attendance
Matches the spec: AI result -> human review -> final. Students never see unreviewed AI output as a final status;
they see PENDING until the teacher finalizes.

## 2026-10 - Thresholds live in the database
`system_settings` holds `min_required_attendance` (default 75) and `healthy_attendance` (default 85).
Defaults exist in code only as a fallback when the rows are missing.

## 2026-10 - Other batches' sessions return 404 (not 403)
Prevents students from probing which session ids exist.

## 2026-10 - Demo emails use demo.edu
The email validator rejects reserved names like `.local` and `.example`.

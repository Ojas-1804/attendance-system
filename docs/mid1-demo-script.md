# Mid-term 1 demo script (about 5 minutes)

**Before the exam:** run the stack, run `seed.py` (it creates sessions relative to today, so reseed on the day:
delete the DB volume with `docker compose down -v`, then `up` and seed again), and have the app running.

1. **Architecture (30s)** - show the diagram in the project spec and the repo layout; explain which parts exist today.
2. **Backend (60s)** - open `http://localhost:8000/docs`. Log in as the student; authorize; call `/students/me/attendance`.
3. **Role security (30s)** - log in as the teacher and call `/students/me/attendance` -> 403. Call without a token -> 401.
4. **Student app (2 min)** - log in; Home (overall %, today's classes); Attendance (Computer Science green, Mathematics yellow,
   Physics red); tap Physics -> filtered history; filter Absent; Schedule tabs; session details; log out.
5. **Correctness (30s)** - run `pytest` (21 passing). Mention cancelled / future / unfinalized sessions are excluded.
6. **Roadmap (30s)** - show the README status table and the Sem 4-8 plan; open the GitHub commit history.

**Likely questions**
- *Why does the app not calculate percentages?* The client is not trusted; the server is the single source of truth.
- *Where is the AI?* Phase 4 (Sem 5). The database already separates `ai_status` and `final_status`.
- *How are thresholds configured?* `system_settings` table; an admin screen comes in Phase 7.

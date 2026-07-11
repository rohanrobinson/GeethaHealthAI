# Geetha Health

A personal medical record iOS app: view your medical records and share them with healthcare providers. All data stays on-device — no backend, no cloud.

**Active development happens in [`ios/`](ios/).** See [docs/ios-pivot.md](docs/ios-pivot.md) for the architecture and roadmap.

## iOS app

Prereqs: Xcode 15+ (full Xcode, not just Command Line Tools).

```
cd ios
xcodegen generate   # regenerates GeethaHealth.xcodeproj from project.yml (brew install xcodegen)
open GeethaHealth.xcodeproj
```

Run the `GeethaHealth` scheme in the iOS Simulator (iOS 17+).

When adding/removing Swift files outside Xcode, re-run `xcodegen generate`.

## Legacy web app (frozen)

The original family-health web app lives in `frontend/` (React + TypeScript + Vite) and `backend/` (Python 3.12 + FastAPI + SQLAlchemy 2 + PostgreSQL 16, JWT auth). It is **frozen** — kept for reference (the domain model informed the iOS SwiftData schema) but no longer developed.

<details>
<summary>Running the legacy web app</summary>

Prereqs: Node.js 18+, Python 3.12, Docker.

```bash
# Postgres
docker compose up -d postgres

# Backend — http://localhost:8000 (docs at /docs)
cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env             # edit SECRET_KEY
uvicorn main:app --reload --port 8000

# Frontend — http://localhost:5173
cd frontend
npm install
npm run dev
```

Or run everything with Docker:

```bash
cp backend/.env.example backend/.env  # edit SECRET_KEY
docker compose up --build
```

API overview: `/auth/register`, `/auth/login`, `/families`, `/families/{family_id}/members`, `/members/{person_id}/conditions`, `/members/{person_id}/medications`, `/members/{person_id}/appointments`, `/members/{person_id}/reports`.

</details>

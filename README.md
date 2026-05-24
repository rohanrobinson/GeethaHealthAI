# Geetha Health AI

Family health management app — React frontend + FastAPI backend + PostgreSQL.

## Stack

| Layer | Tech |
|---|---|
| Frontend | React + TypeScript + Vite |
| Backend | Python 3.12 + FastAPI |
| Database | PostgreSQL 16 |
| ORM | SQLAlchemy 2 |
| Auth | JWT (python-jose) + bcrypt |
| Container | Docker / docker-compose |

## Quick start

### 1. Start Postgres

```bash
docker compose up -d postgres
```

### 2. Backend

```bash
cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env             # edit SECRET_KEY
uvicorn main:app --reload --port 8000
```

API runs on `http://localhost:8000`  
Auto docs at `http://localhost:8000/docs`

### 3. Frontend

```bash
cd frontend
npm install
npm run dev
```

Frontend runs on `http://localhost:5173`

## Or run everything with Docker

```bash
cp backend/.env.example backend/.env  # edit SECRET_KEY
docker compose up --build
```

## API overview

| Resource | Base path |
|---|---|
| Auth | `/auth/register`, `/auth/login` |
| Families | `/families` |
| Members | `/families/{family_id}/members` |
| Conditions | `/members/{person_id}/conditions` |
| Medications | `/members/{person_id}/medications` |
| Appointments | `/members/{person_id}/appointments` |
| Reports | `/members/{person_id}/reports` |

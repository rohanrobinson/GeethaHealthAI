# Family Health Starter

This is a starter monorepo for a React + Node + Postgres app, ready for FHIR/Medplum integration.

## Prereqs
- Node.js 18+
- Docker (for Postgres)

## Quick start
1) Start Postgres
```
docker compose up -d
```

2) Backend
```
cd backend
npm install
npm run prisma:generate
npm run dev
```

3) Frontend
```
cd frontend
npm install
npm run dev
```

Backend runs on `http://localhost:4000` and frontend on `http://localhost:5173`.

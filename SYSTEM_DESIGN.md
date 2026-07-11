# Geetha Health — System Design Outline

**One-page reference for product scope, architecture, and multi-device strategy.**

---

## 1. Goals & scope

- **Product:** Family healthcare tracking — one place to manage medications, conditions, appointments, and documents for everyone in the household.
- **In scope (current/MVP):** Create family & roster, member profiles with Basics / Conditions / Medications / Appointments, upload document (metadata + family-member link). Data today: client-side (e.g. localStorage).
- **Out of scope for now:** Real-time sync, multi-device auth, native mobile app, clinical/EMR integration.

---

## 2. Users & main flows

- **Primary user:** Family admin or caregiver managing a single household.
- **Key flows:** (1) Create family → add members → confirm roster → Family Profile. (2) Open member → view/edit Basics, Conditions, Medications, Appointments. (3) Upload document (name + member) from Documents. (4) Access via My Account (Family Profile, Documents, About).

---

## 3. High-level architecture

- **Current:** Single-page web app (React + Vite). Data in browser (localStorage); no backend yet.
- **Target (when adding backend):** Browser/PWA (and later optional native app) → **API (REST or GraphQL)** → **Backend service** → **DB** (+ object storage for documents). One API serves all clients so the same logic and data power web and future mobile.

---

## 4. Data model (conceptual)

- **Family:** id, familyName, memberIds.
- **Member:** id, firstName, age, role; arrays of Conditions, Medications, Appointments (each with id + relevant fields).
- **Document (future):** id, name, memberId (or familyId), file reference, uploadedAt. Documents page and upload modal already align to this (name + family member).

---

## 5. Multi-device strategy

- **Primary experience:** Responsive web app — one codebase, works on desktop and phone (breakpoints, touch-friendly). Same app is installable as a **PWA** (manifest + service worker) for “app-like” use on phones.
- **Native mobile app:** Defer until needed (e.g. push reminders, deep offline, app-store presence). When added, it consumes the **same API** as the web app; no duplicate business logic.
- **Design principle:** One backend, one API, one web UI; optional native app as another client later.

---

## 6. Key technical decisions (to document as you go)

- **Auth (future):** One account per household (or per user with household access); same identity on web and any future app.
- **Persistence (future):** Replace client-only storage with API-backed storage; define sync/offline strategy (e.g. PWA cache for key pages and assets).
- **Documents (future):** Upload to object storage; metadata (name, member) in DB; optional virus/scan step for uploads.

---

## 7. Non-goals / later

- **v1:** No real-time multi-user sync, no native iOS/Android app, no EMR integration.
- **Later:** Native app only if push, offline, or app-store needs justify it; otherwise PWA + responsive web is the “mobile” experience.

---

*Living doc — update as scope and architecture evolve. Aligns with GeethaFamilyMVP.md and current frontend (family roster, member profile tabs, documents upload modal).*

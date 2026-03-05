# Geetha Health AI – Data Model Recommendation

This doc aligns your **existing Prisma schema** with the **frontend domain** (familyStorage types + MVP) and adds **User** for login.

---

## 1. Current state

| Frontend (familyStorage) | Backend (Prisma) | Notes |
|--------------------------|------------------|--------|
| Family: `familyName`, `members` | `Family`: `name`, `members` | Name field matches. |
| FamilyMember: `firstName`, `age`, `role` | `Person`: `displayName`, `dob`, `role` | Different fields; frontend uses `age` as string. |
| Condition: `name`, `notes` | `Condition`: `code`, `status`, `onsetDate`, `fhir` | UI uses human-readable `name` + `notes`. |
| Medication: `name`, `dosage`, `frequency`, `notes` | `Medication`: `name`, `status`, `fhir` | Missing `dosage`, `frequency`, `notes`. |
| Appointment: `description`, `date`, `time`, `location`, `notes` | `Appointment`: `startTime`, `status`, `fhir` | Missing description, location, notes. |

MVP also requires **Login / Create Family** (email + password, create family), so you need a **User** model and a link from User → Family.

---

## 2. Recommended approach

- **Keep** Family → Person → Condition | Appointment | Medication.
- **Extend** Person and the health entities so the API can serve the current UI without changing frontend types.
- **Add** User and optional User → Family for auth and “create family”.

---

## 3. Suggested Prisma schema changes

### 3.1 User (new) and link to Family

- One user can be associated with one family (e.g. the family they created or joined).
- For MVP, “Login” identifies the user; “Create new family” creates a Family and sets the user’s `familyId`.

```prisma
model User {
  id        String   @id @default(uuid())
  email     String   @unique
  passwordHash String  // store hashed only
  familyId  String?  // null until they create or join a family
  family    Family?  @relation(fields: [familyId], references: [id])
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([familyId])
}
```

- On `Family`, add:

```prisma
model Family {
  id        String   @id @default(uuid())
  name      String
  members   Person[]
  users     User[]   // add this relation
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
```

---

### 3.2 Person (family member) – align with frontend

Frontend uses `firstName`, `age` (string), `role`. Two options:

- **Option A – Minimal:** Keep `displayName`, add `age` (String) and keep `role`. Use `displayName` as “first name” in UI.
- **Option B – Match UI:** Rename to `firstName`, add `age` (String), keep `role`. Deprecate or map `displayName` from `firstName` if needed later.

Recommended for fastest alignment: add `age` as String; keep `displayName` and use it as “first name” in the API response (or add `firstName` and keep `displayName` for display).

Example (Option B – match frontend exactly):

```prisma
model Person {
  id          String        @id @default(uuid())
  familyId    String
  family      Family        @relation(fields: [familyId], references: [id])
  firstName   String        // was displayName
  age         String?       // free text for now, e.g. "34"
  role        String?       // e.g. "Father"
  dob         DateTime?    // optional for future FHIR
  fhir        Json?
  conditions  Condition[]
  appointments Appointment[]
  medications Medication[]
  createdAt   DateTime      @default(now())
  updatedAt   DateTime      @updatedAt

  @@index([familyId])
}
```

---

### 3.3 Condition – add name + notes

Keep `code`/`status`/`onsetDate` for future FHIR; add fields the UI uses:

```prisma
model Condition {
  id        String   @id @default(uuid())
  personId  String
  person    Person   @relation(fields: [personId], references: [id])
  name      String   // e.g. "Hypertension" – used by UI
  notes     String?
  code      String?  // optional, for FHIR later
  status    String?
  onsetDate DateTime?
  fhir      Json?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([personId])
}
```

---

### 3.4 Medication – add dosage, frequency, notes

```prisma
model Medication {
  id        String   @id @default(uuid())
  personId  String
  person    Person   @relation(fields: [personId], references: [id])
  name      String
  dosage    String?
  frequency String?
  notes     String?
  status    String?
  fhir      Json?
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt

  @@index([personId])
}
```

---

### 3.5 Appointment – add description, date, time, location, notes

Use `date` + `time` for UI; keep `startTime` for FHIR if you want (or derive from date+time).

```prisma
model Appointment {
  id          String   @id @default(uuid())
  personId    String
  person      Person   @relation(fields: [personId], references: [id])
  description String   // e.g. "Annual checkup"
  date        String   // ISO date or "YYYY-MM-DD"
  time        String?  // optional
  location    String?
  notes       String?
  startTime   DateTime? // optional, for FHIR
  status      String?
  fhir        Json?
  createdAt   DateTime @default(now())
  updatedAt   DateTime @updatedAt

  @@index([personId])
}
```

---

## 4. Mapping: API ↔ Frontend types

| Frontend (familyStorage) | Backend (Prisma) |
|--------------------------|------------------|
| `familyName` | `Family.name` |
| `FamilyMember.id` | `Person.id` |
| `FamilyMember.firstName` | `Person.firstName` (or `displayName`) |
| `FamilyMember.age` | `Person.age` |
| `FamilyMember.role` | `Person.role` |
| `Condition.name` / `.notes` | `Condition.name` / `.notes` |
| `Medication.name` / `.dosage` / `.frequency` / `.notes` | Same on `Medication` |
| `Appointment.description` / `.date` / `.time` / `.location` / `.notes` | Same on `Appointment` |

Your API can return JSON that matches the existing frontend types so you can switch from `familyStorage` (localStorage) to API without changing the UI types.

---

## 5. Implementation order

1. **Add User model** and `User.familyId` + `Family.users` relation; implement auth (register/login, hash passwords).
2. **Extend Person**: add `age`, optionally rename `displayName` → `firstName`.
3. **Extend Condition**: add `name`, `notes`.
4. **Extend Medication**: add `dosage`, `frequency`, `notes`.
5. **Extend Appointment**: add `description`, `date`, `time`, `location`, `notes`.
6. **API routes**: CRUD for Family, Person, Condition, Medication, Appointment, scoped by `familyId` (from logged-in user).
7. **Frontend**: Replace `familyStorage` with API client that returns the same shapes (or keep types and map in the client once).

---

## 6. Optional: multi-family later

If later a user can belong to multiple families, replace `User.familyId` with a join table:

```prisma
model User {
  id             String         @id @default(uuid())
  email          String         @unique
  passwordHash   String
  familyMemberships FamilyMemberRole[]
  // ...
}

model FamilyMemberRole {
  userId   String
  familyId String
  role     String?  // e.g. "owner", "member"
  user     User     @relation(...)
  family   Family   @relation(...)
  @@id([userId, familyId])
}
```

For MVP, a single `User.familyId` is enough.

---

Summary: keep your existing Family/Person/Condition/Appointment/Medication structure, add User and the fields above so the backend matches the frontend and the MVP login/create-family flow. Then add migrations and API routes in the order above.

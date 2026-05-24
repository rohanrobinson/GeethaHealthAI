from __future__ import annotations
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, EmailStr


# ── Condition ────────────────────────────────────────────────────────────────

class ConditionBase(BaseModel):
    name: str
    notes: Optional[str] = None
    code: Optional[str] = None
    status: Optional[str] = None

class ConditionCreate(ConditionBase):
    pass

class ConditionUpdate(BaseModel):
    name: Optional[str] = None
    notes: Optional[str] = None
    code: Optional[str] = None
    status: Optional[str] = None

class Condition(ConditionBase):
    id: str
    person_id: str
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ── Medication ────────────────────────────────────────────────────────────────

class MedicationBase(BaseModel):
    name: str
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None

class MedicationCreate(MedicationBase):
    pass

class MedicationUpdate(BaseModel):
    name: Optional[str] = None
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None

class Medication(MedicationBase):
    id: str
    person_id: str
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ── Appointment ───────────────────────────────────────────────────────────────

class AppointmentBase(BaseModel):
    description: str
    date: str
    time: Optional[str] = None
    location: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None

class AppointmentCreate(AppointmentBase):
    pass

class AppointmentUpdate(BaseModel):
    description: Optional[str] = None
    date: Optional[str] = None
    time: Optional[str] = None
    location: Optional[str] = None
    notes: Optional[str] = None
    status: Optional[str] = None

class Appointment(AppointmentBase):
    id: str
    person_id: str
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ── Report ────────────────────────────────────────────────────────────────────

class ReportBase(BaseModel):
    title: str
    file_path: str
    link_type: str
    linked_id: str
    notes: Optional[str] = None

class ReportCreate(ReportBase):
    pass

class Report(ReportBase):
    id: str
    person_id: str
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ── Person ────────────────────────────────────────────────────────────────────

class PersonBase(BaseModel):
    first_name: str
    age: Optional[str] = None
    role: Optional[str] = None

class PersonCreate(PersonBase):
    pass

class PersonUpdate(BaseModel):
    first_name: Optional[str] = None
    age: Optional[str] = None
    role: Optional[str] = None

class Person(PersonBase):
    id: str
    family_id: str
    conditions: list[Condition] = []
    medications: list[Medication] = []
    appointments: list[Appointment] = []
    reports: list[Report] = []
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ── Family ────────────────────────────────────────────────────────────────────

class FamilyBase(BaseModel):
    name: str

class FamilyCreate(FamilyBase):
    pass

class FamilyUpdate(BaseModel):
    name: Optional[str] = None

class Family(FamilyBase):
    id: str
    members: list[Person] = []
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}


# ── Auth ──────────────────────────────────────────────────────────────────────

class UserRegister(BaseModel):
    email: EmailStr
    password: str
    family_name: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserOut(BaseModel):
    id: str
    email: str
    family_id: Optional[str] = None
    model_config = {"from_attributes": True}

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut

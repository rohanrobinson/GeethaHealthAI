import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, DateTime, ForeignKey, JSON, Text
from sqlalchemy.orm import relationship
from database import Base


def now_utc():
    return datetime.now(timezone.utc)


def new_uuid():
    return str(uuid.uuid4())


class Family(Base):
    __tablename__ = "families"

    id = Column(String, primary_key=True, default=new_uuid)
    name = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    members = relationship("Person", back_populates="family", cascade="all, delete-orphan")
    users = relationship("User", back_populates="family")


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=new_uuid)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    family_id = Column(String, ForeignKey("families.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    family = relationship("Family", back_populates="users")


class Person(Base):
    __tablename__ = "persons"

    id = Column(String, primary_key=True, default=new_uuid)
    family_id = Column(String, ForeignKey("families.id"), nullable=False)
    first_name = Column(String, nullable=False)
    age = Column(String, nullable=True)
    role = Column(String, nullable=True)
    dob = Column(DateTime(timezone=True), nullable=True)
    fhir = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    family = relationship("Family", back_populates="members")
    conditions = relationship("Condition", back_populates="person", cascade="all, delete-orphan")
    medications = relationship("Medication", back_populates="person", cascade="all, delete-orphan")
    appointments = relationship("Appointment", back_populates="person", cascade="all, delete-orphan")
    reports = relationship("Report", back_populates="person", cascade="all, delete-orphan")


class Condition(Base):
    __tablename__ = "conditions"

    id = Column(String, primary_key=True, default=new_uuid)
    person_id = Column(String, ForeignKey("persons.id"), nullable=False)
    name = Column(String, nullable=False)
    notes = Column(Text, nullable=True)
    code = Column(String, nullable=True)
    status = Column(String, nullable=True)
    onset_date = Column(DateTime(timezone=True), nullable=True)
    fhir = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    person = relationship("Person", back_populates="conditions")


class Medication(Base):
    __tablename__ = "medications"

    id = Column(String, primary_key=True, default=new_uuid)
    person_id = Column(String, ForeignKey("persons.id"), nullable=False)
    name = Column(String, nullable=False)
    dosage = Column(String, nullable=True)
    frequency = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    status = Column(String, nullable=True)
    fhir = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    person = relationship("Person", back_populates="medications")


class Appointment(Base):
    __tablename__ = "appointments"

    id = Column(String, primary_key=True, default=new_uuid)
    person_id = Column(String, ForeignKey("persons.id"), nullable=False)
    description = Column(String, nullable=False)
    date = Column(String, nullable=False)
    time = Column(String, nullable=True)
    location = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    status = Column(String, nullable=True)
    fhir = Column(JSON, nullable=True)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    person = relationship("Person", back_populates="appointments")


class Report(Base):
    __tablename__ = "reports"

    id = Column(String, primary_key=True, default=new_uuid)
    person_id = Column(String, ForeignKey("persons.id"), nullable=False)
    title = Column(String, nullable=False)
    file_path = Column(String, nullable=False)
    link_type = Column(String, nullable=False)  # 'condition' | 'appointment'
    linked_id = Column(String, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), default=now_utc)
    updated_at = Column(DateTime(timezone=True), default=now_utc, onupdate=now_utc)

    person = relationship("Person", back_populates="reports")

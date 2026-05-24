"""
Conditions, medications, appointments, and reports are all scoped to a person.
Routes follow the pattern:
  /members/{person_id}/conditions
  /members/{person_id}/medications
  /members/{person_id}/appointments
  /members/{person_id}/reports
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import models, schemas
from database import get_db

router = APIRouter(prefix="/members/{person_id}", tags=["health data"])


def _get_person_or_404(person_id: str, db: Session) -> models.Person:
    person = db.query(models.Person).filter(models.Person.id == person_id).first()
    if not person:
        raise HTTPException(status_code=404, detail="Member not found")
    return person


# ── Conditions ────────────────────────────────────────────────────────────────

@router.get("/conditions", response_model=list[schemas.Condition])
def list_conditions(person_id: str, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    return db.query(models.Condition).filter(models.Condition.person_id == person_id).all()


@router.post("/conditions", response_model=schemas.Condition, status_code=status.HTTP_201_CREATED)
def create_condition(person_id: str, body: schemas.ConditionCreate, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    condition = models.Condition(person_id=person_id, **body.model_dump())
    db.add(condition)
    db.commit()
    db.refresh(condition)
    return condition


@router.patch("/conditions/{condition_id}", response_model=schemas.Condition)
def update_condition(person_id: str, condition_id: str, body: schemas.ConditionUpdate, db: Session = Depends(get_db)):
    condition = db.query(models.Condition).filter(
        models.Condition.id == condition_id,
        models.Condition.person_id == person_id
    ).first()
    if not condition:
        raise HTTPException(status_code=404, detail="Condition not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(condition, field, value)
    db.commit()
    db.refresh(condition)
    return condition


@router.delete("/conditions/{condition_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_condition(person_id: str, condition_id: str, db: Session = Depends(get_db)):
    condition = db.query(models.Condition).filter(
        models.Condition.id == condition_id,
        models.Condition.person_id == person_id
    ).first()
    if not condition:
        raise HTTPException(status_code=404, detail="Condition not found")
    db.delete(condition)
    db.commit()


# ── Medications ───────────────────────────────────────────────────────────────

@router.get("/medications", response_model=list[schemas.Medication])
def list_medications(person_id: str, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    return db.query(models.Medication).filter(models.Medication.person_id == person_id).all()


@router.post("/medications", response_model=schemas.Medication, status_code=status.HTTP_201_CREATED)
def create_medication(person_id: str, body: schemas.MedicationCreate, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    medication = models.Medication(person_id=person_id, **body.model_dump())
    db.add(medication)
    db.commit()
    db.refresh(medication)
    return medication


@router.patch("/medications/{medication_id}", response_model=schemas.Medication)
def update_medication(person_id: str, medication_id: str, body: schemas.MedicationUpdate, db: Session = Depends(get_db)):
    medication = db.query(models.Medication).filter(
        models.Medication.id == medication_id,
        models.Medication.person_id == person_id
    ).first()
    if not medication:
        raise HTTPException(status_code=404, detail="Medication not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(medication, field, value)
    db.commit()
    db.refresh(medication)
    return medication


@router.delete("/medications/{medication_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_medication(person_id: str, medication_id: str, db: Session = Depends(get_db)):
    medication = db.query(models.Medication).filter(
        models.Medication.id == medication_id,
        models.Medication.person_id == person_id
    ).first()
    if not medication:
        raise HTTPException(status_code=404, detail="Medication not found")
    db.delete(medication)
    db.commit()


# ── Appointments ──────────────────────────────────────────────────────────────

@router.get("/appointments", response_model=list[schemas.Appointment])
def list_appointments(person_id: str, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    return db.query(models.Appointment).filter(models.Appointment.person_id == person_id).all()


@router.post("/appointments", response_model=schemas.Appointment, status_code=status.HTTP_201_CREATED)
def create_appointment(person_id: str, body: schemas.AppointmentCreate, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    appointment = models.Appointment(person_id=person_id, **body.model_dump())
    db.add(appointment)
    db.commit()
    db.refresh(appointment)
    return appointment


@router.patch("/appointments/{appointment_id}", response_model=schemas.Appointment)
def update_appointment(person_id: str, appointment_id: str, body: schemas.AppointmentUpdate, db: Session = Depends(get_db)):
    appointment = db.query(models.Appointment).filter(
        models.Appointment.id == appointment_id,
        models.Appointment.person_id == person_id
    ).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(appointment, field, value)
    db.commit()
    db.refresh(appointment)
    return appointment


@router.delete("/appointments/{appointment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_appointment(person_id: str, appointment_id: str, db: Session = Depends(get_db)):
    appointment = db.query(models.Appointment).filter(
        models.Appointment.id == appointment_id,
        models.Appointment.person_id == person_id
    ).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
    db.delete(appointment)
    db.commit()


# ── Reports ───────────────────────────────────────────────────────────────────

@router.get("/reports", response_model=list[schemas.Report])
def list_reports(person_id: str, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    return db.query(models.Report).filter(models.Report.person_id == person_id).all()


@router.post("/reports", response_model=schemas.Report, status_code=status.HTTP_201_CREATED)
def create_report(person_id: str, body: schemas.ReportCreate, db: Session = Depends(get_db)):
    _get_person_or_404(person_id, db)
    report = models.Report(person_id=person_id, **body.model_dump())
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.delete("/reports/{report_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_report(person_id: str, report_id: str, db: Session = Depends(get_db)):
    report = db.query(models.Report).filter(
        models.Report.id == report_id,
        models.Report.person_id == person_id
    ).first()
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    db.delete(report)
    db.commit()

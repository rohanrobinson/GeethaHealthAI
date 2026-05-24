from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import models, schemas
from database import get_db

router = APIRouter(prefix="/families/{family_id}/members", tags=["members"])


def _get_family_or_404(family_id: str, db: Session) -> models.Family:
    family = db.query(models.Family).filter(models.Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    return family


def _get_person_or_404(person_id: str, family_id: str, db: Session) -> models.Person:
    person = (
        db.query(models.Person)
        .filter(models.Person.id == person_id, models.Person.family_id == family_id)
        .first()
    )
    if not person:
        raise HTTPException(status_code=404, detail="Member not found")
    return person


@router.get("/", response_model=list[schemas.Person])
def list_members(family_id: str, db: Session = Depends(get_db)):
    _get_family_or_404(family_id, db)
    return db.query(models.Person).filter(models.Person.family_id == family_id).all()


@router.post("/", response_model=schemas.Person, status_code=status.HTTP_201_CREATED)
def create_member(family_id: str, body: schemas.PersonCreate, db: Session = Depends(get_db)):
    _get_family_or_404(family_id, db)
    person = models.Person(family_id=family_id, **body.model_dump())
    db.add(person)
    db.commit()
    db.refresh(person)
    return person


@router.get("/{person_id}", response_model=schemas.Person)
def get_member(family_id: str, person_id: str, db: Session = Depends(get_db)):
    return _get_person_or_404(person_id, family_id, db)


@router.patch("/{person_id}", response_model=schemas.Person)
def update_member(family_id: str, person_id: str, body: schemas.PersonUpdate, db: Session = Depends(get_db)):
    person = _get_person_or_404(person_id, family_id, db)
    for field, value in body.model_dump(exclude_none=True).items():
        setattr(person, field, value)
    db.commit()
    db.refresh(person)
    return person


@router.delete("/{person_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_member(family_id: str, person_id: str, db: Session = Depends(get_db)):
    person = _get_person_or_404(person_id, family_id, db)
    db.delete(person)
    db.commit()

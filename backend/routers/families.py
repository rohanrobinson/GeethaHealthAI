from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
import models, schemas
from database import get_db

router = APIRouter(prefix="/families", tags=["families"])


@router.get("/", response_model=list[schemas.Family])
def list_families(db: Session = Depends(get_db)):
    return db.query(models.Family).all()


@router.post("/", response_model=schemas.Family, status_code=status.HTTP_201_CREATED)
def create_family(body: schemas.FamilyCreate, db: Session = Depends(get_db)):
    family = models.Family(name=body.name)
    db.add(family)
    db.commit()
    db.refresh(family)
    return family


@router.get("/{family_id}", response_model=schemas.Family)
def get_family(family_id: str, db: Session = Depends(get_db)):
    family = db.query(models.Family).filter(models.Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    return family


@router.patch("/{family_id}", response_model=schemas.Family)
def update_family(family_id: str, body: schemas.FamilyUpdate, db: Session = Depends(get_db)):
    family = db.query(models.Family).filter(models.Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    if body.name is not None:
        family.name = body.name
    db.commit()
    db.refresh(family)
    return family


@router.delete("/{family_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_family(family_id: str, db: Session = Depends(get_db)):
    family = db.query(models.Family).filter(models.Family.id == family_id).first()
    if not family:
        raise HTTPException(status_code=404, detail="Family not found")
    db.delete(family)
    db.commit()

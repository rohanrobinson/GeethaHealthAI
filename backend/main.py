from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routers import families, persons, health_data, auth

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Geetha Health AI",
    description="Family health management API",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(families.router)
app.include_router(persons.router)
app.include_router(health_data.router)


@app.get("/health", tags=["system"])
def health_check():
    return {"ok": True}

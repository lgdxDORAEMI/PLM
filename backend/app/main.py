from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.account import router as account_router
from app.api.v1.care import router as care_router
from app.api.v1.family import router as family_router
from app.api.v1.movement import router as movement_router
from app.api.v1.profile import router as profile_router
from app.api.v1.routine import router as routine_router
from app.core.config import ALLOWED_ORIGIN_REGEX

app = FastAPI(title="PLM API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=ALLOWED_ORIGIN_REGEX,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(movement_router, prefix="/api/v1")
app.include_router(profile_router, prefix="/api/v1")
app.include_router(routine_router, prefix="/api/v1")
app.include_router(account_router, prefix="/api/v1")
app.include_router(care_router, prefix="/api/v1")
app.include_router(family_router, prefix="/api/v1")


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "PLM API", "status": "ok"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}

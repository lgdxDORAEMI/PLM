from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="PLM API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(?:localhost|127\.0\.0\.1)(?::[0-9]+)?",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "PLM API", "status": "ok"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "healthy"}

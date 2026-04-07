"""FastAPI application for sample_cicd project."""

import logging
import os
from contextlib import asynccontextmanager

from alembic import command
from alembic.config import Config
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.logging_config import JSONFormatter
from app.routers.attachments import router as attachments_router
from app.routers.tasks import router as tasks_router

# --- Structured logging setup ---
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.basicConfig(level=logging.INFO, handlers=[handler], force=True)

logger = logging.getLogger(__name__)


def _run_migrations() -> None:
    """Run Alembic migrations on startup."""
    alembic_ini = os.path.join(os.path.dirname(__file__), "alembic.ini")
    alembic_cfg = Config(alembic_ini)
    command.upgrade(alembic_cfg, "head")


@asynccontextmanager
async def lifespan(application: FastAPI):
    """Application lifespan handler for startup/shutdown events.

    Args:
        application: FastAPI application instance.
    """
    _run_migrations()
    yield


app = FastAPI(lifespan=lifespan)

# --- CORS middleware ---
cors_origins_raw = os.getenv("CORS_ALLOWED_ORIGINS", "*")
cors_origins = [origin.strip() for origin in cors_origins_raw.split(",")]

allow_all = cors_origins == ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=not allow_all,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)

# --- X-Ray initialization (graceful degradation) ---
ENABLE_XRAY = os.getenv("ENABLE_XRAY", "").lower() == "true"

if ENABLE_XRAY:
    try:
        from aws_xray_sdk.core import patch_all, xray_recorder
        from aws_xray_sdk.ext.fastapi.middleware import XRayMiddleware

        xray_recorder.configure(service="sample-cicd-api")
        XRayMiddleware(app, recorder=xray_recorder)
        patch_all()
        logger.info("X-Ray tracing enabled")
    except Exception:
        logger.warning("X-Ray initialization failed, continuing without tracing")

app.include_router(tasks_router, prefix="/tasks", tags=["tasks"])
app.include_router(
    attachments_router,
    prefix="/tasks/{task_id}/attachments",
    tags=["attachments"],
)


@app.get("/")
def root() -> dict[str, str]:
    """Return Hello World message.

    Returns:
        JSON response with greeting message.
    """
    return {"message": "Hello, World!"}


@app.get("/health")
def health() -> dict[str, str]:
    """Health check endpoint for ALB target group.

    Returns:
        JSON response with health status.
    """
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)

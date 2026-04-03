"""FastAPI application for sample_cicd project."""

from contextlib import asynccontextmanager

from alembic import command
from alembic.config import Config
from fastapi import FastAPI

from app.routers.tasks import router as tasks_router


def _run_migrations() -> None:
    """Run Alembic migrations on startup."""
    import os

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

app.include_router(tasks_router, prefix="/tasks", tags=["tasks"])


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

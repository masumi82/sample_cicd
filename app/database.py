"""Database connection and session configuration."""

import os

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker


def _build_database_url() -> str:
    """Build database URL from environment variables.

    If DATABASE_URL is set, use it directly (for testing/local dev).
    Otherwise, construct from individual DB_* variables (for production/ECS).

    Returns:
        Database connection URL string.
    """
    database_url = os.environ.get("DATABASE_URL")
    if database_url:
        return database_url

    username = os.environ["DB_USERNAME"]
    password = os.environ["DB_PASSWORD"]
    host = os.environ["DB_HOST"]
    port = os.environ["DB_PORT"]
    dbname = os.environ["DB_NAME"]
    return f"postgresql://{username}:{password}@{host}:{port}/{dbname}"


engine = create_engine(_build_database_url())
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    """SQLAlchemy declarative base class."""


def get_db() -> Session:
    """Provide a database session for FastAPI dependency injection.

    Yields:
        SQLAlchemy session instance.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

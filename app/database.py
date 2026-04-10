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


def _build_read_database_url() -> str | None:
    """Build read replica database URL from environment variables.

    Checks DATABASE_READ_URL first (local/test), then DB_READ_HOST (ECS).
    Returns None if no read replica is configured (graceful degradation).

    Returns:
        Read replica database URL string, or None.
    """
    read_url = os.environ.get("DATABASE_READ_URL")
    if read_url:
        return read_url

    read_host = os.environ.get("DB_READ_HOST")
    if read_host:
        username = os.environ["DB_USERNAME"]
        password = os.environ["DB_PASSWORD"]
        port = os.environ["DB_PORT"]
        dbname = os.environ["DB_NAME"]
        return f"postgresql://{username}:{password}@{read_host}:{port}/{dbname}"

    return None


engine = create_engine(_build_database_url())
SessionLocal = sessionmaker(bind=engine)

_read_url = _build_read_database_url()
if _read_url:
    _read_engine = create_engine(_read_url)
    SessionLocalRead = sessionmaker(bind=_read_engine)
else:
    SessionLocalRead = SessionLocal


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


def get_read_db() -> Session:
    """Provide a read-only database session for FastAPI dependency injection.

    Uses the read replica if DATABASE_READ_URL or DB_READ_HOST is configured.
    Falls back to the primary database otherwise (graceful degradation).

    Yields:
        SQLAlchemy session instance (read replica or primary).
    """
    db = SessionLocalRead()
    try:
        yield db
    finally:
        db.close()

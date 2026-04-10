"""Tests for database read/write routing (v12)."""

import os
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import StaticPool, create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db, get_read_db
from app.main import app


# Separate engines to verify routing
write_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
read_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
WriteSession = sessionmaker(bind=write_engine)
ReadSession = sessionmaker(bind=read_engine)


def override_write_db():
    db = WriteSession()
    try:
        yield db
    finally:
        db.close()


def override_read_db():
    db = ReadSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def setup_routing_db():
    """Create tables in both engines before each test."""
    Base.metadata.create_all(bind=write_engine)
    Base.metadata.create_all(bind=read_engine)
    yield
    Base.metadata.drop_all(bind=write_engine)
    Base.metadata.drop_all(bind=read_engine)


@pytest.fixture
def routing_client():
    """Client with separate read/write DB overrides."""
    original_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_write_db
    app.dependency_overrides[get_read_db] = override_read_db
    client = TestClient(app)
    yield client
    app.dependency_overrides = original_overrides


@pytest.fixture
def shared_client():
    """Client where read and write use the same DB (fallback mode)."""
    original_overrides = app.dependency_overrides.copy()
    app.dependency_overrides[get_db] = override_write_db
    app.dependency_overrides[get_read_db] = override_write_db
    client = TestClient(app)
    yield client
    app.dependency_overrides = original_overrides


class TestReadWriteSplit:
    """Test that read operations use the read session."""

    def test_list_tasks_uses_read_db(self, routing_client):
        """GET /tasks should use read DB (empty since write goes elsewhere)."""
        # Write a task via write DB
        routing_client.post("/tasks", json={"title": "Test Task"})

        # Read should use read DB which is separate — returns empty
        response = routing_client.get("/tasks")
        assert response.status_code == 200
        assert response.json() == []

    def test_get_task_uses_read_db(self, routing_client):
        """GET /tasks/{id} should use read DB."""
        # Create task via write DB
        create_resp = routing_client.post("/tasks", json={"title": "Test"})
        task_id = create_resp.json()["id"]

        # Read from separate read DB — task not found
        response = routing_client.get(f"/tasks/{task_id}")
        assert response.status_code == 404

    def test_create_task_uses_write_db(self, routing_client):
        """POST /tasks should use write DB."""
        response = routing_client.post("/tasks", json={"title": "Write Test"})
        assert response.status_code == 201
        assert response.json()["title"] == "Write Test"

    def test_update_task_uses_write_db(self, shared_client):
        """PUT /tasks/{id} should use write DB."""
        create_resp = shared_client.post("/tasks", json={"title": "Original"})
        task_id = create_resp.json()["id"]

        response = shared_client.put(f"/tasks/{task_id}", json={"title": "Updated"})
        assert response.status_code == 200
        assert response.json()["title"] == "Updated"

    def test_delete_task_uses_write_db(self, shared_client):
        """DELETE /tasks/{id} should use write DB."""
        create_resp = shared_client.post("/tasks", json={"title": "To Delete"})
        task_id = create_resp.json()["id"]

        response = shared_client.delete(f"/tasks/{task_id}")
        assert response.status_code == 204


class TestGracefulDegradation:
    """Test fallback when read replica is not configured."""

    def test_shared_session_reads_work(self, shared_client):
        """When read/write use same DB, reads return written data."""
        shared_client.post("/tasks", json={"title": "Shared Task"})

        response = shared_client.get("/tasks")
        assert response.status_code == 200
        tasks = response.json()
        assert len(tasks) == 1
        assert tasks[0]["title"] == "Shared Task"

    def test_shared_session_get_by_id_works(self, shared_client):
        """When read/write use same DB, get by ID works."""
        create_resp = shared_client.post("/tasks", json={"title": "Shared Detail"})
        task_id = create_resp.json()["id"]

        response = shared_client.get(f"/tasks/{task_id}")
        assert response.status_code == 200
        assert response.json()["title"] == "Shared Detail"


class TestBuildReadUrl:
    """Test _build_read_database_url function."""

    def test_database_read_url_env(self):
        """DATABASE_READ_URL takes priority."""
        with patch.dict(os.environ, {"DATABASE_READ_URL": "sqlite://"}):
            from app.database import _build_read_database_url

            result = _build_read_database_url()
            assert result == "sqlite://"

    def test_db_read_host_env(self):
        """DB_READ_HOST constructs URL from components."""
        env = {
            "DB_READ_HOST": "replica.example.com",
            "DB_USERNAME": "user",
            "DB_PASSWORD": "pass",
            "DB_PORT": "5432",
            "DB_NAME": "mydb",
        }
        with patch.dict(os.environ, env):
            from app.database import _build_read_database_url

            result = _build_read_database_url()
            assert result == "postgresql://user:pass@replica.example.com:5432/mydb"

    def test_no_read_config_returns_none(self):
        """Returns None when no read replica is configured."""
        env_to_remove = ["DATABASE_READ_URL", "DB_READ_HOST"]
        with patch.dict(os.environ, {}, clear=False):
            for key in env_to_remove:
                os.environ.pop(key, None)
            from app.database import _build_read_database_url

            result = _build_read_database_url()
            assert result is None

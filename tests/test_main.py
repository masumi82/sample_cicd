"""Tests for FastAPI application endpoints."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_root_returns_hello_world():
    """TC-01: GET / returns 200 with Hello World message."""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello, World!"}


def test_root_content_type():
    """TC-02: GET / returns application/json content type."""
    response = client.get("/")
    assert response.headers["content-type"] == "application/json"


def test_health_returns_healthy():
    """TC-03: GET /health returns 200 with healthy status."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_health_content_type():
    """TC-04: GET /health returns application/json content type."""
    response = client.get("/health")
    assert response.headers["content-type"] == "application/json"


def test_not_found():
    """TC-05: GET /notfound returns 404."""
    response = client.get("/notfound")
    assert response.status_code == 404


def test_root_method_not_allowed():
    """TC-06: POST / returns 405 Method Not Allowed."""
    response = client.post("/")
    assert response.status_code == 405

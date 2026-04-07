"""Tests for v6 observability features: CORS, structured logging, X-Ray graceful degradation."""

import json
import logging
import sys

from fastapi.testclient import TestClient

from app.logging_config import JSONFormatter


# --- CORS tests ---


def test_cors_preflight_returns_headers(client: TestClient):
    """OPTIONS preflight request returns CORS headers."""
    response = client.options(
        "/tasks",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert response.status_code == 200
    assert "access-control-allow-origin" in response.headers
    assert response.headers["access-control-allow-origin"] == "*"


def test_cors_get_returns_allow_origin(client: TestClient):
    """GET request includes Access-Control-Allow-Origin header."""
    response = client.get("/", headers={"Origin": "http://localhost:3000"})
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "*"


def test_cors_allows_required_methods(client: TestClient):
    """CORS allows GET, POST, PUT, DELETE, OPTIONS methods."""
    response = client.options(
        "/tasks",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "DELETE",
        },
    )
    assert response.status_code == 200
    allowed = response.headers.get("access-control-allow-methods", "")
    for method in ["GET", "POST", "PUT", "DELETE", "OPTIONS"]:
        assert method in allowed


# --- Structured logging tests ---


def test_json_formatter_outputs_valid_json():
    """JSONFormatter produces valid JSON output."""
    formatter = JSONFormatter()
    record = logging.LogRecord(
        name="test.logger",
        level=logging.INFO,
        pathname="test.py",
        lineno=1,
        msg="Test message",
        args=None,
        exc_info=None,
    )
    output = formatter.format(record)
    parsed = json.loads(output)
    assert parsed["level"] == "INFO"
    assert parsed["logger"] == "test.logger"
    assert parsed["message"] == "Test message"
    assert "timestamp" in parsed


def test_json_formatter_includes_exception():
    """JSONFormatter includes exception info when present."""
    formatter = JSONFormatter()
    record = None
    try:
        raise ValueError("test error")
    except ValueError:
        record = logging.LogRecord(
            name="test.logger",
            level=logging.ERROR,
            pathname="test.py",
            lineno=1,
            msg="Error occurred",
            args=None,
            exc_info=sys.exc_info(),
        )
    assert record is not None
    output = formatter.format(record)
    parsed = json.loads(output)
    assert "exception" in parsed
    assert "ValueError" in parsed["exception"]


def test_json_formatter_required_fields():
    """JSONFormatter output contains all required fields."""
    formatter = JSONFormatter()
    record = logging.LogRecord(
        name="app.routers.tasks",
        level=logging.WARNING,
        pathname="tasks.py",
        lineno=10,
        msg="Something happened",
        args=None,
        exc_info=None,
    )
    output = formatter.format(record)
    parsed = json.loads(output)
    required_fields = {"timestamp", "level", "logger", "message"}
    assert required_fields.issubset(parsed.keys())


# --- X-Ray graceful degradation tests ---


def test_xray_disabled_by_default(monkeypatch):
    """X-Ray is disabled when ENABLE_XRAY is not set."""
    monkeypatch.delenv("ENABLE_XRAY", raising=False)
    from app.main import ENABLE_XRAY
    assert ENABLE_XRAY is False


def test_app_works_without_xray(client: TestClient):
    """Application works normally without X-Ray enabled."""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}

"""Tests for Redis caching service and cache integration in task endpoints (TC-63 to TC-81)."""

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient


@pytest.fixture(autouse=True)
def reset_redis_singleton():
    """Reset the Redis singleton between tests to prevent test pollution."""
    import app.services.cache as cache_mod
    original = cache_mod._redis_client
    yield
    cache_mod._redis_client = original


# ============================
# Cache service unit tests
# ============================


def test_cache_get_returns_none_without_redis(monkeypatch):
    """TC-63: cache_get returns None when REDIS_URL is not set."""
    monkeypatch.delenv("REDIS_URL", raising=False)
    import app.services.cache as cache_mod
    cache_mod._redis_client = None

    from app.services.cache import cache_get
    assert cache_get("any-key") is None


def test_cache_set_does_nothing_without_redis(monkeypatch):
    """TC-64: cache_set does nothing when REDIS_URL is not set."""
    monkeypatch.delenv("REDIS_URL", raising=False)
    import app.services.cache as cache_mod
    cache_mod._redis_client = None

    from app.services.cache import cache_set
    # Should not raise
    cache_set("any-key", {"data": "value"}, ttl=300)


def test_cache_delete_does_nothing_without_redis(monkeypatch):
    """TC-65: cache_delete does nothing when REDIS_URL is not set."""
    monkeypatch.delenv("REDIS_URL", raising=False)
    import app.services.cache as cache_mod
    cache_mod._redis_client = None

    from app.services.cache import cache_delete
    # Should not raise
    cache_delete("any-key")


def test_cache_get_hit(monkeypatch):
    """TC-66: cache_get returns cached data on hit."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    mock_client.get.return_value = '{"id": 1, "title": "Test"}'
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_get
    result = cache_get("tasks:1")
    assert result == {"id": 1, "title": "Test"}
    mock_client.get.assert_called_once_with("tasks:1")


def test_cache_get_miss(monkeypatch):
    """TC-67: cache_get returns None on cache miss."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    mock_client.get.return_value = None
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_get
    result = cache_get("tasks:nonexistent")
    assert result is None


def test_cache_set_with_ttl(monkeypatch):
    """TC-68: cache_set stores data with TTL."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_set
    cache_set("tasks:list", [{"id": 1}], ttl=300)
    mock_client.setex.assert_called_once_with("tasks:list", 300, '[{"id": 1}]')


def test_cache_delete_removes_keys(monkeypatch):
    """TC-69: cache_delete removes specified keys."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_delete
    cache_delete("tasks:list", "tasks:1")
    mock_client.delete.assert_called_once_with("tasks:list", "tasks:1")


def test_cache_get_returns_none_on_error(monkeypatch):
    """TC-70: cache_get returns None when Redis raises an error."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    mock_client.get.side_effect = ConnectionError("Redis down")
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_get
    result = cache_get("tasks:1")
    assert result is None


def test_cache_set_silently_fails_on_error(monkeypatch):
    """TC-71: cache_set silently fails when Redis raises an error."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    mock_client.setex.side_effect = ConnectionError("Redis down")
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_set
    # Should not raise
    cache_set("tasks:list", [{"id": 1}], ttl=300)


def test_cache_delete_silently_fails_on_error(monkeypatch):
    """TC-72: cache_delete silently fails when Redis raises an error."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    mock_client.delete.side_effect = ConnectionError("Redis down")
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_delete
    # Should not raise
    cache_delete("tasks:list")


def test_cache_set_without_ttl(monkeypatch):
    """TC-82: cache_set stores data without TTL when ttl is None."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_set
    cache_set("tasks:list", [{"id": 1}])
    mock_client.set.assert_called_once_with("tasks:list", '[{"id": 1}]')
    mock_client.setex.assert_not_called()


def test_cache_get_returns_none_on_corrupt_json(monkeypatch):
    """TC-83: cache_get returns None when Redis returns invalid JSON."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod

    mock_client = MagicMock()
    mock_client.get.return_value = "not-valid-json{{"
    cache_mod._redis_client = mock_client

    from app.services.cache import cache_get
    result = cache_get("tasks:1")
    assert result is None


def test_get_redis_connection_failure(monkeypatch):
    """TC-84: _get_redis returns None when Redis connection fails."""
    monkeypatch.setenv("REDIS_URL", "redis://localhost:6379")
    import app.services.cache as cache_mod
    cache_mod._redis_client = None

    mock_client = MagicMock()
    mock_client.ping.side_effect = ConnectionError("Connection refused")

    with patch("redis.from_url", return_value=mock_client):
        result = cache_mod._get_redis()
        assert result is None
        assert cache_mod._redis_client is None


# ============================
# Task endpoint cache integration tests
# ============================


@patch("app.routers.tasks.cache_get")
def test_list_tasks_uses_cache(mock_cache_get, client: TestClient):
    """TC-73: GET /tasks returns cached data without hitting DB."""
    mock_cache_get.return_value = [{"id": 1, "title": "Cached", "description": None, "completed": False, "created_at": "2026-01-01T00:00:00", "updated_at": "2026-01-01T00:00:00"}]
    response = client.get("/tasks")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["title"] == "Cached"
    mock_cache_get.assert_called_once_with("tasks:list")


@patch("app.routers.tasks.cache_set")
@patch("app.routers.tasks.cache_get")
def test_list_tasks_populates_cache_on_miss(mock_cache_get, mock_cache_set, client: TestClient):
    """TC-74: GET /tasks populates cache on cache miss."""
    mock_cache_get.return_value = None
    # Create a task first
    client.post("/tasks", json={"title": "Test Task"})
    response = client.get("/tasks")
    assert response.status_code == 200
    assert len(response.json()) == 1
    mock_cache_set.assert_called()
    args = mock_cache_set.call_args
    assert args[0][0] == "tasks:list"


@patch("app.routers.tasks.cache_get")
def test_get_task_uses_cache(mock_cache_get, client: TestClient):
    """TC-75: GET /tasks/{id} returns cached data without hitting DB."""
    mock_cache_get.return_value = {"id": 1, "title": "Cached Task", "description": None, "completed": False, "created_at": "2026-01-01T00:00:00", "updated_at": "2026-01-01T00:00:00"}
    response = client.get("/tasks/1")
    assert response.status_code == 200
    assert response.json()["title"] == "Cached Task"
    mock_cache_get.assert_called_once_with("tasks:1")


@patch("app.routers.tasks.cache_set")
@patch("app.routers.tasks.cache_get")
def test_get_task_populates_cache_on_miss(mock_cache_get, mock_cache_set, client: TestClient):
    """TC-76: GET /tasks/{id} populates cache on cache miss."""
    mock_cache_get.return_value = None
    # Create a task first
    create_resp = client.post("/tasks", json={"title": "Test Task"})
    task_id = create_resp.json()["id"]
    response = client.get(f"/tasks/{task_id}")
    assert response.status_code == 200
    mock_cache_set.assert_called()
    args = mock_cache_set.call_args
    assert args[0][0] == f"tasks:{task_id}"


@patch("app.routers.tasks.cache_delete")
def test_create_task_invalidates_list_cache(mock_cache_delete, client: TestClient):
    """TC-77: POST /tasks invalidates the tasks:list cache."""
    client.post("/tasks", json={"title": "New Task"})
    mock_cache_delete.assert_called_with("tasks:list")


@patch("app.routers.tasks.cache_delete")
def test_update_task_invalidates_caches(mock_cache_delete, client: TestClient):
    """TC-78: PUT /tasks/{id} invalidates both list and individual cache."""
    create_resp = client.post("/tasks", json={"title": "Task"})
    task_id = create_resp.json()["id"]
    mock_cache_delete.reset_mock()
    client.put(f"/tasks/{task_id}", json={"title": "Updated"})
    mock_cache_delete.assert_called_with("tasks:list", f"tasks:{task_id}")


@patch("app.routers.tasks.cache_delete")
def test_delete_task_invalidates_caches(mock_cache_delete, client: TestClient):
    """TC-79: DELETE /tasks/{id} invalidates both list and individual cache."""
    create_resp = client.post("/tasks", json={"title": "Task"})
    task_id = create_resp.json()["id"]
    mock_cache_delete.reset_mock()
    client.delete(f"/tasks/{task_id}")
    mock_cache_delete.assert_called_with("tasks:list", f"tasks:{task_id}")


# ============================
# Graceful degradation tests
# ============================


@patch("app.routers.tasks.cache_set")
@patch("app.routers.tasks.cache_get", return_value=None)
def test_list_tasks_works_without_redis(mock_cache_get, mock_cache_set, client: TestClient):
    """TC-80: GET /tasks works normally when cache returns None (no Redis)."""
    client.post("/tasks", json={"title": "Test"})
    response = client.get("/tasks")
    assert response.status_code == 200
    assert len(response.json()) == 1


@patch("app.routers.tasks.cache_delete")
def test_create_task_works_without_redis(mock_cache_delete, client: TestClient):
    """TC-81: POST /tasks works normally when cache_delete is a no-op."""
    mock_cache_delete.return_value = None
    response = client.post("/tasks", json={"title": "Test"})
    assert response.status_code == 201
    assert response.json()["title"] == "Test"

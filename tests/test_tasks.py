"""Tests for Task CRUD endpoints (TC-07 to TC-18) and event publishing (TC-19 to TC-23)."""

import json
import os
from unittest.mock import MagicMock, patch

import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_aws


def test_list_tasks_empty(client: TestClient):
    """TC-07: GET /tasks returns empty list when no tasks exist."""
    response = client.get("/tasks")
    assert response.status_code == 200
    assert response.json() == []


def test_create_task_with_description(client: TestClient):
    """TC-08: POST /tasks creates a task with title and description."""
    response = client.post(
        "/tasks", json={"title": "Buy groceries", "description": "Milk, eggs, bread"}
    )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Buy groceries"
    assert data["description"] == "Milk, eggs, bread"
    assert data["completed"] is False
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


def test_create_task_without_description(client: TestClient):
    """TC-09: POST /tasks creates a task with title only (description defaults to null)."""
    response = client.post("/tasks", json={"title": "Simple task"})
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Simple task"
    assert data["description"] is None


def test_create_task_validation_error(client: TestClient):
    """TC-10: POST /tasks returns 422 when title is empty."""
    response = client.post("/tasks", json={"title": ""})
    assert response.status_code == 422


def test_list_tasks_after_create(client: TestClient):
    """TC-11: GET /tasks returns tasks after creation."""
    client.post("/tasks", json={"title": "Task 1"})
    response = client.get("/tasks")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 1
    assert data[0]["title"] == "Task 1"


def test_get_task_exists(client: TestClient):
    """TC-12: GET /tasks/{id} returns existing task."""
    create_response = client.post("/tasks", json={"title": "My task"})
    task_id = create_response.json()["id"]

    response = client.get(f"/tasks/{task_id}")
    assert response.status_code == 200
    assert response.json()["title"] == "My task"


def test_get_task_not_found(client: TestClient):
    """TC-13: GET /tasks/{id} returns 404 for non-existent task."""
    response = client.get("/tasks/999")
    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}


def test_update_task_title(client: TestClient):
    """TC-14: PUT /tasks/{id} updates task title."""
    create_response = client.post("/tasks", json={"title": "Old title"})
    task_id = create_response.json()["id"]

    response = client.put(f"/tasks/{task_id}", json={"title": "New title"})
    assert response.status_code == 200
    assert response.json()["title"] == "New title"


def test_update_task_completed(client: TestClient):
    """TC-15: PUT /tasks/{id} marks task as completed."""
    create_response = client.post("/tasks", json={"title": "Task to complete"})
    task_id = create_response.json()["id"]

    response = client.put(f"/tasks/{task_id}", json={"completed": True})
    assert response.status_code == 200
    assert response.json()["completed"] is True


def test_update_task_not_found(client: TestClient):
    """TC-16: PUT /tasks/{id} returns 404 for non-existent task."""
    response = client.put("/tasks/999", json={"title": "Update"})
    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}


def test_delete_task(client: TestClient):
    """TC-17: DELETE /tasks/{id} deletes task and returns 204."""
    create_response = client.post("/tasks", json={"title": "Task to delete"})
    task_id = create_response.json()["id"]

    response = client.delete(f"/tasks/{task_id}")
    assert response.status_code == 204

    # Verify task is deleted
    get_response = client.get(f"/tasks/{task_id}")
    assert get_response.status_code == 404


def test_delete_task_not_found(client: TestClient):
    """TC-18: DELETE /tasks/{id} returns 404 for non-existent task."""
    response = client.delete("/tasks/999")
    assert response.status_code == 404
    assert response.json() == {"detail": "Task not found"}


# ---------------------------------------------------------------------------
# v4: SQS / EventBridge event publishing tests (TC-19 to TC-23)
# ---------------------------------------------------------------------------


@pytest.fixture
def aws_credentials(monkeypatch):
    """Fake AWS credentials required by moto."""
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "ap-northeast-1")
    monkeypatch.setenv("AWS_REGION", "ap-northeast-1")


@mock_aws
def test_create_task_publishes_sqs_event(client: TestClient, aws_credentials, monkeypatch):
    """TC-19: POST /tasks publishes task_created message to SQS queue."""
    sqs = boto3.client("sqs", region_name="ap-northeast-1")
    queue_url = sqs.create_queue(QueueName="test-task-events")["QueueUrl"]
    monkeypatch.setenv("SQS_QUEUE_URL", queue_url)

    response = client.post("/tasks", json={"title": "SQS test task"})

    assert response.status_code == 201
    msgs = sqs.receive_message(QueueUrl=queue_url, MaxNumberOfMessages=1)
    assert "Messages" in msgs
    body = json.loads(msgs["Messages"][0]["Body"])
    assert body["event"] == "task_created"
    assert body["title"] == "SQS test task"
    assert body["task_id"] == response.json()["id"]


def test_complete_task_publishes_eventbridge_event(client: TestClient, monkeypatch):
    """TC-20: PUT /tasks/{id} completed=true publishes TaskCompleted to EventBridge."""
    monkeypatch.setenv("EVENTBRIDGE_BUS_NAME", "test-sample-cicd-bus")

    create_resp = client.post("/tasks", json={"title": "EventBridge test"})
    assert create_resp.status_code == 201
    task_id = create_resp.json()["id"]

    mock_eb = MagicMock()
    mock_eb.put_events.return_value = {
        "FailedEntryCount": 0,
        "Entries": [{"EventId": "test-event-id"}],
    }

    with patch("app.services.events._events_client", new=lambda: mock_eb):
        resp = client.put(f"/tasks/{task_id}", json={"completed": True})

    assert resp.status_code == 200
    assert resp.json()["completed"] is True
    mock_eb.put_events.assert_called_once()
    entries = mock_eb.put_events.call_args.kwargs["Entries"]
    assert entries[0]["DetailType"] == "TaskCompleted"
    assert entries[0]["EventBusName"] == "test-sample-cicd-bus"
    detail = json.loads(entries[0]["Detail"])
    assert detail["task_id"] == task_id
    assert detail["title"] == "EventBridge test"


def test_complete_task_twice_no_duplicate_event(client: TestClient, monkeypatch):
    """TC-21: PUT /tasks/{id} completed=true twice - EventBridge published only once."""
    monkeypatch.setenv("EVENTBRIDGE_BUS_NAME", "test-sample-cicd-bus")

    create_resp = client.post("/tasks", json={"title": "Double complete"})
    assert create_resp.status_code == 201
    task_id = create_resp.json()["id"]

    mock_eb = MagicMock()
    mock_eb.put_events.return_value = {
        "FailedEntryCount": 0,
        "Entries": [{"EventId": "test-event-id"}],
    }

    with patch("app.services.events._events_client", new=lambda: mock_eb):
        # First completion: false → true → event published
        resp1 = client.put(f"/tasks/{task_id}", json={"completed": True})
        assert resp1.json()["completed"] is True

        # Second completion: true → true → no duplicate event
        resp2 = client.put(f"/tasks/{task_id}", json={"completed": True})
        assert resp2.json()["completed"] is True

    assert mock_eb.put_events.call_count == 1


def test_create_task_without_sqs_url_succeeds(client: TestClient):
    """TC-22: POST /tasks succeeds when SQS_QUEUE_URL is not set (event silently skipped)."""
    assert os.environ.get("SQS_QUEUE_URL") is None
    response = client.post("/tasks", json={"title": "No SQS configured"})
    assert response.status_code == 201


def test_complete_task_without_eventbridge_bus_succeeds(client: TestClient):
    """TC-23: PUT /tasks/{id} succeeds when EVENTBRIDGE_BUS_NAME is not set (event silently skipped)."""
    assert os.environ.get("EVENTBRIDGE_BUS_NAME") is None
    create_resp = client.post("/tasks", json={"title": "No EventBridge"})
    task_id = create_resp.json()["id"]
    response = client.put(f"/tasks/{task_id}", json={"completed": True})
    assert response.status_code == 200

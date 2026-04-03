"""Tests for Task CRUD endpoints (TC-07 to TC-18)."""

from fastapi.testclient import TestClient


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

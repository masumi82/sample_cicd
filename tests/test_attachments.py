"""Tests for attachment CRUD endpoints and filename sanitization (TC-24 to TC-39)."""

from unittest.mock import patch

import boto3
import pytest
from fastapi.testclient import TestClient
from moto import mock_aws
from pydantic import ValidationError

from app.schemas import AttachmentCreate


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _create_task(client: TestClient, title: str = "Test task") -> int:
    """Create a task and return its ID."""
    resp = client.post("/tasks", json={"title": title})
    assert resp.status_code == 201
    return resp.json()["id"]


def _setup_s3_bucket(bucket_name: str = "test-attachments"):
    """Create a mock S3 bucket via moto."""
    s3 = boto3.client("s3", region_name="ap-northeast-1")
    s3.create_bucket(
        Bucket=bucket_name,
        CreateBucketConfiguration={"LocationConstraint": "ap-northeast-1"},
    )
    return s3


def _create_attachment(
    client: TestClient,
    task_id: int,
    filename: str = "test.pdf",
    content_type: str = "application/pdf",
) -> dict:
    """Create an attachment and return the response JSON."""
    resp = client.post(
        f"/tasks/{task_id}/attachments",
        json={"filename": filename, "content_type": content_type},
    )
    assert resp.status_code == 201
    return resp.json()


# ---------------------------------------------------------------------------
# TC-24: Create attachment — presigned URL generation
# ---------------------------------------------------------------------------


@mock_aws
def test_create_attachment(client: TestClient, aws_credentials, monkeypatch):
    """TC-24: POST /tasks/{id}/attachments returns presigned URL and creates DB record."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")

    task_id = _create_task(client)
    data = _create_attachment(client, task_id)

    assert data["id"] > 0
    assert data["filename"] == "test.pdf"
    assert data["upload_url"].startswith("https://")

    # Verify DB record via list endpoint
    list_resp = client.get(f"/tasks/{task_id}/attachments")
    assert len(list_resp.json()) == 1


# ---------------------------------------------------------------------------
# TC-25: Create attachment — invalid task
# ---------------------------------------------------------------------------


def test_create_attachment_invalid_task(client: TestClient, monkeypatch):
    """TC-25: POST /tasks/9999/attachments returns 404 for non-existent task."""
    monkeypatch.setenv("S3_BUCKET_NAME", "test-bucket")
    resp = client.post(
        "/tasks/9999/attachments",
        json={"filename": "test.pdf", "content_type": "application/pdf"},
    )
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Task not found"


# ---------------------------------------------------------------------------
# TC-26: Create attachment — invalid content type
# ---------------------------------------------------------------------------


def test_create_attachment_invalid_content_type(client: TestClient, monkeypatch):
    """TC-26: POST with disallowed content_type returns 422."""
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")

    task_id = _create_task(client)
    resp = client.post(
        f"/tasks/{task_id}/attachments",
        json={"filename": "virus.exe", "content_type": "application/x-msdownload"},
    )
    assert resp.status_code == 422
    assert "not allowed" in resp.json()["detail"]


# ---------------------------------------------------------------------------
# TC-27: Create attachment — S3 not configured
# ---------------------------------------------------------------------------


def test_create_attachment_no_s3_config(client: TestClient, monkeypatch):
    """TC-27: POST returns 503 when S3_BUCKET_NAME is not set."""
    monkeypatch.delenv("S3_BUCKET_NAME", raising=False)
    task_id = _create_task(client)
    resp = client.post(
        f"/tasks/{task_id}/attachments",
        json={"filename": "test.pdf", "content_type": "application/pdf"},
    )
    assert resp.status_code == 503
    assert resp.json()["detail"] == "Storage service not configured"


# ---------------------------------------------------------------------------
# TC-28: List attachments — empty
# ---------------------------------------------------------------------------


def test_list_attachments_empty(client: TestClient):
    """TC-28: GET /tasks/{id}/attachments returns empty list for task with no attachments."""
    task_id = _create_task(client)
    resp = client.get(f"/tasks/{task_id}/attachments")
    assert resp.status_code == 200
    assert resp.json() == []


# ---------------------------------------------------------------------------
# TC-29: List attachments — multiple
# ---------------------------------------------------------------------------


@mock_aws
def test_list_attachments(client: TestClient, aws_credentials, monkeypatch):
    """TC-29: GET /tasks/{id}/attachments returns all attachments for the task."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")

    task_id = _create_task(client)
    _create_attachment(client, task_id, "file1.pdf")
    _create_attachment(client, task_id, "file2.png", "image/png")

    resp = client.get(f"/tasks/{task_id}/attachments")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2
    filenames = {a["filename"] for a in data}
    assert filenames == {"file1.pdf", "file2.png"}


# ---------------------------------------------------------------------------
# TC-30: List attachments — invalid task
# ---------------------------------------------------------------------------


def test_list_attachments_invalid_task(client: TestClient):
    """TC-30: GET /tasks/9999/attachments returns 404 for non-existent task."""
    resp = client.get("/tasks/9999/attachments")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TC-31: Get attachment — with CloudFront download URL
# ---------------------------------------------------------------------------


@mock_aws
def test_get_attachment_with_download_url(
    client: TestClient, aws_credentials, monkeypatch
):
    """TC-31: GET attachment with CLOUDFRONT_DOMAIN_NAME returns download_url."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")
    monkeypatch.setenv("CLOUDFRONT_DOMAIN_NAME", "d123.cloudfront.net")

    task_id = _create_task(client)
    created = _create_attachment(client, task_id)

    resp = client.get(f"/tasks/{task_id}/attachments/{created['id']}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["download_url"].startswith("https://d123.cloudfront.net/")
    assert "tasks/" in data["download_url"]


# ---------------------------------------------------------------------------
# TC-32: Get attachment — no CloudFront domain
# ---------------------------------------------------------------------------


@mock_aws
def test_get_attachment_no_cloudfront(
    client: TestClient, aws_credentials, monkeypatch
):
    """TC-32: GET attachment without CLOUDFRONT_DOMAIN_NAME returns empty download_url."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")
    monkeypatch.delenv("CLOUDFRONT_DOMAIN_NAME", raising=False)

    task_id = _create_task(client)
    created = _create_attachment(client, task_id)

    resp = client.get(f"/tasks/{task_id}/attachments/{created['id']}")
    assert resp.status_code == 200
    assert resp.json()["download_url"] == ""


# ---------------------------------------------------------------------------
# TC-33: Get attachment — not found
# ---------------------------------------------------------------------------


def test_get_attachment_not_found(client: TestClient):
    """TC-33: GET /tasks/{id}/attachments/9999 returns 404."""
    task_id = _create_task(client)
    resp = client.get(f"/tasks/{task_id}/attachments/9999")
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Attachment not found"


# ---------------------------------------------------------------------------
# TC-34: Get attachment — belongs to different task
# ---------------------------------------------------------------------------


@mock_aws
def test_get_attachment_wrong_task(client: TestClient, aws_credentials, monkeypatch):
    """TC-34: GET attachment from wrong task returns 404."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")

    task_a = _create_task(client, "Task A")
    task_b = _create_task(client, "Task B")
    attachment = _create_attachment(client, task_b)

    # Try to access task_b's attachment via task_a
    resp = client.get(f"/tasks/{task_a}/attachments/{attachment['id']}")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TC-35: Delete attachment — success
# ---------------------------------------------------------------------------


@mock_aws
def test_delete_attachment(client: TestClient, aws_credentials, monkeypatch):
    """TC-35: DELETE removes attachment from DB and calls S3 delete."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")

    task_id = _create_task(client)
    created = _create_attachment(client, task_id)

    with patch("app.routers.attachments.delete_object") as mock_delete:
        resp = client.delete(f"/tasks/{task_id}/attachments/{created['id']}")

    assert resp.status_code == 204
    mock_delete.assert_called_once()

    # Verify DB record is gone
    list_resp = client.get(f"/tasks/{task_id}/attachments")
    assert len(list_resp.json()) == 0


# ---------------------------------------------------------------------------
# TC-36: Delete attachment — not found
# ---------------------------------------------------------------------------


def test_delete_attachment_not_found(client: TestClient):
    """TC-36: DELETE /tasks/{id}/attachments/9999 returns 404."""
    task_id = _create_task(client)
    resp = client.delete(f"/tasks/{task_id}/attachments/9999")
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# TC-37: Delete task cleans up S3 objects
# ---------------------------------------------------------------------------


@mock_aws
def test_delete_task_cleans_s3(client: TestClient, aws_credentials, monkeypatch):
    """TC-37: DELETE /tasks/{id} deletes S3 objects for all attachments."""
    _setup_s3_bucket("test-attachments")
    monkeypatch.setenv("S3_BUCKET_NAME", "test-attachments")

    task_id = _create_task(client)
    _create_attachment(client, task_id, "file1.pdf")
    _create_attachment(client, task_id, "file2.png", "image/png")

    with patch("app.routers.tasks.delete_object") as mock_delete:
        resp = client.delete(f"/tasks/{task_id}")

    assert resp.status_code == 204
    assert mock_delete.call_count == 2


# ---------------------------------------------------------------------------
# TC-38: Filename sanitization — path traversal and special chars
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "dirty,expected",
    [
        ("normal.pdf", "normal.pdf"),
        ("../../../etc/passwd", "______etc_passwd"),
        ("file/name.txt", "file_name.txt"),
        ("back\\slash.txt", "back_slash.txt"),
        ('has"quotes.txt', "has_quotes.txt"),
        ("has<angle>brackets.txt", "has_angle_brackets.txt"),
        (" spaces.txt ", "spaces.txt"),
        (".hidden.", "hidden"),
    ],
)
def test_filename_sanitization(dirty: str, expected: str):
    """TC-38: AttachmentCreate sanitizes dangerous filename characters."""
    schema = AttachmentCreate(filename=dirty, content_type="text/plain")
    assert schema.filename == expected


# ---------------------------------------------------------------------------
# TC-39: Filename sanitization — empty after sanitization
# ---------------------------------------------------------------------------


def test_filename_sanitization_empty():
    """TC-39: Filename that becomes empty after sanitization raises ValidationError."""
    with pytest.raises(ValidationError, match="empty after sanitization"):
        AttachmentCreate(filename=". .", content_type="text/plain")

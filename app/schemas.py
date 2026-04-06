"""Pydantic schemas for request/response validation."""

from datetime import datetime

import re

from pydantic import BaseModel, ConfigDict, Field, field_validator


class TaskCreate(BaseModel):
    """Schema for creating a new task."""

    title: str = Field(..., min_length=1, max_length=255)
    description: str | None = None


class TaskUpdate(BaseModel):
    """Schema for updating an existing task."""

    title: str | None = Field(None, min_length=1, max_length=255)
    description: str | None = None
    completed: bool | None = None


class TaskResponse(BaseModel):
    """Schema for task response."""

    id: int
    title: str
    description: str | None
    completed: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


# --- Attachment schemas ---


class AttachmentCreate(BaseModel):
    """Schema for requesting a presigned upload URL."""

    filename: str = Field(..., min_length=1, max_length=255)
    content_type: str = Field(..., min_length=1, max_length=100)

    @field_validator("filename")
    @classmethod
    def sanitize_filename(cls, v: str) -> str:
        """Remove path separators and traversal patterns for safe S3 key usage."""
        v = v.replace("/", "_").replace("\\", "_").replace("..", "_")
        v = re.sub(r'[<>:"|?*\x00-\x1f]', "_", v)
        v = v.strip(" .")
        if not v:
            raise ValueError("Filename is empty after sanitization")
        return v


class AttachmentResponse(BaseModel):
    """Schema for attachment metadata response."""

    id: int
    task_id: int
    filename: str
    content_type: str
    s3_key: str
    file_size: int | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AttachmentUploadResponse(BaseModel):
    """Schema for presigned upload URL response."""

    id: int
    filename: str
    upload_url: str


class AttachmentDownloadResponse(AttachmentResponse):
    """Schema for attachment with download URL."""

    download_url: str

"""Pydantic schemas for request/response validation."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


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

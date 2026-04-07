"""Attachment CRUD endpoints for file uploads via S3 presigned URLs."""

import logging
import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.auth import get_current_user
from app.database import get_db
from app.models import Attachment, Task
from app.schemas import (
    AttachmentCreate,
    AttachmentDownloadResponse,
    AttachmentResponse,
    AttachmentUploadResponse,
)
from app.services.storage import (
    ALLOWED_CONTENT_TYPES,
    delete_object,
    generate_upload_url,
)

logger = logging.getLogger(__name__)

router = APIRouter()


def _get_task_or_404(task_id: int, db: Session) -> Task:
    """Get a task by ID or raise 404."""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    return task


@router.post("", response_model=AttachmentUploadResponse, status_code=status.HTTP_201_CREATED)
def create_attachment(
    task_id: int,
    attachment: AttachmentCreate,
    db: Session = Depends(get_db),
    _user: dict | None = Depends(get_current_user),
):
    """Request a presigned upload URL for a file attachment."""
    _get_task_or_404(task_id, db)

    bucket_name = os.environ.get("S3_BUCKET_NAME")
    if not bucket_name:
        raise HTTPException(status_code=503, detail="Storage service not configured")

    if attachment.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"Content type '{attachment.content_type}' not allowed. "
            f"Allowed: {', '.join(sorted(ALLOWED_CONTENT_TYPES))}",
        )

    s3_key = f"tasks/{task_id}/{uuid.uuid4()}-{attachment.filename}"

    upload_url = generate_upload_url(
        bucket=bucket_name,
        key=s3_key,
        content_type=attachment.content_type,
    )

    db_attachment = Attachment(
        task_id=task_id,
        filename=attachment.filename,
        content_type=attachment.content_type,
        s3_key=s3_key,
    )
    db.add(db_attachment)
    db.commit()
    db.refresh(db_attachment)

    return AttachmentUploadResponse(
        id=db_attachment.id,
        filename=db_attachment.filename,
        upload_url=upload_url,
    )


@router.get("", response_model=list[AttachmentResponse])
def list_attachments(task_id: int, db: Session = Depends(get_db), _user: dict | None = Depends(get_current_user)):
    """List all attachments for a task."""
    _get_task_or_404(task_id, db)
    return db.query(Attachment).filter(Attachment.task_id == task_id).all()


@router.get("/{attachment_id}", response_model=AttachmentDownloadResponse)
def get_attachment(task_id: int, attachment_id: int, db: Session = Depends(get_db), _user: dict | None = Depends(get_current_user)):
    """Get attachment metadata with a CloudFront download URL."""
    _get_task_or_404(task_id, db)

    attachment = (
        db.query(Attachment)
        .filter(Attachment.id == attachment_id, Attachment.task_id == task_id)
        .first()
    )
    if not attachment:
        raise HTTPException(status_code=404, detail="Attachment not found")

    cloudfront_domain = os.environ.get("CLOUDFRONT_DOMAIN_NAME", "")
    download_url = f"https://{cloudfront_domain}/{attachment.s3_key}" if cloudfront_domain else ""

    return AttachmentDownloadResponse(
        id=attachment.id,
        task_id=attachment.task_id,
        filename=attachment.filename,
        content_type=attachment.content_type,
        s3_key=attachment.s3_key,
        file_size=attachment.file_size,
        created_at=attachment.created_at,
        updated_at=attachment.updated_at,
        download_url=download_url,
    )


@router.delete("/{attachment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_attachment(task_id: int, attachment_id: int, db: Session = Depends(get_db), _user: dict | None = Depends(get_current_user)):
    """Delete an attachment from S3 and database."""
    _get_task_or_404(task_id, db)

    attachment = (
        db.query(Attachment)
        .filter(Attachment.id == attachment_id, Attachment.task_id == task_id)
        .first()
    )
    if not attachment:
        raise HTTPException(status_code=404, detail="Attachment not found")

    bucket_name = os.environ.get("S3_BUCKET_NAME")
    if bucket_name:
        delete_object(bucket=bucket_name, key=attachment.s3_key)

    db.delete(attachment)
    db.commit()

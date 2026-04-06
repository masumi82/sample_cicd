"""S3 storage service for file attachments."""

import logging
import os

import boto3
from botocore.config import Config

logger = logging.getLogger(__name__)

ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/gif",
    "application/pdf",
    "text/plain",
}

MAX_FILE_SIZE_MB = 10


def _s3_client():
    """Create a boto3 S3 client with regional endpoint for presigned URLs."""
    region = os.environ.get("AWS_REGION", "ap-northeast-1")
    return boto3.client(
        "s3",
        region_name=region,
        endpoint_url=f"https://s3.{region}.amazonaws.com",
        config=Config(signature_version="s3v4"),
    )


def generate_upload_url(bucket: str, key: str, content_type: str, expires: int = 300) -> str:
    """Generate a presigned PUT URL for S3 upload.

    Args:
        bucket: S3 bucket name.
        key: S3 object key.
        content_type: MIME type of the file.
        expires: URL expiration in seconds (default 300).

    Returns:
        Presigned PUT URL string.
    """
    return _s3_client().generate_presigned_url(
        "put_object",
        Params={
            "Bucket": bucket,
            "Key": key,
            "ContentType": content_type,
        },
        ExpiresIn=expires,
    )


def delete_object(bucket: str, key: str) -> None:
    """Delete an object from S3.

    Args:
        bucket: S3 bucket name.
        key: S3 object key.
    """
    try:
        _s3_client().delete_object(Bucket=bucket, Key=key)
        logger.info("Deleted S3 object: s3://%s/%s", bucket, key)
    except Exception as exc:
        logger.warning("Failed to delete S3 object s3://%s/%s: %s", bucket, key, exc)

"""Event publishing service for SQS and EventBridge."""

import json
import logging
import os

import boto3

logger = logging.getLogger(__name__)


def _sqs_client():
    """Create a boto3 SQS client."""
    return boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "ap-northeast-1"))


def _events_client():
    """Create a boto3 EventBridge client."""
    return boto3.client("events", region_name=os.environ.get("AWS_REGION", "ap-northeast-1"))


def publish_task_created(task_id: int, title: str) -> None:
    """Publish a task-created event to SQS.

    Args:
        task_id: The ID of the created task.
        title: The title of the created task.
    """
    queue_url = os.environ.get("SQS_QUEUE_URL")
    if not queue_url:
        logger.debug("SQS_QUEUE_URL not set, skipping publish")
        return

    try:
        message = json.dumps({"event": "task_created", "task_id": task_id, "title": title})
        _sqs_client().send_message(QueueUrl=queue_url, MessageBody=message)
        logger.info("Published task_created event: task_id=%d", task_id)
    except Exception as exc:
        logger.warning("Failed to publish task_created event: %s", exc)


def publish_task_completed(task_id: int, title: str) -> None:
    """Publish a task-completed event to EventBridge.

    Args:
        task_id: The ID of the completed task.
        title: The title of the completed task.
    """
    bus_name = os.environ.get("EVENTBRIDGE_BUS_NAME")
    if not bus_name:
        logger.debug("EVENTBRIDGE_BUS_NAME not set, skipping publish")
        return

    try:
        response = _events_client().put_events(
            Entries=[
                {
                    "Source": "sample-cicd",
                    "DetailType": "TaskCompleted",
                    "Detail": json.dumps({"task_id": task_id, "title": title}),
                    "EventBusName": bus_name,
                }
            ]
        )
        if response.get("FailedEntryCount", 0) > 0:
            logger.warning("EventBridge put_events partial failure: %s", response["Entries"])
        else:
            logger.info("Published task_completed event: task_id=%d", task_id)
    except Exception as exc:
        logger.warning("Failed to publish task_completed event: %s", exc)

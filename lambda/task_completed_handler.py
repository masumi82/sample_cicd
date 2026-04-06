"""EventBridge trigger Lambda: log task completed events."""

import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: dict, context: object) -> dict:
    """Handle EventBridge events for task completed.

    Args:
        event: EventBridge event with detail-type TaskCompleted.
        context: Lambda context object.

    Returns:
        Status response.
    """
    detail = event.get("detail", {})
    task_id = detail.get("task_id")
    title = detail.get("title")
    logger.info("Task completed: task_id=%s, title=%s", task_id, title)

    return {"statusCode": 200}

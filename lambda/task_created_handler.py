"""SQS trigger Lambda: log task created events."""

import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: dict, context: object) -> dict:
    """Handle SQS messages for task created events.

    Args:
        event: SQS event containing Records list.
        context: Lambda context object.

    Returns:
        Status response.
    """
    for record in event.get("Records", []):
        body = json.loads(record["body"])
        task_id = body.get("task_id")
        title = body.get("title")
        logger.info("Task created: task_id=%s, title=%s", task_id, title)

    return {"statusCode": 200}

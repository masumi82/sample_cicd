"""SQS trigger Lambda: log task created events."""

import json
import logging
import os
from datetime import datetime, timezone


class JSONFormatter(logging.Formatter):
    """JSON structured log formatter for CloudWatch Logs Insights."""

    def format(self, record: logging.LogRecord) -> str:
        log_entry = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)
        xray_trace_id = os.getenv("_X_AMZN_TRACE_ID")
        if xray_trace_id:
            log_entry["xray_trace_id"] = xray_trace_id
        return json.dumps(log_entry, ensure_ascii=False)


logger = logging.getLogger()
logger.setLevel(logging.INFO)
if logger.handlers:
    logger.handlers[0].setFormatter(JSONFormatter())
else:
    _handler = logging.StreamHandler()
    _handler.setFormatter(JSONFormatter())
    logger.addHandler(_handler)


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

"""Structured logging configuration for CloudWatch Logs Insights compatibility."""

import json
import logging
import os
from datetime import datetime, timezone


class JSONFormatter(logging.Formatter):
    """JSON structured log formatter for CloudWatch Logs Insights compatibility."""

    def format(self, record: logging.LogRecord) -> str:
        """Format a log record as a JSON string.

        Args:
            record: The log record to format.

        Returns:
            JSON-formatted log string.
        """
        log_entry: dict = {
            "timestamp": datetime.fromtimestamp(
                record.created, tz=timezone.utc
            ).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
            + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info and record.exc_info[0] is not None:
            log_entry["exception"] = self.formatException(record.exc_info)

        # X-Ray trace ID correlation (if available)
        xray_trace_id = os.getenv("_X_AMZN_TRACE_ID")
        if xray_trace_id:
            log_entry["xray_trace_id"] = xray_trace_id

        return json.dumps(log_entry, ensure_ascii=False)

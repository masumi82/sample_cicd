"""EventBridge Scheduler trigger Lambda: delete old completed tasks from RDS."""

import json
import logging
import os
from datetime import datetime, timedelta, timezone

import boto3
import psycopg2


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


def _get_db_credentials() -> dict:
    """Retrieve DB credentials from Secrets Manager.

    Returns:
        Dictionary with host, port, dbname, username, password.
    """
    secret_arn = os.environ["DB_SECRET_ARN"]
    region = os.environ.get("AWS_REGION", "ap-northeast-1")
    client = boto3.client("secretsmanager", region_name=region)
    response = client.get_secret_value(SecretId=secret_arn)
    return json.loads(response["SecretString"])


def handler(event: dict, context: object) -> dict:
    """Delete completed tasks older than the retention period.

    Args:
        event: Scheduler event payload (unused).
        context: Lambda context object.

    Returns:
        Dictionary with the number of deleted tasks.
    """
    retention_days = int(os.environ.get("CLEANUP_RETENTION_DAYS", "30"))
    # timezone.utc を使い tzinfo を除去して naive UTC datetime にする（TIMESTAMP WITHOUT TIME ZONE 列と合わせる）
    cutoff = (datetime.now(tz=timezone.utc) - timedelta(days=retention_days)).replace(tzinfo=None)

    creds = _get_db_credentials()
    conn = psycopg2.connect(
        host=creds["host"],
        port=int(creds.get("port", 5432)),
        dbname=creds["dbname"],
        user=creds["username"],
        password=creds["password"],
        connect_timeout=10,
    )

    try:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM tasks WHERE completed = true AND updated_at < %s",
                (cutoff,),
            )
            deleted = cur.rowcount
        conn.commit()
    except Exception:
        conn.rollback()
        raise  # Lambda に失敗を通知し Scheduler が再試行できるようにする
    finally:
        conn.close()

    logger.info("Cleanup done: deleted %d tasks older than %d days", deleted, retention_days)
    return {"deleted": deleted}

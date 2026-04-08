"""Redis caching service with graceful degradation."""

import json
import logging
import os
from typing import Any

logger = logging.getLogger(__name__)

_redis_client = None


def _get_redis():
    """Get or create Redis client (lazy singleton)."""
    global _redis_client
    redis_url = os.environ.get("REDIS_URL")
    if not redis_url:
        return None
    if _redis_client is None:
        try:
            import redis

            _redis_client = redis.from_url(redis_url, decode_responses=True)
            _redis_client.ping()
            logger.info("Redis connection established: %s", redis_url.split("@")[-1])
        except Exception as exc:
            logger.warning("Redis connection failed, caching disabled: %s", exc)
            _redis_client = None
    return _redis_client


def cache_get(key: str) -> Any | None:
    """Get value from Redis cache. Returns None on miss or error."""
    client = _get_redis()
    if client is None:
        return None
    try:
        value = client.get(key)
        if value is not None:
            logger.debug("Cache HIT: %s", key)
            return json.loads(value)
        logger.debug("Cache MISS: %s", key)
        return None
    except Exception as exc:
        logger.warning("Cache get failed for key %s: %s", key, exc)
        return None


def cache_set(key: str, value: Any, ttl: int | None = None) -> None:
    """Set value in Redis cache. Silently fails on error."""
    client = _get_redis()
    if client is None:
        return
    try:
        serialized = json.dumps(value, default=str)
        if ttl is not None:
            client.setex(key, ttl, serialized)
        else:
            client.set(key, serialized)
        logger.debug("Cache SET: %s (ttl=%s)", key, ttl)
    except Exception as exc:
        logger.warning("Cache set failed for key %s: %s", key, exc)


def cache_delete(*keys: str) -> None:
    """Delete keys from Redis cache. Silently fails on error."""
    client = _get_redis()
    if client is None:
        return
    try:
        client.delete(*keys)
        logger.debug("Cache DELETE: %s", keys)
    except Exception as exc:
        logger.warning("Cache delete failed for keys %s: %s", keys, exc)

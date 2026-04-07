"""JWT authentication module for Cognito integration."""

import json
import logging
import os
import time
import urllib.request

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

logger = logging.getLogger(__name__)

# --- Configuration ---
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID", "")
COGNITO_APP_CLIENT_ID = os.getenv("COGNITO_APP_CLIENT_ID", "")
AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-1")

AUTH_ENABLED = bool(COGNITO_USER_POOL_ID) and bool(COGNITO_APP_CLIENT_ID)

# JWKS cache
_jwks_cache: dict | None = None
_jwks_cache_time: float = 0
_JWKS_CACHE_TTL = 3600  # 1 hour

# HTTPBearer scheme (auto_error=False to allow graceful degradation)
_bearer_scheme = HTTPBearer(auto_error=False)


def _get_jwks() -> dict:
    """Fetch and cache JWKS from Cognito."""
    global _jwks_cache, _jwks_cache_time

    now = time.time()
    if _jwks_cache and (now - _jwks_cache_time) < _JWKS_CACHE_TTL:
        return _jwks_cache

    jwks_url = (
        f"https://cognito-idp.{AWS_REGION}.amazonaws.com/"
        f"{COGNITO_USER_POOL_ID}/.well-known/jwks.json"
    )
    try:
        with urllib.request.urlopen(jwks_url, timeout=5) as resp:
            _jwks_cache = json.loads(resp.read())
            _jwks_cache_time = now
            logger.info("JWKS fetched and cached from %s", jwks_url)
            return _jwks_cache
    except Exception:
        logger.warning("Failed to fetch JWKS from %s", jwks_url)
        if _jwks_cache:
            return _jwks_cache
        raise


def _find_key(kid: str) -> dict | None:
    """Find a key in JWKS by kid."""
    jwks = _get_jwks()
    for key in jwks.get("keys", []):
        if key.get("kid") == kid:
            return key
    return None


def _verify_token(token: str) -> dict:
    """Verify JWT token and return claims."""
    from jose import JWTError, jwt

    issuer = f"https://cognito-idp.{AWS_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}"

    try:
        unverified_header = jwt.get_unverified_header(token)
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token format",
        ) from e

    kid = unverified_header.get("kid")
    if not kid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token missing kid header",
        )

    key = _find_key(kid)
    if not key:
        # Refresh JWKS cache and retry
        global _jwks_cache_time
        _jwks_cache_time = 0
        key = _find_key(kid)
        if not key:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token signing key not found",
            )

    try:
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=COGNITO_APP_CLIENT_ID,
            issuer=issuer,
        )
    except jwt.ExpiredSignatureError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token expired",
        ) from e
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token validation failed",
        ) from e

    # Verify token_use claim
    token_use = claims.get("token_use")
    if token_use != "id":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type",
        )

    return claims


def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
) -> dict | None:
    """FastAPI dependency to get the current authenticated user.

    When AUTH_ENABLED is False (COGNITO env vars not set),
    returns None without requiring authentication (graceful degradation).

    Args:
        credentials: Bearer token from Authorization header.

    Returns:
        User claims dict or None (when auth is disabled).

    Raises:
        HTTPException: 401 if authentication fails.
    """
    if not AUTH_ENABLED:
        return None

    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return _verify_token(credentials.credentials)

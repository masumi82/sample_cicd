"""v7: JWT authentication tests (TC-48 ~ TC-55)."""

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.auth import get_current_user
from app.main import app


# --- TC-48: AUTH_ENABLED is False when env vars are not set ---

def test_auth_disabled_by_default():
    """TC-48: AUTH_ENABLED should be False when COGNITO env vars are not set."""
    from app.auth import AUTH_ENABLED

    assert AUTH_ENABLED is False


# --- TC-49: get_current_user returns None when auth is disabled ---

def test_get_current_user_returns_none_when_disabled():
    """TC-49: get_current_user should return None when AUTH_ENABLED is False."""
    import app.auth as auth_module

    original = auth_module.AUTH_ENABLED
    try:
        auth_module.AUTH_ENABLED = False
        result = get_current_user(credentials=None)
        assert result is None
    finally:
        auth_module.AUTH_ENABLED = original


# --- TC-50: 401 when no Bearer token and auth is enabled ---

def test_tasks_returns_401_without_auth_header():
    """TC-50: GET /tasks should return 401 when auth is enabled and no token."""
    # Remove the test override so real auth logic runs
    original_override = app.dependency_overrides.pop(get_current_user, None)

    import app.auth as auth_module

    original_enabled = auth_module.AUTH_ENABLED
    auth_module.AUTH_ENABLED = True

    try:
        client = TestClient(app)
        response = client.get("/tasks")
        assert response.status_code == 401
    finally:
        auth_module.AUTH_ENABLED = original_enabled
        if original_override is not None:
            app.dependency_overrides[get_current_user] = original_override


# --- TC-51: Public endpoint / is accessible without auth ---

def test_root_accessible_without_auth():
    """TC-51: GET / should return 200 without authentication."""
    original_override = app.dependency_overrides.pop(get_current_user, None)

    import app.auth as auth_module

    original_enabled = auth_module.AUTH_ENABLED
    auth_module.AUTH_ENABLED = True

    try:
        client = TestClient(app)
        response = client.get("/")
        assert response.status_code == 200
        assert response.json() == {"message": "Hello, World!"}
    finally:
        auth_module.AUTH_ENABLED = original_enabled
        if original_override is not None:
            app.dependency_overrides[get_current_user] = original_override


# --- TC-52: Public endpoint /health is accessible without auth ---

def test_health_accessible_without_auth():
    """TC-52: GET /health should return 200 without authentication."""
    original_override = app.dependency_overrides.pop(get_current_user, None)

    import app.auth as auth_module

    original_enabled = auth_module.AUTH_ENABLED
    auth_module.AUTH_ENABLED = True

    try:
        client = TestClient(app)
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json() == {"status": "healthy"}
    finally:
        auth_module.AUTH_ENABLED = original_enabled
        if original_override is not None:
            app.dependency_overrides[get_current_user] = original_override


# --- TC-53: Authenticated request succeeds ---

def test_tasks_accessible_with_valid_auth(client: TestClient):
    """TC-53: GET /tasks should return 200 when user is authenticated (via override)."""
    response = client.get("/tasks")
    assert response.status_code == 200
    assert isinstance(response.json(), list)


# --- TC-54: Invalid token format raises 401 ---

def test_verify_token_invalid_format():
    """TC-54: _verify_token should raise 401 for invalid token format."""
    import app.auth as auth_module

    original_enabled = auth_module.AUTH_ENABLED
    original_pool = auth_module.COGNITO_USER_POOL_ID
    original_client = auth_module.COGNITO_APP_CLIENT_ID

    auth_module.AUTH_ENABLED = True
    auth_module.COGNITO_USER_POOL_ID = "ap-northeast-1_TestPool"
    auth_module.COGNITO_APP_CLIENT_ID = "test-client-id"

    try:
        from app.auth import _verify_token

        with pytest.raises(HTTPException) as exc_info:
            _verify_token("not-a-valid-jwt")
        assert exc_info.value.status_code == 401
        assert "Invalid token format" in exc_info.value.detail
    finally:
        auth_module.AUTH_ENABLED = original_enabled
        auth_module.COGNITO_USER_POOL_ID = original_pool
        auth_module.COGNITO_APP_CLIENT_ID = original_client


# --- TC-55: Token with unknown kid raises 401 ---

def test_verify_token_unknown_kid():
    """TC-55: _verify_token should raise 401 when kid is not found in JWKS."""
    from unittest.mock import patch

    import app.auth as auth_module
    from jose import jwt as jose_jwt

    original_enabled = auth_module.AUTH_ENABLED
    original_pool = auth_module.COGNITO_USER_POOL_ID
    original_client = auth_module.COGNITO_APP_CLIENT_ID

    auth_module.AUTH_ENABLED = True
    auth_module.COGNITO_USER_POOL_ID = "ap-northeast-1_TestPool"
    auth_module.COGNITO_APP_CLIENT_ID = "test-client-id"

    try:
        # Create a token with a header containing a kid
        fake_token = jose_jwt.encode(
            {"sub": "test", "token_use": "id"},
            "secret",
            algorithm="HS256",
            headers={"kid": "nonexistent-kid"},
        )

        from app.auth import _verify_token

        # Mock _get_jwks to prevent real network requests
        with patch("app.auth._get_jwks", return_value={"keys": []}):
            with pytest.raises(HTTPException) as exc_info:
                _verify_token(fake_token)
            assert exc_info.value.status_code == 401
    finally:
        auth_module.AUTH_ENABLED = original_enabled
        auth_module.COGNITO_USER_POOL_ID = original_pool
        auth_module.COGNITO_APP_CLIENT_ID = original_client

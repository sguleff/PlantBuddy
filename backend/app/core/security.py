import hmac
from datetime import datetime, timedelta, timezone
from typing import Optional

import jwt

from app.core.config import get_settings


ALGORITHM = "HS256"


def verify_password(plain_password: str) -> bool:
    settings = get_settings()
    return hmac.compare_digest(plain_password, settings.app_password)


def create_access_token(subject: str) -> str:
    settings = get_settings()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {"sub": subject, "exp": expires_at, "type": "access"}
    return jwt.encode(payload, settings.app_secret_key, algorithm=ALGORITHM)


def create_refresh_token(subject: str) -> str:
    settings = get_settings()
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.refresh_token_expire_days)
    payload = {"sub": subject, "exp": expires_at, "type": "refresh"}
    return jwt.encode(payload, settings.app_secret_key, algorithm=ALGORITHM)


def decode_access_token(token: str) -> Optional[dict]:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.app_secret_key, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    if payload.get("type") != "access":
        return None
    return payload


def decode_refresh_token(token: str) -> Optional[dict]:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.app_secret_key, algorithms=[ALGORITHM])
    except jwt.PyJWTError:
        return None
    if payload.get("type") != "refresh":
        return None
    return payload

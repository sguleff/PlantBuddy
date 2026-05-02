from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.security import decode_access_token
from app.db import get_db


bearer_scheme = HTTPBearer(auto_error=False)


def get_current_username(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> str:
    settings = get_settings()
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    payload = decode_access_token(credentials.credentials)
    if payload is None or payload.get("sub") != settings.app_username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return settings.app_username


def get_current_db(
    db: Session = Depends(get_db),
    _: str = Depends(get_current_username),
) -> Session:
    return db

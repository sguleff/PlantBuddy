from fastapi import APIRouter, Depends, HTTPException, status

from app.api.deps import get_current_username
from app.core.config import get_settings
from app.core.security import create_access_token, create_refresh_token, decode_refresh_token, verify_password
from app.schemas import CurrentUserResponse, LoginRequest, RefreshTokenRequest, TokenResponse


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest):
    settings = get_settings()
    if payload.username != settings.app_username or not verify_password(payload.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return TokenResponse(
        access_token=create_access_token(settings.app_username),
        refresh_token=create_refresh_token(settings.app_username),
        expires_in_minutes=settings.jwt_expire_minutes,
        refresh_expires_in_days=settings.refresh_token_expire_days,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshTokenRequest):
    settings = get_settings()
    decoded = decode_refresh_token(payload.refresh_token)
    if decoded is None or decoded.get("sub") != settings.app_username:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(
        access_token=create_access_token(settings.app_username),
        refresh_token=create_refresh_token(settings.app_username),
        expires_in_minutes=settings.jwt_expire_minutes,
        refresh_expires_in_days=settings.refresh_token_expire_days,
    )


@router.get("/me", response_model=CurrentUserResponse)
def get_me(username: str = Depends(get_current_username)):
    return CurrentUserResponse(username=username)

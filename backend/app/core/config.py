from functools import lru_cache
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_env: str = "development"
    app_secret_key: str = Field(default="change-me", validation_alias="APP_SECRET_KEY")
    app_username: str = Field(default="plantbuddy", validation_alias="APP_USERNAME")
    app_password: str = Field(default="change-me", validation_alias="APP_PASSWORD")
    jwt_expire_minutes: int = Field(default=120, validation_alias="JWT_EXPIRE_MINUTES")
    refresh_token_expire_days: int = Field(default=30, validation_alias="REFRESH_TOKEN_EXPIRE_DAYS")

    database_url: str = Field(
        default="postgresql+psycopg://plantbuddy:plantbuddy@localhost:5432/plantbuddy",
        validation_alias="DATABASE_URL",
    )
    database_schema: str = Field(default="plantbuddy", validation_alias="DATABASE_SCHEMA")

    openai_api_key: str = Field(default="", validation_alias="OPENAI_API_KEY")
    openai_model: str = Field(default="gpt-4o-mini", validation_alias="OPENAI_MODEL")
    deep_analysis_model: str = Field(default="gpt-5.2-chat-latest", validation_alias="DEEP_ANALYSIS_MODEL")
    background_worker_enabled: bool = Field(default=True, validation_alias="BACKGROUND_WORKER_ENABLED")
    background_worker_interval_seconds: int = Field(default=15, validation_alias="BACKGROUND_WORKER_INTERVAL_SECONDS")
    run_migrations_on_startup: bool = Field(default=False, validation_alias="RUN_MIGRATIONS_ON_STARTUP")
    docs_enabled: bool = Field(default=True, validation_alias="DOCS_ENABLED")
    plantbuddy_storage_path: str = Field(
        default="./storage",
        validation_alias="PLANTBUDDY_STORAGE_PATH",
    )
    cors_allowed_origins: str = Field(
        default="http://localhost:8000,http://127.0.0.1:8000,http://localhost:8080,http://127.0.0.1:8080",
        validation_alias="CORS_ALLOWED_ORIGINS",
    )
    public_base_url: str = Field(default="http://localhost:8000", validation_alias="PUBLIC_BASE_URL")
    frontend_api_base_url: str = Field(
        default="http://127.0.0.1:8000/api",
        validation_alias="FRONTEND_API_BASE_URL",
    )
    trusted_hosts: str = Field(default="localhost,127.0.0.1", validation_alias="TRUSTED_HOSTS")
    secure_headers_enabled: bool = Field(default=True, validation_alias="SECURE_HEADERS_ENABLED")
    max_upload_mb: int = Field(default=25, validation_alias="MAX_UPLOAD_MB")

    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]

    @property
    def trusted_host_patterns(self) -> List[str]:
        return [host.strip() for host in self.trusted_hosts.split(",") if host.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

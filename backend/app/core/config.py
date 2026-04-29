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

    database_url: str = Field(
        default="postgresql+psycopg://plantbuddy:plantbuddy@localhost:5432/plantbuddy",
        validation_alias="DATABASE_URL",
    )
    database_schema: str = Field(default="plantbuddy", validation_alias="DATABASE_SCHEMA")

    openai_api_key: str = Field(default="", validation_alias="OPENAI_API_KEY")
    plantbuddy_storage_path: str = Field(
        default="./storage",
        validation_alias="PLANTBUDDY_STORAGE_PATH",
    )
    cors_allowed_origins: str = Field(
        default="http://localhost:8000,http://localhost:8080",
        validation_alias="CORS_ALLOWED_ORIGINS",
    )
    public_base_url: str = Field(default="http://localhost:8000", validation_alias="PUBLIC_BASE_URL")

    model_config = SettingsConfigDict(env_file=(".env", "../.env"), extra="ignore")

    @property
    def cors_origins(self) -> List[str]:
        return [origin.strip() for origin in self.cors_allowed_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str
    jwt_secret: str
    access_token_minutes: int = 15
    refresh_token_days: int = 7
    # Session times are stored as campus-local wall-clock time (see docs/decisions.md).
    timezone: str = "Asia/Kolkata"
    # Comma-separated list, or "*" for development. Set explicit origins in production.
    cors_origins: str = "*"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()

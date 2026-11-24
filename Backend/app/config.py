from pathlib import Path
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = Field(min_length=1)
    jwt_secret_key: str = Field(min_length=32)
    access_token_minutes: int = 60
    cors_origins: str = "http://localhost:3000,http://localhost:5000,http://localhost:8080"
    # Flutter web uses a temporary localhost port unless one is explicitly chosen.
    # This regex is limited to loopback hosts; production can set it to an empty value.
    cors_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    auto_create_tables: bool = False
    upload_dir: Path = Path(__file__).resolve().parents[1] / "uploads"
    report_upload_dir: Path = Path(__file__).resolve().parents[2] / "private_reports"

    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[1] / ".env",
        extra="ignore",
        hide_input_in_errors=True,
    )

    @property
    def allowed_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def allowed_origin_regex(self) -> str | None:
        value = self.cors_origin_regex.strip()
        return value or None


settings = Settings()

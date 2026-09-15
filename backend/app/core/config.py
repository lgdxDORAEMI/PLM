from functools import lru_cache
from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict

# 로컬 Flutter Web 개발 포트만 허용한다. main.py의 CORSMiddleware와
# app/api/v1/movement.py의 WebSocket Origin 검증이 이 값을 같이 참조한다 —
# 한 곳에만 정의해서 두 곳이 서로 다른 규칙으로 어긋나지 않게 한다.
ALLOWED_ORIGIN_REGEX = r"http://(?:localhost|127\.0\.0\.1)(?::[0-9]+)?"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    supabase_url: str = ""
    supabase_anon_key: SecretStr = SecretStr("")
    supabase_service_role_key: SecretStr = SecretStr("")
    llm_api_key: SecretStr = SecretStr("")
    llm_api_base_url: str = ""


@lru_cache
def get_settings() -> Settings:
    return Settings()

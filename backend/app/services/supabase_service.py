from functools import lru_cache

from supabase import Client, create_client

from app.core.config import Settings, get_settings


class SupabaseService:
    """서버 전용 Supabase client를 지연 생성한다."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._client: Client | None = None

    @property
    def client(self) -> Client:
        if self._client is None:
            key = self.settings.supabase_service_role_key.get_secret_value()
            if not self.settings.supabase_url or not key:
                raise ValueError("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required")
            self._client = create_client(self.settings.supabase_url, key)
        return self._client


@lru_cache
def get_supabase_service() -> SupabaseService:
    return SupabaseService(get_settings())

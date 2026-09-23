"""Read-only ThinQ Connect inventory with a short process-local cache."""

import asyncio
import time
from dataclasses import dataclass
from enum import StrEnum
from uuid import UUID

import aiohttp
from thinqconnect.thinq_api import ThinQAPIException, ThinQApi

from app.core.config import get_settings

from .models import ThinQDevice, normalize_device


class InventoryStatus(StrEnum):
    CONNECTED = "connected"
    NOT_CONFIGURED = "not_configured"
    AUTH_ERROR = "auth_error"
    TIMEOUT = "timeout"
    ERROR = "error"
    UNSUPPORTED_COUNTRY = "unsupported_country"


class ControlStatus(StrEnum):
    OK = "ok"
    NOT_CONFIGURED = "not_configured"
    AUTH_ERROR = "auth_error"
    TIMEOUT = "timeout"
    ERROR = "error"


@dataclass(frozen=True)
class ControlResult:
    status: ControlStatus
    # LG 오류 코드(예: "0102")만 담는다. SDK 예외 메시지는 요청 정보를 echo할 수 있어 절대 담지 않는다.
    error_code: str | None = None


@dataclass(frozen=True)
class DeviceInventory:
    devices: tuple[ThinQDevice, ...]
    status: InventoryStatus


class ThinQClient:
    def __init__(self, ttl_seconds: int = 300) -> None:
        self._ttl_seconds = ttl_seconds
        self._cached: DeviceInventory | None = None
        self._expires_at = 0.0
        self._lock = asyncio.Lock()

    def clear_cache(self) -> None:
        self._cached = None
        self._expires_at = 0.0

    async def get_inventory(self) -> DeviceInventory:
        """Never propagate SDK exceptions: they may contain sensitive request details."""
        settings = get_settings()
        pat = settings.thinq_pat.get_secret_value()
        if not pat or not settings.thinq_client_id:
            return DeviceInventory((), InventoryStatus.NOT_CONFIGURED)
        try:
            UUID(settings.thinq_client_id)
        except ValueError:
            return DeviceInventory((), InventoryStatus.NOT_CONFIGURED)
        if self._cached is not None and time.monotonic() < self._expires_at:
            return self._cached
        async with self._lock:
            if self._cached is not None and time.monotonic() < self._expires_at:
                return self._cached
            result = await self._fetch(pat, settings.thinq_country_code, settings.thinq_client_id)
            if result.status == InventoryStatus.CONNECTED:
                self._cached = result
                self._expires_at = time.monotonic() + self._ttl_seconds
            return result

    async def _fetch(self, pat: str, country: str, client_id: str) -> DeviceInventory:
        try:
            async with aiohttp.ClientSession() as session:
                try:
                    api = ThinQApi(session, pat, country, client_id)
                except ValueError:
                    return DeviceInventory((), InventoryStatus.UNSUPPORTED_COUNTRY)
                raw = await asyncio.wait_for(api.async_get_device_list(timeout=8), timeout=10)
            if raw is None:
                return DeviceInventory((), InventoryStatus.ERROR)
            if not isinstance(raw, list):
                return DeviceInventory((), InventoryStatus.ERROR)
            devices = tuple(device for row in raw if (device := normalize_device(row)) is not None)
            return DeviceInventory(devices, InventoryStatus.CONNECTED)
        except ThinQAPIException as error:
            # Never log or chain this exception: SDK messages may contain request data.
            if error.code in {"1103", "1218", "1302"}:
                return DeviceInventory((), InventoryStatus.AUTH_ERROR)
            if error.code == "1307":
                return DeviceInventory((), InventoryStatus.UNSUPPORTED_COUNTRY)
            return DeviceInventory((), InventoryStatus.ERROR)
        except (asyncio.TimeoutError, TimeoutError):
            return DeviceInventory((), InventoryStatus.TIMEOUT)
        except ValueError:
            return DeviceInventory((), InventoryStatus.ERROR)
        except aiohttp.ClientError:
            return DeviceInventory((), InventoryStatus.ERROR)
        except Exception:
            # The household guide must remain available for unexpected SDK failures.
            return DeviceInventory((), InventoryStatus.ERROR)

    async def control(self, device_id: str, payload: dict) -> ControlResult:
        """Never propagate SDK exceptions: the message may contain sensitive request details.
        The LG error *code* alone is safe to keep — it is a short category id, never echoed request data."""
        settings = get_settings()
        pat = settings.thinq_pat.get_secret_value()
        if not pat or not settings.thinq_client_id:
            return ControlResult(ControlStatus.NOT_CONFIGURED)
        try:
            UUID(settings.thinq_client_id)
        except ValueError:
            return ControlResult(ControlStatus.NOT_CONFIGURED)
        try:
            async with aiohttp.ClientSession() as session:
                try:
                    api = ThinQApi(session, pat, settings.thinq_country_code, settings.thinq_client_id)
                except ValueError:
                    return ControlResult(ControlStatus.ERROR)
                await asyncio.wait_for(api.async_post_device_control(device_id, payload, timeout=8), timeout=10)
            return ControlResult(ControlStatus.OK)
        except ThinQAPIException as error:
            # Never log or chain this exception: the message may contain request data.
            if error.code in {"1103", "1218", "1302"}:
                return ControlResult(ControlStatus.AUTH_ERROR, error.code)
            return ControlResult(ControlStatus.ERROR, error.code)
        except (asyncio.TimeoutError, TimeoutError):
            return ControlResult(ControlStatus.TIMEOUT)
        except aiohttp.ClientError:
            return ControlResult(ControlStatus.ERROR)
        except Exception:
            return ControlResult(ControlStatus.ERROR)


_client = ThinQClient()


def get_thinq_client() -> ThinQClient:
    return _client

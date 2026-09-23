"""Air purifier control endpoint: owned-device gating and SDK payload shape."""

import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, call, patch

from httpx import ASGITransport, AsyncClient
from thinqconnect.thinq_api import ThinQAPIException

from app.core.security import CurrentUser, get_current_user
from app.main import app
from app.services.thinq.client import (
    ControlResult,
    ControlStatus,
    DeviceInventory,
    InventoryStatus,
    ThinQClient,
    get_thinq_client,
)
from app.services.thinq.models import ApplianceType, ThinQDevice


def purifier(device_id: str = "purifier-1") -> ThinQDevice:
    # The control endpoint is appliance-type-agnostic; type only matters to the household mapper (Phase 2).
    return ThinQDevice(device_id=device_id, name="공청이", device_type=ApplianceType.WASHER)


class ControlPayloadTest(unittest.IsolatedAsyncioTestCase):
    async def test_power_on_posts_documented_command(self) -> None:
        client = ThinQClient()
        with patch("app.services.thinq.client.ThinQApi") as api:
            api.return_value.async_post_device_control = AsyncMock(return_value={})
            result = await client.control(
                "purifier-1", {"operation": {"airPurifierOperationMode": "POWER_ON"}}
            )
        self.assertEqual(result.status, ControlStatus.OK)
        api.return_value.async_post_device_control.assert_awaited_once_with(
            "purifier-1", {"operation": {"airPurifierOperationMode": "POWER_ON"}}, timeout=8
        )

    async def test_auth_error_maps_without_leaking_pat(self) -> None:
        secret = "SECRET_TEST_PAT_DO_NOT_EXPOSE"
        client = ThinQClient()
        with patch("app.services.thinq.client.ThinQApi") as api:
            api.return_value.async_post_device_control = AsyncMock(
                side_effect=ThinQAPIException("1103", secret, {})
            )
            result = await client.control("purifier-1", {"operation": {"airPurifierOperationMode": "POWER_OFF"}})
        self.assertEqual(result.status, ControlStatus.AUTH_ERROR)
        self.assertEqual(result.error_code, "1103")
        self.assertNotIn(secret, repr(result))


class ControlEndpointTest(unittest.IsolatedAsyncioTestCase):
    async def _call(self, client: ThinQClient, device_id: str, body: dict):
        with patch(
            "app.services.thinq.access.get_settings",
            return_value=SimpleNamespace(plm_wife_email="wife@example.com"),
        ):
            app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1", email="wife@example.com")
            app.dependency_overrides[get_thinq_client] = lambda: client
            try:
                async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
                    return await http.post(f"/api/v1/thinq/devices/{device_id}/control", json=body)
            finally:
                app.dependency_overrides.clear()

    async def test_power_off_calls_control_with_air_purifier_payload(self) -> None:
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.OK)) as control,
        ):
            response = await self._call(client, "purifier-1", {"power": "off"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
        control.assert_awaited_once_with("purifier-1", {"operation": {"airPurifierOperationMode": "POWER_OFF"}})

    async def test_wind_strength_maps_to_documented_enum(self) -> None:
        """전원이 꺼진 기기가 켜기+바람세기를 한 요청으로 거부할 수 있어, 두 번의 개별 요청으로 나눠 보낸다."""
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.OK)) as control,
        ):
            response = await self._call(client, "purifier-1", {"power": "on", "wind_strength": "auto"})
        self.assertEqual(response.status_code, 200)
        control.assert_has_awaits([
            call("purifier-1", {"operation": {"airPurifierOperationMode": "POWER_ON"}}),
            call("purifier-1", {"airFlow": {"windStrength": "AUTO"}}),
        ])

    async def test_wind_strength_skipped_when_power_call_fails(self) -> None:
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.ERROR)) as control,
        ):
            response = await self._call(client, "purifier-1", {"power": "on", "wind_strength": "auto"})
        self.assertEqual(response.status_code, 502)
        control.assert_awaited_once_with("purifier-1", {"operation": {"airPurifierOperationMode": "POWER_ON"}})

    async def test_unowned_device_id_is_rejected(self) -> None:
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control") as control,
        ):
            response = await self._call(client, "some-other-device", {"power": "on"})
        self.assertEqual(response.status_code, 404)
        control.assert_not_called()

    async def test_empty_body_is_rejected(self) -> None:
        client = ThinQClient()
        response = await self._call(client, "purifier-1", {})
        self.assertEqual(response.status_code, 400)

    async def test_sdk_failure_returns_502(self) -> None:
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.ERROR)),
        ):
            response = await self._call(client, "purifier-1", {"power": "on"})
        self.assertEqual(response.status_code, 502)

    async def test_auth_error_and_timeout_get_distinct_messages(self) -> None:
        """502 하나로 뭉치면 네트워크 탭만 보고 원인(PAT 권한 vs 타임아웃)을 구분할 수 없다."""
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.AUTH_ERROR)),
        ):
            auth_response = await self._call(client, "purifier-1", {"power": "on"})
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.TIMEOUT)),
        ):
            timeout_response = await self._call(client, "purifier-1", {"power": "on"})
        self.assertEqual(auth_response.status_code, 502)
        self.assertEqual(timeout_response.status_code, 502)
        self.assertNotEqual(auth_response.json()["detail"], timeout_response.json()["detail"])

    async def test_lg_error_code_is_appended_when_present(self) -> None:
        """LG 오류 코드만 노출한다(민감한 메시지 원문은 여전히 감춘다) — 기기별 원인 구분용."""
        client = ThinQClient()
        inventory = DeviceInventory((purifier(),), InventoryStatus.CONNECTED)
        with (
            patch.object(client, "get_inventory", return_value=inventory),
            patch.object(client, "control", return_value=ControlResult(ControlStatus.ERROR, "0102")),
        ):
            response = await self._call(client, "purifier-1", {"power": "on"})
        self.assertIn("0102", response.json()["detail"])

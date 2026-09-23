"""Owned-device gating and safe ThinQ failure behavior."""

import io
import logging
import unittest
from datetime import date
from types import SimpleNamespace
from unittest.mock import patch

from httpx import ASGITransport, AsyncClient
from thinqconnect.thinq_api import ThinQAPIException

from app.api.v1.guide import get_guide_service
from app.core.security import CurrentUser, get_current_user
from app.domains.guide.schemas import GuideItem, GuideResponse, RoutineCategory
from app.main import app
from app.services.thinq.appliance_mapper import apply_inventory
from app.services.thinq.client import (
    DeviceInventory,
    InventoryStatus,
    ThinQClient,
    get_thinq_client,
)
from app.services.thinq.models import ApplianceType, ThinQDevice, normalize_device


def task(code: str, title: str, owner: str = "appliance") -> GuideItem:
    return GuideItem(
        item_id=code,
        item_key=f"household:{code}",
        title=title,
        payload={"owner": owner, "reason": "원래 추천"},
        status="scheduled",
    )


def guide(*items: GuideItem) -> GuideResponse:
    return GuideResponse(date=date(2026, 9, 22), category=RoutineCategory.HOUSEHOLD, items=list(items))


def device(kind: ApplianceType, suffix: str) -> ThinQDevice:
    return ThinQDevice(device_id=suffix, name=suffix, device_type=kind)


class ApplianceMapperTest(unittest.TestCase):
    def test_only_owned_washer_matches_laundry(self) -> None:
        result = apply_inventory(
            guide(task("laundry", "빨래"), task("cleaning", "청소"), task("dishes", "설거지")),
            DeviceInventory((device(ApplianceType.WASHER, "세탁기"),), InventoryStatus.CONNECTED),
        )
        self.assertEqual([item.payload["owner"] for item in result.items], ["appliance", "partner", "partner"])
        self.assertEqual(result.items[0].payload["appliances"][0]["name"], "세탁기")

    def test_robot_vacuum_matches_cleaning(self) -> None:
        result = apply_inventory(guide(task("cleaning", "청소", "self")), DeviceInventory(
            (device(ApplianceType.ROBOT_VACUUM, "로봇청소기"),), InventoryStatus.CONNECTED,
        ))
        self.assertEqual(result.items[0].payload["owner"], "appliance")

    def test_dishwasher_matches_dishes(self) -> None:
        result = apply_inventory(guide(task("dishes", "설거지")), DeviceInventory(
            (device(ApplianceType.DISHWASHER, "식기세척기"),), InventoryStatus.CONNECTED,
        ))
        self.assertEqual(result.items[0].payload["appliances"][0]["device_type"], "dishwasher")

    def test_washer_and_dryer_both_display(self) -> None:
        result = apply_inventory(guide(task("laundry", "빨래")), DeviceInventory(
            (device(ApplianceType.WASHER, "세탁기"), device(ApplianceType.DRYER, "건조기")),
            InventoryStatus.CONNECTED,
        ))
        self.assertEqual([appliance["name"] for appliance in result.items[0].payload["appliances"]], ["세탁기", "건조기"])

    def test_empty_inventory_has_no_appliance_tasks(self) -> None:
        result = apply_inventory(guide(task("laundry", "빨래"), task("groceries", "장보기", "partner")),
                                 DeviceInventory((), InventoryStatus.CONNECTED))
        self.assertNotIn("appliance", [item.payload["owner"] for item in result.items])
        self.assertEqual(result.items[1].payload["owner"], "partner")

    def test_air_purifier_is_injected_regardless_of_ai_output(self) -> None:
        result = apply_inventory(
            guide(task("laundry", "빨래")),
            DeviceInventory(
                (device(ApplianceType.WASHER, "세탁기"), device(ApplianceType.AIR_PURIFIER, "공청이")),
                InventoryStatus.CONNECTED,
            ),
        )
        purifier_items = [item for item in result.items if item.item_key == "household:air_purifier"]
        self.assertEqual(len(purifier_items), 1)
        self.assertEqual(purifier_items[0].title, "공기청정기 가동")
        self.assertEqual(purifier_items[0].payload["owner"], "appliance")
        self.assertEqual(purifier_items[0].payload["appliances"][0]["name"], "공청이")

    def test_no_air_purifier_item_without_the_device(self) -> None:
        result = apply_inventory(
            guide(task("laundry", "빨래")),
            DeviceInventory((device(ApplianceType.WASHER, "세탁기"),), InventoryStatus.CONNECTED),
        )
        self.assertNotIn("household:air_purifier", [item.item_key for item in result.items])

    def test_air_purifier_not_injected_when_inventory_unavailable(self) -> None:
        result = apply_inventory(
            guide(task("laundry", "빨래")),
            DeviceInventory((device(ApplianceType.AIR_PURIFIER, "공청이"),), InventoryStatus.TIMEOUT),
        )
        self.assertNotIn("household:air_purifier", [item.item_key for item in result.items])

    def test_unknown_type_and_unrelated_title_never_match(self) -> None:
        unknown = normalize_device({"deviceId": "x", "deviceInfo": {"alias": "에어컨", "deviceType": "DEVICE_AIR_CONDITIONER"}})
        self.assertEqual(unknown.device_type, ApplianceType.UNKNOWN)
        result = apply_inventory(guide(task("custom", "청소용품 장보기")), DeviceInventory(
            (device(ApplianceType.ROBOT_VACUUM, "로봇청소기"),), InventoryStatus.CONNECTED,
        ))
        self.assertEqual(result.items[0].payload["owner"], "partner")


class ThinQFailureTest(unittest.IsolatedAsyncioTestCase):
    async def test_device_endpoint_returns_only_normalized_fields(self) -> None:
        client = ThinQClient()
        inventory = DeviceInventory(
            (ThinQDevice("washer-id", "세탁기", ApplianceType.WASHER, "private-model"),),
            InventoryStatus.CONNECTED,
        )
        with (
            patch("app.services.thinq.access.get_settings", return_value=SimpleNamespace(plm_wife_email="wife@example.com")),
            patch.object(client, "get_inventory", return_value=inventory),
        ):
            app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1", email="wife@example.com")
            app.dependency_overrides[get_thinq_client] = lambda: client
            try:
                async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
                    response = await http.get("/api/v1/thinq/devices")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json(), {
                    "status": "connected",
                    "devices": [{"device_id": "washer-id", "name": "세탁기", "device_type": "washer"}],
                })
            finally:
                app.dependency_overrides.clear()

    async def test_other_account_cannot_view_configured_pat_devices(self) -> None:
        client = ThinQClient()
        with (
            patch("app.services.thinq.access.get_settings", return_value=SimpleNamespace(plm_wife_email="wife@example.com")),
            patch.object(client, "get_inventory") as inventory,
        ):
            app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="husband-1", email="husband@example.com")
            app.dependency_overrides[get_thinq_client] = lambda: client
            try:
                async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
                    response = await http.get("/api/v1/thinq/devices")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json(), {"status": "not_configured", "devices": []})
                inventory.assert_not_called()
            finally:
                app.dependency_overrides.clear()

    async def test_timeout_keeps_other_household_items(self) -> None:
        client = ThinQClient()
        with (
            patch("app.services.thinq.access.get_settings", return_value=SimpleNamespace(plm_wife_email="wife@example.com")),
            patch.object(
                client, "get_inventory",
                return_value=DeviceInventory((), InventoryStatus.TIMEOUT),
            ),
        ):
            class GuideService:
                def get_guide(self, *_):
                    return guide(task("laundry", "빨래"), task("groceries", "장보기", "partner"))

            app.dependency_overrides[get_current_user] = lambda: CurrentUser(id="wife-1", email="wife@example.com")
            app.dependency_overrides[get_guide_service] = GuideService
            app.dependency_overrides[get_thinq_client] = lambda: client
            try:
                async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as http:
                    response = await http.get("/api/v1/household/today")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()["appliance_connection_status"], "timeout")
                self.assertEqual([item["payload"]["owner"] for item in response.json()["items"]], ["partner", "partner"])
            finally:
                app.dependency_overrides.clear()

    async def test_invalid_pat_never_appears_in_result_or_log(self) -> None:
        secret = "SECRET_TEST_PAT_DO_NOT_EXPOSE"
        client = ThinQClient()
        stream = io.StringIO()
        handler = logging.StreamHandler(stream)
        logger = logging.getLogger("app.services.thinq.client")
        logger.addHandler(handler)
        try:
            with patch("app.services.thinq.client.ThinQApi") as api:
                api.return_value.async_get_device_list.side_effect = ThinQAPIException("1103", secret, {})
                result = await client._fetch(secret, "KR", "00000000-0000-4000-8000-000000000001")
            self.assertEqual(result.status, InventoryStatus.AUTH_ERROR)
            self.assertNotIn(secret, repr(result) + stream.getvalue())
        finally:
            logger.removeHandler(handler)

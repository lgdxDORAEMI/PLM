"""Deterministic household activity to owned-appliance matching."""

from app.domains.guide.schemas import GuideItem, GuideResponse

from .client import DeviceInventory, InventoryStatus
from .models import ApplianceType


ACTIVITY_APPLIANCES: dict[str, tuple[ApplianceType, ...]] = {
    "laundry": (ApplianceType.WASHER, ApplianceType.DRYER),
    "cleaning": (ApplianceType.ROBOT_VACUUM,),
    "dishes": (ApplianceType.DISHWASHER,),
}
TITLE_ACTIVITIES = {
    "빨래": "laundry",
    "세탁": "laundry",
    "건조": "laundry",
    "바닥 청소": "cleaning",
    "바닥청소": "cleaning",
    "거실 청소": "cleaning",
    "거실청소": "cleaning",
    "청소": "cleaning",
    "설거지": "dishes",
}


def _activity(item: GuideItem) -> str | None:
    """Stored activity code takes priority; title fallback is exact, not substring."""
    if item.item_key.startswith("household:"):
        code = item.item_key.partition(":")[2]
        if code in ACTIVITY_APPLIANCES:
            return code
        if code != "custom":
            return None
    return TITLE_ACTIVITIES.get(item.title.strip())


def apply_inventory(guide: GuideResponse, inventory: DeviceInventory) -> GuideResponse:
    """Promote only tasks supported by actual devices; never mutate stored AI output."""
    items: list[GuideItem] = []
    for item in guide.items:
        payload = dict(item.payload)
        payload.pop("appliances", None)
        activity = _activity(item)
        allowed = ACTIVITY_APPLIANCES.get(activity or "", ())
        matches = [
            device.public_dict()
            for device in inventory.devices
            if device.device_type in allowed
        ] if inventory.status == InventoryStatus.CONNECTED else []
        if matches:
            payload["owner"] = "appliance"
            payload["appliances"] = matches
            items.append(item.model_copy(update={"payload": payload}))
        elif payload.get("owner") == "appliance":
            payload["owner"] = "partner"
            payload["applianceAction"] = "none"
            reason = (
                "가전 연결을 확인할 수 없어 가족과 나눠 주세요."
                if inventory.status != InventoryStatus.CONNECTED
                else "보유한 가전으로 처리할 수 없어 가족과 나눠 주세요."
            )
            payload["reason"] = reason
            items.append(item.model_copy(update={"payload": payload, "description": reason}))
        else:
            items.append(item.model_copy(update={"payload": payload}))
    return guide.model_copy(update={"items": items, "appliance_connection_status": inventory.status.value})

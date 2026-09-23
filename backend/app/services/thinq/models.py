"""Only the device fields needed by the household guide leave this module."""

from dataclasses import dataclass
from enum import StrEnum
from typing import Any


class ApplianceType(StrEnum):
    WASHER = "washer"
    DRYER = "dryer"
    ROBOT_VACUUM = "robot_vacuum"
    DISHWASHER = "dishwasher"
    UNKNOWN = "unknown"


# ThinQ Connect deviceInfo.deviceType values, as published by LG's integrations.
DEVICE_TYPES = {
    "DEVICE_WASHER": ApplianceType.WASHER,
    "DEVICE_WASHTOWER_WASHER": ApplianceType.WASHER,
    "DEVICE_WASHCOMBO_MAIN": ApplianceType.WASHER,
    "DEVICE_DRYER": ApplianceType.DRYER,
    "DEVICE_WASHTOWER_DRYER": ApplianceType.DRYER,
    "DEVICE_ROBOT_CLEANER": ApplianceType.ROBOT_VACUUM,
    "DEVICE_DISH_WASHER": ApplianceType.DISHWASHER,
}
DEFAULT_NAMES = {
    ApplianceType.WASHER: "세탁기",
    ApplianceType.DRYER: "건조기",
    ApplianceType.ROBOT_VACUUM: "로봇청소기",
    ApplianceType.DISHWASHER: "식기세척기",
    ApplianceType.UNKNOWN: "가전",
}


@dataclass(frozen=True)
class ThinQDevice:
    device_id: str
    name: str
    device_type: ApplianceType
    model_name: str | None = None

    def public_dict(self) -> dict[str, str]:
        return {
            "device_id": self.device_id,
            "name": self.name,
            "device_type": self.device_type.value,
        }


def normalize_device(raw: Any) -> ThinQDevice | None:
    """Accept documented deviceId/deviceInfo fields and ignore incomplete rows."""
    if not isinstance(raw, dict):
        return None
    info = raw.get("deviceInfo")
    if not isinstance(info, dict):
        return None
    device_id = raw.get("deviceId")
    raw_type = info.get("deviceType")
    if not isinstance(device_id, str) or not device_id or not isinstance(raw_type, str):
        return None
    appliance_type = DEVICE_TYPES.get(raw_type, ApplianceType.UNKNOWN)
    alias = info.get("alias")
    model = info.get("modelName")
    name = alias.strip() if isinstance(alias, str) and alias.strip() else DEFAULT_NAMES[appliance_type]
    return ThinQDevice(
        device_id=device_id,
        name=name,
        device_type=appliance_type,
        model_name=model if isinstance(model, str) else None,
    )

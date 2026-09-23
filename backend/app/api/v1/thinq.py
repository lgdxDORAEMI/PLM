"""Authenticated, minimal ThinQ device inventory and control endpoints."""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.security import CurrentUser, get_current_user
from app.services.thinq.access import inventory_for_user
from app.services.thinq.client import ControlStatus, InventoryStatus, ThinQClient, get_thinq_client

router = APIRouter(prefix="/thinq", tags=["thinq"])

_WIND_STRENGTH = {"low": "LOW", "mid": "MID", "high": "HIGH", "auto": "AUTO"}
# ControlStatus별로 다른 문구를 줘야 프론트/네트워크 탭만 보고도 원인을 구분할 수 있다.
# SDK 예외 원문은 절대 넣지 않는다(PAT 등 요청 정보가 섞여 나올 수 있어 client.py가 이미 거른다).
_CONTROL_ERROR_DETAIL = {
    ControlStatus.NOT_CONFIGURED: "ThinQ 연결 설정이 필요합니다.",
    ControlStatus.AUTH_ERROR: "ThinQ 인증에 실패했습니다. PAT 권한(제어 스코프)을 확인해 주세요.",
    ControlStatus.TIMEOUT: "ThinQ 응답이 지연되었습니다. 잠시 후 다시 시도해 주세요.",
    ControlStatus.ERROR: "가전 제어에 실패했습니다. 기기가 온라인인지 확인해 주세요.",
}


class DevicesResponse(BaseModel):
    status: str
    devices: list[dict[str, str]]


class ControlRequest(BaseModel):
    power: Literal["on", "off"] | None = None
    wind_strength: Literal["low", "mid", "high", "auto"] | None = None


class ControlResponse(BaseModel):
    status: str


@router.get("/devices", response_model=DevicesResponse)
async def get_devices(
    user: Annotated[CurrentUser, Depends(get_current_user)],
    client: Annotated[ThinQClient, Depends(get_thinq_client)],
) -> DevicesResponse:
    """Expose normalized inventory only; the server PAT stays private."""
    inventory = await inventory_for_user(user, client)
    return DevicesResponse(
        status=inventory.status.value,
        devices=[device.public_dict() for device in inventory.devices],
    )


@router.post("/devices/{device_id}/control", response_model=ControlResponse)
async def control_device(
    device_id: str,
    body: ControlRequest,
    user: Annotated[CurrentUser, Depends(get_current_user)],
    client: Annotated[ThinQClient, Depends(get_thinq_client)],
) -> ControlResponse:
    """Household guide (power only) and sleep guide (power + wind_strength) share this endpoint."""
    if body.power is None and body.wind_strength is None:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "제어할 값이 없습니다.")
    inventory = await inventory_for_user(user, client)
    if inventory.status != InventoryStatus.CONNECTED or not any(
        device.device_id == device_id for device in inventory.devices
    ):
        raise HTTPException(status.HTTP_404_NOT_FOUND, "등록된 가전을 찾을 수 없습니다.")
    payload: dict[str, dict[str, str]] = {}
    if body.power is not None:
        payload["operation"] = {"airPurifierOperationMode": "POWER_ON" if body.power == "on" else "POWER_OFF"}
    if body.wind_strength is not None:
        payload["airFlow"] = {"windStrength": _WIND_STRENGTH[body.wind_strength]}
    result = await client.control(device_id, payload)
    if result != ControlStatus.OK:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, _CONTROL_ERROR_DETAIL[result])
    return ControlResponse(status="ok")

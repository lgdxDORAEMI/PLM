"""Authenticated, minimal ThinQ device inventory endpoint."""

from typing import Annotated

from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.security import CurrentUser, get_current_user
from app.services.thinq.access import inventory_for_user
from app.services.thinq.client import ThinQClient, get_thinq_client

router = APIRouter(prefix="/thinq", tags=["thinq"])


class DevicesResponse(BaseModel):
    status: str
    devices: list[dict[str, str]]


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

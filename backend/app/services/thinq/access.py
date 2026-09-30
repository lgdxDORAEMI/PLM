"""Bind the server's single ThinQ PAT to the configured wife account."""

from app.core.config import get_settings
from app.core.security import CurrentUser

from .client import DeviceInventory, InventoryStatus, ThinQClient


async def inventory_for_user(user: CurrentUser, client: ThinQClient) -> DeviceInventory:
    """Do not expose one account's registered devices to another login."""
    owner_email = get_settings().plm_wife_email.strip().casefold()
    user_email = (user.email or "").strip().casefold()
    if not owner_email:
        return DeviceInventory((), InventoryStatus.NOT_CONFIGURED)
    if user_email != owner_email:
        return DeviceInventory((), InventoryStatus.ACCOUNT_MISMATCH)
    return await client.get_inventory()

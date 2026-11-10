"""CRUD endpoints for item management."""

from fastapi import APIRouter, HTTPException, status

from src.models.item import Item, ItemCreate, ItemUpdate
from src.services.item_service import item_service

router = APIRouter(prefix="/api/v1/items", tags=["items"])


@router.get("", response_model=list[Item])
async def list_items() -> list[Item]:
    """List all items."""
    return await item_service.list_items()


@router.post("", response_model=Item, status_code=status.HTTP_201_CREATED)
async def create_item(data: ItemCreate) -> Item:
    """Create a new item."""
    return await item_service.create_item(data)


@router.get("/{item_id}", response_model=Item)
async def get_item(item_id: str) -> Item:
    """Get a single item by ID."""
    item = await item_service.get_item(item_id)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@router.patch("/{item_id}", response_model=Item)
async def update_item(item_id: str, data: ItemUpdate) -> Item:
    """Update an existing item."""
    item = await item_service.update_item(item_id, data)
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")
    return item


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_item(item_id: str) -> None:
    """Delete an item by ID."""
    deleted = await item_service.delete_item(item_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Item not found")

"""In-memory item service with OpenTelemetry spans."""

from datetime import datetime, timezone
from uuid import uuid4

from opentelemetry import trace

from src.models.item import Item, ItemCreate, ItemUpdate

tracer = trace.get_tracer(__name__)


class ItemService:
    """Simple in-memory item store with OpenTelemetry spans."""

    def __init__(self) -> None:
        self._items: dict[str, Item] = {}

    async def list_items(self) -> list[Item]:
        """Return all items."""
        with tracer.start_as_current_span("item_service.list_items"):
            return list(self._items.values())

    async def get_item(self, item_id: str) -> Item | None:
        """Get a single item by ID."""
        with tracer.start_as_current_span("item_service.get_item") as span:
            span.set_attribute("item.id", item_id)
            return self._items.get(item_id)

    async def create_item(self, data: ItemCreate) -> Item:
        """Create a new item."""
        with tracer.start_as_current_span("item_service.create_item") as span:
            item = Item(
                id=str(uuid4()),
                name=data.name,
                description=data.description or "",
                price=data.price,
                created_at=datetime.now(timezone.utc),
                updated_at=datetime.now(timezone.utc),
            )
            self._items[item.id] = item
            span.set_attribute("item.id", item.id)
            span.set_attribute("item.name", item.name)
            return item

    async def update_item(self, item_id: str, data: ItemUpdate) -> Item | None:
        """Update an existing item."""
        with tracer.start_as_current_span("item_service.update_item") as span:
            span.set_attribute("item.id", item_id)
            existing = self._items.get(item_id)
            if not existing:
                return None
            update_data = data.model_dump(exclude_unset=True)
            updated = existing.model_copy(
                update={**update_data, "updated_at": datetime.now(timezone.utc)},
            )
            self._items[item_id] = updated
            return updated

    async def delete_item(self, item_id: str) -> bool:
        """Delete an item by ID."""
        with tracer.start_as_current_span("item_service.delete_item") as span:
            span.set_attribute("item.id", item_id)
            if item_id in self._items:
                del self._items[item_id]
                return True
            return False


item_service = ItemService()

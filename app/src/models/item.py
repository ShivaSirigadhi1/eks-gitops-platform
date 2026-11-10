"""Item data models."""

from datetime import datetime
from uuid import uuid4

from pydantic import BaseModel, Field


class ItemCreate(BaseModel):
    """Schema for creating a new item."""

    name: str = Field(..., min_length=1, max_length=100)
    description: str | None = None
    price: float = Field(..., ge=0)


class ItemUpdate(BaseModel):
    """Schema for updating an existing item."""

    name: str | None = None
    description: str | None = None
    price: float | None = None


class Item(BaseModel):
    """Complete item schema with system-generated fields."""

    id: str = Field(default_factory=lambda: str(uuid4()))
    name: str
    description: str = ""
    price: float
    created_at: datetime
    updated_at: datetime

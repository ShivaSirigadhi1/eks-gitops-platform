"""Tests for item CRUD endpoints."""

from fastapi import status


def test_root(client):
    """Test the root endpoint returns service info."""
    response = client.get("/")
    assert response.status_code == status.HTTP_200_OK
    data = response.json()
    assert data["service"] == "blueprint-app"


def test_list_items_empty(client):
    """Test listing items when none exist."""
    response = client.get("/api/v1/items")
    assert response.status_code == status.HTTP_200_OK
    assert response.json() == []


def test_create_and_get_item(client):
    """Test creating an item and retrieving it."""
    create_response = client.post(
        "/api/v1/items",
        json={"name": "Test Item", "description": "A test item", "price": 10.0},
    )
    assert create_response.status_code == status.HTTP_201_CREATED
    item = create_response.json()
    assert item["name"] == "Test Item"
    assert item["price"] == 10.0
    item_id = item["id"]

    get_response = client.get(f"/api/v1/items/{item_id}")
    assert get_response.status_code == status.HTTP_200_OK
    assert get_response.json()["name"] == "Test Item"


def test_get_nonexistent_item(client):
    """Test getting a non-existent item returns 404."""
    response = client.get("/api/v1/items/nonexistent")
    assert response.status_code == status.HTTP_404_NOT_FOUND


def test_update_item(client):
    """Test updating an existing item."""
    create_response = client.post(
        "/api/v1/items",
        json={"name": "Original", "price": 5.0},
    )
    item_id = create_response.json()["id"]

    update_response = client.patch(
        f"/api/v1/items/{item_id}",
        json={"name": "Updated", "price": 15.0},
    )
    assert update_response.status_code == status.HTTP_200_OK
    assert update_response.json()["name"] == "Updated"
    assert update_response.json()["price"] == 15.0


def test_delete_item(client):
    """Test deleting an item."""
    create_response = client.post(
        "/api/v1/items",
        json={"name": "To Delete", "price": 1.0},
    )
    item_id = create_response.json()["id"]

    delete_response = client.delete(f"/api/v1/items/{item_id}")
    assert delete_response.status_code == status.HTTP_204_NO_CONTENT

    get_response = client.get(f"/api/v1/items/{item_id}")
    assert get_response.status_code == status.HTTP_404_NOT_FOUND

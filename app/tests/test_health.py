"""Tests for health check endpoints."""

from fastapi import status


def test_liveness(client):
    """Test the liveness probe returns 200."""
    response = client.get("/healthz")
    assert response.status_code == status.HTTP_200_OK
    assert response.text == "ok"


def test_readiness(client):
    """Test the readiness probe returns 200."""
    response = client.get("/readyz")
    assert response.status_code == status.HTTP_200_OK
    assert response.text == "ok"

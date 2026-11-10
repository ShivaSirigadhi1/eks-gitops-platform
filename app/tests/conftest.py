"""Pytest configuration and fixtures."""

import os

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("LOG_LEVEL", "debug")
os.environ.setdefault("OTEL_TRACES_SAMPLER_ARG", "1.0")

from src.main import create_app


@pytest.fixture
def client():
    """Create a TestClient for the FastAPI app."""
    app = create_app()
    with TestClient(app) as test_client:
        yield test_client

"""Health check endpoints for Kubernetes probes."""

from fastapi import APIRouter, Response, status

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def liveness() -> Response:
    """Liveness probe — indicates the app is running."""
    return Response(status_code=status.HTTP_200_OK, content="ok")


@router.get("/readyz")
async def readiness() -> Response:
    """Readiness probe — indicates the app is ready to serve traffic."""
    return Response(status_code=status.HTTP_200_OK, content="ok")

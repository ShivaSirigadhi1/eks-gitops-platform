"""FastAPI application entry point with OTel, Prometheus, and structured logging."""

import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

from src.routers import health, items
from src.telemetry.logging import configure_logging, get_logger
from src.telemetry.metrics import setup_metrics
from src.telemetry.tracing import configure_tracing

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan — startup and shutdown."""
    service_name = os.getenv("SERVICE_NAME", "blueprint-app")
    logger.info("starting up", service=service_name)

    tracer = configure_tracing(service_name)
    app.state.tracer = tracer

    FastAPIInstrumentor.instrument_app(app)
    RequestsInstrumentor().instrument()

    setup_metrics(app)

    logger.info(
        "startup complete",
        service=service_name,
        environment=os.getenv("ENVIRONMENT", "development"),
    )
    yield

    logger.info("shutting down")


def create_app() -> FastAPI:
    """Create and configure the FastAPI application."""
    configure_logging()

    app = FastAPI(
        title="Pipeline Blueprint App",
        description="Sample FastAPI application demonstrating CI/CD, SecOps, and Observability",
        version=os.getenv("APP_VERSION", "0.1.0"),
        lifespan=lifespan,
        docs_url="/docs" if os.getenv("ENABLE_SWAGGER", "false").lower() == "true" else None,
        redoc_url=None,
    )

    app.include_router(health.router)
    app.include_router(items.router)

    @app.get("/")
    async def root():
        return {
            "service": "blueprint-app",
            "version": os.getenv("APP_VERSION", "0.1.0"),
            "environment": os.getenv("ENVIRONMENT", "development"),
        }

    @app.get("/api/v1/version")
    async def version():
        return {
            "version": os.getenv("APP_VERSION", "0.1.0"),
            "commit": os.getenv("COMMIT_SHA", "unknown"),
            "build_time": os.getenv("BUILD_TIME", "unknown"),
        }

    return app


app = create_app()

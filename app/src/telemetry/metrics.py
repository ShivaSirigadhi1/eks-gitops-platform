"""Prometheus metrics configuration."""

from prometheus_client import Counter, Gauge, Histogram
from prometheus_fastapi_instrumentator import Instrumentator

HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "endpoint", "status"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

ACTIVE_REQUESTS = Gauge(
    "active_requests",
    "Current number of active HTTP requests",
)


def setup_metrics(app) -> Instrumentator:
    """Configure Prometheus metrics instrumentation for a FastAPI app."""
    instrumentator = Instrumentator(
        should_group_status_codes=True,
        should_ignore_untemplated=True,
        should_instrument_requests_inprogress=True,
        excluded_handlers=["/metrics", "/healthz", "/readyz"],
        inprogress_name="http_requests_active",
        inprogress_labels=True,
    )

    instrumentator.instrument(app).expose(
        app,
        endpoint="/metrics",
        include_in_schema=False,
    )

    return instrumentator

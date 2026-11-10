"""OpenTelemetry distributed tracing configuration."""

import os

from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.trace.sampling import ParentBasedTraceIdRatio


def configure_tracing(service_name: str = "blueprint-app") -> trace.Tracer:
    """Configure OpenTelemetry tracing with OTLP exporter."""
    otel_endpoint = os.getenv(
        "OTEL_EXPORTER_OTLP_ENDPOINT",
        "http://localhost:4318",
    )
    service_version = os.getenv("APP_VERSION", "0.1.0")
    environment = os.getenv("ENVIRONMENT", "development")

    resource = Resource.create(
        attributes={
            "service.name": service_name,
            "service.version": service_version,
            "deployment.environment": environment,
        },
    )

    sampling_ratio = float(os.getenv("OTEL_TRACES_SAMPLER_ARG", "0.2"))
    sampler = ParentBasedTraceIdRatio(sampling_ratio)

    provider = TracerProvider(resource=resource, sampler=sampler)

    otlp_exporter = OTLPSpanExporter(
        endpoint=f"{otel_endpoint}/v1/traces",
        timeout=5,
    )
    span_processor = BatchSpanProcessor(otlp_exporter)
    provider.add_span_processor(span_processor)

    trace.set_tracer_provider(provider)

    return trace.get_tracer(service_name, service_version)

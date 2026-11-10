# Stage 1: Builder
FROM python:3.12-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir pip --upgrade

COPY requirements.txt pyproject.toml ./
RUN pip install --no-cache-dir --user -r requirements.txt

COPY src/ ./src/

RUN pip install --no-cache-dir --user ruff mypy \
    && python -m ruff check src/ \
    && python -m mypy src/ --ignore-missing-imports

# Stage 2: Runtime
FROM python:3.12-slim

RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid 1000 --shell /bin/bash --create-home appuser \
    && mkdir -p /app \
    && chown -R appuser:appuser /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /root/.local /root/.local
COPY --from=builder /build/src/ ./src/

ENV PATH=/root/.local/bin:$PATH \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1

ENV SERVER_PORT=8080 \
    METRICS_PORT=9090 \
    LOG_LEVEL=info \
    LOG_FORMAT=json

USER appuser

EXPOSE 8080 9090

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -sf http://localhost:${SERVER_PORT}/healthz || exit 1

LABEL org.opencontainers.image.source="https://github.com/your-org/eks-gitops-platform" \
      org.opencontainers.image.revision="${COMMIT_SHA}" \
      org.opencontainers.image.created="${BUILD_TIME}" \
      org.opencontainers.image.title="Pipeline Blueprint App" \
      org.opencontainers.image.description="Sample FastAPI application with OTel instrumentation" \
      org.opencontainers.image.version="${APP_VERSION}"

CMD ["sh", "-c", "uvicorn src.main:app --host 0.0.0.0 --port ${SERVER_PORT} --workers 4 --log-level ${LOG_LEVEL}"]

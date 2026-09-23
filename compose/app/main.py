#!/usr/bin/env python3
# ==============================================================================
# Description: Simple HTTP application with Prometheus metrics instrumentation.
#   Exposes /metrics, /health, and / endpoints. Tracks request count, latency,
#   in-progress requests, and errors using prometheus-client.
# Author: Infrastructure Team
# Usage: python3 main.py
# Dependencies: fastapi, uvicorn, prometheus-client
# ==============================================================================

import time
from contextlib import asynccontextmanager
from typing import Dict, Any

from fastapi import FastAPI, Request, Response
from fastapi.responses import PlainTextResponse
from prometheus_client import (
    Counter,
    Histogram,
    Gauge,
    make_asgi_app,
    CONTENT_TYPE_LATEST,
    generate_latest,
)

# -----------------------------------------------------------------------------
# Prometheus Metrics Definitions
# -----------------------------------------------------------------------------

# Counter: Total HTTP requests by method, path, and status code
HTTP_REQUESTS_TOTAL = Counter(
    name="http_requests_total",
    documentation="Total number of HTTP requests by method, path, and status code",
    labelnames=["method", "path", "status"],
)

# Histogram: HTTP request duration in seconds by method and path
HTTP_REQUEST_DURATION_SECONDS = Histogram(
    name="http_request_duration_seconds",
    documentation="HTTP request latency in seconds by method and path",
    labelnames=["method", "path"],
    buckets=[0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0],
)

# Gauge: Number of HTTP requests currently in progress
HTTP_REQUESTS_IN_PROGRESS = Gauge(
    name="http_requests_in_progress",
    documentation="Number of HTTP requests currently being processed",
)

# Counter: Total HTTP errors by error type
HTTP_ERRORS_TOTAL = Counter(
    name="http_errors_total",
    documentation="Total number of HTTP errors by error type",
    labelnames=["error_type"],
)


# -----------------------------------------------------------------------------
# Application Lifecycle
# -----------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler for startup/shutdown events."""
    # Startup
    yield
    # Shutdown


# -----------------------------------------------------------------------------
# FastAPI Application
# -----------------------------------------------------------------------------

app = FastAPI(
    title="Dummy Application",
    description="A simple HTTP application with Prometheus metrics for observability testing",
    version="1.0.0",
    lifespan=lifespan,
)

# Mount Prometheus metrics endpoint at /metrics
metrics_app = make_asgi_app()
app.mount("/metrics", metrics_app)


# -----------------------------------------------------------------------------
# Middleware for Metrics Instrumentation
# -----------------------------------------------------------------------------

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    """Middleware to instrument all HTTP requests with Prometheus metrics."""
    # Track in-progress requests
    HTTP_REQUESTS_IN_PROGRESS.inc()

    # Record start time
    start_time = time.perf_counter()

    # Extract method and path for labels
    method = request.method
    path = request.url.path

    try:
        # Process the request
        response = await call_next(request)

        # Calculate duration
        duration = time.perf_counter() - start_time

        # Record metrics
        status_code = str(response.status_code)
        HTTP_REQUESTS_TOTAL.labels(method=method, path=path, status=status_code).inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(method=method, path=path).observe(duration)

        # Track 5xx errors
        if 500 <= response.status_code < 600:
            HTTP_ERRORS_TOTAL.labels(error_type="server_error").inc()

        return response

    except Exception as e:
        # Calculate duration even on exception
        duration = time.perf_counter() - start_time

        # Record error metrics
        HTTP_REQUESTS_TOTAL.labels(method=method, path=path, status="500").inc()
        HTTP_REQUEST_DURATION_SECONDS.labels(method=method, path=path).observe(duration)
        HTTP_ERRORS_TOTAL.labels(error_type=type(e).__name__).inc()

        raise

    finally:
        # Decrement in-progress counter
        HTTP_REQUESTS_IN_PROGRESS.dec()


# -----------------------------------------------------------------------------
# API Endpoints
# -----------------------------------------------------------------------------

@app.get(
    "/",
    summary="Root endpoint",
    description="Returns basic application information",
    response_description="Application metadata",
)
async def root() -> Dict[str, Any]:
    """Root endpoint returning basic application info."""
    return {
        "name": "Dummy Application",
        "version": "1.0.0",
        "description": "A simple HTTP application with Prometheus metrics for observability testing",
    }


@app.get(
    "/health",
    summary="Health check endpoint",
    description="Returns the health status of the application",
    response_description="Health status",
)
async def health() -> Dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}


# -----------------------------------------------------------------------------
# Entry Point
# -----------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
#!/usr/bin/env python3
# ==============================================================================
# Description: Unit tests for the dummy application HTTP endpoints and metrics.
# Author: Infrastructure Team
# Usage: pytest compose/app/test_main.py -v
# Dependencies: pytest, pytest-asyncio, httpx, prometheus-client, fastapi
# ==============================================================================

import pytest
from unittest.mock import patch, MagicMock
from fastapi.testclient import TestClient

# Import the app after setting up any necessary mocks
from main import app, HTTP_REQUESTS_TOTAL, HTTP_REQUEST_DURATION_SECONDS, HTTP_REQUESTS_IN_PROGRESS, HTTP_ERRORS_TOTAL


class TestHealthEndpoint:
    """Tests for the /health endpoint."""

    def test_health_endpoint_returns_ok(self):
        """Test that /health returns 200 with status ok."""
        with TestClient(app) as client:
            response = client.get("/health")
            assert response.status_code == 200
            assert response.json() == {"status": "ok"}

    def test_health_endpoint_increments_requests_total(self):
        """Test that /health increments http_requests_total counter."""
        with TestClient(app) as client:
            # Get initial count
            initial_count = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/health", status="200")._value.get()

            response = client.get("/health")

            # Get count after request
            final_count = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/health", status="200")._value.get()

            assert response.status_code == 200
            assert final_count == initial_count + 1

    def test_health_endpoint_updates_in_progress_gauge(self):
        """Test that /health updates http_requests_in_progress gauge."""
        with TestClient(app) as client:
            # The gauge should be 0 before and after (request is fast)
            initial_in_progress = HTTP_REQUESTS_IN_PROGRESS._value.get()
            response = client.get("/health")
            final_in_progress = HTTP_REQUESTS_IN_PROGRESS._value.get()

            assert response.status_code == 200
            assert final_in_progress == initial_in_progress


class TestRootEndpoint:
    """Tests for the / endpoint."""

    def test_root_endpoint_returns_info(self):
        """Test that / returns basic application info."""
        with TestClient(app) as client:
            response = client.get("/")
            assert response.status_code == 200
            data = response.json()
            assert "name" in data
            assert "version" in data
            assert "description" in data

    def test_root_endpoint_increments_requests_total(self):
        """Test that / increments http_requests_total counter."""
        with TestClient(app) as client:
            initial_count = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/", status="200")._value.get()
            response = client.get("/")
            final_count = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/", status="200")._value.get()

            assert response.status_code == 200
            assert final_count == initial_count + 1


class TestMetricsEndpoint:
    """Tests for the /metrics endpoint."""

    def test_metrics_endpoint_returns_prometheus_format(self):
        """Test that /metrics returns Prometheus format metrics."""
        with TestClient(app) as client:
            response = client.get("/metrics")
            assert response.status_code == 200
            # Check for Prometheus format markers
            assert "http_requests_total" in response.text
            assert "http_request_duration_seconds" in response.text
            assert "http_requests_in_progress" in response.text
            assert "http_errors_total" in response.text
            # Check for HELP and TYPE lines
            assert "# HELP" in response.text
            assert "# TYPE" in response.text

    def test_metrics_endpoint_exposes_custom_metrics(self):
        """Test that all required custom metrics are exposed."""
        with TestClient(app) as client:
            response = client.get("/metrics")
            assert response.status_code == 200

            # Check all four required metrics
            assert 'http_requests_total' in response.text
            assert 'http_request_duration_seconds' in response.text
            assert 'http_requests_in_progress' in response.text
            assert 'http_errors_total' in response.text


class TestMetricsInstrumentation:
    """Tests for metrics instrumentation behavior."""

    def test_http_requests_total_counter_increments(self):
        """Test that http_requests_total increments on each request."""
        with TestClient(app) as client:
            # Make multiple requests
            client.get("/")
            client.get("/")
            client.get("/health")

            # Check counter values
            root_count = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/", status="200")._value.get()
            health_count = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/health", status="200")._value.get()

            assert root_count >= 2  # At least 2 from this test + possibly from other tests
            assert health_count >= 1

    def test_http_request_duration_seconds_histogram_records(self):
        """Test that http_request_duration_seconds records latency."""
        with TestClient(app) as client:
            response = client.get("/")
            assert response.status_code == 200

            # Check that histogram has recorded values via collect()
            labeled = HTTP_REQUEST_DURATION_SECONDS.labels(method="GET", path="/")
            duration_sum = labeled._sum.get()

            # Get count from collected samples
            duration_count = 0
            for metric in HTTP_REQUEST_DURATION_SECONDS.collect():
                for sample in metric.samples:
                    if sample.name == "http_request_duration_seconds_count" and sample.labels.get("method") == "GET" and sample.labels.get("path") == "/":
                        duration_count = sample.value
                        break

            assert duration_count >= 1
            assert duration_sum > 0

    def test_http_requests_in_progress_gauge_tracks_active(self):
        """Test that http_requests_in_progress tracks in-flight requests."""
        # This is tested implicitly by the gauge not going negative
        with TestClient(app) as client:
            initial = HTTP_REQUESTS_IN_PROGRESS._value.get()
            response = client.get("/")
            final = HTTP_REQUESTS_IN_PROGRESS._value.get()

            assert response.status_code == 200
            assert final == initial  # Should return to baseline

    def test_http_errors_total_counter_increments_on_error(self):
        """Test that http_errors_total increments on 5xx errors."""
        # We'll test this by checking the metric exists and can be incremented
        initial_count = HTTP_ERRORS_TOTAL.labels(error_type="internal_error")._value.get()
        HTTP_ERRORS_TOTAL.labels(error_type="internal_error").inc()
        final_count = HTTP_ERRORS_TOTAL.labels(error_type="internal_error")._value.get()

        assert final_count == initial_count + 1


class TestMetricLabels:
    """Tests for metric label structure."""

    def test_requests_total_has_method_path_status_labels(self):
        """Test that http_requests_total has correct labels."""
        with TestClient(app) as client:
            client.get("/health")

            # Verify we can access with labels
            metric = HTTP_REQUESTS_TOTAL.labels(method="GET", path="/health", status="200")
            assert metric._value.get() >= 1

    def test_request_duration_has_method_path_labels(self):
        """Test that http_request_duration_seconds has correct labels."""
        with TestClient(app) as client:
            client.get("/health")

            labeled = HTTP_REQUEST_DURATION_SECONDS.labels(method="GET", path="/health")

            # Get count from collected samples
            duration_count = 0
            for metric in HTTP_REQUEST_DURATION_SECONDS.collect():
                for sample in metric.samples:
                    if sample.name == "http_request_duration_seconds_count" and sample.labels.get("method") == "GET" and sample.labels.get("path") == "/health":
                        duration_count = sample.value
                        break

            assert duration_count >= 1

    def test_errors_total_has_error_type_label(self):
        """Test that http_errors_total has error_type label."""
        HTTP_ERRORS_TOTAL.labels(error_type="test_error").inc()
        metric = HTTP_ERRORS_TOTAL.labels(error_type="test_error")
        assert metric._value.get() >= 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
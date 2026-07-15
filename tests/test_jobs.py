"""Tests for the jobs API."""

from uuid import uuid4

from fastapi.testclient import TestClient


def test_create_and_read_job(client: TestClient) -> None:
    create_response = client.post(
        "/jobs",
        json={
            "payload": {
                "task": "generate-report",
                "customer_id": 42,
            }
        },
    )

    assert create_response.status_code == 201

    created_job = create_response.json()

    assert created_job["status"] == "queued"
    assert created_job["payload"]["customer_id"] == 42
    assert create_response.headers["location"] == f"/jobs/{created_job['id']}"

    read_response = client.get(f"/jobs/{created_job['id']}")

    assert read_response.status_code == 200
    assert read_response.json() == created_job


def test_list_jobs_starts_empty(client: TestClient) -> None:
    response = client.get("/jobs")

    assert response.status_code == 200
    assert response.json() == []


def test_list_jobs_contains_created_job(client: TestClient) -> None:
    create_response = client.post(
        "/jobs",
        json={"payload": {"task": "send-email"}},
    )

    created_job = create_response.json()
    list_response = client.get("/jobs")

    assert list_response.status_code == 200
    assert list_response.json() == [created_job]


def test_missing_job_returns_404(client: TestClient) -> None:
    response = client.get(f"/jobs/{uuid4()}")

    assert response.status_code == 404
    assert response.json() == {"detail": "Job not found"}


def test_invalid_job_id_returns_422(client: TestClient) -> None:
    response = client.get("/jobs/not-a-uuid")

    assert response.status_code == 422


def test_unknown_request_field_returns_422(client: TestClient) -> None:
    response = client.post(
        "/jobs",
        json={
            "payload": {},
            "unexpected_field": True,
        },
    )

    assert response.status_code == 422

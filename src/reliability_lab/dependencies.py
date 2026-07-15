"""FastAPI dependency providers."""

from typing import cast

from fastapi import Request

from reliability_lab.store import JobStore


def get_job_store(request: Request) -> JobStore:
    """Return the application-scoped job store."""

    return cast(JobStore, request.app.state.job_store)

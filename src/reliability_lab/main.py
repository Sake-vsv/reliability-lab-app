"""FastAPI application entry point."""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import Annotated
from uuid import UUID

from fastapi import Depends, FastAPI, HTTPException, Response, status

from reliability_lab.config import get_settings
from reliability_lab.dependencies import get_job_store
from reliability_lab.schemas import (
    HealthResponse,
    JobCreate,
    JobRead,
    VersionResponse,
)
from reliability_lab.store import JobStore

JobStoreDependency = Annotated[JobStore, Depends(get_job_store)]


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Create and release process-level resources."""

    app.state.job_store = JobStore()

    try:
        yield
    finally:
        del app.state.job_store


def create_app() -> FastAPI:
    """Build a configured FastAPI application."""

    settings = get_settings()

    app = FastAPI(
        title=settings.service_name,
        version=settings.service_version,
        description="A learning service for end-to-end DevOps and SRE practices.",
        lifespan=lifespan,
    )

    @app.get(
        "/health/live",
        response_model=HealthResponse,
        tags=["health"],
    )
    def liveness() -> HealthResponse:
        """Confirm that the application process can answer requests."""

        return HealthResponse(status="alive")

    @app.get(
        "/health/ready",
        response_model=HealthResponse,
        tags=["health"],
    )
    def readiness() -> HealthResponse:
        """Confirm that the application is ready to receive traffic."""

        return HealthResponse(status="ready")

    @app.get(
        "/version",
        response_model=VersionResponse,
        tags=["system"],
    )
    def version() -> VersionResponse:
        """Expose the running service version and environment."""

        return VersionResponse(
            service=settings.service_name,
            version=settings.service_version,
            environment=settings.environment,
        )

    @app.post(
        "/jobs",
        response_model=JobRead,
        status_code=status.HTTP_201_CREATED,
        tags=["jobs"],
    )
    def create_job(
        request: JobCreate,
        response: Response,
        store: JobStoreDependency,
    ) -> JobRead:
        """Create a queued job."""

        job = store.create(request)
        response.headers["Location"] = f"/jobs/{job.id}"
        return job

    @app.get(
        "/jobs",
        response_model=list[JobRead],
        tags=["jobs"],
    )
    def list_jobs(
        store: JobStoreDependency,
    ) -> list[JobRead]:
        """List all jobs known to this process."""

        return store.list_all()

    @app.get(
        "/jobs/{job_id}",
        response_model=JobRead,
        tags=["jobs"],
    )
    def get_job(
        job_id: UUID,
        store: JobStoreDependency,
    ) -> JobRead:
        """Return one job or a 404 response."""

        job = store.get(job_id)

        if job is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Job not found",
            )

        return job

    return app


app = create_app()

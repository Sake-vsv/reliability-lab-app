"""Temporary in-memory storage used before PostgreSQL is introduced."""

from datetime import UTC, datetime
from uuid import UUID, uuid4

from reliability_lab.schemas import JobCreate, JobRead, JobStatus


class JobStore:
    """Store jobs in one Python process.

    This implementation is intentionally temporary. It is not shared between
    processes and loses all data when the process stops.
    """

    def __init__(self) -> None:
        self._jobs: dict[UUID, JobRead] = {}

    def create(self, request: JobCreate) -> JobRead:
        """Create and retain a queued job."""

        job = JobRead(
            id=uuid4(),
            status=JobStatus.QUEUED,
            payload=request.payload.copy(),
            created_at=datetime.now(UTC),
        )
        self._jobs[job.id] = job
        return job

    def get(self, job_id: UUID) -> JobRead | None:
        """Return a job by identifier, or None when it does not exist."""

        return self._jobs.get(job_id)

    def list_all(self) -> list[JobRead]:
        """Return jobs ordered by creation time."""

        return sorted(
            self._jobs.values(),
            key=lambda job: job.created_at,
        )

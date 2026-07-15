"""API request and response models."""

from datetime import datetime
from enum import StrEnum
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class JobStatus(StrEnum):
    """States through which a job can move."""

    QUEUED = "queued"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"


class JobCreate(BaseModel):
    """Payload accepted when a client creates a job."""

    model_config = ConfigDict(extra="forbid")

    payload: dict[str, Any] = Field(
        default_factory=dict,
        description="JSON data required by the job",
    )


class JobRead(BaseModel):
    """Public representation of a job."""

    id: UUID
    status: JobStatus
    payload: dict[str, Any]
    created_at: datetime


class HealthResponse(BaseModel):
    """Response returned by health endpoints."""

    status: Literal["alive", "ready"]


class VersionResponse(BaseModel):
    """Build and runtime identity of the service."""

    service: str
    version: str
    environment: str

"""Shared pytest fixtures."""

from collections.abc import Iterator

import pytest
from fastapi.testclient import TestClient

from reliability_lab.main import create_app


@pytest.fixture
def client() -> Iterator[TestClient]:
    """Provide a fresh application and store for every test."""

    with TestClient(create_app()) as test_client:
        yield test_client

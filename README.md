# Reliability Job Service

A production-style learning application used to demonstrate end-to-end DevOps
and Site Reliability Engineering practices.

## Current architecture

```text
HTTP client -> Uvicorn -> FastAPI -> in-memory JobStore
```

The in-memory store is temporary. PostgreSQL and Redis will be introduced in a
later milestone.

## Requirements

- Ubuntu 24.04
- Python 3.12
- GNU Make

## Local setup

```bash
python3 -m venv .venv
source .venv/bin/activate
make bootstrap
make lock
make sync
make quality
```

## Run the service

```bash
make run
```

The API is available at:

```text
http://127.0.0.1:8000
```

Interactive API documentation:

```text
http://127.0.0.1:8000/docs
```

OpenAPI document:

```text
http://127.0.0.1:8000/openapi.json
```

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health/live` | Process liveness |
| GET | `/health/ready` | Traffic readiness |
| GET | `/version` | Service version and environment |
| POST | `/jobs` | Create a queued job |
| GET | `/jobs` | List jobs |
| GET | `/jobs/{job_id}` | Retrieve one job |

## Quality checks

```bash
make quality
```

This runs formatting checks, linting, static type checking, tests and code
coverage validation.

## Current limitation

Jobs are stored in one application process and disappear when the process
restarts. This is intentional for the first milestone.

## License

MIT

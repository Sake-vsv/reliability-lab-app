.RECIPEPREFIX := >

PYTHON := python
PIP := $(PYTHON) -m pip
PIPTOOLS := $(PYTHON) -m piptools

PIP_VERSION := 26.0.1
PIP_TOOLS_VERSION := 7.5.3

.PHONY: check-venv preflight bootstrap lock lock-upgrade sync doctor run test lint format format-check type-check quality clean

check-venv:
>$(PYTHON) -c 'import sys; assert sys.prefix != sys.base_prefix, "ERROR: activate .venv before running Make"; print("Virtual environment: OK")'

preflight: check-venv
>$(PYTHON) -c 'import sys; assert sys.version_info[:2] == (3, 12), "ERROR: Python 3.12 is required"; print("Python version: OK")'
>test -f pyproject.toml || { echo "ERROR: pyproject.toml is missing"; exit 1; }
>test -f README.md || { echo "ERROR: README.md is missing"; exit 1; }
>test -f LICENSE || { echo "ERROR: LICENSE is missing"; exit 1; }
>test -f src/reliability_lab/__init__.py || { echo "ERROR: Python package is missing"; exit 1; }
>test -d tests || { echo "ERROR: tests directory is missing"; exit 1; }
>echo "Project files: OK"

bootstrap: check-venv
>$(PIP) install --upgrade "pip==$(PIP_VERSION)" "pip-tools==$(PIP_TOOLS_VERSION)"
>$(PYTHON) -c 'from importlib.metadata import version; assert version("pip") == "$(PIP_VERSION)"; assert version("pip-tools") == "$(PIP_TOOLS_VERSION)"; print("Packaging toolchain: OK")'

requirements.txt: pyproject.toml
>$(PIPTOOLS) compile --generate-hashes --output-file=requirements.txt pyproject.toml

requirements-dev.txt: pyproject.toml
>$(PIPTOOLS) compile --generate-hashes --extra dev --output-file=requirements-dev.txt pyproject.toml

lock: preflight requirements.txt requirements-dev.txt
>echo "Dependency lock files: OK"

lock-upgrade: preflight
>$(PIPTOOLS) compile --upgrade --generate-hashes --output-file=requirements.txt pyproject.toml
>$(PIPTOOLS) compile --upgrade --generate-hashes --extra dev --output-file=requirements-dev.txt pyproject.toml

sync: preflight requirements.txt requirements-dev.txt
>$(PIP) uninstall -y reliability-lab-app >/dev/null 2>&1 || true
>$(PIPTOOLS) sync requirements-dev.txt
>$(PIP) install --no-deps -e .
>$(PIP) check

doctor: preflight
>test -f requirements.txt || { echo "ERROR: requirements.txt is missing"; exit 1; }
>test -f requirements-dev.txt || { echo "ERROR: requirements-dev.txt is missing"; exit 1; }
>$(PYTHON) -c 'from importlib.metadata import version; assert version("pip") == "$(PIP_VERSION)", version("pip"); assert version("pip-tools") == "$(PIP_TOOLS_VERSION)", version("pip-tools"); print("Packaging versions: OK")'
>$(PIP) check
>$(PYTHON) -c 'import fastapi, pydantic, pydantic_settings, reliability_lab, uvicorn; print("Python imports: OK")'
>echo "Environment doctor: all checks passed"

run: check-venv
>uvicorn reliability_lab.main:app --reload --host 127.0.0.1 --port 8000

test: check-venv
>pytest

lint: check-venv
>ruff check .

format: check-venv
>ruff check --fix .
>ruff format .

format-check: check-venv
>ruff format --check .

type-check: check-venv
>mypy src tests

quality: format-check lint type-check test

clean:
>rm -rf .coverage .mypy_cache .pytest_cache .ruff_cache htmlcov
>find . -type d -name __pycache__ -prune -exec rm -rf {} +

# Local Docker Compose infrastructure
COMPOSE_CMD := env -u COMPOSE_FILE docker compose --project-directory "$(CURDIR)" --env-file "$(CURDIR)/.env" --file "$(CURDIR)/compose.yaml"

.PHONY: infra-config infra-pull infra-up infra-status infra-logs infra-down infra-reset infra-check postgres-shell redis-shell

infra-config:
>$(COMPOSE_CMD) config --quiet

infra-pull:
>$(COMPOSE_CMD) pull

infra-up: infra-config
>$(COMPOSE_CMD) up -d --wait

infra-status:
>$(COMPOSE_CMD) ps

infra-logs:
>$(COMPOSE_CMD) logs --tail=100 -f

infra-down:
>$(COMPOSE_CMD) down --remove-orphans

infra-reset:
>test "$(CONFIRM)" = "YES" || { echo "ERROR: this deletes all local database data"; echo "Run: make infra-reset CONFIRM=YES"; exit 1; }
>$(COMPOSE_CMD) down --volumes --remove-orphans

infra-check:
>./scripts/check-checkpoint-2a.sh

postgres-shell:
>$(COMPOSE_CMD) exec postgres sh -c 'psql -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"'

redis-shell:
>$(COMPOSE_CMD) exec redis redis-cli

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)"

cd "$ROOT_DIR"

COMPOSE=(
  env -u COMPOSE_FILE
  docker compose
  --project-directory "$ROOT_DIR"
  --env-file "$ROOT_DIR/.env"
  --file "$ROOT_DIR/compose.yaml"
)

echo "=== Required files ==="
for file in compose.yaml .env .env.example; do
  test -f "$file" || {
    echo "ERROR: missing $file"
    exit 1
  }
  echo "OK: $file"
done

echo
echo "=== Docker engine ==="
command -v docker >/dev/null
docker info >/dev/null
echo "Docker engine: OK"

echo
echo "=== Compose configuration ==="
"${COMPOSE[@]}" config --quiet
echo "Compose configuration: OK"

echo
echo "=== Starting services ==="
"${COMPOSE[@]}" up -d --wait

echo
echo "=== Container health ==="
for service in postgres redis; do
  container_id="$("${COMPOSE[@]}" ps -q "$service")"

  if [[ -z "$container_id" ]]; then
    echo "ERROR: container not found for $service"
    exit 1
  fi

  health_status="$(
    docker inspect \
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
      "$container_id"
  )"

  if [[ "$health_status" != "healthy" ]]; then
    echo "ERROR: $service health status is $health_status"
    exit 1
  fi

  echo "$service: healthy"
done

echo
echo "=== PostgreSQL functional check ==="
postgres_result="$(
  "${COMPOSE[@]}" exec -T postgres \
    sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Atc "SELECT 1;"' |
    tr -d '\r\n'
)"

if [[ "$postgres_result" != "1" ]]; then
  echo "ERROR: PostgreSQL returned '$postgres_result'"
  exit 1
fi

echo "PostgreSQL query: OK"

echo
echo "=== Redis functional check ==="
redis_result="$(
  "${COMPOSE[@]}" exec -T redis redis-cli ping |
    tr -d '\r\n'
)"

if [[ "$redis_result" != "PONG" ]]; then
  echo "ERROR: Redis returned '$redis_result'"
  exit 1
fi

echo "Redis ping: OK"

echo
echo "=== Local-only port bindings ==="
postgres_binding="$("${COMPOSE[@]}" port postgres 5432)"
redis_binding="$("${COMPOSE[@]}" port redis 6379)"

if [[ "$postgres_binding" != 127.0.0.1:* ]]; then
  echo "ERROR: PostgreSQL is exposed outside 127.0.0.1"
  echo "Actual binding: $postgres_binding"
  exit 1
fi

if [[ "$redis_binding" != 127.0.0.1:* ]]; then
  echo "ERROR: Redis is exposed outside 127.0.0.1"
  echo "Actual binding: $redis_binding"
  exit 1
fi

echo "PostgreSQL: $postgres_binding"
echo "Redis:      $redis_binding"

echo
echo "=== Git secret protection ==="
if ! git check-ignore -q .env; then
  echo "ERROR: .env is not ignored by Git"
  exit 1
fi

if git ls-files --error-unmatch .env >/dev/null 2>&1; then
  echo "ERROR: .env is already tracked by Git"
  exit 1
fi

echo ".env is ignored and not tracked"

echo
echo "Checkpoint 2A completed successfully."

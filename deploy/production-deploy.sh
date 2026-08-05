#!/bin/sh
set -eu

: "${IMAGE_TAG:?IMAGE_TAG is required}"

compose() {
  docker compose --env-file .env -f docker-compose.prod.yml "$@"
}

mkdir -p data logs deploy

if ! docker network inspect api-router-shared >/dev/null 2>&1; then
  docker network create api-router-shared >/dev/null
fi

compose pull new-api
compose up -d --remove-orphans

attempt=1
while [ "$attempt" -le 60 ]; do
  health="$(docker inspect --format '{{.State.Health.Status}}' new-api 2>/dev/null || true)"
  case "$health" in
    healthy)
      echo "new-api is healthy"
      exit 0
      ;;
    unhealthy|exited|dead)
      echo "new-api health check failed with status: $health" >&2
      compose ps >&2 || true
      docker logs --tail 100 new-api >&2 || true
      exit 1
      ;;
  esac
  sleep 2
  attempt=$((attempt + 1))
done

echo "new-api did not become healthy within 120 seconds" >&2
compose ps >&2 || true
docker logs --tail 100 new-api >&2 || true
exit 1

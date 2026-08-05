# Production migration from the original Compose deployment

This procedure replaces the existing Docker Compose application with the image built from this repository while preserving the PostgreSQL data volume.

## Data ownership

The PostgreSQL volume `new-api_pg_data` is the source of truth for users, channels, API keys, balances, options, and other application records. Do not remove it during the migration.

Redis is not the primary data store. The original Compose file does not mount a Redis data volume, so Redis should be treated as disposable cache/session infrastructure for this migration.

The following values must be preserved from the old deployment:

- `SESSION_SECRET`
- `CRYPTO_SECRET`, when explicitly configured
- `SQL_DSN` database name, user, host, and password
- `REDIS_CONN_STRING` and `REDIS_PASSWORD`
- `SESSION_COOKIE_SECURE`
- `SESSION_COOKIE_TRUSTED_URL`
- `TRUSTED_PROXIES`
- OAuth, payment, email, storage, and provider credentials

Changing `SESSION_SECRET` invalidates existing logins and temporary authentication flows.

## One-time server preparation

Run these commands as the deployment user with permission to use Docker. Replace the deployment path, but do not change the existing volume name.

```sh
mkdir -p /opt/dawn-router/deploy /opt/dawn-router/data /opt/dawn-router/logs
cd /opt/dawn-router

# Preserve file-based data mounted at /data by the old application container.
# Copy logs only when they are needed for historical audit/debugging.
if [ -d /path/to/old-compose/data ]; then
  cp -a /path/to/old-compose/data/. data/
fi
if [ -d /path/to/old-compose/logs ]; then
  cp -a /path/to/old-compose/logs/. logs/
fi

docker network inspect api-router-shared >/dev/null 2>&1 || \
  docker network create api-router-shared

cp /path/to/deploy/.env.production.example .env
cp /path/to/deploy/app.env.example deploy/app.env
chmod 600 .env deploy/app.env
```

Fill the two environment files with the existing production values. Do not commit either file.

If the GHCR package is private, log in once on the server with a read-only package token. Do not place the token in Compose or in GitHub workflow command arguments:

```sh
echo "$GHCR_READ_TOKEN" | docker login ghcr.io \
  --username "$GHCR_READ_USER" --password-stdin
```

## Backup and cutover

Schedule a maintenance window and announce that writes will stop. **Never run `docker compose down -v` and never run `docker volume rm new-api_pg_data`.**

First record the current state and create a PostgreSQL backup:

```sh
cd /path/to/old-compose
BACKUP_DIR="$(pwd)/backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

docker volume inspect new-api_pg_data > "$BACKUP_DIR/volume-inspect.json"
docker inspect postgres > "$BACKUP_DIR/postgres-inspect.json"
docker compose config > "$BACKUP_DIR/old-compose.config.yml"
docker compose ps > "$BACKUP_DIR/old-compose.ps.txt"

docker exec postgres sh -c \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' \
  > "$BACKUP_DIR/new-api.dump"

docker exec postgres sh -c \
  'pg_dumpall --globals-only -U "$POSTGRES_USER"' \
  > "$BACKUP_DIR/postgres-globals.sql"

sha256sum "$BACKUP_DIR"/*
```

Validate that the backup is non-empty and copy it to storage outside the server before continuing. A backup that has not been tested or copied away is not a rollback plan.

Stop only the old application stack without removing volumes:

```sh
docker compose -f olddockercompose.yaml down --remove-orphans
```

If the old file is not available, stop and remove only the old containers by name. Do not remove the volume:

```sh
docker rm -f new-api postgres redis
```

Then deploy the new image with the preserved PostgreSQL volume:

```sh
cd /opt/dawn-router
IMAGE_TAG=sha-<published-commit> \
IMAGE_REPOSITORY=ghcr.io/ymngkhtd/dawn-router \
./deploy/production-deploy.sh
```

The production Compose file explicitly binds `pg_data` to the existing external volume `new-api_pg_data`, so Compose cannot silently create a new empty database volume.

## Verification

Before reopening traffic through Nginx or the load balancer, verify the container and API health:

```sh
docker compose --env-file .env -f docker-compose.prod.yml ps
curl --fail http://127.0.0.1:13500/api/status
```

Then verify from the admin UI:

1. Existing admin account can log in.
2. Existing users are present.
3. Existing channels and channel keys are present.
4. User balances and quotas are unchanged.
5. A test request reaches a known trusted channel.
6. Nginx upstream still points to `127.0.0.1:13500`.
7. Logs contain no database migration or Redis authentication errors.

Keep the old database backup and old image tag until the business verification window is complete.

## Manual rollback

This deployment intentionally does not perform automatic rollback. If the new image is unhealthy, inspect logs first. After identifying the last known-good immutable tag, deploy it explicitly:

```sh
cd /opt/dawn-router
IMAGE_TAG=sha-<previous-known-good-commit> \
IMAGE_REPOSITORY=ghcr.io/ymngkhtd/dawn-router \
./deploy/production-deploy.sh
```

Do not restore the PostgreSQL dump merely because the application container failed. Restore the database only when the migration changed data incompatibly and the restore procedure has been reviewed.

## GitHub Actions configuration

The production source branch is `Dawn-router-main`.

Upstream changes should be merged into this branch through the automated or manual sync Pull Request flow documented in [upstream-sync.md](../development/upstream-sync.md). Do not deploy an upstream branch directly to production.

The image workflow publishes:

```text
ghcr.io/ymngkhtd/dawn-router:sha-<commit>
```

Configure a protected GitHub Environment named `production`:

Repository variables:

- `PRODUCTION_SSH_HOST`
- `PRODUCTION_SSH_USER`
- `PRODUCTION_DEPLOY_PATH` (for example `/opt/dawn-router`)

Environment secrets:

- `PRODUCTION_SSH_PRIVATE_KEY`
- `PRODUCTION_KNOWN_HOSTS`

The deploy workflow is manual and concurrency-limited. Use the immutable `sha-<commit>` tag, not `latest`, for production releases.

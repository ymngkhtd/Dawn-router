# Production deployment files

- `app.env.example`: application environment template. Copy to the production host as `deploy/app.env`.
- `.env.production.example`: Docker Compose interpolation template. Copy to the production host as `.env`.
- `production-deploy.sh`: pulls an immutable image tag, starts the stack, and waits for the application health check.

Never commit the populated `.env` or `deploy/app.env` files. The production database volume is intentionally declared as the external volume `new-api_pg_data` in `docker-compose.prod.yml`.

# Production deployment files

- `app.env.example`: application environment template. Copy to the production host as `deploy/app.env`.
- `.env.production.example`: Docker Compose interpolation template. Copy to the production host as `.env`.
- `production-deploy.sh`: pulls an immutable image tag, starts the stack, and waits for the application health check.
- `deploy-remote.sh`: local macOS/POSIX shell wrapper for uploading the Compose/script files and invoking `production-deploy.sh` over SSH.
- `deploy-remote.ps1`: local Windows wrapper that uploads only the Compose/script files and invokes `production-deploy.sh` over SSH. It never uploads `.env` or `app.env`.

Never commit the populated `.env` or `deploy/app.env` files. The production database volume is intentionally declared as the external volume `new-api_pg_data` in `docker-compose.prod.yml`.

## Local CD from PowerShell

After the GHCR workflow succeeds, run the wrapper from the repository root with the immutable image tag:

```powershell
pwsh -File .\deploy\deploy-remote.ps1 `
	-ImageTag sha-c8bb944c418809b8884a635439490b5aa5921eb2 `
	-Server deploy@your-server.example.com `
	-SshPort 2222 `
	-DeployPath /opt/dawn-router `
	-SshKey "$HOME\.ssh\dawn-router-deploy"
```

Use `-SkipUpload` only when the production Compose file and deployment script are already current on the server. The server-side `.env`, `deploy/app.env`, PostgreSQL volume, and Redis password are never uploaded by this wrapper.

## Local CD from macOS

After the GHCR workflow succeeds, run the wrapper from the repository root with the immutable image tag:

```sh
chmod +x ./deploy/deploy-remote.sh
./deploy/deploy-remote.sh \
	--image-tag sha-c8bb944c418809b8884a635439490b5aa5921eb2 \
	--server deploy@your-server.example.com \
	--ssh-port 2222 \
	--deploy-path /opt/dawn-router \
	--ssh-key "$HOME/.ssh/dawn-router-deploy"
```

Use `--skip-upload` only when the production Compose file and deployment script are already current on the server. The server-side `.env`, `deploy/app.env`, PostgreSQL volume, and Redis password are never uploaded by this wrapper. The script uses the macOS-provided `ssh` and `scp` commands and keeps strict host key checking enabled.

If the configured SSH private key does not exist, the macOS wrapper falls back to interactive password authentication. Run it from a terminal, ensure password authentication is enabled for the server account, and add the server host key to `~/.ssh/known_hosts` first. The password is never accepted as a command-line argument, stored by the script, or written to logs.

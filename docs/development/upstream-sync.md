# Fork upstream synchronization

This repository is a Fork with local development on `Dawn-router-main`. Keep the fork as `origin` and add the original repository as `upstream`.

## Remote model

```text
origin   -> https://github.com/ymngkhtd/Dawn-router.git
upstream -> the parent repository shown on GitHub as "forked from"
```

Do not push custom work directly to the upstream repository. Do not replace `Dawn-router-main` with a hard reset from upstream.

## First-time setup

Run locally after the current work is committed or safely stashed:

```powershell
git remote add upstream https://github.com/QuantumNous/new-api.git
git fetch upstream --prune
git push --set-upstream origin Dawn-router-main
```

If the parent repository URL differs, use the URL shown in the Fork page instead.

Verify the remotes:

```powershell
git remote -v
git branch -vv
```

`origin` is your writable Fork. `upstream` is read-only reference code. Never use `git push upstream ...` for normal development.

## Recommended sync flow

Use a temporary branch and a Pull Request for every upstream update:

```powershell
git fetch upstream --prune
git switch Dawn-router-main
git pull --ff-only origin Dawn-router-main

$syncBranch = "sync/upstream-$(Get-Date -Format yyyyMMdd-HHmm)"
git switch -c $syncBranch
git merge --no-ff upstream/main
git push --set-upstream origin $syncBranch
```

Open a Pull Request with:

```text
base: Dawn-router-main
compare: sync/upstream-YYYYMMDD-HHmm
```

Let CI run before merging. Review at least:

- Database migrations and model changes
- Authentication and session behavior
- Relay/provider request behavior
- Dockerfiles and Compose changes
- GitHub Actions permissions and third-party actions
- Frontend route and locale changes
- Changes to protected project attribution or metadata

After verification, merge the Pull Request into `Dawn-router-main`. Delete the temporary sync branch after merge.

## Automated sync

[upstream-sync.yml](../../.github/workflows/upstream-sync.yml) runs daily and can also be started with `workflow_dispatch`. It discovers the Fork parent through the GitHub API, fetches its default branch, creates an `automation/upstream-sync-*` branch, and opens a Pull Request into `Dawn-router-main`.

The workflow intentionally stops when the merge has conflicts. Conflict resolution should happen in a human-reviewed branch, not inside an unattended production pipeline.

## Conflict resolution

When the sync Pull Request has conflicts:

```powershell
git fetch upstream --prune
git switch sync/upstream-YYYYMMDD-HHmm
git merge upstream/main
```

Resolve the files, then:

```powershell
git add <resolved-files>
git commit
git push
```

Run the relevant tests again. Do not use `git reset --hard`, force-push, or discard local product changes without reviewing the conflict.

## Release relationship

The branch relationship is:

```text
upstream/main
    |
    +--> sync/upstream-* --> Pull Request --> Dawn-router-main
                                            |
                                            +--> GHCR image sha-<commit>
                                                      |
                                                      +--> manual production deploy
```

A successful merge into `Dawn-router-main` triggers [ghcr-publish.yml](../../.github/workflows/ghcr-publish.yml). Production deployment should then use that commit's immutable `sha-<commit>` image tag through [production-deploy.yml](../../.github/workflows/production-deploy.yml).

This keeps upstream integration, application CI, image publishing, and production release as separate reviewable steps.

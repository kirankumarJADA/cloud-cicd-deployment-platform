# Troubleshooting

## Pipeline

**`backend-test` fails**
Read the job log; the surefire report is uploaded as the
`backend-surefire-reports` artifact. Tests use in-memory H2, so failures are
logic/wiring, not environment.

**`frontend-build` fails on lint**
Run `cd frontend && npm run lint` locally. The CI uses `--max-warnings 0`, so
warnings fail the build by design.

**`image-push` — `denied: permission_denied`**
The workflow needs `packages: write` (already set) and the repo must allow
GitHub Actions to publish packages: Settings → Actions → Workflow permissions
→ *Read and write permissions*.

**`deploy-production` — `Permission denied (publickey)`**
`SSH_PRIVATE_KEY` doesn't match the public key in
`/home/deploy/.ssh/authorized_keys`, or `SSH_USER`/`SSH_HOST` is wrong.
Verify locally: `ssh -i deploy_key deploy@<host> echo ok`.

**`deploy-production` — host key verification failed**
The `ssh-keyscan` step populates `known_hosts`. If the VM was rebuilt with a
new host key, this resolves itself on the next run; no action needed.

## Runtime

**Backend container restarts / unhealthy**
```bash
docker compose -f deployment/docker-compose.prod.yml logs --tail=100 backend
```
Most common cause: `JWT_SECRET` missing or under 32 bytes — the app fails
fast by design. Check `deployment/.env`.

**Backend can't reach the database**
Postgres isn't ready, or credentials mismatch. Confirm:
```bash
docker compose -f deployment/docker-compose.prod.yml ps
docker compose -f deployment/docker-compose.prod.yml exec postgres \
  pg_isready -U appuser -d appdb
```
`DATABASE_PASSWORD` must be identical for the `postgres` and `backend` services
(both read it from the same `.env`).

**Flyway: "Validate failed" / checksum mismatch**
A migration file was edited after being applied. Never modify an applied
migration — add a new `V2__*.sql`. To reset a *dev* DB only:
`docker compose down -v`.

**502 / 504 from nginx**
Backend not up yet (it has a ~45 s start period) or crashed. Check backend
health: `curl localhost/actuator/health/readiness`. nginx retries
automatically once the upstream is healthy.

**429 Too Many Requests**
Rate limiting is working. Limits: `/api/auth` 3 r/s, other `/api` 10 r/s,
20 concurrent connections per IP. Tune the `limit_req_zone` values in
`nginx/nginx.conf` if legitimate traffic is throttled.

**Deploy succeeded but app shows old version**
Browsers cache the SPA shell aggressively. The config sends `no-cache` for
`index.html`; hard-refresh (Ctrl/Cmd+Shift+R). Confirm the running tag:
`cat /opt/cloud-cicd-deployment-platform/.deployed_tag`.

**Disk filling up**
Old images accumulate. `deploy.sh` prunes dangling images each run; for a
deeper clean: `docker system prune -af` (does not touch the `pgdata` volume).
`vm-setup.sh` caps container logs at 3 × 10 MB.

## Data safety

The PostgreSQL data lives in the `pgdata` named volume and is **not** removed
by `docker compose down` or by redeploys — only by `down -v` or an explicit
`docker volume rm`. Back it up with:

```bash
docker compose -f deployment/docker-compose.prod.yml exec postgres \
  pg_dump -U appuser appdb > backup_$(date +%F).sql
```

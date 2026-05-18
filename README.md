<h1 align="center">Cloud CI/CD Deployment Platform</h1>

<p align="center">
  <em>A production-grade demonstration of automated build → test → containerize → push → deploy.</em>
</p>

<p align="center">
  <img alt="Java" src="https://img.shields.io/badge/Java-21-orange">
  <img alt="Spring Boot" src="https://img.shields.io/badge/Spring%20Boot-3.3-6DB33F">
  <img alt="React" src="https://img.shields.io/badge/React-18%20%2B%20Vite-61DAFB">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-multi--stage-2496ED">
  <img alt="CI/CD" src="https://img.shields.io/badge/GitHub%20Actions-5%20jobs-2088FF">
  <img alt="nginx" src="https://img.shields.io/badge/nginx-reverse%20proxy-009639">
</p>

---

## What this is

This repository is **not a CRUD app**. It is a reference implementation of the
machinery that takes code from a `git push` to a running production service on
a Linux cloud server — with **zero manual steps** in between.

The sample application (Spring Boot + React + PostgreSQL) exists only to give
the pipeline something real to test, containerize, and deploy. The engineering
value lives in the **CI/CD pipeline, Docker strategy, reverse proxy, deployment
scripts, secrets handling, and reliability mechanisms**.

```
 push to main
     │
     ├─▶ backend-test ─────┐   (run in parallel)
     ├─▶ frontend-build ───┤
     │                     ▼
     │              docker-build  (backend + frontend, matrix, layer-cached)
     │                     ▼
     │              image-push    (GHCR, immutable sha-<commit> + latest)
     │                     ▼
     │           deploy-production (SSH → Ubuntu VM)
     │                     ├─ pull new images
     │                     ├─ recreate containers
     │                     ├─ health-gate (wait for readiness)
     │                     └─ auto-rollback on failure
     ▼
 production updated, smoke-tested, traceable
```

## Highlights

- **Full GitHub Actions pipeline** — 5 jobs (`backend-test`, `frontend-build`,
  `docker-build`, `image-push`, `deploy-production`), parallel where possible,
  Maven + npm + Docker-layer caching, PR-safe (tests on PRs, deploy only on `main`).
- **Multi-stage Dockerfiles** — backend builds then runs on a slim JRE as a
  non-root user; frontend builds with Vite then serves static assets via nginx.
  Both declare container `HEALTHCHECK`s.
- **Health-gated, self-rolling-back deploys** — a bad build physically cannot
  take production down; `deploy.sh` reverts to the last good image tag.
- **Production nginx edge proxy** — single exposed port, API/SPA routing,
  security headers, CSP, per-zone rate limiting, JSON access logs, SSL-ready.
- **Real secrets hygiene** — every credential is an environment variable fed
  from GitHub Secrets; nothing sensitive is committed; `.env` is git-ignored.
- **Observability** — Actuator liveness/readiness probes, Micrometer →
  Prometheus metrics, optional Grafana, structured logs, cron-able smoke test.
- **Verified** — frontend build + ESLint pass; all shell scripts pass
  `shellcheck`; all YAML validated.

## Tech stack

| Layer | Choice |
|---|---|
| Backend | Java 21, Spring Boot 3.3, Spring Security (stateless JWT), JPA, Flyway |
| Frontend | React 18, Vite, React Router |
| Database | PostgreSQL 16 (persistent named volume) |
| Containers | Docker, multi-stage builds, Docker Compose |
| CI/CD | GitHub Actions → GitHub Container Registry |
| Edge | nginx 1.27 reverse proxy (TLS-ready, rate-limited) |
| Host | Ubuntu 22.04/24.04 VM (AWS EC2 compatible) |
| Monitoring | Spring Boot Actuator, Micrometer, Prometheus, Grafana |

## Architecture

See **[docs/architecture.md](docs/architecture.md)** for the full diagram and
rationale. In short: the browser hits **edge nginx** (the only exposed port),
which routes `/` to the React SPA container and `/api/**` to the Spring Boot
container, which persists to PostgreSQL on a private bridge network. The
backend and database are never published to the host.

## Quick start (local, full stack)

From the **project root** — one command:

```bash
make up
```

This copies `.env.example` → `docker/.env` if needed, then builds and starts
all four services (frontend, backend, PostgreSQL, nginx). First build takes a
few minutes (Maven + npm); the backend healthcheck has a 70 s start window
while Flyway runs the initial migration.

Without `make`:

### Run locally

```bash
copy .env.example .env
docker compose -f docker/docker-compose.yml up --build
```

Then:

| URL | What |
|---|---|
| <http://localhost:8080> | Operations console (sign in `admin` / `AdminPass123`) |
| <http://localhost:8080/actuator/health> | `{"status":"UP"}` |
| <http://localhost:8080/api/public/health> | lightweight liveness JSON |

`make ps` shows health status, `make logs` tails logs, `make down` stops it,
`make clean` also wipes the database volume. Rotate the seeded admin
credential immediately in any real environment.

Full local options (including hot-reload dev mode) are in
**[docs/local-development.md](docs/local-development.md)**.

## Deploy to a cloud VM

One-time VM bootstrap, then every `git push origin main` deploys
automatically. The complete walkthrough, including **AWS EC2** specifics and
the exact GitHub Secrets to set, is in
**[docs/deployment.md](docs/deployment.md)**.

```bash
# on a fresh Ubuntu VM
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/server-bootstrap.sh | sudo bash
```

### Required GitHub Secrets

`SSH_HOST` · `SSH_USER` · `SSH_PRIVATE_KEY` · `DOCKER_USERNAME` ·
`DOCKER_PASSWORD` · `JWT_SECRET` · `DATABASE_PASSWORD`

No secret is ever hardcoded or committed.

## CI/CD pipeline explained

| Job | Trigger | Does |
|---|---|---|
| `backend-test` | every push & PR | `./mvnw clean verify` (JUnit, H2); fails pipeline on any test failure; uploads surefire report |
| `frontend-build` | every push & PR | `npm ci` → ESLint (`--max-warnings 0`) → `vite build`; uploads `dist/` |
| `docker-build` | after both pass | builds backend + frontend images (matrix, parallel) with GHA layer cache; no push |
| `image-push` | `main` only | pushes immutable `sha-<commit>` + `latest` tags to GHCR |
| `deploy-production` | `main` only | SSH to VM → render `.env` from secrets → registry login → `deploy.sh` (health-gated, rollback) → smoke test → step summary |

Defined in **[.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)**.

## Docker explained

- **Backend** — stage 1 resolves Maven deps (cached layer) and builds the jar;
  stage 2 is a slim `eclipse-temurin:21-jre` running as an unprivileged user
  with a tuned JVM (`MaxRAMPercentage`, G1GC) and a curl-based `HEALTHCHECK`.
- **Frontend** — stage 1 runs `vite build`; stage 2 serves the static bundle
  from `nginx:alpine` with immutable asset caching and SPA history fallback.
- **Compose** — `docker/` builds locally for development; `deployment/` pulls
  versioned registry images for production with `restart: always`, per-service
  healthchecks, resource limits, and a persistent `pgdata` volume.

## Reliability & monitoring

Restart policies, persistent DB volume, container + compose healthchecks,
health-gated deploys with automatic rollback, structured backend logs, JSON
nginx logs, log rotation, and a cron-friendly smoke test. Metrics via
Actuator + Micrometer with an optional Prometheus/Grafana add-on. Details in
**[monitoring/README.md](monitoring/README.md)**.

## Repository layout

```
.github/workflows/   CI/CD pipeline
backend/             Spring Boot service (Java 21) + multi-stage Dockerfile + tests
frontend/            React + Vite SPA + multi-stage Dockerfile
docker/              local-dev compose (builds images)
deployment/          production compose (pulls registry images)
nginx/               edge reverse proxy: routing, TLS, rate limit, security headers
scripts/             server-bootstrap · vm-setup · deploy · health-check
monitoring/          Prometheus + Grafana add-on
docs/                architecture · deployment · local-development · troubleshooting
```

## Documentation

- [Architecture](docs/architecture.md) — diagrams, components, design rationale
- [Deployment guide](docs/deployment.md) — VM + AWS EC2 + secrets, step by step
- [Local development](docs/local-development.md) — Docker and hot-reload modes
- [Troubleshooting](docs/troubleshooting.md) — pipeline & runtime failure modes
- [Monitoring](monitoring/README.md) — metrics, probes, reliability mechanisms

## Screenshots

The operations console renders a control-room dashboard (live service health,
user count, process uptime, the last deployment pipeline as a 5-stage strip,
a deployment log, and the authenticated session). Run the quick start above
to view it locally; capture screenshots into `docs/screenshots/` and they will
appear here.

## Key Engineering Challenges Solved

- Fixed container healthcheck failures (`localhost` → `127.0.0.1`)
- Solved JWT secret initialization failures in Spring Security
- Debugged nginx reverse proxy startup and container dependency ordering
- Implemented health-gated deployments with rollback protection
- Verified container networking across frontend, backend, and PostgreSQL

## License

MIT — see [LICENSE](LICENSE).

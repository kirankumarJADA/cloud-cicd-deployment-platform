# Local Development

Two ways to run the stack locally: full Docker (closest to production) or
hot-reload dev mode (fastest iteration).

## Option A — Full stack with Docker (recommended first run)

```bash
cp .env.example docker/.env
# edit docker/.env: set JWT_SECRET (>=32 chars) and DATABASE_PASSWORD
cd docker
docker compose up --build
```

Everything comes up behind the edge proxy:

- App: <http://localhost:8080>
- Health: <http://localhost:8080/api/public/health>
- Actuator: <http://localhost:8080/actuator/health>

Sign in with the seeded admin: `admin` / `AdminPass123`.

Tear down (keep data): `docker compose down`
Tear down (wipe DB): `docker compose down -v`

## Option B — Hot-reload dev mode

Run PostgreSQL in Docker, backend and frontend natively.

**Database**

```bash
docker run --rm -d --name ccd-pg -p 5432:5432 \
  -e POSTGRES_DB=appdb -e POSTGRES_USER=appuser -e POSTGRES_PASSWORD=changeme \
  postgres:16-alpine
```

**Backend** (JDK 21 + Maven required)

```bash
cd backend
export JWT_SECRET="local-dev-secret-that-is-at-least-32-bytes-long"
export DATABASE_URL=jdbc:postgresql://localhost:5432/appdb
export DATABASE_USERNAME=appuser
export DATABASE_PASSWORD=changeme
./mvnw spring-boot:run
```

**Frontend** (Node 20+)

```bash
cd frontend
npm install
npm run dev      # http://localhost:5173, proxies /api to :8080
```

## Running tests

Backend:

```bash
cd backend && ./mvnw test          # uses in-memory H2, no DB needed
```

Frontend:

```bash
cd frontend && npm run lint && npm run build
```

## Useful commands

| Command | What |
|---|---|
| `docker compose logs -f backend` | tail backend logs |
| `docker compose ps` | service + health status |
| `./scripts/health-check.sh` | run the smoke test against localhost |
| `curl localhost:8080/actuator/prometheus` | raw metrics |

## Project layout

```
backend/      Spring Boot service (Java 21, JWT, JPA, Flyway, Actuator)
frontend/     React + Vite SPA (operations console UI)
docker/       local-dev compose (builds images)
deployment/   production compose (pulls registry images)
nginx/        edge reverse proxy config (routing, TLS, rate limit, headers)
scripts/      server-bootstrap / vm-setup / deploy / health-check
monitoring/   Prometheus + Grafana add-on
.github/      CI/CD pipeline
docs/         architecture, deployment, local dev, troubleshooting
```

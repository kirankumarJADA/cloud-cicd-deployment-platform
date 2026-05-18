# Monitoring & Reliability

This stack ships with three layers of observability.

## 1. Application metrics (Micrometer + Prometheus)

The backend exposes Prometheus-format metrics via Spring Boot Actuator at:

```
GET /actuator/prometheus
```

Out of the box this includes JVM memory and GC, HTTP request latency and
counts per endpoint, HikariCP connection-pool stats, and process uptime — all
tagged with `application=cloud-cicd-deployment-platform`.

Bring up Prometheus + Grafana next to the production stack:

```bash
docker compose -f deployment/docker-compose.prod.yml \
               -f monitoring/docker-compose.monitoring.yml up -d
```

Grafana is then available on port `3000` with Prometheus pre-wired as the
default datasource. Build dashboards from the JVM (Micrometer) and Spring MVC
metrics, or import community dashboard ID `4701` (JVM Micrometer).

## 2. Health probes

| Endpoint | Purpose | Auth |
|---|---|---|
| `/api/public/health` | Lightweight liveness for load balancers & scripts | none |
| `/actuator/health/liveness` | Kubernetes/Docker liveness probe | none |
| `/actuator/health/readiness` | Includes DB connectivity; gates traffic | none |
| `/actuator/health` | Full component detail | when authorized |

Both Docker images declare `HEALTHCHECK` instructions, and every service in
the production compose file has a Compose-level healthcheck. `deploy.sh`
treats readiness as the deploy gate and rolls back if it never goes green.

## 3. Reliability mechanisms

- **Restart policies** — every production container uses `restart: always`.
- **Persistent DB volume** — `pgdata` survives container recreation and redeploys.
- **Health-gated deploys** — new containers must pass health checks or the
  deployment automatically rolls back to the previous image tag.
- **Structured logs** — backend logs are ISO-8601 timestamped key-value lines;
  nginx access logs are JSON for ingestion by Loki/ELK.
- **Log rotation** — `vm-setup.sh` caps container logs at 3 × 10 MB so a
  chatty service can't fill the disk.
- **Uptime monitoring** — `scripts/health-check.sh` is cron-friendly and exits
  non-zero on any failed check, so it can drive an external alerting hook.

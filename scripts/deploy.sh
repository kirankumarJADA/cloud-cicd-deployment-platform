#!/usr/bin/env bash
# =============================================================================
# deploy.sh
#
# Runs ON the Linux VM (invoked over SSH by the GitHub Actions deploy job, or
# manually). It performs a safe, health-gated redeployment:
#
#   1. record the currently-running image tag (for rollback)
#   2. pull the new tagged images from the registry
#   3. recreate containers with the new images
#   4. wait for the application health endpoint to go green
#   5. on failure -> roll back to the previous tag and exit non-zero
#
# Required environment (provided via deployment/.env on the VM):
#   REGISTRY IMAGE_OWNER IMAGE_TAG
#   DATABASE_NAME DATABASE_USERNAME DATABASE_PASSWORD
#   JWT_SECRET APP_VERSION
# =============================================================================
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/cloud-cicd-deployment-platform}"
COMPOSE_FILE="${APP_DIR}/deployment/docker-compose.prod.yml"
ENV_FILE="${APP_DIR}/deployment/.env"
HEALTH_URL="${HEALTH_URL:-http://localhost/api/public/health}"
HEALTH_RETRIES="${HEALTH_RETRIES:-30}"
HEALTH_DELAY="${HEALTH_DELAY:-5}"

ts()  { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '\033[1;34m[deploy %s]\033[0m %s\n' "$(ts)" "$*"; }
err() { printf '\033[1;31m[deploy %s ERROR]\033[0m %s\n' "$(ts)" "$*" >&2; }

cd "${APP_DIR}"

if [[ ! -f "${ENV_FILE}" ]]; then
  err "Missing ${ENV_FILE}. The deploy job must render it from GitHub secrets."
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "${ENV_FILE}"
set +a

compose() { docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" "$@"; }

# ---- 1. capture rollback target --------------------------------------------
PREVIOUS_TAG="$(cat "${APP_DIR}/.deployed_tag" 2>/dev/null || echo '')"
log "New tag      : ${IMAGE_TAG}"
log "Previous tag : ${PREVIOUS_TAG:-<none>}"

# ---- 2. pull -----------------------------------------------------------------
log "Pulling images from ${REGISTRY}/${IMAGE_OWNER} ..."
compose pull backend frontend

# ---- 3. recreate -------------------------------------------------------------
log "Recreating containers..."
compose up -d --remove-orphans

# ---- 4. health gate ----------------------------------------------------------
log "Waiting for application health at ${HEALTH_URL} ..."
healthy=0
for i in $(seq 1 "${HEALTH_RETRIES}"); do
  if curl -fsS --max-time 4 "${HEALTH_URL}" >/dev/null 2>&1; then
    healthy=1
    log "Health check passed on attempt ${i}."
    break
  fi
  log "Attempt ${i}/${HEALTH_RETRIES} not ready yet; retrying in ${HEALTH_DELAY}s..."
  sleep "${HEALTH_DELAY}"
done

# ---- 5. rollback on failure --------------------------------------------------
if [[ "${healthy}" -ne 1 ]]; then
  err "Deployment unhealthy after $((HEALTH_RETRIES * HEALTH_DELAY))s."
  compose logs --tail=80 backend || true
  if [[ -n "${PREVIOUS_TAG}" ]]; then
    err "Rolling back to ${PREVIOUS_TAG}..."
    IMAGE_TAG="${PREVIOUS_TAG}" compose up -d --remove-orphans
    err "Rollback complete. Deployment FAILED."
  else
    err "No previous tag recorded; cannot roll back automatically."
  fi
  exit 1
fi

# ---- success: persist deployed tag, prune ----------------------------------
echo "${IMAGE_TAG}" > "${APP_DIR}/.deployed_tag"
log "Pruning dangling images..."
docker image prune -f >/dev/null 2>&1 || true

log "Deployment SUCCESSFUL. Running tag: ${IMAGE_TAG}"
compose ps

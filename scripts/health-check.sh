#!/usr/bin/env bash
# =============================================================================
# health-check.sh
#
# Standalone smoke test. Can run locally, in CI after deploy, or from a cron
# job for uptime monitoring. Verifies the full request path through the edge
# proxy: public health, actuator probes, and an authenticated round-trip.
#
# Usage:
#   ./health-check.sh                       # checks http://localhost
#   BASE_URL=https://my-domain ./health-check.sh
# =============================================================================
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
PASS=0
FAIL=0

green() { printf '\033[1;32m%s\033[0m\n' "$*"; }
red()   { printf '\033[1;31m%s\033[0m\n' "$*"; }

check() {
  local name="$1" url="$2" expect="${3:-200}"
  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 "${url}" || echo 000)"
  if [[ "${code}" == "${expect}" ]]; then
    green "  PASS  ${name} (${code})"
    PASS=$((PASS + 1))
  else
    red   "  FAIL  ${name} (got ${code}, expected ${expect})"
    FAIL=$((FAIL + 1))
  fi
}

echo "Health check against ${BASE_URL}"
echo "------------------------------------------------------------"
check "frontend SPA"          "${BASE_URL}/"                          200
check "public health"         "${BASE_URL}/api/public/health"         200
check "actuator liveness"     "${BASE_URL}/actuator/health/liveness"  200
check "actuator readiness"    "${BASE_URL}/actuator/health/readiness" 200
check "secured endpoint 403"  "${BASE_URL}/api/dashboard"             403

# Authenticated round-trip with the seeded admin account.
echo "------------------------------------------------------------"
TOKEN="$(curl -s --max-time 8 -X POST "${BASE_URL}/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d '{"username":"admin","password":"AdminPass123"}' \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p' || true)"

if [[ -n "${TOKEN}" ]]; then
  CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
    -H "Authorization: Bearer ${TOKEN}" "${BASE_URL}/api/dashboard")"
  if [[ "${CODE}" == "200" ]]; then
    green "  PASS  authenticated dashboard (200)"
    PASS=$((PASS + 1))
  else
    red   "  FAIL  authenticated dashboard (${CODE})"
    FAIL=$((FAIL + 1))
  fi
else
  red "  FAIL  could not obtain auth token (login failed)"
  FAIL=$((FAIL + 1))
fi

echo "------------------------------------------------------------"
echo "Passed: ${PASS}  Failed: ${FAIL}"
[[ "${FAIL}" -eq 0 ]] || exit 1
green "All health checks passed."

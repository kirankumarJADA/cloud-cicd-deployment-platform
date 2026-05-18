#!/usr/bin/env bash
# =============================================================================
# server-bootstrap.sh
#
# Run ONCE on a fresh Ubuntu 22.04/24.04 VM (AWS EC2, DigitalOcean, etc.) as
# root or via sudo. It installs Docker Engine + Compose plugin, creates an
# unprivileged `deploy` user used by the CI/CD SSH deployment, and prepares
# the application directory.
#
#   curl -fsSL https://raw.githubusercontent.com/<you>/<repo>/main/scripts/server-bootstrap.sh | sudo bash
#   # or: scp it over and run:  sudo bash server-bootstrap.sh
# =============================================================================
set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-deploy}"
APP_DIR="${APP_DIR:-/opt/cloud-cicd-deployment-platform}"

log() { printf '\033[1;32m[bootstrap]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[bootstrap:error]\033[0m %s\n' "$*" >&2; }

if [[ "${EUID}" -ne 0 ]]; then
  err "This script must run as root (use sudo)."
  exit 1
fi

log "Updating apt and installing prerequisites..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl gnupg lsb-release ufw fail2ban

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker Engine from the official repository..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
else
  log "Docker already installed: $(docker --version)"
fi

systemctl enable --now docker

if ! id -u "${DEPLOY_USER}" >/dev/null 2>&1; then
  log "Creating deploy user '${DEPLOY_USER}'..."
  useradd --create-home --shell /bin/bash "${DEPLOY_USER}"
else
  log "User '${DEPLOY_USER}' already exists."
fi

log "Granting '${DEPLOY_USER}' access to the Docker daemon..."
usermod -aG docker "${DEPLOY_USER}"

log "Preparing application directory at ${APP_DIR}..."
mkdir -p "${APP_DIR}"
chown -R "${DEPLOY_USER}:${DEPLOY_USER}" "${APP_DIR}"

# SSH key directory for the CI deploy key.
DEPLOY_HOME="$(getent passwd "${DEPLOY_USER}" | cut -d: -f6)"
install -d -m 700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${DEPLOY_HOME}/.ssh"
touch "${DEPLOY_HOME}/.ssh/authorized_keys"
chmod 600 "${DEPLOY_HOME}/.ssh/authorized_keys"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${DEPLOY_HOME}/.ssh/authorized_keys"

log "Configuring firewall (UFW)..."
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

log "Enabling fail2ban for SSH brute-force protection..."
systemctl enable --now fail2ban

cat <<EOF

============================================================
 Bootstrap complete.

 Next steps:
   1. Add your CI deploy PUBLIC key to:
        ${DEPLOY_HOME}/.ssh/authorized_keys
   2. Store the matching PRIVATE key in GitHub secret:
        SSH_PRIVATE_KEY
   3. Set GitHub secrets: SSH_HOST, SSH_USER (=${DEPLOY_USER}),
        DOCKER_USERNAME, DOCKER_PASSWORD, JWT_SECRET, DATABASE_PASSWORD
   4. Push to main — the pipeline deploys automatically.

 App directory : ${APP_DIR}
 Deploy user   : ${DEPLOY_USER}
 Docker        : $(docker --version)
 Compose       : $(docker compose version | head -1)
============================================================
EOF

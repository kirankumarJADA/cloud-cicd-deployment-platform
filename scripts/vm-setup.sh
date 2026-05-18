#!/usr/bin/env bash
# =============================================================================
# vm-setup.sh
#
# Optional second-pass hardening / tuning, run after server-bootstrap.sh.
# Idempotent. Configures:
#   - a swap file (helps small VMs avoid OOM during image builds/pulls)
#   - Docker daemon log rotation (prevents disk fill from container logs)
#   - sysctl tuning for a containerized web workload
#   - automatic security updates
#
# Usage:  sudo bash vm-setup.sh
# =============================================================================
set -euo pipefail

SWAP_SIZE="${SWAP_SIZE:-2G}"

log() { printf '\033[1;36m[vm-setup]\033[0m %s\n' "$*"; }

if [[ "${EUID}" -ne 0 ]]; then
  echo "Must run as root (sudo)." >&2
  exit 1
fi

# ---- Swap -------------------------------------------------------------------
if ! swapon --show | grep -q '/swapfile'; then
  log "Creating ${SWAP_SIZE} swap file..."
  fallocate -l "${SWAP_SIZE}" /swapfile || \
    dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
else
  log "Swap already present, skipping."
fi

# ---- Docker daemon: log rotation + sane defaults ----------------------------
log "Configuring Docker daemon log rotation..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
JSON
systemctl restart docker

# ---- Kernel tuning for a web workload --------------------------------------
log "Applying sysctl tuning..."
cat > /etc/sysctl.d/99-cloud-cicd.conf <<'SYSCTL'
net.core.somaxconn = 1024
net.ipv4.tcp_tw_reuse = 1
vm.swappiness = 10
fs.file-max = 200000
SYSCTL
sysctl --system >/dev/null

# ---- Unattended security upgrades ------------------------------------------
log "Enabling unattended security upgrades..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

log "VM setup complete."
free -h | sed 's/^/  /'

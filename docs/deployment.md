# Deployment Guide

This walks through a clean production deployment to an Ubuntu VM. Total
hands-on time: ~15 minutes, then every subsequent deploy is fully automatic.

## 0. Prerequisites

- An Ubuntu 22.04 or 24.04 VM with a public IP (AWS EC2, DigitalOcean,
  Hetzner, etc.). 1 vCPU / 2 GB RAM is enough; 2 GB swap is added by `vm-setup.sh`.
- A GitHub repository containing this project.
- An SSH key pair dedicated to deployment (do **not** reuse a personal key).

### AWS EC2 specifics

- AMI: *Ubuntu Server 24.04 LTS*.
- Instance type: `t3.small` or larger.
- Security Group inbound rules: TCP 22 (your IP only), TCP 80, TCP 443.
- Attach a key pair, or add your deploy public key via user-data.

## 1. Bootstrap the VM (once)

SSH in as the default sudo user and run:

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/main/scripts/server-bootstrap.sh | sudo bash
sudo bash /opt/cloud-cicd-deployment-platform/scripts/vm-setup.sh   # optional hardening
```

This installs Docker + Compose, creates the unprivileged `deploy` user,
configures UFW + fail2ban, and prepares `/opt/cloud-cicd-deployment-platform`.

## 2. Install the deploy key

Generate a key pair locally:

```bash
ssh-keygen -t ed25519 -f deploy_key -C "github-actions-deploy" -N ""
```

Append the **public** key on the VM:

```bash
sudo tee -a /home/deploy/.ssh/authorized_keys < deploy_key.pub
```

Keep the **private** key for the next step.

## 3. Configure GitHub Secrets

Repository → Settings → Secrets and variables → Actions → *New repository secret*:

| Secret | Value |
|---|---|
| `SSH_HOST` | VM public IP / hostname |
| `SSH_USER` | `deploy` |
| `SSH_PRIVATE_KEY` | full contents of the private `deploy_key` |
| `DOCKER_USERNAME` | your GitHub username (for GHCR login on the VM) |
| `DOCKER_PASSWORD` | a GitHub PAT with `read:packages` |
| `JWT_SECRET` | `openssl rand -base64 48` |
| `DATABASE_PASSWORD` | `openssl rand -base64 24` |

> Images are pushed using the built-in `GITHUB_TOKEN`; `DOCKER_USERNAME` /
> `DOCKER_PASSWORD` are only used so the VM can *pull* from GHCR.

For the production environment gate, optionally create a GitHub
*Environment* named `production` with required reviewers.

## 4. Deploy

```bash
git push origin main
```

The pipeline runs: `backend-test` + `frontend-build` (parallel) →
`docker-build` (matrix) → `image-push` → `deploy-production`.

`deploy-production` copies compose/nginx/scripts to the VM, renders
`deployment/.env` from secrets, logs the VM into the registry, runs
`deploy.sh` (pull → recreate → health gate → rollback on failure), and runs
the post-deploy smoke test.

Visit `http://<SSH_HOST>/` and sign in with `admin` / `AdminPass123`
(change immediately).

## 5. Enable HTTPS (recommended)

1. Point a DNS A record at the VM.
2. Issue certs (e.g. `certbot certonly --standalone -d your-domain.com`).
3. In `nginx/conf.d/default.conf`, uncomment the 443 server block and the
   HTTP→HTTPS redirect; in `deployment/docker-compose.prod.yml` uncomment the
   `443:443` port and the certs volume mount.
4. Re-deploy (push any commit, or re-run the workflow).

## Manual / emergency deploy

If GitHub is unavailable, from the VM:

```bash
cd /opt/cloud-cicd-deployment-platform
# ensure deployment/.env exists and IMAGE_TAG points at a known-good sha
APP_DIR=$(pwd) ./scripts/deploy.sh
```

## Rollback

`deploy.sh` auto-rolls-back a failed deploy. To roll back a *succeeded* deploy
that turned out bad, set `IMAGE_TAG=sha-<previous>` in `deployment/.env` and
re-run `./scripts/deploy.sh`. The previous good tag is recorded in
`/opt/cloud-cicd-deployment-platform/.deployed_tag`.

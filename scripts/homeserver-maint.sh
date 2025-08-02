#!/usr/bin/env bash
# homeserver-maint.sh — Weekly OS & Docker maintenance for Ubuntu Server
set -euo pipefail

## ─── USER CONFIG ────────────────────────────────────────────────
LOG_DIR="/var/log/homeserver-maint"
STACK_ROOT="/opt"                     # where compose stacks live
KEEP_IMAGES_DAYS=7                    # prune images older than this
HC_URL="https://hc-ping.com/<YOUR-UUID>"
## ────────────────────────────────────────────────────────────────

mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_DIR/$(date +%F).log") 2>&1

curl -fsS -m 10 --retry 3 "$HC_URL/start" || true
trap 'curl -fsS -m 10 --retry 3 "$HC_URL/fail" -d "exit=$?" || true' ERR INT TERM

echo "=== $(date -Is) : Maintenance started ==="
export DEBIAN_FRONTEND=noninteractive

# 1) APT updates
apt-get update -qq \
  -oAcquire::AllowReleaseInfoChange::Suite=true \
  -oAcquire::AllowReleaseInfoChange::Codename=true
apt-get -yq full-upgrade
apt-get -yq autoremove --purge

# 2) Snap refresh (if snaps present)
command -v snap &>/dev/null && snap refresh || true

# 3) Update & redeploy every Compose stack
find "$STACK_ROOT" -maxdepth 2 -type f -name 'docker-compose.yml' | while read -r yml; do
  dir="$(dirname "$yml")"
  echo "[INFO] Updating stack in $dir"
  ( cd "$dir" && docker compose pull && docker compose up -d --remove-orphans )
done

# 4) Docker cleanup
H=$((KEEP_IMAGES_DAYS*24))
docker image     prune -af --filter "until=${H}h" || true
docker container prune -f  --filter "until=${H}h" || true
docker volume    prune -f                       || true
echo "[OK] Docker pruned (≥${KEEP_IMAGES_DAYS} days old)."

# 5) Filesystem & SMART checks
df -hT
for d in /dev/sd?; do smartctl -H "$d" || true; done

echo "=== $(date -Is) : Maintenance finished successfully ==="
curl -fsS -m 10 --retry 3 "$HC_URL" || true

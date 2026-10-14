#!/usr/bin/env bash
# Warfront Mandate: WW3 — initial deployment on the EXISTING DigitalOcean Droplet.
# Source of truth: Claude's active Godot branch (not the outdated main branch).
# This installs the multiplayer SERVER, not a browser/Android client build.
set -Eeuo pipefail
trap 'echo "Deployment stopped on line $LINENO. Check the error above; no game data has been deleted." >&2' ERR

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root from the DigitalOcean Droplet web console: sudo bash deploy-digitalocean.sh" >&2
  exit 1
fi

REPO="https://github.com/pimpurcity-eng/command-of-nations-game.git"
GAME_BRANCH="claude/v0.26-fixes"
DEST="/opt/warfront/command-of-nations-game"
echo "Preparing Warfront Mandate server; using latest $GAME_BRANCH."

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git docker.io docker-compose-v2 caddy
systemctl enable --now docker
systemctl enable --now caddy

# A small amount of swap cushions Docker/Godot imports on the owner's 2 GB VPS.
if [[ ! -e /swapfile-warfront ]] && [[ "$(awk '/MemTotal/ {print $2}' /proc/meminfo)" -le 2500000 ]] && [[ "$(awk '/SwapTotal/ {print $2}' /proc/meminfo)" -eq 0 ]]; then
  fallocate -l 2G /swapfile-warfront
  chmod 600 /swapfile-warfront
  mkswap /swapfile-warfront
  swapon /swapfile-warfront
  grep -q '^/swapfile-warfront ' /etc/fstab || printf '/swapfile-warfront none swap sw 0 0\n' >> /etc/fstab
fi

mkdir -p /opt/warfront
if [[ ! -d "$DEST/.git" ]]; then
  if [[ -e "$DEST" ]]; then
    echo "$DEST already exists without Git metadata. Refusing to overwrite it." >&2
    exit 1
  fi
  git clone --depth 1 --single-branch --branch "$GAME_BRANCH" "$REPO" "$DEST"
else
  cd "$DEST"
  [[ "$(git branch --show-current)" == "$GAME_BRANCH" ]] || { echo "Existing checkout is not on $GAME_BRANCH. Refusing to overwrite." >&2; exit 1; }
  git pull --ff-only
fi
cd "$DEST"

# Only the game's existing PUBLIC Supabase configuration is used.
# NEVER place a Supabase service-role key or login password here.
CFG="game/config/accounts.cfg"
[[ -f "$CFG" ]] || { echo "Missing $CFG; cannot verify account integration." >&2; exit 1; }
SUPABASE_URL="$(grep '^url=' "$CFG" | head -n 1 | cut -d '"' -f 2)"
SUPABASE_ANON_KEY="$(grep '^publishable_key=' "$CFG" | head -n 1 | cut -d '"' -f 2)"
[[ "$SUPABASE_URL" == https://*.supabase.co ]] || { echo "Unexpected Supabase URL." >&2; exit 1; }
[[ "$SUPABASE_ANON_KEY" == sb_publishable_* ]] || { echo "Missing published Supabase client key." >&2; exit 1; }
umask 077
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > server/.env
chmod 600 server/.env

# Match port 8910 is mapped to loopback only. Caddy serves HTTPS + WebSockets.
docker compose --env-file server/.env -f server/docker-compose.yml config --quiet
docker compose --env-file server/.env -f server/docker-compose.yml up -d --build
install -m 0644 server/Caddyfile /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy

echo
echo "Container status:"
docker compose --env-file server/.env -f server/docker-compose.yml ps
echo
echo "Recent match server logs:"
docker compose --env-file server/.env -f server/docker-compose.yml logs --tail=30 match-main
echo
echo "NEXT: Set play.warfrontmandate.com A record to this Droplet public IP."
echo "Then test the server using an account-enabled Warfront Mandate client."
echo "Do not claim the game is playable until login, real WebSocket and match tests pass."

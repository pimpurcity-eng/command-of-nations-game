#!/usr/bin/env bash
# Warfront Mandate: keeps the match server on the newest game code by itself (owner 2026-10-14:
# "am I gonna have to do this every single time we make an update?" - no).
# Run every 15 minutes by the warfront-update systemd timer (see install-auto-update.sh).
# If nothing changed on GitHub it does nothing. If the new build fails, the running server keeps
# going on the old code and the error is in: journalctl -u warfront-update
set -Eeuo pipefail
DEST="/opt/warfront/command-of-nations-game"
cd "$DEST"
BRANCH="$(git branch --show-current)"
git fetch --quiet origin "$BRANCH"
if [[ "$(git rev-parse HEAD)" == "$(git rev-parse "origin/$BRANCH")" ]]; then
  exit 0
fi
echo "New game code on $BRANCH: $(git rev-parse --short HEAD) -> $(git rev-parse --short "origin/$BRANCH")"
git pull --ff-only --quiet
# Build first; only swap the running server once the new image built cleanly.
docker compose --env-file server/.env -f server/docker-compose.yml build
docker compose --env-file server/.env -f server/docker-compose.yml up -d
if [[ -f server/Caddyfile ]] && ! cmp -s server/Caddyfile /etc/caddy/Caddyfile; then
  install -m 0644 server/Caddyfile /etc/caddy/Caddyfile
  caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
fi
docker image prune -f >/dev/null
echo "Match server updated to $(git rev-parse --short HEAD)."

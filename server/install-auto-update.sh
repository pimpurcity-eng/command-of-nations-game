#!/usr/bin/env bash
# One-time install of automatic server updates. Run once as root in the Droplet console:
#   curl -fsSL https://raw.githubusercontent.com/pimpurcity-eng/command-of-nations-game/claude/v0.26-fixes/server/install-auto-update.sh | bash
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
DEST="/opt/warfront/command-of-nations-game"
[[ -d "$DEST/.git" ]] || { echo "Run the first-time server setup (deploy-digitalocean.sh) first." >&2; exit 1; }
cd "$DEST" && git pull --ff-only --quiet
install -m 0755 server/auto-update.sh /usr/local/bin/warfront-update
cat > /etc/systemd/system/warfront-update.service <<'UNIT'
[Unit]
Description=Update the Warfront Mandate match server from GitHub
After=network-online.target docker.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/warfront-update
UNIT
cat > /etc/systemd/system/warfront-update.timer <<'UNIT'
[Unit]
Description=Check GitHub for new Warfront Mandate game code every 15 minutes
[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
Persistent=true
[Install]
WantedBy=timers.target
UNIT
systemctl daemon-reload
systemctl enable --now warfront-update.timer
systemctl start --no-block warfront-update.service || true
echo
echo "DONE. The server now updates itself every 15 minutes. You never need to run anything again."
systemctl list-timers warfront-update.timer --no-pager | head -3

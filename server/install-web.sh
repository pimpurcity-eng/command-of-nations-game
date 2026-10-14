#!/usr/bin/env bash
# One-time setup so play.warfrontmandate.com also serves the browser version of the game.
# Run once as root in the Droplet console:
#   curl -fsSL https://raw.githubusercontent.com/pimpurcity-eng/command-of-nations-game/claude/v0.26-fixes/server/install-web.sh | bash
# It prints ONE line (a public key). Add it on GitHub as a read-only deploy key of the builds
# repository; the server then fetches and updates the web game by itself.
set -Eeuo pipefail
[[ "$EUID" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }
DEST="/opt/warfront/command-of-nations-game"
[[ -d "$DEST/.git" ]] || { echo "Run the first-time server setup first." >&2; exit 1; }
apt-get install -y -qq git-lfs >/dev/null
git lfs install --system --skip-repo >/dev/null
cd "$DEST" && git pull --ff-only --quiet
# The updater always runs the newest updater from GitHub, so future fixes need no new install.
cat > /usr/local/bin/warfront-update <<'WRAP'
#!/usr/bin/env bash
set -Eeuo pipefail
cd /opt/warfront/command-of-nations-game
git fetch --quiet origin "$(git branch --show-current)"
exec bash <(git show "origin/$(git branch --show-current):server/auto-update.sh")
WRAP
chmod 755 /usr/local/bin/warfront-update
mkdir -p /root/.ssh /opt/warfront/web && chmod 700 /root/.ssh
[[ -f /root/.ssh/warfront_builds ]] || ssh-keygen -q -t ed25519 -N "" -C "warfront-server" -f /root/.ssh/warfront_builds
install -m 0644 server/Caddyfile /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile >/dev/null && systemctl reload caddy
systemctl start --no-block warfront-update.service || true
echo
echo "================================================================"
echo "Copy this ONE line and add it on GitHub (builds repo -> Settings -> Deploy keys -> Add deploy key):"
echo
cat /root/.ssh/warfront_builds.pub
echo
echo "Leave 'Allow write access' UNTICKED. The web game appears within 15 minutes after that."
echo "================================================================"

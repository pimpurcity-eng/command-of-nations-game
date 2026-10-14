#!/usr/bin/env bash
# Copies the newest browser version of the game (web/ in the private builds repository) to
# /opt/warfront/web, which Caddy serves at https://play.warfrontmandate.com.
# Read access uses this server's own deploy key (/root/.ssh/warfront_builds); nothing secret
# ever leaves the server. Does nothing until the key has been added on GitHub.
set -Eeuo pipefail
KEY="/root/.ssh/warfront_builds"
REPO="git@github.com:pimpurcity-eng/Command-of-nations-builds.git"
CLONE="/opt/warfront/builds"
WEB="/opt/warfront/web"
[[ -f "$KEY" ]] || exit 0
export GIT_SSH_COMMAND="ssh -i $KEY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"
export GIT_LFS_SKIP_SMUDGE=1
if [[ ! -d "$CLONE/.git" ]]; then
  git clone --quiet --depth 1 --single-branch --branch main "$REPO" "$CLONE" || { echo "Builds repository not reachable yet (deploy key not added on GitHub?)."; exit 0; }
fi
cd "$CLONE"
git fetch --quiet --depth 1 origin main
CURRENT="$(cat "$WEB/.commit" 2>/dev/null || true)"
LATEST="$(git rev-parse origin/main)"
[[ "$CURRENT" == "$LATEST" ]] && exit 0
git reset --quiet --hard origin/main
git lfs pull --include "web/*" --exclude "*.apk"
[[ -f web/index.html && -s web/index.pck && -s web/index.wasm ]] || { echo "Web build incomplete; keeping the current one."; exit 0; }
rm -rf "$WEB.new" && cp -r web "$WEB.new" && echo "$LATEST" > "$WEB.new/.commit"
rm -rf "$WEB.old" && { [[ -d "$WEB" ]] && mv "$WEB" "$WEB.old" || true; } && mv "$WEB.new" "$WEB" && rm -rf "$WEB.old"
echo "Web game updated to $(cat "$WEB/VERSION" 2>/dev/null || echo "$LATEST")."

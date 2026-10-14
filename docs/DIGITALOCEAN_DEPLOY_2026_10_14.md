# Warfront Mandate — DigitalOcean deployment handoff (2026-10-14)

## Infrastructure verified
- The EXISTING Droplet `Warfront-mandate` (ID 608977824) is ACTIVE.
- Public IP: `159.89.82.50`; DigitalOcean region New York 1.
- Ubuntu 24.04 LTS, Basic 2 vCPU / 2 GB RAM / 60 GB SSD, US$18/month.
- Do not create another server. This VPS is already being billed.
- No additional Edge/Cloudflare service is required to start testing.
- The DigitalOcean app connector can read/manage Droplets, **not execute commands inside them**. The bootstrap still needs the DigitalOcean web console (or authenticated SSH). SSH credentials must NEVER be sent in chat.

## Latest game source
- **Do not deploy from `main`**: it is an older, disconnected Git history.
- Deploy from `claude/v0.26-fixes` in `pimpurcity-eng/command-of-nations-game`.
- As of this handoff, PR #11 (dense skyline + dynamic garrison centre + large city-only unit models) and PRs #10, #8, #7, #6, #5 are merged into Claude's line. Six subsequent commits were found after PR #11.
- The online authoritative server, AI control of unoccupied/offline countries, gameplay, economic victory, research, accounts and city changes live in that line. Deploy the actual source, not an earlier Android APK.
- PR #9 anti-cheat is **NOT merged**; its hook-up was not tested against this newest branch. Review and port it separately; don't claim that all unmerged work is in the deployed game.
- Private original 3D models, owner's licensed RAVNIR audio, and Android signing files are not stored in this public repo. The headless match server can be deployed from source but actual Android/browser releases need the verified private assets and export pipeline.

## One-time bootstrap on existing Droplet
Open DigitalOcean → Droplets → Warfront-mandate → Access → Launch Droplet Console. Run as root:
```bash
curl -fsSL https://raw.githubusercontent.com/pimpurcity-eng/command-of-nations-game/chatgpt/digitalocean-deploy-20261014/server/deploy-digitalocean.sh -o /root/warfront-deploy.sh
bash /root/warfront-deploy.sh
```
The script installs Docker/Compose/Caddy, fetches the **current Claude branch**, reads the public Supabase publishable key from the source, builds the persistent match server, and reverse-proxies on `play.warfrontmandate.com`. The compose file binds the private match port to localhost. It preserves existing Docker match-save volumes and refuses to overwrite an unexpected Git directory. Test/dev sign-ins remain disabled in production.

## Still needed to finish public deployment
1. Confirm bootstrap completes and container stays healthy. Inspect `docker compose --env-file server/.env -f server/docker-compose.yml logs --tail=100 match-main`. Existing tests only prove previous local builds, not this server.
2. In the account that hosts DNS for `warfrontmandate.com`, point **A record `play`** to `159.89.82.50`. Caddy must be able to receive ports 80/443 to issue its HTTPS certificate.
3. Connect a fresh, account-enabled Android client to `wss://play.warfrontmandate.com`, confirm a real registered sign-in, create a match, close/reopen clients, verify save/resume, AI takeover and competitive visibility.
4. Investigate phone crash/performance and provide a NEW signed APK with owner's original private model library, licensed audio and signing identity. Do not substitute an untested screenshot/concept.
5. The multiplayer VPS is not by itself a browser-playable website; exporting the Godot web game and publishing the website is separate.

## Verification
- DigitalOcean API: account active, one active $18 Droplet. No server shell commands were run at creation of this file.
- GitHub: based this handoff branch on Claude's latest branch. Script newly authored; **runtime deploy and DNS not yet verified**.

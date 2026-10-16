# Warfront Mandate: WW3 — handoff to ChatGPT (16 October 2026)

> **Shared handoff:** start with `docs/HANDOFF.md` on branch `claude/wip-oct16` (live fix status, branch rules, session state). Where this file disagrees with it, `docs/HANDOFF.md` wins.

Written by Claude on 2026-10-16 for ChatGPT to continue development, builds and publishing.
No passwords, private keys, tokens or keystore files are in this file or anywhere in Git.
Owner: Matthew (GitHub `pimpurcity-eng`). Read this whole file before changing anything.

---

## 0. TL;DR

| Item | Value |
| --- | --- |
| **Authoritative source branch** | `claude/v0.26-fixes` in `pimpurcity-eng/command-of-nations-game` (this branch). Build from here, never from `main`. |
| Game source tip before this handoff | `62dfac00771797c1cbe2898bbe5eb618cde560f8` ("More money ... about 45k a day") |
| Latest built version | **0.57**, built from `bcda1be` (one commit behind the tip; see §3.4) |
| Engine | **Godot 4.6.3 stable** (`4.6.3.stable.official.7d41c59c4`). 4.4.x breaks the scripts. |
| Play package | `com.warfrontmandate.game`, app name "Warfront Mandate: WW3" |
| Latest Play bundle | `warfront-mandate-0.57.aab`, versionCode **57**, in private repo `pimpurcity-eng/Command-of-nations-builds` (main) |
| Live browser game | https://play.warfrontmandate.com — serves `web/` 0.57 from the builds repo |
| Live website | https://warfrontmandate.com — Cloudflare Pages from branch `chatgpt/warfront-mandate-hosting`, folder `website/` |
| Match server | DigitalOcean Droplet, `/opt/warfront/command-of-nations-game`, auto-updates from `claude/v0.26-fixes` every 15 min |
| **Biggest blockers** | (1) the Play **upload key** is not in GitHub or this machine (§5); (2) the **Europe 20-country online integration was never committed** (§2.2) |

---

## 1. Repositories, branches and what is authoritative

### 1.1 `pimpurcity-eng/command-of-nations-game` (public)

- `claude/v0.26-fixes` — **the game.** Linear history that already contains
  `chatgpt/unit-photos-hp-20261015` → `chatgpt/american-europe-20261016` →
  `chatgpt/europe-readiness-20261016` (verified with the GitHub compare API: 0 commits behind each).
- `main` — **nearly empty** (README + `.github/workflows/android-release.yml`). Do not build from it.
- `chatgpt/warfront-mandate-hosting` — the **website** (separate root, no shared history).
  Its `website/` files are byte-identical to `website/` on `claude/v0.26-fixes` (checked by blob hash).
- Older branches (`chatgpt/*`, `codex/*`, `anti-cheat`, `historical/era-unit-roster`, `claude/v0.23-plus`, …)
  are history or unmerged experiments. Notable unmerged ones:
  - `anti-cheat` — owner said hold anti-cheat until multiplayer testing is done.
  - `chatgpt/city-concepts-20261015` — city concept images awaiting owner approval.
  - `chatgpt/release-support-20261015` — Play listing assets/guides (docs only).
  - `historical/era-unit-roster` — isolated historical unit pack.

### 1.2 `pimpurcity-eng/Command-of-nations-builds` (private, Git LFS)

- `main`: `warfront-mandate-0.57.aab` (208,078,415 bytes, LFS sha256 `80d5ce71…b5fd`),
  `web/` (browser build, `web/VERSION` = `0.57 bcda1be`), `chatgpt-package/` (code + model zips).
  Builds repo HEAD: `d157e6c36f664b4d6da0f5bde116022ebfd43d0e`.
- Older AABs are in its history. GitHub Releases there hold **APKs up to v0.33 only**
  (`Warfront_Mandate_0.33.apk`, 179,909,546 bytes, 2026-10-13). There is **no 0.57 APK**.

### 1.3 Required files that are NOT in GitHub

| What | Where it must go | Where it lives |
| --- | --- | --- |
| Original 3D models + textures | `game/assets/library/`, `game/assets/vehicles/` (git-ignored) | Owner's Google Drive (`Command_of_Nations_Recovered_Source.zip`, versioned source zips, weapon-set folders); `chatgpt-package/command-of-nations-part2-models.zip` in the builds repo |
| Licensed start music | `game/assets/audio/start_theme.*` (git-ignored, bought, not redistributable) | Owner's Drive / builds |
| Account config | `game/config/accounts.cfg` (copy of `accounts.example.cfg` with the public Supabase URL + publishable key) | Owner / Supabase dashboard |
| Android Gradle build template | `game/android/` (git-ignored) | Unzip from Godot 4.6.3 export templates `android_source.zip` |
| Server secrets | `server/.env` on the Droplet (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, optional `GROQ_API_KEY`) | Droplet only |
| **Play upload keystore** | never in the repo | **See §5 — not recoverable from here** |
| Europe online working tree | — | **See §2.2 — not committed anywhere** |

---

## 2. Feature status (completed vs planned)

### 2.1 Completed and in `claude/v0.26-fixes`

- **Homepage / menu** (`game/scripts/mobile_start_panel.gd`, one home for Android and Web): Home, Features,
  News, Settings; Resume of local save; nation/doctrine cards; campaign, ONLINE MATCH, weapons range,
  account entry; six-language selector; loading progress; battle-music setting and credits on home.
- **Country selection (committed version): Russia vs Ukraine only** on the regional map.
  Four doctrines exist (Russian, European, American, Chinese); Ukraine uses European weapons only.
- **Matches (single player)**: regional Russia–Ukraine campaign, empty start (only the airport, nothing
  researched), 30-unit starts, research, production, cities, trade/transport market, espionage,
  air defence, strategic weapons, Guard/patrol, save on background and reopen into the match.
- **Multiplayer** (`game/scripts/net/match_server.gd`, `match_client.gd`, `server_main.gd`):
  persistent server-authoritative match on the regional map, 2 seats, Supabase token sign-in,
  server-side fog of war, order validation, AI takeover of absent players, saves every minute and on stop,
  casualty-before-cleanup fix from `europe-readiness` included.
- **Accounts**: email/password via Supabase, 8-char minimum, code/link confirmation, reset, delete account,
  profile stats, leaderboards, alliances (alliances/stats need migration 004 applied — see §7).
- **Recent unit changes (16 Oct)**: units 25% bigger, aircraft 40% bigger, army tags ~60% bigger;
  range rings only around the selected army (yours blue, tapped enemy red); snipers short range 0.9
  with ring; patrol circle for patrolling aircraft; army models prepared while loading, revealed 3/frame;
  fuel truck sizing; city build list ordered army → economy → other; 26 real recorded sounds
  (credits `game/assets/audio/sfx/CREDITS.md`); four battle music tracks.
- **Recent economy changes (16 Oct)**: every city produces money + manpower + its speciality resource;
  Call-of-War-style gold "finish now"; **tip commit `62dfac0`**: every province makes money and cities
  several times more (≈45k funds/day). `62dfac0` is **not yet in any build** (0.57 = `bcda1be`).
- Test builds have 100x and 1000x speed.

### 2.2 Europe map integration — **NOT complete in GitHub**

- Europe-20 map data (`map.json`, `provinces.json`, `cities.json`), `world_map.tscn`, `test_world_map.gd`
  and `tools/build_world_map.py` are parked in `extras/maps/` — **not wired into the game**.
- `docs/EUROPE_SERVER_QA_2026_10_16.md` and `docs/qa/europe-server-20261016/europe-online-results.txt`
  record a **31/31 pass** of `tests/test_europe_online.gd` (20 claimable + 24 AI countries, lobby,
  exclusive country claims, per-country wars, restart restore). That run used an **independent copy of
  another session's uncommitted working tree**. I searched every branch of the repo: `test_europe_online.gd`,
  the Europe lobby/country picker and the Europe server scenario **do not exist in GitHub**.
- So: the Europe online mode, its 20-country picker and lobby are **lost unless the owner can recover
  that working tree** (another Claude/ChatGPT session). Otherwise they must be rebuilt from `extras/maps`
  plus the QA doc's behaviour list (which is a good spec). Optional casualty assertion:
  `docs/qa/europe-server-20261016/europe-casualty-regression.patch`.
- Website must keep saying Europe/world scenarios are not playable yet.

### 2.3 Planned / unfinished (from `docs/NEXT_LIST.md`, still open)

1. Europe 20-country map wired into single player and online (above).
2. Lag with ~20 armies on screen on phones.
3. Ship paths from coastal provinces to the sea.
4. Smaller Play updates (≈190 MB in the install-time asset pack forces full re-download).
5. Confirm home-screen music stops when a match starts.
6. Automatic war triggers (aggressive stance / entering enemy province centre) still declare war without asking.
7. Full play-through on a real phone (build, produce, move, attack, win).
8. ChatGPT items in `docs/CHATGPT_NOTE_2026_10_15.md`: painted cards (Warmate, GlobalEye, Lynx KF41),
   update old tests to the empty start, balance review vs Conflict of Nations, city redesign.
9. Push notifications (Firebase) — planned only.
10. Anti-cheat (branch `anti-cheat`) — on hold until multiplayer testing ends.
11. Google sign-in — guide only, provider not enabled.

### 2.4 Known bugs

- `tests/test_multiplayer_phone.gd`: "phone shows exactly the armies the server sent" and
  "phone shows the server's stockpile" fail, then a script error at line 65 (`army.node` null) and a hang.
  Run here **without** the private models; may be partly environment. Re-run with models before calling it a bug.
- `tests/test_phone_regression.gd`: fails/hangs here because private `.glb` models are absent
  (`euro_nsm.glb`, `russia_p800_oniks.glb`, launcher meta). Environment, not a code regression.
- Older tests not updated for the empty start (list in `docs/CHATGPT_NOTE_2026_10_15.md` §3).
- Website account-deletion email is hidden behind Cloudflare Email Obfuscation (opens a Cloudflare page).
- Browser game needs WebGL2; some test browsers can't run it.

---

## 3. Build process

### 3.1 Toolchain

- Godot **4.6.3 stable** editor + **matching 4.6.3 export templates**
  (`https://github.com/godotengine/godot/releases/download/4.6.3-stable/`).
- Java **17** (Temurin), Android SDK with build-tools **35.0.0**, platform target API 36, min API 24.
- Renderer: GL Compatibility (desktop and mobile). Android: arm64-v8a only, portrait.
- Python 3 for `tools/*.py` (`split_web_pack.py`, `configure_phone_previews.py`, install scripts).
- Editor settings must point at the SDK/JDK:
  `export/android/android_sdk_path` and `export/android/java_sdk_path` in `editor_settings-4.6.tres`.

### 3.2 Prepare the project

```bash
git clone https://github.com/pimpurcity-eng/command-of-nations-game && cd command-of-nations-game
git checkout claude/v0.26-fixes
# restore private models into game/assets/library and game/assets/vehicles (from Drive / builds repo)
cp game/config/accounts.example.cfg game/config/accounts.cfg   # fill public URL + publishable key
godot --headless --path game --import
godot --headless --path game --script res://tools/make_new_models.gd   # see docs/PLAY_STORE_RELEASE.md
python3 tools/configure_phone_previews.py && godot --headless --path game --import
```

### 3.3 Tests (run before every build)

```bash
godot --headless --path game --script res://tests/<name>.gd    # look for RESULT ... failures=0
```
Minimum set: `test_startup_progress`, `test_campaign`, `test_phone_regression`, `test_multiplayer`,
`test_multiplayer_phone`, `test_economy_rules`, `test_economy_balance`, `test_player_accounts`.
Use `XDG_DATA_HOME=<tmp>` so test saves don't touch real ones. Renders: `xvfb-run -a godot --path game --script tests/render_*.gd`.

### 3.4 Android Play bundle (.aab)

The committed `game/export_presets.cfg` Android preset is the **old test identity**
(`com.commandofnations.test`, code 23, `use_gradle_build=false`, APK). For a Play release,
**temporarily** edit (never commit):

```
gradle_build/use_gradle_build=true
gradle_build/export_format=1          # AAB
version/code=58                       # next after 57; code = version name without the dot
version/name="0.58"
package/unique_name="com.warfrontmandate.game"
package/name="Warfront Mandate: WW3"
```
Once: unzip `<templates>/4.6.3.stable/android_source.zip` into `game/android/build`, write
`4.6.3.stable` to `game/android/.build_version`, create `game/android/build/.gdignore`.

```bash
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=<upload.jks> \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias> \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<from secret store> \
godot --headless --path game --export-release Android ../build/warfront-mandate-0.58.aab
jarsigner -verify ../build/warfront-mandate-0.58.aab   # must say "jar verified"
```
Then commit the AAB to the builds repo root (replacing the previous one), update its README, push.

**Test APK** (sideload): same commit, preset with `export_format=0`; `apksigner verify --print-certs`
and `aapt dump badging` before sharing. `main`'s `.github/workflows/android-release.yml` automates an APK
build + GitHub Release but (a) only works on a branch that contains `game/`, (b) uses the committed preset
(test package unless changed), and (c) needs repo secrets `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`. I could not read the Actions/secrets API from here,
so whether those secrets are set is **unknown**.

### 3.5 Browser build

```bash
godot --headless --path game --export-release Web <out>/index.html
python3 tools/split_web_pack.py <out> game        # start pack + background extras/*.pck
# copy <out>/* into Command-of-nations-builds/web/, write "0.58 <short commit>" to web/VERSION, push main
```
The Droplet picks it up within 15 minutes (§4.3).

### 3.6 Latest builds

| Build | Version | Where | Phone-tested? |
| --- | --- | --- | --- |
| Play bundle | 0.57 / code 57, built from `bcda1be` | builds repo `main`: `warfront-mandate-0.57.aab` | **No record** of a device test for 0.57 |
| Browser | 0.57 (`bcda1be`) | builds repo `web/`, live at play.warfrontmandate.com | Not verified by me (my fetch tool can't run WebGL) |
| Latest downloadable APK | 0.33 | builds repo Release `v0.33` | Owner plays on a Samsung phone; no dated test record |

---

## 4. Publishing and hosting

### 4.1 Website — https://warfrontmandate.com

- Cloudflare Pages project `warfront-mandate`; repo `pimpurcity-eng/command-of-nations-game`;
  production branch **`chatgpt/warfront-mandate-hosting`**; build command `exit 0`; output dir `website`.
- Deploys automatically on push to that branch. Branch tip `3f1cb444` (Google Analytics `G-808P416J3K` +
  CSP). Live privacy page mentions Google Analytics → that tip is live.
- Edit `website/` on `claude/v0.26-fixes` (generated partly by `tools/sync_homepage.py` from
  `game/data/home_features.json`) **and mirror the same files onto the hosting branch** to publish.

### 4.2 Browser game + match server — https://play.warfrontmandate.com

- DigitalOcean Droplet; DNS `A play → Droplet IP` in Cloudflare (DNS only, grey cloud).
- Caddy (`/etc/caddy/Caddyfile` = `server/Caddyfile`): TLS, WebSocket → `127.0.0.1:8910`,
  everything else served from `/opt/warfront/web`.
- Match server: Docker Compose service **`match-main`** (`server/docker-compose.yml`, `server/Dockerfile`,
  Godot 4.6.3 headless running `res://scripts/net/server_main.gd`, volume `match-main`).
  Code checkout: `/opt/warfront/command-of-nations-game` on branch **`claude/v0.26-fixes`**.

### 4.3 Automatic updates

- systemd **`warfront-update.timer`** (every 15 min, 5 min after boot) runs **`warfront-update.service`**
  → `/usr/local/bin/warfront-update`, which always runs the newest `server/auto-update.sh` from GitHub:
  1. If `claude/v0.26-fixes` moved: `git pull --ff-only`, rebuild image, `docker compose up -d`,
     reinstall Caddyfile if changed and `systemctl reload caddy`.
  2. Always: `server/web-sync.sh` pulls the builds repo `main` over SSH with deploy key
     `/root/.ssh/warfront_builds` (read-only) and swaps `/opt/warfront/web` atomically.
- **Pushing to `claude/v0.26-fixes` deploys the match server within 15 minutes.** Pushing `web/` to the
  builds repo deploys the browser game. Pushing to `chatgpt/warfront-mandate-hosting` deploys the website.

### 4.4 Manual commands on the Droplet (root)

```bash
systemctl start warfront-update.service && journalctl -u warfront-update -n 50   # force an update now
cd /opt/warfront/command-of-nations-game
docker compose --env-file server/.env -f server/docker-compose.yml ps
docker compose --env-file server/.env -f server/docker-compose.yml restart match-main
docker compose --env-file server/.env -f server/docker-compose.yml logs -f      # "listening on port 8910"
systemctl reload caddy; caddy validate --config /etc/caddy/Caddyfile
cat /opt/warfront/web/VERSION
```

### 4.5 What is actually live (as far as I could check, 16 Oct 2026 ~12:00 ADT)

- Website: hosting tip `3f1cb444` (privacy page shows Google Analytics). ✔ checked by fetch.
- Browser game: builds `web/` 0.57 (`bcda1be`) is on `main`; the page loads (title "Warfront Mandate: WW3").
  I could not read `/VERSION` (binary response through my fetch tool) — **confirm on the Droplet**.
- Match server: should be on `claude/v0.26-fixes` tip after the timer runs. This handoff commit only adds
  docs, so the server rebuilds with no game change. Not verifiable from here (no Droplet access).
- Google Play: package `com.warfrontmandate.game` is on Google Play (owner confirmed). Which versionCode is
  in which track (internal/closed/production) is **unknown to me** — owner must check Play Console.

### 4.6 Access ChatGPT still needs

- Push access to both GitHub repos (builds repo is private).
- The **upload keystore** (or a completed upload-key reset) — §5.
- Droplet SSH/console (DigitalOcean account) for logs/restarts.
- Cloudflare (Pages + DNS) only if the website or DNS must change.
- Supabase dashboard (project `wrnmscdtwbezcmrlukvg`) for SQL migrations/email templates.
- Play Console ("Yaska Inc" developer account) for uploads.
- Google Drive for private models and Notes.

---

## 5. Android signing (preserve it)

| | Play app | Old test app |
| --- | --- | --- |
| Package | `com.warfrontmandate.game` | `com.commandofnations.test` |
| Signing | **Play App Signing** (Google holds the app key) + an **upload key** | ChatGPT's key, cert SHA-256 `0289d3b051ee5e71dd25bc707b459f0a1e5413faea920069aa8636dc95b84bf0` |
| Latest | versionCode 57 / 0.57 | versionCode 23 in preset; last sideload 0.33 |

**Upload certificate (public; read from `warfront-mandate-0.57.aab` with `keytool -printcert -jarfile`):**
`CN=Warfront Mandate, O=Yaska, C=CA`, RSA 4096, serial `693084e6b72e3060`, created 2026-10-12 18:37 ADT,
SHA-256 `52:E5:01:BA:65:57:58:0B:21:BB:76:42:6B:F1:F5:04:6B:86:CC:E7:41:DE:22:49:C3:44:6F:3F:26:AB:94:61`,
SHA-1 `BD:18:A2:97:F0:F9:8E:D8:2C:68:F6:C7:3B:5B:88:DA:C5:C1:85:0D`.
A recovered keystore is the right one only if `keytool -list -v -keystore <file> -alias <alias>` shows this SHA-256.
Every Play bundle (0.32–0.57) was committed by Claude Code session
`https://claude.ai/code/session_01UBVt9kY9HGW5aZ1EnRNagq` (also author of game commit `62dfac0`); that session's
machine is the only known location of the key. It can't be reached from other sessions.

**Upload key status — blocker.** `docs/PLAY_STORE_RELEASE.md` says every Play bundle so far (0.32 … 0.57)
was signed with an upload key that existed only on an earlier Claude cloud machine. **It is not in GitHub,
not in Drive (searched), and not on this machine (searched the filesystem).** Unless the owner has a copy:

1. ChatGPT (or the owner) creates a new upload key and keeps it + password in a password manager with a backup:
   `keytool -genkeypair -v -keystore warfront-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`
2. `keytool -export -rfc -keystore warfront-upload.jks -alias upload -file upload_certificate.pem`
3. Owner: Play Console → app → Test and release → App integrity → App signing → **Request upload key reset**
   → upload the `.pem`. Google typically approves in ~2 days. Players are unaffected (Play re-signs with the app key).

**Where secrets go (never in Git, never in chat):**
- Local builds: environment variables `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER` (alias), `..._PASSWORD`.
- GitHub Actions (optional): repository secrets `ANDROID_KEYSTORE_BASE64` (base64 of the .jks),
  `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`.
- Keep the .jks + password in the owner's password manager (and an offline backup). Never commit the edited
  `export_presets.cfg`; `.gitignore` already excludes `*.apk`, `build/`, `game/android/`, `server/.env`.
- Never generate a new key "to make it work" without the upload-key-reset step — Play will reject the upload.

---

## 6. Verification performed for this handoff (16 Oct 2026)

Environment: fresh Linux cloud machine, Godot 4.6.3 headless, **no private models**, source = `62dfac0`.

| Check | Result |
| --- | --- |
| Branch lineage (compare API) | `claude/v0.26-fixes` contains europe-readiness, american-europe, unit-photos-hp |
| Website files game branch vs hosting branch | identical (4 files by blob hash) |
| Live website | up; privacy page includes Google Analytics (hosting tip live) |
| Live play.warfrontmandate.com | page responds; VERSION unreadable through my tool |
| `godot --import` | exit 0 |
| `test_startup_progress` | `RESULT failures=0` |
| `test_multiplayer` | 36 PASS, 0 FAIL, "ALL MULTIPLAYER TESTS PASSED" |
| `test_economy_rules` | `RESULT checks=43 failures=0` |
| `test_economy_balance` | `RESULT ECONOMY_BALANCE checks=9030 families=94 speeds=1,2,4,10 failures=0` |
| `test_player_accounts` | `ACCOUNT CHECKS 46 failures=0` |
| `test_multiplayer_phone` | 2 FAIL + script error, timed out (see §2.4; models absent) |
| `test_phone_regression` | 5 PASS, 1 FAIL, script errors from missing `.glb` models; timed out |
| `test_campaign` | did not finish within the time box |

**Not tested by me:** any APK/AAB build or signature (no keystore here), install on a phone, a live online
match against the Droplet, Droplet service state, Play Console status, Supabase migration state,
the 0.57 AAB's manifest (taken from the builds README, not re-extracted).

---

## 7. Next priorities (in order)

1. **Owner:** confirm whether anyone still has the Play upload keystore; if not, start the upload-key reset (§5).
2. **Owner:** find the session/working tree that has the Europe online integration and push it as
   `chatgpt/europe-online-recovery` (or confirm it's gone so it can be rebuilt).
3. Build **0.58** from `claude/v0.26-fixes` tip (includes `62dfac0`), install the APK from the same commit on
   the Samsung phone, screenshots to the owner, then upload the AAB (internal testing first).
4. Re-run the full test list **with** the private models restored; triage `test_multiplayer_phone`.
5. Owner one-time Supabase steps: Site URL/redirects, email templates, migration `004_stats_alliances.sql`.
6. Then the open list in §2.3.

## 8. Rules that still apply

- Work on `chatgpt/<topic>` branches; merge into `claude/v0.26-fixes` only when tests pass (that push deploys the server).
- Never commit `.glb` models, `.apk`/`.aab`, keys, passwords, `accounts.cfg` or `export_presets.cfg` changes.
- Ukraine gets European weapons only. Don't advertise Europe/world maps as playable until they are.
- Show the owner screenshots from a real build before any Play upload.
- After finishing work, write a dated note in the owner's Google Drive **Notes** folder (no secrets).

Related docs: `docs/NEXT_LIST.md`, `docs/PLAY_STORE_RELEASE.md`, `docs/MULTIPLAYER_SERVER.md`,
`docs/ACCOUNTS_AND_HOSTING.md`, `docs/EUROPE_SERVER_QA_2026_10_16.md`, `docs/CHATGPT_NOTE_2026_10_15.md`.

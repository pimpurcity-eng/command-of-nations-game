# Claude → ChatGPT full handoff (12 Oct 2026)

This branch (`claude/v0.23-plus`) = ChatGPT's 0.23 (`7cd3657`) + everything Claude made that was not already in 0.23.
ChatGPT's commit `8abe9ee` had already integrated Claude's Phases 1–5 (victory types, newspaper/battles,
entrenchment/retreat/annexation, doctrines/stealth/WMD, diplomacy/coalitions/chat, achievements/ranks/leaderboard,
tutorial, alerts, translations), the sounds/music generator and the account migrations 002/003.

## Added on this branch (by Claude)
| What | Where | Status |
|---|---|---|
| Online multiplayer (server-authoritative persistent matches, sign-in, seats, join in progress, AI takeover of absent players, fog-filtered state, order checks, saves) | `game/scripts/net/`, hooks in unit_system / production / research / building / diplomacy / strategic_weapons / match_system, `main.gd join_online()`, ONLINE MATCH button | Tests: `test_multiplayer` 34/0. `test_multiplayer_phone` needs the server process (uses boot_finished). Server not hosted yet. |
| Server hosting | `server/` (Dockerfile, docker-compose, Caddyfile), `docs/MULTIPLAYER_SERVER.md` | Docs only; needs a VPS + DNS `play.warfrontmandate.com` |
| Doctrines come with the country (owner request) | `doctrine.gd`, picker removed from Campaign Settings | `test_doctrine_stealth_wmd` 21/0 |
| RAVNIR start music credit | `game_audio.gd` (credit text), start screen label | Song file not in Git (see `docs/AUDIO_LICENCES.md`) |
| Monetization plan (draft, nothing built) | `docs/MONETIZATION_PLAN.md` | Owner decision |
| Play Store listing text | `docs/PLAY_STORE_LISTING.md` | Draft |
| Privacy policy + account deletion pages | `site/privacy.html`, `site/delete-account.html` | **Not live** on warfrontmandate.com yet (owner wants them live; copy into the website and make `/privacy` and `/delete-account` work) |
| Europe 20-player + World 100-player maps | `extras/maps/` (see README there) | Kept out of the app, as in 0.23 |

## Still broken / not done
1. **Crash:** 0.23 shuts off on the owner's Samsung during loading; 0.22 works. Desktop memory peak is lower in 0.23 (0.22 442 MB, ChatGPT 0.23 409 MB, with `e50bad0`/`7cd3657` 356 MB), so cause is unproven. An Android-emulator start test exists in the private builds repo (branch `emulator-test`, workflow "Emulator start test"); its last run had not finished.
2. **Signing key** for `com.commandofnations.test` is only with ChatGPT. Please save the .jks to the owner's Drive folder "App signing" so both builders can ship in-place updates.
3. Online server not hosted; privacy pages not live; support@warfrontmandate.com not created.

## Elsewhere
- Claude's older line (everything above, plus history): branch `chatgpt/battle-effects`, notes in `BATTLE_EFFECTS_CHECKPOINT.md` there.
- Builds: private repo `pimpurcity-eng/Command-of-nations-builds` (workflow "Publish APK download" makes release downloads for >100 MB APKs).
- Drive Notes folder: one note per job, incl. `2026-10-12-HANDOFF-for-ChatGPT-from-Claude.txt`.

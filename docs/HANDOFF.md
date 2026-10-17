# Warfront Mandate: WW3 — shared handoff (Claude ⇄ ChatGPT)

**This is the one file both AIs read first and update last, every session.**
Owner: Matthew (GitHub `pimpurcity-eng`). No passwords, keys, tokens or keystores here or anywhere in Git.
Older notes (`CHATGPT_HANDOFF.md`, `docs/NEXT_LIST.md`, `docs/CHATGPT_NOTE_2026_10_16.md`,
`docs/START_HERE_SECOND_CLAUDE.md`) are background only; where they disagree with this file, this file wins.

## 1. Session rules

1. Start: `git fetch`, check out `claude/wip-oct16`, read §3 and §5 of this file.
2. **One fix at a time:** change → run the related tests → commit → push → update §3 and §4 → tell Matthew in
   plain words what changed and what to test in the game.
3. Push **only** to `claude/wip-oct16` (or a branch named in §2). Never push to or merge into
   `claude/v0.26-fixes` until Matthew has tested the WIP fixes. Never force-push.
4. Before starting, check §5 "In progress" so two sessions never work on the same fix.
5. Don't edit `export_presets.cfg`. Don't build or publish the Play app or website from WIP.
6. Code comments cite the owner with a date, e.g. `## Owner 2026-10-16: ...`.
7. End of session: fill in §5 and add a dated one-line pointer note in Google Drive → **Notes**.

## 2. Branches and live systems

| What | Where |
| --- | --- |
| Working branch | `claude/wip-oct16` — unfinished Oct 16 fixes. **Do not build from it.** |
| Tutorial repair review | `chatgpt/training-flow-fix-20261017`, based on `claude/v0.61` at `585e635`. Matthew requested preserving Claude's design and repairing the flagship tutorial. Source review only; no publication. |
| Release audit | `chatgpt/release-oct16` — ChatGPT's current full-game check; owner authorized fixing and publishing after the review. |
| Stable branch | `claude/v0.26-fixes` — buildable game; the match server auto-updates from it every 15 min. |
| Merge plan | When the WIP list is finished and tested: merge WIP into stable, reverting `20c7171` (the commit that moved WIP off stable). Matthew approves first. |
| Builds repo | `pimpurcity-eng/Command-of-nations-builds` (private): latest **0.57** = `bcda1be`, versionCode 57. |
| Website | https://warfrontmandate.com — branch `chatgpt/warfront-mandate-hosting`, folder `website/`. |
| Browser game | https://play.warfrontmandate.com |
| Supabase | project `wrnmscdtwbezcmrlukvg`. Migrations applied: foundation, hardening, achievements, **004 stats_alliances, 005 premium** (both live 16 Oct). |
| Engine | Godot **4.6.3 stable** (4.4.x breaks the scripts). |

Tests: `rm -f "$HOME/.local/share/Command of Nations/resume.cfg"` then
`cd game && timeout 1500 xvfb-run -a godot --path . --script tests/<test>.gd` (one at a time).
Some tests need the private `.glb` models (Google Drive / builds repo); note it if a failure is only missing models.

## 3. Oct 16 fix list (Matthew's numbers)

Status: ✅ done (needs Matthew's in-game check) · 🔧 in progress · ⬜ to do · ⏭ skipped by Matthew · ❓ question · ⏸ on hold (Matthew said wait)

| # | Fix | Status | Commit / note |
| --- | --- | --- | --- |
| 1 | Colour bar check | ⏭ | |
| 2 | Same start amount in every slot | ⏭ | |
| 3 | 6 vs 7 cities | ⏭ | |
| 4 | More money, Call of War style (~45k/day per country) | ✅ | `f8033ad` |
| 5 | Can't buy too much at the start | ✅ | |
| 6 | Units cost money + manpower + 2 resources | ✅ | |
| 7 | Google sign-in in the Android app | ✅ | Supabase redirect `warfrontmandate://auth-callback` |
| 8 | Create account without a code box | ✅ | |
| 9 | Premium account groundwork | ✅ | `29de857` and snapshots; `docs/PREMIUM.md`; migration 005 live |
| 10 | Units render earlier when zooming/tapping | ✅ | phones load on-screen models between zoom 45 and 30 (`PREPARE_ZOOM`); `test_zoom_visibility` 8/8 |
| 11 | Units easier to tap | ✅ | tap reach was in raw phone pixels (~3 mm on a 1080-1440 px phone); now scaled to the screen (`TapScale`). `test_tap_scale` |
| 12 | Camera jiggle | ✅ | tap wobble (14 px) and pinch dead zone were in raw phone pixels, so a normal tap nudged the map; now scaled to the screen. Earlier smoothing work kept. `test_tap_scale`, `test_camera_pinch_anchor` |
| 13 | Messages in Diplomacy | ✅ | verified by `test_oct16_diplomacy_news` (12/12) |
| 14 | Diplomacy shows this map's alliance only | ✅ | verified by `test_oct16_diplomacy_news` (12/12) |
| 15 | Show which country is leading | ✅ | verified by `test_oct16_diplomacy_news` (12/12) |
| 16 | Better newspaper anyone can post in | ✅ | verified by `test_oct16_diplomacy_news` (12/12) |
| 17 | Remove the horse-racing sound | ✅ | |
| 18 | Game speed affects every timer | ✅ | verified by `test_oct16_pacing` (329 pass, 0 fail) |
| 19 | Units move too fast | ✅ | verified by `test_oct16_pacing` (329 pass, 0 fail) |
| 20 | Faster on own land, terrain matters | ✅ | verified by `test_oct16_pacing` (329 pass, 0 fail) |
| 21 | Level-1 buildings 30 min at 1x, harder after | ⏸ | Matthew 2026-10-16: "yes, but wait on that" — ON HOLD. Data is 30 min; Ukraine shows 33 because of the European doctrine (×0.9). Before starting, confirm with Matthew which way (keep the penalty, or apply it to units only). |
| 22 | Level-1 unit research 30 min–2 h | ✅ | verified by `test_oct16_pacing` (329 pass, 0 fail) |
| 23 | Every unit's first level by day 6 (except nukes) | ✅ | verified by `test_oct16_pacing` (329 pass, 0 fail) |
| 24 | Battle animation ~5 s, then still until next shot | ✅ | verified by `test_oct16_combat` (38/38) |
| 25 | Planes can attack enemy planes | ✅ | verified by `test_oct16_combat` (38/38) |
| 26 | Patrol hits regularly (65% of a strike) | ✅ | verified by `test_oct16_combat` (38/38) |
| 27 | Air defence hits patrolling planes | ✅ | verified by `test_oct16_combat` (38/38) |
| 28 | Heal armies with gold | ✅ | verified by `test_oct16_combat` (38/38) |
| 29 | Attacker at a city shows as attacker | ✅ | verified by `test_oct16_combat` (38/38) |
| 30 | Fire modes: fire at will / return fire / hold fire | ✅ | verified by `test_oct16_combat` (38/38) |
| 31 | City screen: resources only, no tank picture | ✅ | |
| 32 | Visible production countdown | ✅ | |
| 33 | Clear building vs unit icons | ✅ | |
| 34 | Bigger reports | ✅ | in code (full-screen reports, 28–34 px type); no automated check — look on a phone |
| 35 | Show how you won; why the win came early | ✅ | verified by `test_oct16_pacing` (result says how it was won; elimination needs the capital too) |
| 36 | Rally spot for new troops | ✅ | bug fixed: a unit that appears standing on its rally point was refused ("no land route"); now counts as arrived. `test_oct16_premium_rally` all pass |
| 37 | Queued troops go to the rally spot (free) | ✅ | verified by `test_oct16_premium_rally` (every queued unit goes to the rally point) |
| 38 | Units 2x faster by train | ✅ | verified by `test_oct16_pacing` (train twice as fast as walking) |
| 39 | Bigger tracks | ✅ | |
| 40 | Show and raise train/ship capacity per level | ✅ | verified by `test_transport_market` (capacity table per level, shown on station/port cards) |
| 41 | Transport helicopter carries no troops | ⏸ | Matthew 2026-10-16: yes, the transport helicopter should carry troops — but WAIT, do not start until he says go. |

## 4. Commit log (WIP branch, newest first)

| Date (UTC) | Commit | Who | What |
| --- | --- | --- | --- |
| 10-16 | `1994686` | Claude | Start-here note for a second Claude (combat 24–30) |
| 10-16 | `29de857` | Claude | Premium gold frame on profile (fix 9) |
| 10-16 | `0a5c1bf` `8f1f55e` `7564b29` | Claude | Fix 9 snapshots |
| 10-16 | `f8033ad` | Claude | Fix 4: ~45k funds/day per country |
| 10-16 | `8570af0` | Claude | Combat test change from a stopped helper |

## 5. Session state

**17 Oct (ChatGPT) — flagship tutorial repairs for review, `chatgpt/training-flow-fix-20261017`.**
Matthew confirmed the flow: opening film on all phone shapes → optional basic controls →
supply film and ship/train arrivals → required Warfront features → keep playing the full match.
Claude's films, art, formations and 5+5 aid loadout are retained. Fixed city-model and garrison-badge
taps during city lessons, Move completion after selection clears, stale menus/order modes on a new
training game, and missing/stalled film recovery. Added actionable animated map callouts and menu
outlines. Required features now include actual Industry, trade-route and station-upgrade actions,
weapon-price inspection, Guard on/off, economic victory, diplomacy and reports.
Godot 4.6.3: training 97/0; real-input regressions 13/0; cinema/layout/recovery 23/0;
ordinary city tap cycle 4/0; Home 5/0; startup 8/0 (**150 checks, 0 failures**).
Native OpenGL captures use the live game's original assets in asset-only QA packs; these packs
are not committed or used to replace the game. Both films decode in source tests; the owner's
installed Android playback failure has not been reproduced on a physical phone.
**No APK/AAB export, Play upload, website deployment or release-branch merge was performed.**
See [TRAINING_REPAIR_2026_10_17.md](TRAINING_REPAIR_2026_10_17.md) before integrating into the
complete release project. Keep all private assets and existing signing/configuration intact.

**17 Oct (Claude) — home screen for several games, branch `claude/home-multigame-20261017`** (based on
`chatgpt/europe-live-20261017`). Owner asked: several games at once, news on home, "Europe map coming soon",
and the Russia–Ukraine start replaced by tutorials listed in the Games list (1-player and 2-player).
- Home: YOUR ACTIVE GAMES rows (1-player tutorial, 2-player online tutorial, any older offline campaign),
  each with its own Resume; SHOW ALL / JOIN NEW; NEWS (two newest items + All news).
- New GAMES tab: MY GAMES + NEW GAMES (Russia vs Ukraine 1P, Russia vs Ukraine 2P online (locked until
  Tutorial.done()), Iran · U.S. · Israel 6P and China economy (coming soon), side asked in a popup on Play/Join,
  Europe · 20 nations **COMING SOON** (button disabled; Europe code untouched), Weapons range).
- The old START/NEW CAMPAIGN button is gone; `fresh_button` is now Start Tutorial. Existing campaign saves still resume.
- Main: `resume_requested` resumes the paused game; "continue" while the tutorial is paused loads the saved campaign;
  the joined online side is remembered in `settings.cfg` [online] `joined_regional`.
- Tests updated and passing: `review_homepage`, `test_home_button`, `test_startup_progress`, `test_american_europe`.

**PAUSED at Matthew's request (16 Oct, 23:20 UTC):** Wait for Claude to finish before any more edits, merge or publication. The current map/update is a test build; larger tutorial work comes afterwards. Additional verified launcher-cleanup and tutorial-move fixes are saved on `chatgpt/release-oct16` only; reconcile after Claude finishes.

ChatGPT full-game release audit on `chatgpt/release-oct16`, based on `beff4dc`.
Matthew authorized fixing remaining bugs and publishing, then explicitly requested a whole-game
review before the update (16 Oct, 22:46 UTC). This authorization supersedes the earlier publishing
pause; fixes 21 and 41 remain on hold. One worker only. See [RELEASE_AUDIT_2026_10_16.md](RELEASE_AUDIT_2026_10_16.md).

The camera event-order regression, smoothed-zoom anchor drift, garrison tap cycle and group-mode
town destination gaps are fixed and tested. A real multiplayer initial-snapshot bug is also
fixed: the phone now shows its assigned country and server state as soon as it attaches.
Actual timer/movement consistency passes 48 checks at 1×/2×/4×/10×. Broad-suite failures and
performance profiling are still being investigated; this is not a released build yet.

**Open bugs**
- Original assets are restored locally; multiplayer phone and phone regression now pass.
- Europe 20-country online work was never committed (`CHATGPT_HANDOFF.md` §2.2).
- `test_battle_effects` passes with restored launcher models.

**Needs Matthew**
- Fixes 21 and 41 are ON HOLD until Matthew says go (see the table).
- Physical-phone review of camera feel, tap targets and report readability remains useful;
  automated and rendered checks are being completed under Matthew's publish authorization.

**Last session:** 2026-10-16, Claude — created this file; fixes 10, 11, 12, 36 bug; verified 13–16, 18–20, 22–30, 35, 37, 38, 40 with tests; `test_economy_rules` now 64/64.

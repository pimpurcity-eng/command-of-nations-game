# Release audit — 16 October 2026

Owner request: "scan through the whole thing again ... find ... any problems and then do an update."
One worker. Working branch `chatgpt/release-oct16`, based on Claude WIP `beff4dc6043af05f882d18fe5bf63b647bce4cfd`.
The owner explicitly authorized fixing and publishing; keep building-time doctrine choice (21)
and troop-carrying helicopter (41) on hold.

## Verified findings and changes

- Latest Claude camera still calculated pinch after each individual finger event. Re-ran the
  existing 16-check gesture regression against this exact version: four failures. Applied the
  frame-coalesced pinch fix from PR #19 while retaining Claude's new screen-scaled tap thresholds:
  16 checks now pass.
- The map tap cycle still contained only armies. When a garrison covered a city's centre, repeated
  taps could never select the city. Added the city after its armies in the cycle; four real-scene
  regression checks pass with the original models.
- Full-project pinch-anchor test exposed drift during smoothed zoom (0.0605 map units after ten
  frames). Corrected the rendered camera around its interpolated ground anchor. Broadened the
  test to check every smoothed frame at three phone sizes and subsequent pan/programmatic moves.
- Restored 406 manifest-verified original weapon/building assets from 22 owner-supplied archives;
  zero missing entries across the arsenal, air-defence, new-weapons and October 12 manifests.
- Fixed joining a multiplayer match before its first periodic tick: the client now applies the
  already-received welcome snapshot when the running scene attaches. The dedicated-server phone
  test passes, with the correct country, armies and resources present immediately.
- Fixed group selection treating a large garrison polygon as the target of every tap on the
  town beneath it. Model-centre priority now leaves a distinct town destination. Phone regression
  11/11, army selection 10/10, touch controls 14/14 and city tap cycle 4/4 pass.
- Added a real-system speed regression: at 1×, 2×, 4× and 10×, production, construction,
  research, movement and the game clock advance consistently. Construction's displayed deadline
  agrees with actual completion at every speed. 48 checks pass.
- Corrected old test fixtures for intentional selection clearing after movement, archived
  research defaults, real-time dedicated-server waits and the launcher's physical erector delay.
  Campaign and multiplayer phone regressions now pass.

Focused checks after the changes: camera gestures 16/16, pinch anchor 9/9 across three phone
sizes, screen-scaled tap reach passes, city/army tap cycle 4/4. The pinch-anchor test now fails
with a nonzero exit code if drift recurs; previously it printed FAIL but exited successfully.
Real OpenGL city and menu screenshots rendered successfully with the original assets.

Economy rules 64/64, economy balance 8,410 checks, accounts 58/58, multiplayer 36/36,
Oct 16 combat 38/38, pacing 329/329, zoom 8/8 and diplomacy/news 12/12 pass.
The broader suite and performance profiling are still running. It has flagged further failures
that need triage against current rules; no release claim yet.
- Builds repo remains at 0.57; none of this WIP has been released there yet.

## Validation and publication status

In progress. Record each test result and every new finding here before the release commit.
No new build, production merge, live deployment or Play upload has happened yet.
Do not call the release complete from test exit code alone: check for script errors too.

## Handoff details

`docs/HANDOFF.md` remains the shared source of truth. Read it first; the earlier camera-only PR
is not merged, so this release branch incorporates its changes directly. Original signing key
was recovered and verified earlier; no reset or new key is needed. Do not store credentials here.

## Paused for Claude — 16 October, 23:20 UTC

Matthew clarified that this map/build is for testing and that the larger tutorial changes
come after this build. He then asked ChatGPT to wait because Claude is almost finished.
Stop editing, merging and publishing until his completed work is available for reconciliation.

Two additional verified fixes are saved on `chatgpt/release-oct16` only:
- Physical launcher/silo animation tweens are bound to their model lifetime. Removing or
  swapping a model now cancels pending callbacks: regression changed from 2 failures plus
  freed-capture errors to 6/6 passing with no such errors.
- Tutorial movement now follows the chosen army after a successful order clears selection.
  The progression regression passes, including selection clearing and tutorial advancement.

CPU-only profiling in this environment: simulation subscribers about 5.8 ms/tick; an 80-unit
scene with 19 visible models about 13.2 ms/frame in the headless profiler. Zoom median
6.7–7.3 ms, p95 23.3–25.6 ms; one initial-load hitch of 63.2 ms. These are cloud CPU timings,
not physical-phone FPS. No rendering-performance claim or release has been made.

The first broad run exposed many stale fixtures for the old starting buildings/research,
queues, unit sizes, unlock days and physical launch delays. Updating them was in progress;
do not interpret the original failures as all current gameplay bugs, or claim the whole suite
is green. Local test-maintenance work remains unfinished. No APK/AAB export, production merge,
server deployment, browser publication or Play upload occurred. Play Console currently shows
admin@yaska.app signed out; no new login attempt or credential request was started.

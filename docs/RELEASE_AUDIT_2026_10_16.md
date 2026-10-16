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

# Warfront Mandate — website, speed and player-flow audit
17 October 2026 · Atlantic time

The most urgent weaknesses are the path into a game, training progression, and multiplayer admission. The homepage has a coherent visual identity and the game already contains many substantial systems. Its player journey needs to become dependable before more maps and presentation work can establish the flagship experience.

This is an audit. No game code, live website, account setting, database, or deployment was changed.

## What was checked and how confident the findings are

- **Live browser:** the homepage, Games and Features anchors, public Privacy and Account deletion pages, Support link, and the browser game's initial error handling.
- **Live delivery:** HTML, build version, engine JavaScript and WebAssembly, compressed game pack, cache validation, and the directory of all 2,692 files inside the pack. Both training movies were extracted, checksummed, and inspected with a media probe.
- **Source:** startup, home, game saves, training, map input, army movement, research, cities, trade, visual loading, accounts, multiplayer client/server and publishing scripts. This was a focused source review, not a line-by-line certification of every file.
- **Competitors:** Call of War and Conflict of Nations official manuals and wikis. Their documented flows were compared; no fresh accounts were created and no authenticated competitor matches were played.
- **Limits:** this review browser reports that WebGL2 is unavailable. It could not render Warfront's battlefield, measure battlefield frame rate, or reproduce the Android freeze directly. Android login, Google callback, purchases, two-device play, and account deletion were not executed. There is no measured Lighthouse score or mobile Core Web Vitals result.

“Observed” below means seen on the live website or measured from its delivery. “Source-confirmed” means the relevant logic is present in the inspected release source. “Needs device testing” means a plausible risk or a product gap that is not a reproduced runtime failure.

## Release snapshot

| Item | Checked result |
| --- | --- |
| Public website | https://warfrontmandate.com/ |
| Browser game | https://play.warfrontmandate.com/ |
| Live VERSION around 09:39 Atlantic | `0.60-complete source 24a802e74dae9e7c66337d7f56255d0f1b41aeba` |
| Live files last modified | 17 October, about 08:35 Atlantic |
| Later source available | `claude/v0.61`, commit `585e6356b238804d6d65739ca473b85945d1369a` |
| Difference in 0.61 | Home-first launch, moving movies and additional battle music out of the start pack, movie loading/waiting support |
| Production conclusion | The later loading work was not in the live build inspected. Its finished export and device behavior were not verified here. |

The public homepage has its own source history. A homepage change does not prove that the game export or Android build was updated. The inspected `main` commit in the source repository contains a README and release workflow rather than the full game; the game exists on the release/development branches. This is a release-provenance risk, not evidence that the source has been lost.

## Fixes in priority order

P0 means it blocks the required first-player journey or admission rule. P1 means a major usability or loading problem. P2 means an important improvement or a device check.

| ID | Priority | Finding | Evidence | Required outcome |
| --- | --- | --- | --- | --- |
| 1 | P0 | Training can miss a successful tank move. | Source-confirmed: accepted movement clears selection; the lesson checks the selected moving tank. | Track the ordered army and accepted order independently of current selection. |
| 2 | P0 | The same selection dependency affects the reinforcement movement lesson. | Source-confirmed: reinforcement completion also checks the selected moving army. | Finish the step after the correct reinforcement receives a valid order, including after deselection. |
| 3 | P0 | The requested level-10 rule is not enforced in the inspected multiplayer admission path. | Source-confirmed: sign-in leads to seat admission without a commander-level or training-completion check. | Verify account training and level on the server before admission to regular matches. |
| 4 | P0 | Training rewards 10 XP, which is not level 10. | Source-confirmed: XP-to-level formula leaves a new account at level 1 after 10 XP. | Make progression and unlock text match the intended level-10 requirement. |
| 5 | P1 | The two-player button enters an ordinary online match rather than the shared training flow. | Source-confirmed: the online path connects directly and clears local training on welcome. | Provide a distinct two-player training match and track each commander's completion. |
| 6 | P1 | A capital tap can select its garrison before its city. | Source-confirmed: overlapping army/city hits cycle armies before the city. | Make the city target unambiguous during city lessons and provide an explicit city action. |
| 7 | P1 | Cold game entry transfers about 104 MB before startup completes. | Observed: full compressed pack and engine download. | Load a small lobby first; defer films, spare music, unused map data, and optional assets. |
| 8 | P1 | Later speed work is not in the inspected live release. | Observed VERSION plus source comparison. | Validate and publish one identified game export, then verify its live version. |
| 9 | P1 | Website mode buttons lose the visitor's choice. | Observed: Resume, 1-player Play, 2-player Join and Range Play all point to the same bare game URL. | Pass the requested destination into the game and preserve it through login/loading. |
| 10 | P1 | “My Games” is a fixed set of save types, not a list of individual online matches. | Source-confirmed: training/online/classic slots and a remembered online country. | Store and display per-account match IDs and per-match resume targets. |
| 11 | P1 | Choosing an occupied side can silently assign the other side in the regional server. | Source-confirmed: admission falls back to any free regional seat. | Show live availability and require the player's consent to a different country. |
| 12 | P1 | Mobile reconnection is manual. | Source-confirmed: the inspected client closes and tells the player to rejoin; no automatic retry/resync flow was found there. | Reconnect with bounded backoff, recover the same seat, and show connection state. |
| 13 | P2 | Restart can replace the sole training save immediately. | Source-confirmed: RESTART follows the new-training path, which resets and saves the scenario. | Confirm replacement or offer a separate new save. |
| 14 | P2 | Several “new feature” lessons check menu opening rather than successful use. | Source-confirmed: Trade, Transport market, Victory and Diplomacy completion conditions. | Teach a completed trade action and explain the effect on income, logistics and victory. |
| 15 | P2 | Some account and production flows need less friction. | Source review: account tokens are memory-only; unresearched city art is dimmed; many blockers use small labels/tooltips. | Verify cold-launch sign-in, keep art readable, and show actionable blocker explanations on phones. |
| 16 | P2 | Recovery and support need a more useful fallback. | Observed: raw WebGL2 error; Support led this review browser to Cloudflare's email-protection page. | Explain supported browsers, offer retry/help, and make support contact copyable. |

## Why the training gets stuck

In `main.gd → player_order()`, an accepted normal Move order ends by calling `clear_army_selection()`. That sets `units.selected = -1`.

In `training_match.gd → _action_done()`, the Move lesson requires a nonempty current selection whose unit is armour and is moving. The reinforcement lesson has the same dependency.

The normal successful path is therefore:

1. Select tanks.
2. Tap Move and choose a destination.
3. The move is accepted and the selection is cleared.
4. Training polls for a selected moving tank and sees no selection.

This is a source-confirmed logic conflict. It does not establish the cause of the separate Android map-launch freeze. Reselecting a moving army may let the current lesson proceed, but that is an undocumented workaround.

The fix should listen for the correct army's accepted movement order or record its ID when the lesson starts. It must also survive fast arrivals, deselection, saves, and reopening the game.

City selection is a separate problem. The current map input can cycle overlapping armies before opening the city. “Tap your capital” is unreliable instruction when the capital is covered by a garrison. The existing Show Me action centers that capital but does not directly open its city panel. During that lesson, highlight a reliable city entry or expose a clear city-versus-army choice.

Some lesson conditions are broader than their wording: “Open your capital” accepts any controlled city; “queue infantry” accepts any friendly production job. Tighten these checks to match what the player is being taught.

## Training, XP and multiplayer access

The preserved requirement is mandatory training for every new player, with one-player or two-player training, the ability to continue the full match, and commander level 10 before regular multiplayer.

The current adapter uses:

`level = floor(sqrt(XP / 100)) + 1`

Therefore:

| XP | Commander level |
| --- | --- |
| 0 | 1 |
| 10 | 1 |
| 8,100 | 10 |

Awarding 10 XP and saying the other games are unlocked does not implement that rule. Simply changing the award to 8,100 would also be a product decision; the appropriate fix is a deliberate training progression that earns the required level and records completion per account.

The local home references `Tutorial.done()`, a device setting. In the inspected home implementation, the `locked_games` collection is not populated by the current game-card construction. More importantly, the server's authenticated admission path performs no level-10 check. A disabled button alone would not enforce access.

The regular online path also bypasses `start_training(..., players=2)`. The presence of a “players” field in local training is not proof that two-player training works online. That needs a real shared training session with separate progress for each commander.

Free play after the guided section is already represented in the training state. Preserve the full match through victory or defeat while improving progression.

## Speed: measured facts

All sizes below are decimal MB. These are HTTP transfer and file measurements from this review environment, not the user's connection speed or a browser time-to-interactive measurement.

| Component | Decoded file size | Transferred with gzip |
| --- | ---: | ---: |
| Game pack | 101.67 MB | 93.70 MB |
| Godot WebAssembly engine | 37.70 MB | 9.93 MB |
| Engine JavaScript | about 0.32 MB | 0.082 MB |
| Main total | about 139.4 MB | **103.71 MB** |

The HTML, splash and small incidental files add a little more. Optional asset packs can add further downloads later.

The full game-pack request took 5.22 seconds here, including 3.22 seconds to the first response. Engine and other request latencies varied. Those observations are environment-dependent and should not be presented as the experience of a Canadian phone user.

The payload alone imposes these ideal transfer times:

| Effective connection | Minimum time for 103.71 MB |
| --- | ---: |
| 5 Mbps | 166 seconds |
| 10 Mbps | 83 seconds |
| 20 Mbps | 41 seconds |

Unpacking, engine initialization, map setup and shader/model preparation add time. Connection overhead and contention can add more.

Useful facts inside the current start pack:

| Contents | Included bytes |
| --- | ---: |
| Both training films | 11.59 MB |
| Battle music tracks 2–5 | 14.11 MB |
| Files explicitly named for Europe20 | 8.98 MB |
| Files under tests/ | 1.64 MB across 266 files |

These groups are not a promise of equal compressed savings. Europe-related files are a filename-based subtotal, not a complete dependency analysis.

Compression is already active. A conditional request for the unchanged pack returned HTTP 304, so basic cache revalidation works. Do not misdiagnose this as “gzip is off” or “it always downloads everything again.”

The next improvements should preserve all game features:

1. Keep the lightweight account/home/match browser usable before creating the 3D world. The current loader prepares the map behind the home and disables navigation during boot.
2. Complete and verify the existing 0.61 split: films and spare battle tracks arrive when needed. That source change targets roughly 25.7 MB of decoded start-pack contents.
3. Move Europe-only data and art behind choosing Europe, with a tested dependency manifest.
4. Keep the existing mobile model limits, visibility budgets and incremental reveals; profile before changing them.
5. Profile the city/research panels. Their half-second refreshes recreate cost controls, styles and some signal bindings. Update only changed values if profiling shows a material cost.
6. Give failed asset downloads a visible retry/status path. The current extras loader retries indefinitely at a fixed five-second interval.
7. After correctness, consider a smaller engine build and versioned immutable assets. Keep short caching for the entry manifest.

## The videos are present

Both live movies passed their packed checksum and were readable by the media probe:

| Movie | Picture | Duration | Audio | File size |
| --- | --- | ---: | --- | ---: |
| Opening | Theora, 960 × 540, 30 fps | 30.03 s | Vorbis stereo | 3.58 MB |
| Supply arrival | Theora, 960 × 540, 30 fps | 30.03 s | Vorbis stereo | 8.01 MB |

This rules out “the live pack contains neither movie.” It does not prove that Godot plays them correctly on the phone.

Godot's official 4.6 documentation warns that its Web video playback performs poorly. That is a performance risk worth testing, not a proven explanation for the reported failure. For the browser edition, evaluate browser-native video playback with an appropriate web codec; retain and test native game playback on Android.

The current cinema has captions, portrait framing, a skip control and a missing-film fallback. Test first frame, sound, completion, skip, Home/Resume and app backgrounding on the actual Samsung device. A stalled movie must always offer a working Continue route.

## What the two competitors do well

This comparison describes their official documented behavior. It is not a claim that their interfaces were independently benchmarked on this device.

| Journey | Call of War / Conflict of Nations baseline | Warfront finding and next step |
| --- | --- | --- |
| Find a game | Call of War separates My Games and New Games, with search, game ID and scenario information. CON documents campaign categories and automatic spawning of new public rounds. | Warfront has the beginnings of Home/Games, but needs actual match records, filtering, capacity, day, speed and availability. |
| Choose a nation | Both document choosing an available country. Call of War exposes doctrine in country selection. | Warfront already displays weapon-system/doctrine labels. Add live seat availability and avoid silent reassignment. |
| Learn the game | CON places new accounts into tutorial campaigns. Both provide continuing reference material. | Keep the cinematic opening and full training match; fix action progression and account-level completion. |
| Issue orders | Army and province/city selection lead to context-specific controls. | Warfront's overlapping garrison/city hit testing needs predictable intent, especially in training. |
| Research and produce | CON explains research, building prerequisites, costs and upkeep. | Warfront already opens unit cards from research pictures. Improve mobile readability and take a blocked production action directly to its missing prerequisite. |
| Manage a nation | Both expose city/province lists, economy information and queues; CON documents multi-city actions. | Make aggregate shortages and queues easy to scan. Assess bulk city actions in a real match before claiming they are absent. |
| Return later | Call of War lists individual ongoing rounds; CON explains persistent play while logged out. | Resume a specific account match, restore the same country and reconnect after phone network changes. |
| Understand victory | Both describe campaign victory and progress. | Make economic victory, transport capacity and Guard results visible through actual play, since those are Warfront's strongest distinctions. |

The important lesson is predictable navigation and feedback. Warfront can keep its own economy, logistics, realistic units and defence systems while adopting these established flow conventions.

## Recommended player flow

**New commander:** Homepage → Start Training → opening film → choose Russia or Ukraine → real orders and city actions → research/production → an actual trade and Guard action → supply film → inspect/unload the ship and train → continue the training match and earn progression → regular multiplayer unlocks at level 10 after training completion.

**Returning commander:** Open game → restored account → Your Active Games → Resume the specific match → receive authoritative state and a clear “while away” report.

**Eligible commander joining multiplayer:** New Games → choose a particular round → see map, day, speed, slots and rules → choose an available country with weapon system and starting-force preview → confirm → enter match.

**Network loss:** visible reconnect state → bounded automatic retry → restore the same match and seat → explain any failed pending order. A reconnect must not create a second country or another match.

Website links should carry intent such as training, online, practice or a specific resume target. Do not auto-join a regular match before the player has completed the required selection and eligibility checks.

## What is already working in the design/source

- The public homepage has consistent colours, typography, a clear value proposition, responsive portrait/landscape artwork and lazy-loaded lower-page images.
- Public Privacy and Account deletion information opened successfully.
- The game has Home/Games/Features structure and active-save entries.
- Country selection includes weapon-system/doctrine information.
- Research pictures are wired to unit cards; the code already has production prerequisites and queue feedback.
- Training has real action checks, captions, spotlights, supply manifests, unloading and a free-play state.
- Multiplayer code has server authority, fog-of-war filtering, account-bound seats, saves and 48-hour inactivity takeover.
- Browser asset delivery has gzip, cache revalidation and split optional packs.

These are useful foundations. Do not remove them while fixing the journey.

## Checks required before calling the fixes complete

| Check | Passing result |
| --- | --- |
| Cold start on Samsung/Chrome at a controlled connection speed | Measured download size, time to usable home, time to training and peak memory; no freeze. |
| Russia and Ukraine full training paths | Every real lesson completes using its normal instruction without reselecting an army as a workaround. |
| Capital with overlapping garrison | City lesson opens the city reliably while ordinary army selection remains usable. |
| Videos | Picture, audio, skip, natural completion and resume work; a failed/stalled movie has a usable exit. |
| Account progression | Training reward is granted once; commander level is correct; progress survives device change. |
| Eligibility | Unfinished training and level-9 accounts are refused by regular-match server admission; eligible level-10 accounts are accepted. |
| Two-player training | Both commanders share one training match and have separately recorded completion/progression. |
| Country conflict | Two players requesting one seat cannot both receive it; the second sees a clear choice. |
| Multiple rounds | Two online match IDs appear separately and each Resume returns to its own state/country. |
| Network interruption and app restart | Account/session behavior is clear; the same match/seat is recovered and orders are not duplicated. |
| Published build | Live VERSION, exported asset manifest and tested source commit agree. |

Capture funnel events for game launch, download completion, home ready, video first frame/failure, training step completion, login failure, join rejection and reconnection. Page views alone cannot reveal where a canvas game loses players.

## Evidence links

Release source: [0.60 source snapshot](https://github.com/pimpurcity-eng/command-of-nations-game/tree/24a802e74dae9e7c66337d7f56255d0f1b41aeba). Later source: [0.61 change](https://github.com/pimpurcity-eng/command-of-nations-game/commit/585e6356b238804d6d65739ca473b85945d1369a).

Key files at the inspected release: `game/scripts/main.gd` (`player_order`, `join_online`, `start_training`); `training_match.gd` (`_action_done`, `focus_objective`); `mobile_start_panel.gd` (`GAME_KINDS`, `active_games`, `_build_games`); `net/match_server.gd` (`_authenticated`, `admit`); `accounts/player_auth.gd` (`level_for`, `complete_training`); `startup_loader.gd`; `web_extras.gd`; `research_panel.gd`; `city_panel.gd`; and `server/web-sync.sh`.

Official comparison sources: [Call of War joining rounds](https://wiki.callofwar.com/wiki/JOINING_GAME_ROUNDS), [main interface](https://wiki.callofwar.com/wiki/MAIN_INTERFACE), [army controls](https://wiki.callofwar.com/wiki/ARMY_CONTROLS), [doctrines](https://wiki.callofwar.com/wiki/DOCTRINES); [Conflict of Nations campaign types](https://wiki.conflictnations.com/Campaign_Types), [interface](https://wiki.conflictnations.com/User_Interface), [beginner introduction](https://wiki.conflictnations.com/Beginner_Intro).

Technical references: [Godot 4.6 VideoStreamPlayer](https://docs.godotengine.org/en/4.6/classes/class_videostreamplayer.html), [Supabase sessions](https://supabase.com/docs/guides/auth/sessions).

Account review was source-only. Database configuration, row-level policies and live account permissions were not audited. Session persistence should use appropriate platform storage and token refresh; do not store player passwords to make Resume easier.

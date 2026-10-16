# Europe server QA and integration handoff — 16 October 2026

Matthew asked both conversations to work together after the Europe author resumed. The Europe author owns map activation, American roster gaps, menu/country picker and release deployment. This branch contributes a small server correction and independent verification of that author's saved work.

Branch: `chatgpt/europe-readiness-20261016`.
Base: `f214d036380eea0ce5c6b35fb8c0930e3e0f284f` on `chatgpt/american-europe-20261016`.

## Fix to carry into the integrated release

`MatchServer._state()` indexed the live unit array and `UnitSystem.snapshot()` by the same position. The snapshot skips health <= 0.001 before combat removes the live entry. A casualty can shift every subsequent entry, use the wrong army for visibility checks, and raise an out-of-bounds script error while sending the welcome or recurring ticks. This failure was reproduced in the unmodified regional multiplayer test.

The server now looks up each snapshot entry's live army by id before applying visibility and stripping enemy orders. The packet shape and lobby protocol stay compatible with the Europe author's implementation.

The existing multiplayer test adds an explicit casualty-before-cleanup regression and compares the initial AI countries without relying on dictionary insertion order. A separate patch adds the same casualty assertion to the author's new Europe test, which was still uncommitted when copied:

`docs/qa/europe-server-20261016/europe-casualty-regression.patch`

Apply that optional assertion after the author commits `game/tests/test_europe_online.gd`. The runtime correction applies directly to the corresponding `_state()` block of the current Europe server.

## Verified results

Godot **4.6.3**, headless, with isolated test data directories:

| Run | Result | Scope |
| --- | --- | --- |
| `game/tests/test_multiplayer.gd` on this branch | **35 passed, 0 failed; exit 0; no script errors** | Real regional game and localhost WebSockets; admission, fog, command ownership, chat/diplomacy, 48-hour AI takeover, saved match/seats, restart, casualty regression. |
| `tests/test_europe_online.gd` in an independent copy of the Europe author's saved working tree, plus this fix and its Europe assertion | **31 passed, 0 failed; exit 0; no script errors** | Real Europe game, 20 selectable countries plus 24 permanent AI countries; lobby/picker, exclusive country claims, resume, fog, per-country wars, persisted reservations/restart, authoritative speed, immediate welcome application, casualty regression. |

The Europe test output is retained in `docs/qa/europe-server-20261016/europe-online-results.txt`. Its source was copied from the author's active checkout before testing; later changes by that author need their normal verification. Test saves were isolated with `XDG_DATA_HOME`, avoiding the author's ongoing runs.

## Coordination and release boundary

The author's current code already implements lobby preview, exact Europe country selection, permanent AI nations and immediate application of the welcome packet. Keep those implementations. My earlier overlapping lobby experiment was removed before preparing this handoff.

No live branch, hosting configuration, Google Play release, Android build, account settings or database was changed by this contribution. The author should merge the small runtime fix into the integrated Europe source, keep its existing deployment process, and verify the published client/server together. Local headless checks do not establish physical Android or live-cloud readiness.

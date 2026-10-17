# Europe integration recovery — 16 October 2026

Recovered the complete Europe working tree from checkpoint `1935892` and its merge `7598982`, then merged the current authoritative game branch (`bc8af3b`). The recovered source includes the shared Europe campaign, 20-country picker/lobby with flags and weapon systems, seven cities per selectable country, American roster gaps, map caches, and the saved-seat multiplayer flow. All existing regional game changes remain in the integration history.

Additional fixes in this branch:

- Add a separate `match-europe` service for `europe-1`, map `europe20`, default 1× speed and 48-hour AI takeover. Route `/europe` WebSockets to it while the regional service keeps its existing route.
- Mount Europe's persistent volume at the game's actual custom user directory, so its saves and country reservations survive container replacement.
- Do not silently continue a server image build after Godot import fails. Correct the standalone image's AI inactivity default to 48 real hours.
- Keep client AI disabled after applying a welcome that changes the selected country. The Europe online test explicitly exercises that country change.
- Use the same current arsenal on both ends of the dedicated phone test; the old test started a current server but loaded an archived catalogue on the phone.

Recovered original private model archives and existing local American models are build inputs only. They remain excluded from this public source repository. Account configuration and Android signing files remain excluded too.

Validation and publishing status will be recorded after the integrated checks and build complete. The earlier `EUROPE_SERVER_QA_2026_10_16.md` documents the casualty fix already contained in this source.

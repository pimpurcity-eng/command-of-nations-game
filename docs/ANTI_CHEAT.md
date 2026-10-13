# Anti-Cheat — Warfront Mandate

Warfront Mandate checks every match for cheating automatically. Nobody has to press anything.

The system lives in one file, `game/scripts/anti_cheat.gd`, and does three jobs:

| Job | When it runs | What it catches |
|---|---|---|
| **Start sweep** | Once per match, after everyone has joined and the map has loaded | Modded/edited game files, wrong game version, edited save files, extra starting units, extra starting resources, impossible unit stats, debug builds in ranked play |
| **Watchdog** | Every 2 seconds during the match | Speed hacks, resources that appear from nowhere (memory editors like GameGuardian), units that appear without being produced, god-mode health, impossible unit levels |
| **Save seal** | Every save and load | Save files edited outside the game, or copied from another phone |

## Why the sweep waits until everyone has joined

Running the check at the very start of loading would be too early: armies and resources aren't in place yet, and in multiplayer the other players aren't connected. Instead the sweep runs at the moment the match actually begins (`start_campaign_play()`), when:

- every player is in the match,
- every starting army is on the map,
- every country has its starting resources.

That is the one moment when every honest player's game should look exactly the same, so any difference stands out.

## How the start sweep decides who is cheating

Each player's game builds a small **report**:

- a fingerprint (SHA-256 hash) of every game script — the same build gives the same hash on every phone, and a modded APK gives a different one;
- the game version and whether it's a debug build;
- whether their save file's seal was intact;
- for every country: number of units, highest unit health, highest level, total tiers, starting stockpile.

**In multiplayer**, the reports are compared and **the majority wins**. If four players agree that Europe starts with 63 units and one player's game says 90, that one player is flagged. The host breaks ties.

**In single player** there is nobody to compare with, so protection comes from the save seal, the hard limits on unit stats and the watchdog.

## Verdicts

Every finding has a weight:

| Level | Points | Example |
|---|---|---|
| info | 0 | — |
| warn | 1 | Older game version, debug build in a ranked match |
| cheat | 3 | Edited game files, edited save, extra units, memory-edited resources, speed hack |

- **0 points → CLEAN**
- **1–2 points → SUSPICIOUS** (shown, but the match stays ranked)
- **3+ points → CHEATING** (match becomes UNRANKED)

## What happens to a cheater

Nothing is banned automatically — false positives happen, and an automatic ban on a false positive loses an honest player.

When a match is flagged:

1. The player sees: *"ANTI-CHEAT · match is now UNRANKED · reason"*.
2. No medals, ranks or achievements are earned or synced to the account for that match.
3. In multiplayer, the host gets the `player_flagged(player_id, verdict, findings)` signal and can remove the player.
4. The full report is kept in `anti_cheat.last_report` so it can be uploaded to the account server later for review.

## How each cheat is detected

**Modded APK / edited scripts.** Every script in the build is hashed. Honest players on the same version all get the same hash. A changed script changes the hash.

**Memory editors (GameGuardian, Cheat Engine).** These change the number shown on screen (e.g. oil = 99,999). The anti-cheat keeps its own shadow copy of every stockpile. If a stockpile jumps by 500+ and at least doubles *without the production system announcing a change*, it was edited in memory.

**Speed hacks.** These make the game engine think more time has passed than really has. The watchdog adds up the engine's frame times over 10 seconds and compares them with the phone's real clock. More than 35% off → flagged (first time a warning, twice in a row a cheat). Normal game-speed buttons (1x, 4x…) are not affected because they work on the game clock, not the engine.

**Units from nowhere.** The watchdog counts units every check. The number may only grow by the number of units the production system actually built.

**God mode.** No unit may have more than 100 health or be above level 10.

**Edited saves.** Each save gets a seal: an HMAC-SHA256 signature made with a key tied to that phone. Change one number in the save file and the seal no longer matches. Saves made before anti-cheat existed have no seal and still load.

## Tuning

All limits are plain variables at the top of `anti_cheat.gd`:

| Setting | Default | Meaning |
|---|---|---|
| `max_unit_health` | 100 | Highest legal unit health |
| `max_unit_level` | 10 | Highest legal research level |
| `max_clock_speed` | 64 | Highest legal game speed button |
| `check_interval` | 2.0 s | How often the watchdog runs |
| `speed_tolerance` | 0.35 | Allowed real-time drift before a speed-hack flag |
| `resource_jump_min` | 500 | Smallest unexplained resource jump that counts |
| `resource_jump_ratio` | 1.0 | Jump must also be this big vs. what was there (1.0 = doubled) |
| `ranked` | true | Refuse debug builds |

If honest players are being flagged, raise the limit for that check rather than turning the whole system off.

## Hooking it into the game

`docs/anti_cheat_main_hookup.patch` adds anti-cheat to `game/scripts/main.gd`. It applies cleanly to the 0.23 Android crash-fix source:

```
git apply docs/anti_cheat_main_hookup.patch
```

What it changes (about 30 lines):

1. Creates the `AntiCheat` node next to the production system and shows a status message if the match is flagged.
2. Runs the start sweep in `start_campaign_play()`, once per match (skipped in the weapons test).
3. Seals the state in `save_game()` and `autosave()`.
4. Checks the seal in `load_game()`, then re-baselines the watchdog after a load.
5. Stops `_award()` and `_award_count()` from giving medals in a flagged match.

### Multiplayer

When online play is added, each player calls `anti_cheat.build_report()` once the lobby is full and sends it to the host. The host passes them all in:

```gdscript
var sweep := anti_cheat.run_start_sweep({"2": report_from_player_2, "3": report_from_player_3})
```

and listens to `player_flagged` to remove or warn players.

## Testing

`game/tests/test_anti_cheat.gd` runs 18 checks with a small fake game (no map needed):

```
godot --headless --path <project> --script res://game/tests/test_anti_cheat.gd
```

Covers: clean match stays clean, real production is not flagged, memory-edited oil is caught, units from nowhere are caught, produced units are not, god-mode health, sealed save survives a real save/load, edited save is rejected, old unsealed saves still load, a modded player among three is CHEATING while the honest two stay CLEAN, an older version is only SUSPICIOUS, debug builds flagged in ranked play, a 3x speed hack is caught and normal timing is not.

All 18 pass on Godot 4.6.3. The test has been added to the Android release workflow.

## Limits — what this does not stop

No phone game anti-cheat is perfect, because the cheater controls the phone. Honest limits:

- A determined hacker can find and patch out `anti_cheat.gd` itself. In multiplayer this changes their file fingerprint, so the other players catch it. In single player it can't be caught.
- The save key lives inside the game, so a skilled reverse-engineer could rebuild it.
- Root/emulator detection and Google Play Integrity checks need an Android plugin. **Play Integrity** is the next step once the game is on the Play Store — it lets the server confirm the APK is the genuine one from Google Play.
- For real competitive multiplayer, the strongest protection is the host (or a server) running the simulation and only accepting *orders* from players, never their resource numbers. This sweep is built to fit that later.

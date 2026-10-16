# Start here — second Claude session (combat fixes 24-30)

You are joining development of "Warfront Mandate: WW3", a Godot 4.6.3 Call-of-War-style strategy game
(Russia vs Ukraine), web + Android. Owner: Matthew (GitHub pimpurcity-eng).

1. Clone pimpurcity-eng/command-of-nations-game, check out branch `claude/wip-oct16`, and create your
   own branch from it: `claude/combat-oct16`. Commit and push ONLY to `claude/combat-oct16`.
2. Read `docs/CHATGPT_NOTE_2026_10_16.md` (numbered fix list) and, on branch `claude/v0.26-fixes`,
   `CHATGPT_HANDOFF.md` (build and test details).
3. If Godot 4.6.3 isn't installed, download the official Linux build (4.6.3-stable) from
   godotengine.org. 4.4.x breaks the scripts.
4. Your job is fixes 24-30 ONLY (combat). Another Claude session is doing the other numbers on
   `claude/wip-oct16`, so don't change camera, city screen, accounts, economy, pacing or UI panels.
   - 24 Battle animation lasts about 5 seconds per exchange of fire, then units stand still until they
     fire again.
   - 25 "My plane wouldn't attack the enemy plane": planes must be able to attack enemy aircraft (in the
     air or on their airfield) and damage them.
   - 26 Patrol did too little damage: each patrol hit stays at 65% of an attack strike (owner rule), but
     it must hit regularly, everything inside the patrol circle.
   - 27 Air defence did no damage to a patrolling plane: AD in range must shoot patrolling planes (full
     damage vs attacking/patrolling planes; AD fires every 7 min at 1x).
   - 28 Heal armies with gold (Call of War style button in the army panel, priced with GoldWallet).
   - 29 Attacking an enemy army in a city listed me as "defending": the attacker must show as attacker.
   - 30 Fire modes per army: Fire at will (default) / Return fire / Hold fire.
   An earlier helper half-did some of this: see `game/tests/test_oct16_combat.gd` and the
   "Owner 2026-10-16" comments in air_battle_system.gd, combat_system.gd, combat_effects.gd,
   unit_system.gd. Check what exists before writing new code.
5. ONE fix at a time: fix, test, commit, push, then tell Matthew in plain words what changed and what to
   test in the game, then the next fix.
   - Tests: `cd game && timeout 1500 xvfb-run -a godot --path . --script tests/<test>.gd`
     (one test at a time). First delete a stale save: `rm -f "$HOME/.local/share/Command of Nations/resume.cfg"`.
   - Run tests/test_oct16_combat.gd, test_oct15_evening.gd, test_battle_effects.gd,
     test_layered_air_defense.gd.
6. Rules: never put passwords, keys or signing files in Git. Don't edit export_presets.cfg. Don't build or
   publish the Play app or website (the other session does builds). Code comments cite the owner with a
   date, e.g. `## Owner 2026-10-16: ...`.

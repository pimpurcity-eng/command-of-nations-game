# Note for ChatGPT — Warfront Mandate: WW3 (2026-10-15)

Claude builds and publishes the app and the website. The Play Store listing is done; don't redo it.
Your job is game work that Claude is not doing right now. Each item says what is done and how to prove it.

## Setup
- Repo `pimpurcity-eng/command-of-nations-game`. Start from branch `claude/v0.26-fixes` (latest is 0.50).
  Work on your own branch `chatgpt/<topic>`, one per item below. Don't push to Claude's branch or `main`.
- Godot **4.6.3** (4.4.1 breaks the scripts). Run tests with
  `godot --headless --path game --script tests/<name>.gd` (look for `RESULT ... failures=0`).
- Your browser has no WebGL2, so you can't play the web build. Check visuals with headless renders
  (`xvfb-run -a godot --path game --script <render script>`) and attach the PNGs.
- Never commit `.glb` models, `.aab`/`.apk` files, keys, passwords or `export_presets.cfg` changes.

## 1. Cities (you own this one)
The owner wants the cities redesigned like Call of War and has handed this to you.
- Change `game/scripts/city_system.gd` and city art only. Claude will not touch city_system.gd while you have it.
- Rules that must stay:
  - round town with no grey square;
  - the army in the city centre, with no buildings under it (`GARRISON_CLEAR_RADIUS`);
  - close cities never touch (Kharkiv and Belgorod);
  - no red in the cities;
  - full quality on phones.
- Done when: `tests/test_city_courtyard.gd` passes and you send renders of Moscow, Kharkiv/Belgorod and Kursk
  at close and far zoom.

## 2. Ukraine equivalents for Russia-only units
Russia has four unit types Ukraine has nothing to match:
- `loitering_russia` (Lancet)
- `interceptor_russia` (MiG-31)
- `a50u_russia` (radar plane)
- `airborne_ifv_russia`

Add Ukrainian equivalents to `game/data/equipment.json`. Use the same stats, cost and research days, with a different name and model:
- Switchblade 600 or Warmate (for the Lancet)
- an F-16 interceptor branch (for the MiG-31)
- Saab 340 AEW / GlobalEye (for the radar plane)
- a Western airborne IFV

Keep the JSON layout (2 spaces, same key order) so the diff only shows your additions. Models go in the
owner's Drive and the install tools, not Git. Add unit pictures in `game/assets/interface/unit_art/`, the same style as yours.
- Done when: `tests/test_weapon_batch.gd` and `tests/test_owner_night.gd` pass.

## 3. Bring the old tests up to date
The owner changed the starting rules: no buildings at the start except the airport, and nothing researched.
These tests still expect the old start, so they fail:
- `test_city_tap_rail`, `test_economy_rules`, `test_guard_queue`, `test_trade`, `test_campaign`, `test_menu_province`
  - Fix: in each test, build the barracks, factory or train station and research the unit first. Don't change the game rules.
- `test_oct12_assets` "ship starts at sea" (13) and `test_map_features` (5)
  - Find out why and report whether each is a real game bug or an out-of-date test. Fix real bugs only in files you list in your report.
- `test_selection_heading` (2), `test_progression` (2), `test_weapon_batch` (1), `test_multiplayer`
  - Same treatment.
- `test_all_weapons_map`: 176 failures, already there in 0.44.
  - Make a list grouped by cause first; don't mass-edit.
- Done when: each test above passes, or has a one-line reason it can't, in your report.

## 4. Balance check against Conflict of Nations
Claude set the damage tables from Call of War, in `CombatSystem.ATTACK`/`DEFENCE`, by unit type
against infantry, light and heavy targets. National bonuses are the four doctrines in `game/scripts/doctrine.gd`
(Russian, European, American, Chinese; Ukraine is European). Owner's rule: Russian air defence and rockets beat
Europe's; Europe has the better tanks, aircraft and research. There are no other country bonuses; don't add any.
- Write `docs/BALANCE_REVIEW.md`: for each unit type, our numbers next to Conflict of Nations' (hit points,
  attack and defence against soft, hard and air, speed, range), with sources linked.
- Propose changes as a table, and keep Russia and Ukraine/Europe even overall. Don't apply them;
  the owner decides and Claude applies.

## Report back
For every item, send:
- branch and commit hash;
- tests run, with their RESULT lines;
- pictures where it's visual;
- anything you didn't finish, and why.

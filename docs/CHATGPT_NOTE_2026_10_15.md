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

## 2. Same units on both sides (owner: "the same amount of weapons for each side")
Claude already added `interceptor_ukraine` (Gripen E) and `airborne_ifv_ukraine` (Lynx KF41) using existing models.
Two Russian units still have no Ukrainian match, because no European model exists yet:
- `loitering_russia` (Lancet) -> **Warmate** loitering drone (Poland): needs a 3D model + unit picture.
- `a50u_russia` (A-50 radar plane) -> **Saab GlobalEye** (Sweden): needs a 3D model + unit picture.
Also needed: a unit picture for the **Lynx KF41** (`unit_art/euro_lynx_kf41.webp`, same style as the others,
then map it in `game/data/menu_art.json`).
**Ukraine gets European weapons only - nothing American, Israeli or other non-European.**
Add each new family by copying the Russian one in `game/data/equipment.json` (same stats, cost and research days;
id ending `_ukraine`), keeping the JSON layout. Models go in the owner's Drive, not Git.
- Done when: both sides have the same number of units and `tests/test_doctrine_stealth_wmd.gd` passes.

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
(Russian, European, American, Chinese; Ukraine is European and uses European weapons only). Owner's rule: Russian air defence and rockets beat
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

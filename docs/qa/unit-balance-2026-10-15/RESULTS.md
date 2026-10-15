# Unit balance and full-width card QA

Engine: Godot 4.6.3, GL Compatibility. Base: `98d83cf42d457c8751c801cdea9439172732e936`.
The comparator is a separate untouched checkout at that exact commit.

## Focused checks

| Check | Outcome |
|---|---|
| `test_economy_balance.gd` | 9,030 checks, 0 failures; 94×5 price/work/upkeep coverage, exact European research discount, actual 1×/2×/4×/10× research and 1×/4×/10× building/production completion, queue level/bill locking, legacy-save refunds, country-specific modernization, gold quotes, market floors, income/upkeep reconciliation and a complete 10× save validation |
| `test_transport_market.gd` | 74 passes, 0 failures; physical cargo/equipment, escrow, rail/sea/air, floors/demand, Wanted requests, freight research and UI. Updated the interdiction fixture to use an actual frigate against sea cargo instead of relabelling a tank as naval. |
| `test_unit_balance.gd` | 65,964 checks, 0 failures; all 94 families × 5 levels × 4 doctrines, finite valid values, progression, condition persistence and actual land/naval/AA/air HP damage |
| Real combat invariants | Patrol damage shared once per target stack; two aircraft share one defensive volley; strongest-ten limit; ineligible SAMs do not suppress short-range drone cover; small/large nuclear-stack outcomes |
| `test_unit_details.gd` headless | 30 checks, 0 failures |
| `test_unit_details.gd` native X11/llvmpipe | 30 checks, 0 failures; six genuine panel PNGs below |
| `test_air_defense_tree.gd` | 46 checks, 0 failures; updated old raw-percent expectation to verify monotonic HP damage and exact tier ratio without double scaling |
| `test_layered_air_defense.gd` | 6 passes, 0 failures |
| `test_player_accounts.gd` | 46 checks, 0 failures |
| `test_touch_controls.gd` | 11 printed passes, exit 0; final summary absent from captured output |
| `export_economy_balance.gd` | 470 unit/level and 53 building/level rows, 0 failures; actual shared backend prices and 1×/4×/10× durations |
| `export_unit_balance.gd` | 470 rows, 0 failures; CSV values are taken from the runtime helpers |
| Headless editor import | Passed without script/parse errors |
| `git diff --check` | Passed |

UI checks cover research-tile and army/city `open_unit` entry, selected/locked levels, actual research start,
enemy doctrine and disabled enemy research, photo width without distortion, vertical scrolling, visible
research action, 10× remaining-work countdown, the enemy’s own European research discount, production/upkeep prices, viewport resizing (640×1280, 720×1560, 1440×900) and the mixed-stack 110/110 HP total.
The source hero is cropped to fit its panel with aspect preserved, never stretched.

## Broader legacy suite comparison

| Existing test | This branch | Untouched base | Evidence / limit |
|---|---|---|---|
| `test_doctrine_stealth_wmd` | 0 assertion failures; one missing-model instantiate error | Same | The P-800 projectile is absent in both checkouts; assertions are not a clean asset-complete pass |
| `test_battle_effects` | 5 failures | 5 failures | Missing model attachments/projectile and smoke fixture |
| `test_building_expansion` | 21 failures | 21 failures | Missing facility models/previews and existing infrastructure assertion |
| `test_map_features` | 9 failures | 9 failures | Existing map/fixture assertions |
| `test_campaign` | Aborts at line 45; timeout | Same | Old research/production fixture indexes an empty array |
| `test_air_defense_models` | Missing legacy models; timeout | Same | Model resources absent from Git checkout |

The comparator runs were captured before the follow-up timing/price changes. `test_doctrine_stealth_wmd` was rerun after that follow-up: 0 assertion failures and the same absent P-800 error. The other broad legacy suites have not been rerun for the follow-up; they are baseline context, not a current full regression pass.

These suites were actually run on both revisions. Their original failure signatures are preserved in
`baseline-comparison.txt`; they were not edited to hide failures. Licensed model files were not replaced,
redistributed or committed. This checkout cannot establish a clean full regression result.

## Native screenshots

- [Full-width unit/research card](Unit_Card_Full_Width.png)
- [Separate attack, defence and terrain columns](Unit_Card_Combat_Terrain.png)
- [Production prices, upkeep and research bill](Unit_Card_Prices.png)
- [European tank card](European_Tank_Card.png)
- [Army total HP and full-width header](Army_Details_Actual_HP.png)
- [Per-unit HP and terrain](Army_Units_Actual_HP.png)

Screenshots render the actual reusable Godot panels using existing artwork in a standalone UI fixture.
They are not Android screenshots, live web captures, generated concepts, or proof of a full match playtest.

## Release handoff

Merge/review the source branch into Claude's current work and run the project with all private assets.
Build and deploy the client and authoritative server together so values and simulation agree. Retest a new
and an existing damaged save, unit modernization, both country rosters and an online opponent. Playtest
combined arms and equal-resource budgets; check pacing and revise numbers from actual results. Claude owns
merging, signing and release. No live deployment, Play upload or APK was produced by this work.

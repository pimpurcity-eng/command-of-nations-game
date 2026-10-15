# Starting forces and Odessa coastline — 15 October 2026

Matthew reported Odessa hanging over the map edge and restated the start:
3 tanks, 3 air defence, 1 aircraft, 23 infantry per country; three units per
city, with the remaining infantry placed singly in provinces. He also asked
for pictures before a release.

## Source and release status

- Base: `claude/v0.26-fixes` at `98d83cf42d457c8751c801cdea9439172732e936`.
- Review branch: `chatgpt/restore-start-army-odessa-20261015`.
- Claude retains merge, build and release ownership. This is a source correction;
  an Android APK or live deployment has not been produced by this work.
- The starting-force change applies to new campaigns. Existing saved matches
  keep their actual armies.

## Findings and correction

The active `populate_campaign_forces()` used a different rule from the older
scenario unit array: 4 light tanks, 4 air defence, 1 aircraft and 22 infantry
per side. The capital had seven ground units, the two front cities four each,
and the other four cities one each, with eleven separate infantry elsewhere.

The corrected new-match layout is:

| Location | Infantry | Tanks | Air defence | Aircraft |
| --- | ---: | ---: | ---: | ---: |
| Capital | 1 | 1 | 1 | 0 |
| Each of two front cities | 1 | 1 | 1 | 0 |
| Each of four remaining cities | 3 | 0 | 0 | 0 |
| Eight separate province posts | 8 | 0 | 0 | 0 |
| Existing province airport | 0 | 0 | 0 | 1 |
| **Per-country total** | **23** | **3** | **3** | **1** |

This yields 21 ground units in seven cities, eight single infantry armies in
provinces and the one grounded aircraft: 30 units per country. Air defence
retains its separate stack so it cannot pin the mobile city army in place.
The selected infantry post is removed from the candidate list after placement.
Scenario metadata, startup progress total and the two old troop-count test
assertions now match this layout. Starter levels and aircraft families remain
as in the current source.

City geometry previously conformed vertically to the ground without checking
whether a building's footprint was supported by land. The new city footprint
check samples rotated corners, edge midpoints and the centre against the drawn
ground index before adding complete buildings, roofs or park pieces. It keeps
the city's actual coordinates and destination intact. The check also fixes
the same overhang found at Rostov-on-Don.

## Godot 4.6.3 verification

| Check | Result |
| --- | --- |
| `test_starting_force_layout` | `RESULT starting_force_layout checks=70 failures=0` |
| `test_coastal_cities` | `RESULT coastal_cities checks=42 failures=0` |
| `test_city_courtyard` | `CITY COURTYARD: 207414 checks; 0 failures` |
| `test_owner_oct12` | `RESULT checks=390 failures=0` |
| `test_touch_controls` | 14 passes; `RESULT failures=0` |
| Editor import / script scan | No parse or script errors |
| Diff whitespace | Pass |

The new tests reproduce the original regressions: 24 starting-layout failures
and two coastal-city failures on the untouched base. Odessa had 5,125 city
vertices outside the drawn land; Rostov had 234. The corrected geometry check
reports no unsupported city vertices across all fourteen towns.

Two broader existing tests were also examined on both the base and correction.
`test_menu_province` has the same five research-fixture failures and missing
`tanks_russia` dictionary access on both. `test_oct15_evening` has the same
country-label movement failure and freed-node error during the patrol check
on both. These scripts do not finish, and are not counted as passing checks.

## Picture review

`tests/render_start_coast_review.gd` renders Odessa from the actual base and
corrected source using the same camera and graphics settings. It also creates
a starting-force count sheet from a new match, with assertions on each city's
three units and the eight remaining infantry. Its count sheet is a review
visual, not an added game menu. The coast views hide unit models to show the
building footprint clearly; their map badges still show the garrison counts.

Original unit-model files are not included in this checkout, so this review
does not establish weapon-model rendering or physical Samsung APK stability.
Run the normal complete asset/build pipeline after merging and inspect a new
match on Android before releasing it.

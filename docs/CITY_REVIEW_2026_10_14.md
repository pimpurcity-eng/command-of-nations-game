# City and unit renderer review — 14 October 2026

Based on Claude's latest `2b43f8f`, preserving his phone controls, zoom visibility, layered air defence, nuclear effects and other gameplay changes.

Claude's `43582a6` already removed the white pavement disc and enlarged ground garrisons by 35%. Native rendering with recovered original T-62 and motor-rifleman models confirmed that tanks are readable, but infantry remains small and the procedural city is a sparse ring around a large centre.

Changes:
- Keep the white disc disabled and grey concrete / blue-grey glass / slate colours.
- Reduce the clear centre radius from 0.70 to 0.54 district units (0.3888 world units), approximately 40% less reserved area.
- Bring the rear skyline inward, broaden tower silhouettes, fill the surrounding district with taller/wider apartment blocks and larger low-rise houses, and use a more readable facade window grid. Keep a clear centre and taller buildings behind it.
- Keep Claude's 1.35 city multiplier for tanks and other ordinary ground vehicles. Infantry and portable mortars receive a further 1.25 multiplier only while inside a city (combined 1.6875 relative to ordinary travel size). Aircraft and ships keep existing sizing. Uniform scaling and original model textures/proportions are retained.

Verification:
- Original-model OpenGL Compatibility renders at 720 x 960: Moscow with T-62; Tula with motor rifleman. These are isolated city/asset renderer scenes on a flat ground plane, not screenshots of an APK or the full running campaign. The original model load was confirmed for both. No AI image generation was used.
- Courtyard geometry checks: 79,841 checks, zero failures across all current cities in both capital configurations; also covers the compact reserve, disabled disc and infantry/tank garrison multipliers.
- Unit map sizing: 5,728 checks, zero failures across 88 equipment families.
- `git diff --check` clean.

No latest installed APK was available in this task. No new APK was built or signed. The next builder must use this integrated source with current private assets/signing identity and verify garrison labels, touch selection, city entry/exit, terrain, camera angles and performance in the exported app. Do not report phone or APK testing as complete.

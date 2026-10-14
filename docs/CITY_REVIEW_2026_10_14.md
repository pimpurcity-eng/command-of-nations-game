# Dense city and larger garrison — 14 October 2026

Owner approved implementation at 05:45 Atlantic after selecting the dense grey skyscraper-city concept with a larger tank. This supersedes the earlier same-size-in/out instruction and the sparse circular city layout from PR #10. The concept is art direction, not an APK screenshot or a replacement 3D asset.

Based on Claude's `454b282`, preserving his latest economy, weapons, combat and other gameplay work.

- All cities use the shared procedural district builder: dense muted street blocks and a permanent rear skyscraper cluster. Future cities and maps using this builder inherit the change.
- While occupied, the centre's cached building meshes hide and a compact dark square appears. The last visible live unit leaving or dying restores those buildings and hides the square. Flying aircraft and ships do not open it; grounded aircraft do. Hidden enemies do not reveal themselves through the city layout.
- Original ground vehicle models use a 1.60 city multiplier relative to travel size. Infantry and portable mortars receive an additional 1.50 multiplier (2.40 total). Original meshes, textures and proportions remain intact. Aircraft and ships retain existing sizing.
- Buildings and paving follow the terrain. Occupancy changes toggle cached batches rather than rebuilding the city. No white circular platform.

Validation after rebasing onto Claude's latest source:
- Godot 4.6.3 import: no script errors.
- `test_city_courtyard.gd`: 95,894 checks, zero failures, covering all currently loaded cities in both capital configurations, skyline retention, unobstructed square, occupancy and departure.
- `test_unit_map_size.gd`: 5,728 checks, zero failures across 88 equipment families.
- Actual OpenGL Compatibility renderer previews with original T-62 and motor-rifleman models, occupied and empty, at 720 x 960. Isolated flat-ground scenes, not full campaign/Android screenshots.
- `git diff --check` passes.

No APK built or signed in this task. Next builder: include this change together with current private assets and signing identity; verify multiple army stacks, city entry/exit, terrain, camera angles, labels, touch selection and performance in the exported campaign on the owner's phone. Do not claim the photorealistic concept is the exact procedural renderer output or that Android testing is complete.

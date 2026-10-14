# Missing unit artwork — 14 October 2026

Status: **COMPLETE**. 61 of the 61 previously missing unit portraits have been generated, reviewed, and installed. The current catalogue has 161 of 161 model-specific pictures, covering 420 of 420 offered research cards.

The finished artwork matches the existing realistic military catalogue style and is saved as square 512 × 512 WebP assets under `game/assets/interface/unit_art/`. Each model picture is reused by matching research levels, expanded research details, production and clicked-unit cards. Roman level badges stay in the UI rather than being baked into the images. Existing finished art and current gameplay are preserved.

Created with the built-in Imagegen tool. The exact subject prompts, saved asset paths and content hashes are recorded in `progress.json`; `RESEARCH_ART_COVERAGE.json` lists every research level and its shared picture. Every installed picture decoded successfully and matches a path already referenced by the shared manifest. Godot 4.6.3 imported the complete set without errors. The runtime check passed 3,305 checks with zero failures, loading all 420 research cards through both research and production/selected-unit helpers. All 161 model images have distinct content hashes; no unit model is missing its assigned picture. See `UNIT_ART_VALIDATION_2026-10-14.json` and `game/tests/test_unit_art_coverage.gd`.

The game-source artwork is complete and ready for the next browser/Android export. Existing builds receive these pictures when rebuilt and deployed; this artwork completion does not itself replace an installed APK or a published browser build.

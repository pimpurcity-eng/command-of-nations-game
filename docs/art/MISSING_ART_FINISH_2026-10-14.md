# Missing unit artwork — 14 October 2026

Status: **IN PROGRESS**. 13 of the 61 previously missing unit portraits have been generated, reviewed, and installed. The current catalogue has 113 of 161 model-specific pictures, covering 278 of 420 offered research cards.

The finished artwork matches the existing realistic military catalogue style and is saved as square 512 × 512 WebP assets under `game/assets/interface/unit_art/`. Each model picture is reused by matching research levels, expanded research details, production and clicked-unit cards. Roman level badges stay in the UI rather than being baked into the images. Existing finished art and current gameplay are preserved.

Created with the built-in Imagegen tool. The exact subject prompts, saved asset paths and content hashes are recorded in `progress.json`; `RESEARCH_ART_COVERAGE.json` lists every research level and its shared picture. Every installed picture decoded successfully and matches a path already referenced by the shared manifest. Godot import and runtime coverage checks are performed before publishing the completed set.

This is game-source artwork. No APK export is included in this artwork task.

# Saved artwork restored to the shared game branch

Recovered 39 finished equipment illustrations from `Warfront_Research_Art_Checkpoint.zip` and added them to `claude/v0.26-fixes` on 14 October 2026. The owner explicitly requested that the missing artwork be added to GitHub.

The saved generation checkpoint now has 107 finished images: 90 equipment pictures, 15 building pictures, and 2 city pictures. The 68 images already present in the game branch match the checkpoint byte for byte. Ten earlier air-defence illustrations are also retained, giving 117 existing images among the 178 unique paths in `game/data/menu_art.json`.

**61 planned images remain unfinished.** This is a restoration of the finished saved work, not a claim that all artwork has been completed. The older checkpoint handoff's completion counts were stale; the recovered `docs/art/progress.json` records the actual 107 finished files.

Validation: all 107 recovered images decode successfully at 512 × 512; all 39 additions match their saved original bytes and are already referenced by the shared menu manifest. Existing pictures and the manifest are unchanged. The current `MenuArt` / `CowUI` / `FacilityVisual` wiring shares these images across research, production, unit cards, and city menus. No gameplay scripts or 3D models were replaced.

Godot 4.6.3 imported the new WebP files without script parse errors; their import metadata is included. A headless runtime check passed 1,188 checks with zero failures, covering all 420 offered research levels, shared texture identity in research/selected-unit cards, correct images for model-changing tiers, and Roman labels I–V. This commit does not itself build an APK or verify phone rendering.

## Research levels and duplicate pictures

Audited all 420 offered research cards: 84 active families with levels 1–5. They use 161 distinct models, so 259 repeated card slots reuse a picture. The 100 model pictures available after restoration cover 249 research cards; the remaining 61 picture paths belong to distinct models, not repeated levels. See `RESEARCH_ART_COVERAGE.json` for every family, level, model, picture, and the deduplicated remaining list.

The research tree, active research jobs, selected research details, city production, production list, army details, army selection, army orders, and HUD already call `CowUI.research_picture(id, level)`. That function selects the model at the requested research level before looking up the shared image. For example, Russian long-range air defence reuses Buk-M3 for levels 1–2, S-400 for levels 3–4, and S-500 for level 5. Different models within a family keep their own pictures; an upgrade that keeps the same model reuses its existing picture.

The owner requested Roman level numerals. Research labels and card shields, unit selection, unit details, army orders, and production level labels now use I, II, III, IV, V. The expanded unit picture has a Roman level badge. Numerals remain UI overlays, so research and unit cards share the same original image.

The fallback image resolver now receives the selected level, too, so a tier without new custom art looks for that tier's original preview before falling back to a generic family picture.

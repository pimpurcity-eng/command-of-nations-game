# Upgrade pictures and Roman levels

The owner's final instruction is to reuse the existing unit pictures and change the level markers to I, II, III, IV, V. Repeated upgrades of the same unit model share one image in research, selected research details, city production, and clicked-unit cards. A change to a different model keeps that model's own image.

`EquipmentIdentity.picture_tier()` chooses one existing preview source for each model. This also fixes repeated levels choosing different original preview files while the browser's extra artwork pack is still downloading. Research statistics, costs, names, unlock days, and model choices still use the requested tier. The selected research picture now has the same Roman numeral badge as the research tree and expanded unit picture.

No new artwork generation is needed for repeated upgrade levels. The earlier list of missing custom artwork paths is not a count of extra pictures needed for those repeated levels.

Verified with Godot 4.6.3: editor import has no script parse errors; 1,873 runtime checks passed with zero failures across all 420 offered research cards. Checks include sharing the exact texture between research and clicked-unit cards, keeping one preview through repeated upgrades, preserving level-specific titles, and Roman level labels. Changes to unrelated files from concurrent game work are preserved.

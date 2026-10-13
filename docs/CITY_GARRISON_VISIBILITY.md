# City garrison visibility — 13 October 2026

Based on Claude's branch including seven cities per country and strongest-unit stack display (333829a).

- Increase the existing normalized unit dimensions by 20% in all three axes, retaining the same proportions, meshes, textures, animations, and touch-selection logic.
- Tanks receive a further 10% readability increase after the owner found the preview tank too small (32% total above PR #7). The courtyard was widened to fit.
- Portable mortars retain their smaller class limits. Projectile dimensions are unchanged.
- Replace the tiny city-centre square with a circular garrison courtyard centred on the real city destination, 0.504 world-unit radius.
- Reserve the centre against procedural buildings and parks. Retain skyscrapers with their existing shapes behind the courtyard, and arrange lower buildings around it.
- Preserve geography, unit destinations, building production, facility logic and saves.
- Three separately generated visual concepts explore grey concrete, muted brick and charcoal colours. These are art-direction concepts, not screenshots or replacement game models. The owner selected grey concrete: applied muted concrete walls, blue-grey glass and slate roofs while preserving procedural skyscraper geometry.

Validation: Godot 4.6.3 headless unit sizing test passes 5,728 checks across 88 weapon families. Courtyard geometry checks pass for all 14 current cities, each as capital and ordinary city (90,602 checks). Editor import reported no script errors. Original-model city rendering and physical Android testing remain outstanding; camera rotation and larger multi-unit formations need visual review. All future cities and maps using CitySystem share this generator; separate future city renderers must use the same courtyard and palette. No APK built.

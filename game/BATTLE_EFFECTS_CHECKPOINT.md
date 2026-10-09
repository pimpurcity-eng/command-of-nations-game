# Battle effects checkpoint

Changes applied to the recovered Command of Nations Godot 4.6.3 source.

- Tank and IFV combat now emits firing events, including defensive fire.
- Visible shooters produce muzzle flashes and brief model recoil without moving the simulation position.
- Missiles and interceptors use the recovered missile mesh, turn along their trajectory and leave fading smoke puffs. Artillery follows a higher ballistic arc; tank shells travel directly.
- Impacts produce flash, fire, smoke and an expanding shock ring.
- Added persistent flames were removed at the user's request; the earlier brief impact effect is restored. Missile trails use soft translucent smoke instead of polygon spheres.
- The original 20AB launcher now faces its truck cab toward the enemy when firing. Both country variants are checked in four firing directions.
- Damaged visible units emit smoke. Destroyed ground and naval units leave bounded, temporary wrecks using their original model geometry.
- Every unit has a soft ground shadow. Aircraft shadows remain on the ground; original meshes also cast sunlight shadows.
- Effects respect fog visibility and have bounded object counts and cleanup on campaign reset.

Validation: Godot native battle-effects checks and existing campaign checks for Russia and Ukraine pass with zero failures. Native OpenGL missile-flight preview rendered successfully.

The preview is a controlled scene in the existing game using its real models and effect code. This checkpoint is not deployed. Separate turret/rotor animation, battle audio, authentic per-launcher missile selection and phone performance validation remain future work. Existing model texture and missing-model issues are unchanged.

Changed integration files: scripts/combat_system.gd, scripts/combat_effects.gd, scripts/unit_system.gd, scripts/unit_visual.gd, scripts/unit_shadow.gd, assets/unit_shadow.gdshader. Tests are in tests/test_battle_effects.gd and tests/render_battle_effects.gd.

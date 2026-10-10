# Project audit — 2026-10-08

Shared audit for the developers (ChatGPT and Claude) working on Command of Nations,
so we both work from the same list. This was meant to be a GitHub issue, but the
Claude integration doesn't have permission to create issues on this repository yet.

## Current state

**GitHub (`pimpurcity-eng/command-of-nations-game`)**
- One branch (`main`) and one commit ("Initial commit").
- The only file is `README.md`.
- No Godot project files: no `project.godot`, `.tscn`, `.gd`, `.glb`/`.gltf`/`.fbx`, maps or textures.

**Floot app "Command of Nations"** (built by ChatGPT, published 2026-10-08)
- A React/SVG 2D prototype in a single file, `pages/_index.tsx`. It is not Godot.
- Map: 8 polygon provinces (Kyiv, Kharkiv, Dnipro, Odesa, Eastern, Belgorod, Kursk, Rostov).
- Units: 4 armies drawn as SVG tank icons with number labels.
- Working: tapping a province selects it. Selecting an army, pressing "Move army", then
  tapping a province moves the army there instantly. Also working: daily income, the
  "Build factory" counter and research tiers.
- Missing: terrain types, 3D models, combat, province capture, movement paths, and
  pinch-to-zoom or drag (zoom is +/- buttons only).

**Original 3D assets** (T-90, Su-57, helicopters, ships, air defense, etc.)
- Not in GitHub or Floot. Probably on a local machine or in Google Drive.

## Blockers
- [ ] Push the full Godot project to this repository: `project.godot`, scenes, scripts, maps and textures.
- [ ] Add the original 3D models, using Git LFS for large binaries, or link the Google Drive folder here.
- [ ] Decide whether the Floot React prototype is separate from the Godot game or replaces it.
- [ ] Confirm the branch name for Claude's work: `claude-development` or `claude/godot-strategy-game-io20at`.

## Planned first fixes (once the project is in the repo)
1. Run the project headless in Godot 4 and audit it: missing assets, script errors, and
   rendering problems (the small squares in the terrain, doubled rendering). Record what
   already works before changing anything.
2. Unit selection and movement: tap to select, tap a destination, show the movement path
   clearly, and add pinch-to-zoom and map dragging. Keep the existing mechanics.
3. T-90: switch to the original T-90 model and give Russian equipment the Su-57-style blue
   camouflage. Remove the labels above units and scale units to the map.
4. Terrain and cities: fix the square artifacts and doubled rendering, and set up the
   seven terrain types (urban, forest, mountains, hills, plains, desert, water).
5. Test in a portrait Android viewport (1080×2400) and attach real in-game screenshots for review.

All changes go through pull requests. Nothing is merged into `main` or published without
the owner's approval.

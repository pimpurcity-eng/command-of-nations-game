# Android test builds (for Claude and ChatGPT)

Owner: Matthew. Test builds only; never publish to a store.

## Current test build — 2026-10-10

- **0.16-weapons, versionCode 16**, package `com.commandofnations.test`.
- Godot 4.6.3 official Android debug template; ARM64 only, portrait,
  Compatibility renderer. Android 7.0 / API 24 minimum; target API 36.
- All 101 live original models: previous 69 plus 32 ships, drones and missiles.
  All-weapons mode uses the real campaign map, 165 local roads, separate sea
  berths and friendly airbase positions. Size, selection and live rotor fixes.
- APK **92,368,437 bytes** (<100 MB), SHA256
  `a351c671ee73134e07bd5fce065bd1334013133a51534e3574c45374d38b61f9`.
- APK ZIP/manifest/signatures verified, all live models present, no broken remaps.
  Original missile projectile models and material textures included.
- Eight required native suites: failures=0. New weapons 239/0; real-map suite
  572/0 in both source and final extracted APK. Road regression failures=0.
  Native portrait review has no script/render errors. Android hardware testing
  of this update remains for the owner.
- Install directly over ChatGPT 0.14 or 0.15; retain saves and the same key.
  On the start screen select **ALL WEAPONS · REAL MAP** to inspect/control either
  faction's equipment. Starts paused: tap Play to execute movement orders.

## Signing and first installation

The owner authorized ChatGPT to sign with its own key and keep it for every later
build. The private signing key and password are backed up separately; neither is
in this repository or the source handoff. Never generate a replacement key for an
update. Certificate SHA256:
`0289d3b051ee5e71dd25bc707b459f0a1e5413faea920069aa8636dc95b84bf0`.

This key differs from Claude's 0.13 test app. As the owner's takeover instructions
state, the first installation requires uninstalling Claude's same-package app
once, then installing 0.14. Uninstalling removes that app's local saves. Later
ChatGPT builds signed with this key can update 0.14 normally; do not uninstall or
clear saves as a routine step. Use versionCode 17 or higher for the next build.

## Rebuilding

1. Install Godot 4.6.3 and its matching official Android export templates.
   This build used Java 17 and Android SDK build-tools 35.0.0 with Gradle disabled.
2. Restore private original assets using `tools/install_air_defense.py`,
   `tools/install_arsenal.py`, `tools/install_new_weapons.py` and
   `tools/install_naval_drone_missiles.py`; retain building
   models and their original building textures. Models are never public Git files.
3. Run `godot --headless --path game --import` and all eight required suites
   using `xvfb-run -a godot --path game --script tests/<name>.gd`. After the
   first import, run `python3 tools/configure_phone_previews.py`, then import
   again before exporting. Also run `test_new_weapons`,
   `test_all_weapons_map` and `test_province_connections`.
4. Configure the editor's Android SDK/Java paths. Set the private environment
   variables `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`,
   `GODOT_ANDROID_KEYSTORE_DEBUG_USER`, `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`.
   From the repo: `godot --headless --path game --export-debug Android build/command-of-nations-test.apk`.
5. Verify with `apksigner verify --verbose --print-certs`, `aapt dump badging`
   and `aapt dump xmltree ... AndroidManifest.xml`; check the final size <100 MB.
6. Show native screenshots before any publication. APKs and signing files stay
   private; no store publication, public repo upload or main merge is authorized.

## Export size exclusions

The Android preset excludes unused root vehicle models/textures, duplicated
archived weapons, test scripts, reserve drone/catapult variants and unused missile
launch pictures. It keeps every live arsenal/AA model, their original materials,
shared building models/textures, and both original Tomahawk projectile models and
material textures required by existing missile effects. All source originals stay
private and unchanged. `configure_phone_previews.py` resizes derived research
picture imports only, to 512 pixels. Model/material textures are not resized.

# Android test builds (for Claude and ChatGPT)

Owner: Matthew. Test builds only; never publish to a store.

## Current test build — 2026-10-10

- **0.14-test, versionCode 14**, package `com.commandofnations.test`.
- Godot 4.6.3 official Android debug template; ARM64 only, portrait,
  Compatibility renderer. Android 7.0 (API 24) minimum; template targets API 36.
- Includes all 69 original live weapon models: ten AA, 29 tanks/APCs/aircraft,
  and 30 new artillery/helicopter/rocket models with their supplied pictures.
- APK: **94,199,951 bytes** (<100 MB).
- SHA256: `e396e898bc1ed384c6ebf4912d00682ba98615455f3600ace7a7676443bdae17`.
- APK ZIP integrity, package/version, portrait, ARM64 and v2/v3 signatures checked.
  Every packaged resource remap resolves; all 69 imported original models present.
- Eight required native Xvfb suites pass with zero failures. Additional new-weapons
  suite: 239 checks, zero failures in both source and the extracted APK resources.
  Native packaged-game screenshot rendering has zero errors. An actual Android
  device has not been tested.

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
clear saves as a routine step. Use versionCode 15 or higher for the next build.

## Rebuilding

1. Install Godot 4.6.3 and its matching official Android export templates.
   This build used Java 17 and Android SDK build-tools 35.0.0 with Gradle disabled.
2. Restore private original assets using `tools/install_air_defense.py`,
   `tools/install_arsenal.py` and `tools/install_new_weapons.py`; retain building
   models and their original building textures. Models are never public Git files.
3. Run `godot --headless --path game --import` and all eight required suites
   using `xvfb-run -a godot --path game --script tests/<name>.gd`. Also run
   `test_new_weapons` after equipment changes.
4. Configure the editor's Android SDK/Java paths. Set the private environment
   variables `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`,
   `GODOT_ANDROID_KEYSTORE_DEBUG_USER`, `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`.
   From the repo: `godot --headless --path game --export-debug Android build/command-of-nations-test.apk`.
5. Verify with `apksigner verify --verbose --print-certs`, `aapt dump badging`
   and `aapt dump xmltree ... AndroidManifest.xml`; check the final size <100 MB.
6. Show native screenshots before any publication. APKs and signing files stay
   private; no store publication, public repo upload or main merge is authorized.

## Export size exclusions

The Android preset excludes obsolete root weapon GLBs, their unused original and
recoloured weapon PNGs, the duplicate `weapons_2026_10_09` folder, and tests. It
keeps live `airdefense/` and `arsenal/`, original warehouse buildings and their
building textures, interface pictures and current game data. These exclusions
change packaging only; no original file is deleted or modified. A custom shield
and globe vector launcher icon replaces the exporter fallback icon.

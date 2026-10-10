# Android test builds (for Claude and ChatGPT)

Owner: Matthew. Test builds only; never publish to a store.

## Current state (2026-10-09)
- Latest test app: **0.10-test**, `version/code=10`, package `com.commandofnations.test`,
  built from `chatgpt/battle-effects` at `bc83e05` (Godot 4.6.3, Android preset `Android`,
  arm64, debug-signed, portrait, Compatibility renderer).
- Delivered privately in `pimpurcity-eng/Command-of-nations-builds` (private repo, one file
  `command-of-nations-test.apk`, must stay under GitHub's 100 MB limit). The Android export
  preset leaves out the archived weapon models (`exclude_filter`), giving ~84 MB.

## Signing
Android only installs an update over an existing app when it is signed with the **same key**.
The 0.1–0.10 builds were signed with Claude's debug keystore. ChatGPT's 0.9 air-defence APK
used a different key, so the two cannot update each other.

The keystore is a credential and is **not** in this repository or any shared folder. Until
Matthew decides how ChatGPT should get signing access, ChatGPT hands its work over as usual
(commits/bundle/patch) and Claude builds and signs the app. Never ask Matthew to uninstall
the app or clear saves as a routine step.

## Building (whoever holds the key)
1. Godot 4.6.3 with Android export templates, Android SDK (build-tools 35), JDK 21.
2. Install private models first (gitignored, never committed):
   `python3 tools/install_air_defense.py <weapons.airdefense.zip>`.
3. Bump `version/code` (next: **11**) and `version/name` in `game/export_presets.cfg`.
4. Set `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER`,
   `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD` to the test keystore, then from `game/`:
   `godot --headless --export-debug Android ../build/command-of-nations-test.apk`
5. Check: `apksigner verify`, the ten `airdefense` models present, size < 100 MB.
6. Run all suites (`game/tests/test_*.gd`) before handing a build to Matthew, and send
   screenshots before publishing anything.

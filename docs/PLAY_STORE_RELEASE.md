# Building and uploading Warfront Mandate to Google Play (for ChatGPT / any developer)

Written by Claude, 2026-10-14. No keys or passwords are in this file - never put them in Git or chat.

## App identity (never change these)
- Package: `com.warfrontmandate.game` - app name "Warfront Mandate: WW3".
- First Play bundle: version code 32, version name 0.32 (builds repo: `warfront-mandate-0.32.aab`).
- Latest: version code 43, version name 0.43 (`warfront-mandate-0.43.aab`). Version code = version name without the dot, so the next is 44 for 0.44.
- Every new upload needs a HIGHER version code (33, 34, ...).

## One-time: your own upload key
The 0.32 bundle was signed with Claude's upload key, which only exists in Claude's cloud machine and
cannot be shared. To upload future versions yourself:
1. Create your own upload key once and keep it (and its password) private, with a backup:
   `keytool -genkeypair -v -keystore warfront-upload.jks -alias upload -keyalg RSA -keysize 4096 -validity 10000`
2. Export its certificate (public, safe to share):
   `keytool -export -rfc -keystore warfront-upload.jks -alias upload -file upload_certificate.pem`
3. Give `upload_certificate.pem` to the owner. In Play Console: the app -> Test and release -> App integrity
   -> App signing -> "Request upload key reset" -> reason "lost/changed developer" -> upload the .pem.
   Google approves in about 2 days. From then on your key signs every upload.
(Play App Signing re-signs the app for users, so changing the upload key does not affect players.)

## Each release
1. Source: branch `claude/v0.26-fixes` of `pimpurcity-eng/command-of-nations-game` (fetch, merge, never build from `main`).
2. The original private 3D models must be in `game/assets/library` (not in Git); run `tools/make_new_models.gd`.
3. Android build template (once): unzip `<godot export templates>/4.6.3.stable/android_source.zip` into
   `game/android/build`, write `4.6.3.stable` to `game/android/.build_version`, and create `game/android/build/.gdignore`
   (`game/android/` is git-ignored).
4. TEMPORARILY edit the Android preset in `game/export_presets.cfg` (restore it afterwards, never commit it):
   `gradle_build/use_gradle_build=true`, `gradle_build/export_format=1` (AAB),
   `version/code=<next number>`, `version/name="0.xx"`,
   `package/unique_name="com.warfrontmandate.game"`, `package/name="Warfront Mandate: WW3"`.
5. Export with the key given through environment variables (not written into any file):
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH=... GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... godot --headless --export-release Android ../build/warfront-mandate-0.xx.aab`
6. Check: `jarsigner -verify <file>.aab` says "jar verified".
7. Test the same build on a phone or emulator first (an APK from the same commit) and show the owner screenshots.
8. Upload in Play Console: the app -> Test and release -> Testing -> Closed testing (or Production)
   -> Create new release -> upload the .aab -> release notes -> Next -> Save -> Send for review.
9. Write a dated note in the Drive Notes folder (no secrets).

## Web version (separate, automatic)
`https://play.warfrontmandate.com` serves the browser build from the builds repo `web/` folder:
export Web, run `python3 tools/split_web_pack.py <out> game`, copy into `web/`, update `web/VERSION`, push.
The server updates itself within 15 minutes. The match server also auto-updates from `claude/v0.26-fixes`.

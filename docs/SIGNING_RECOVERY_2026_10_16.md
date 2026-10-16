# Warfront Mandate Android signing recovery — 16 October 2026

The original Play upload key has not been recovered. This note records a verified older test key and a prepared fallback; no upload-key reset, Play upload, or production deployment has been performed.

## Original Play upload key

Claude's updated handoff identifies the original builder session as the only known location of the key used for Play bundles 0.32–0.57. That separate session is unavailable to the owner for two days.

Expected SHA-256 from the signed 0.57 bundle, as recorded in the handoff:

`52:E5:01:BA:65:57:58:0B:21:BB:76:42:6B:F1:F5:04:6B:86:CC:E7:41:DE:22:49:C3:44:6F:3F:26:AB:94:61`

## Backup recovered and verified

- Existing private backup: `Command_of_Nations_Private_Signing_Backup.zip`, created 10 October 2026.
- Contains `commandofnations-test.p12`, alias `commandofnations-test`, and the owner's existing signing configuration.
- Key type: RSA 3072, private key entry. Loading the private key and signing/verifying a test message succeeded.
- SHA-256: `02:89:D3:B0:51:EE:5E:71:DD:25:BC:70:7B:45:9F:0A:1E:54:13:FA:EA:92:00:69:AA:86:36:DC:95:B8:4B:F0`.
- This is the older sideload/test key, not the current Play upload key.
- An encrypted copy of the recovered .p12 has been restored to the owner's existing **Command of Nations - App signing (PRIVATE, do not share)** Drive folder. Readback confirmed owner-only access.
- The password remains in the owner's pre-existing private backup; no password was copied to Drive, this repository, or the chat.
- Exported public certificate: `warfront_recovered_key_certificate.pem`, saved with the recovery files and available to the owner as a download.

## Search coverage

- Current workspace and available local Android/Gradle directories: no original Play key.
- Drive filename searches for .jks, .keystore and signing/upload-key names: no matching Play keystore.
- Existing private signing folder and its Optomized child: empty before the recovered test key was restored.
- All 60 commits in the private builds repository were inspected for signing/key file paths: none.
- All 243 commits reachable from the authoritative source branch were inspected for keystore/private-signing file paths: none.
- These checks do not inspect the original Claude session's filesystem, the owner's phone, or differently named keys inside unrelated archives.

## Available paths

1. Recover the original key inside the original Claude builder session when that session becomes available, and verify its full certificate fingerprint.
2. If the owner chooses to change upload keys now, the recovered, backed-up RSA key meets Google's minimum upload-key size. Its exported public certificate is ready for an upload-key reset request. It becomes a Play upload key only after Google accepts and activates that reset.

Google Play Console: existing Warfront Mandate app → Manage Play app signing → Upload key certificate → Request upload key reset. Attach the public PEM certificate. Keep the existing package `com.warfrontmandate.game` and the Google-held app signing key.

The browser available to this task currently shows Google sign-in before Play Console; account authentication is required before the current Play certificate or reset status can be checked. A browser upload-key change must be completed by the owner because the browser's credential-change policy requires user handoff.

Official guidance: [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en) and [Android app signing](https://developer.android.com/studio/publish/app-signing).

## Release preparation

The repository's checked-in Android preset still uses `com.commandofnations.test`, version code 23. A Play build must use `com.warfrontmandate.game` and a version code higher than the latest accepted Play upload. No export preset or game source was changed during this recovery.

After the signing path is chosen, restore private models, run the required game checks, build an APK and AAB from the same source commit, verify the package/certificate, and show genuine build screenshots before a Play upload.

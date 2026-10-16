# Warfront Mandate Android signing recovery — 16 October 2026

The original Play upload key has been recovered and independently verified. A replacement upload-key reset is still pending; cancellation and restoration of Play uploads have not yet been confirmed. No Play upload or production deployment was performed during this recovery.

## Verified original upload key

- File: `warfront-upload.jks`, PKCS12 container, 4296 bytes.
- File SHA-256: `d75db8aa1c8f70ddc718b68aee445598ca909679cd34159287c4e0e5c299e8e1`.
- Alias: `upload`; RSA 4096 private key.
- Certificate subject: `CN=Warfront Mandate, O=Yaska, C=CA`.
- Certificate SHA-256: `52:E5:01:BA:65:57:58:0B:21:BB:76:42:6B:F1:F5:04:6B:86:CC:E7:41:DE:22:49:C3:44:6F:3F:26:AB:94:61`.
- Certificate SHA-1: `BD:18:A2:97:F0:F9:8E:D8:2C:68:F6:C7:3B:5B:88:DA:C5:C1:85:0D`.
- The owner supplied the keystore and its password. Loading the private key succeeded; signing a test message with RSA/SHA-256 and verifying against this certificate passed.
- The full certificate fingerprint matches the previously recorded original Play upload certificate.
- An encrypted keystore backup was saved in the owner's existing private signing folder. Readback confirmed the expected size, folder, and owner-only permissions. The password was not copied to Drive or GitHub.
- This test establishes key access and certificate identity; it does not validate a new game build or a Play upload.

## Pending upload-key reset

The owner submitted a replacement certificate on 16 October at 16:41 UTC. Google's confirmation email schedules activation for **18 October 2026 at 16:41 UTC** (13:41 Atlantic Daylight Time). Google says new APK/AAB uploads are blocked while this reset is pending.

The scheduled replacement is the older backed-up test key, with certificate SHA-256:

`02:89:D3:B0:51:EE:5E:71:DD:25:BC:70:7B:45:9F:0A:1E:54:13:FA:EA:92:00:69:AA:86:36:DC:95:B8:4B:F0`

The original key is now verified, so the owner has been advised to cancel the pending reset in Play Console. **Cancellation has not yet been observed.** After cancellation, confirm Play Console retains the original upload certificate and permits uploads. Do not assume the block clears immediately.

If the reset remains pending and activates, the scheduled replacement key must be used for subsequent Play uploads. Check Console status before signing a release.

## Recovery history

Before the owner recovered the original key from Claude, searches of the current machine, Drive filenames, source/build repository histories and saved Play-build artifacts did not locate it. The older backup `Command_of_Nations_Private_Signing_Backup.zip` was found and verified first. It remains a fallback, rather than the original Play credential.

## Release preparation

Use the authoritative `claude/v0.26-fixes` source branch and confirm the current head before building. Preserve the Play package `com.warfrontmandate.game`; use a version code higher than the latest accepted upload. Apply release export settings privately.

Restore required private assets, run the required game checks, build an APK and AAB from the same source commit, verify package and signing certificate, and show genuine build screenshots before a Play upload.

Official references: [Use Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756?hl=en) and [Android app signing](https://developer.android.com/studio/publish/app-signing).

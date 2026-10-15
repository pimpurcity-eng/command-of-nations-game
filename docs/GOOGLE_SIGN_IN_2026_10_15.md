# Turn on Google sign-in - Warfront Mandate

Supabase project: **wrnmscdtwbezcmrlukvg**, Warfront Mandate.
Checked 15 October 2026: project healthy; public Auth settings return `external.google = false`
and `external.email = true`. No dashboard setting has been changed. The existing game source
already implements Google sign-in for the browser. Android remains email-only in this source. The Android app is already on Google Play and running.
Any mention of OAuth Testing below concerns the Google sign-in client, not the Android release.

## 1. Select the existing Google Cloud project

Open https://console.cloud.google.com/ and use the project picker at the top. Choose the Google
Cloud project for Warfront Mandate. Its ID is separate from the Supabase project ID.
Open **Google Auth Platform** and **Get started** if setup has not been completed.

Under **Branding**, use:

- App name: `Warfront Mandate: WW3`.
- User support email: a verified address you can receive mail at.
- Home page: `https://warfrontmandate.com/`.
- Privacy policy: `https://warfrontmandate.com/privacy.html`.
- Authorized domain: `warfrontmandate.com` (domain only).
- Developer contact: a monitored address.

Verify domain ownership if Google asks. Support-mailbox delivery has not been tested here.
In **Audience**, use **External** for players outside your Workspace organisation. While the
OAuth app is **Testing**, add each Google account that will test under **Test users**.
In **Data Access**, use basic sign-in scopes only: `openid`, email and profile. No Gmail, Drive
or Calendar access is needed. Complete Google's publishing/brand checks before public access.

## 2. Create or reuse a Web application client

Open **Clients -> Create client -> Web application**. Reuse an existing correctly configured
Web client if one exists, rather than creating duplicates.

| Field | Exact value |
| --- | --- |
| Name | `Warfront Mandate Web` |
| Authorized JavaScript origins | `https://play.warfrontmandate.com` |
| Authorized redirect URIs | `https://wrnmscdtwbezcmrlukvg.supabase.co/auth/v1/callback` |

Click **Create**. Keep the **Client ID** and **Client secret** ready in your own dashboard.
The origin has no path. Google's callback has no wildcard. The `/**` value goes in Supabase's
allow-list in step 4, not in Google's OAuth client.

## 3. Enable Google in Supabase

Open https://supabase.com/dashboard/project/wrnmscdtwbezcmrlukvg and confirm **Warfront Mandate**.
Go to **Authentication -> Sign In / Providers -> Google**.

1. Turn **Enable Sign in with Google** on.
2. Paste the Web **Client ID** into **Client IDs** (or Client ID, depending on dashboard labels).
3. Paste the **Client secret** into the secret field.
4. Keep the normal security defaults; do not turn on skip-nonce/security bypasses for this flow.
5. Save.

Keep the secret in Google and Supabase. Never put it in the game, Git, Drive notes or chat.

## 4. Set the return address

In **Authentication -> URL Configuration**:

| Field | Value |
| --- | --- |
| Site URL | `https://play.warfrontmandate.com/` |
| Redirect URLs - exact root | `https://play.warfrontmandate.com/` |
| Redirect URLs - requested allow-list | `https://play.warfrontmandate.com/**` |

Save. Preserve other existing legitimate return URLs. The exact root covers today's game
return path; `/**` covers paths below this specific host. Do not broaden to other domains
or put a wildcard in Site URL.

## 5. Check the complete sign-in

Use a browser/device with working WebGL2. Reopen https://play.warfrontmandate.com/.

1. Open **Account**. After provider settings are checked, **Sign in with Google** should appear.
2. Select it and choose an allowed test account while Google's OAuth app is in Testing.
3. Complete Google's screen and return to `play.warfrontmandate.com`.
4. Confirm the commander profile opens and sign-in tokens disappear from the address bar.
   New Google accounts receive the existing default commander name.
5. Check sign-out/sign-in again and return to an assigned online nation, if available.

Current source stores tokens in memory and clears the URL fragment after reading it. Do not
promise login persists after closing the browser until separately verified. Never capture a
URL containing access or refresh tokens in screenshots or notes.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| No Google button | Provider enabled/saved in this exact Supabase project; reload so the game checks settings again |
| `redirect_uri_mismatch` | Exact Supabase callback in Google's authorized redirect URI field |
| `access_denied` / test-user error | Add that Google account under Audience -> Test users, or finish public OAuth publishing |
| Wrong return page | Site URL and allow-list must cover the exact play-host root |
| Works on web, absent on Android | Expected now. Android needs its own tested app deep link/return flow |
| WebGL2 launch error | Browser graphics support prevents startup; it is separate from OAuth setup |

## What was checked

Read-only provider verification used `/auth/v1/settings` with a publishable key. No password,
Google secret, service-role key or token is included. OAuth completion is untested because this
session's browser cannot launch the game. No database schema, RLS, key or auth setting changed.

Official instructions checked 15 October 2026:

- https://supabase.com/docs/guides/auth/social-login/auth-google
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/changelog (HTML used after the markdown index was unsupported)

The recent old TLS cipher deprecation does not change this Google callback setup. No relevant
OAuth setup-breaking change was identified in this check.

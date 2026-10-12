# Warfront Mandate: accounts and online server preparation

## Implemented in this branch

- Reuses the existing native Supabase account screens for signup, six-digit email confirmation, login, recovery, logout, profiles and account deletion.
- Account switches clear cached profiles. Responses from a previous session cannot repopulate profiles or restore a logged-out session.
- Local campaign results no longer submit online XP. Migration 003 revokes players' access to the old client-reported result RPC.
- A Node 22 HTTPS-behind-proxy API verifies every player token with Supabase Auth and requires confirmed, non-anonymous accounts. It admits only defined lobby and order requests, limits request size/rate, rejects extra client identity fields and does not expose database errors or server secrets.
- Server-only PostgreSQL functions persist two-country lobbies, membership, ordered commands, snapshots and verified rewards. Retries use a stable UUID; checkpoints use revision guards; completed matches award XP once. Clients cannot start matches, overwrite checkpoints, report winners or view raw snapshots.

## What is NOT finished

The gateway is **not an authoritative Godot simulation worker**. It does not execute movement, combat, research, production, economic trade or elapsed offline time. Valid commands are only queued. The existing game is not wired to the gateway. There is no live Supabase project, SMTP configuration, server deployment, 100-client load test or updated Android build from this change. `WM_MULTIPLAYER_ENABLED` stays false until the simulation and country-specific state filtering are connected and tested.

The reviewed account branch predates the current 0.22 local game. This branch contains a focused diff against `chatgpt/battle-effects`; it must not replace the newer game wholesale. Port only the account fixes and backend files into the current game. Europe and world previews are not enabled or modified here.

## Tests actually run

- Godot 4.6 isolated native account project: 33 checks passed, using simulated provider responses.
- Node gateway: 10 tests passed (invalid/unconfirmed authentication, closed multiplayer, identity spoofing, membership denial, order validation, privileged route absence, request limits, origin handling and secret separation).
- Embedded PostgreSQL (PGlite) with provider Auth stand-ins: 12 behavioral checks passed, plus parent test. Applied all three migrations, checked RLS and privileges, replay guards, checkpoint compare-and-swap, persisted restart recovery, one-time rewards, limits and deletion cascades.

These are local checks, not proof of live Supabase Auth/email delivery or a physical Android test.

Run backend tests: `cd backend`, `npm ci`, `npm test`. Run the account test in the existing Godot project with `godot --headless --path game --script res://tests/test_player_accounts.gd`; if the older branch lacks private models, use the isolated account fixture rather than modifying campaign assets.

## Live account setup after Supabase connection

1. Use a Warfront Mandate Supabase project dedicated to this game, separate from Yaska. Confirm its region and plan before provisioning a paid resource.
2. Require confirmed email/password accounts. Set a 12-character password minimum, six-digit OTP email templates, short OTP expiry and provider rate limits. Site URL: `https://warfrontmandate.com`.
3. Apply 001, 002 and 003 in order to the intended project. Keep `private` outside exposed Data API schemas. Verify the grants with separate anonymous, confirmed and unconfirmed accounts.
4. Configure custom SMTP for non-team testers. The default Supabase sender is insufficient for public onboarding. Verify sender domain DNS and test delivery, expired/used codes, recovery, deletion and two-account data isolation before inviting testers.
5. Only the project URL and `sb_publishable_` key go in Godot `game/config/accounts.cfg`; server keys belong in host secret settings. Keep credentials out of GitHub and chat.
6. Include configuration and account changes in a tested build of the current game. Website publication does not update an installed APK.

## Gateway deployment after simulation integration

Use a Linux server behind HTTPS at an intended API address such as `api.warfrontmandate.com`. The Node service binds to loopback by default; the Docker image binds inside the container and must be published only to the host's loopback address (for example `-p 127.0.0.1:8080:8080`). Configure host secrets from `.env.example`; never send them to phones. Health endpoint reports `not_ready` while multiplayer is disabled. The current rate limiter uses socket addresses and does not trust forwarded headers; configure trusted proxy handling before public scaling behind a reverse proxy.

A simulation worker alone calls `server_start_match`, `server_restore_match`, `server_checkpoint` and `server_finish_match`. It must enforce ownership, legal routes, timing, prerequisites and resource balances using the current Godot rules. A queued response is not an accepted/applied order. Add fog-of-war filtered state delivery and a persistent worker lease before running multiple workers against a match. Add monitoring, restore drills and load tests before choosing server size.

No paid resources or public online accounts were created by this preparation.

References:
- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/reference/javascript/auth-getuser

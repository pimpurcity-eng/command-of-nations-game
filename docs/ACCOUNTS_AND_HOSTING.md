# Command of Nations — accounts and hosting

Status: first native account implementation, not a deployed service. Existing campaign remains offline. No paid services were provisioned, no real registration/email was sent, no shared multiplayer match exists yet. Infantry prototypes remain archived and unused.

## First implementation

More → Player account opens a native portrait sheet. Register an email/password/commander name; enter an emailed six-digit confirmation code; sign in; request a password-reset code; verify it and replace the password; log out. Email code flows avoid having to deep-link from an email app into Android. Password confirmation and server-facing input validation are included. Signup does not auto-login, unconfirmed accounts cannot become player sessions, and recovery sessions cannot be used as normal player sessions. Expiring in-memory sessions refresh with a 30-second retry backoff. Requests time out after 20 seconds; raw backend errors/tokens are not displayed or logged. Android network permission is enabled for the next build.

Passwords, access tokens and refresh tokens are never saved locally. A cold app restart requires login; durable auto-login must use Android Keystore/iOS Keychain before being added. Tokens in client memory only inform UI. Future game servers must independently validate token signature, issuer, audience, expiry and user identity, and enforce account restrictions. Never trust client-side signed_in(), client-declared commander names, user_metadata, army state, or resource balances as authorization.

The profile migration creates a private UUID-linked profile on Auth signup and uses row-level security to allow a confirmed player to read/rename their own profile. Emails remain in Auth, not a public profile directory. Commander names are display names, not unique login identifiers. No client-editable roles, bans, currency or match state exists.

## Connect the service

1. Provision a dedicated Command of Nations Supabase project, independent of Yaska. Start with a nearby North American region and measure latency from testers.
2. Enable email/password signup and require Confirm Email. Enforce a minimum 12-character password. Configure six-digit OTPs, short OTP expiry and provider-side signup/verify/recovery rate limits. Local resend cooldown is convenience only, not a security boundary.
3. Configure a transactional SMTP sender for the chosen domain, verify SPF/DKIM and configure DMARC. Supabase's default sender reaches project-team addresses only, so it is unsuitable for the 100 testers. Raise email throughput deliberately for a tester onboarding wave, keeping abuse controls. Invite in batches.
4. Apply backend/migrations/001_player_accounts.sql once to that project, with private excluded from exposed Data API schemas. Configure confirmation/reset templates from backend/email/. They use {{ .Token }}, not a website callback.
5. Copy game/config/accounts.example.cfg to game/config/accounts.cfg with the HTTPS project URL and sb_publishable_ client key. No service-role key, JWT signing key, SMTP password or secret key belongs in Godot. Build-time configuration must include only these public values.
6. Verify registration and delivery to a non-team email address, code expiry/replay/retry, duplicate emails, confirmed/unconfirmed login, recovery/relogin, refresh, offline handling, and logout against the actual provider. Test database isolation with two real accounts, including denied cross-player reads/updates and denied privileged fields. Migration has been prepared, not applied or validated on a live PostgreSQL service.
7. Render/review screens, then coordinate Claude's Android build/signing. Existing installed app does not gain this code automatically. No APK/release was published in this change.

## Hosting that grows with players

| Component | First testers | Growth path |
| --- | --- | --- |
| Accounts and profiles | Managed Supabase Auth + PostgreSQL | Increase database compute after measuring bottlenecks; keep stable player UUIDs |
| Email | Transactional SMTP on the game domain | Adjust quotas and monitor delivery/bounces |
| Website / downloads | Static site and object storage/CDN | CDN absorbs download bursts without loading simulation servers |
| Shared matches | Separate Linux headless Godot workers, using the existing game rules | Assign matches to additional workers; capacity grows with active matches, not one server per player |
| Match gateway | HTTPS/WebSocket service validating Auth tokens | Add instances behind a load balancer; route each match to its owning worker |
| Persistent match state | Server-owned snapshots and an ordered command log in PostgreSQL | Snapshot/checkpoint intervals, restore drills, database scaling and archival |

A hundred interested people is not a hundred simultaneous players. Before picking a game server size, measure concurrent logins, active matches, players per match, message traffic and simulation tick cost. Run 25/50/100-client load tests with reconnects, missed updates and a worker restart. Measure latency, CPU/memory, gateway error rate, queue depth and checkpoint recovery. Do not promise a capacity based on an Auth monthly-active-user allowance.

Phones draw units and effects. The server decides ownership, movement time, research, production, combat outcomes and resources. Do not synchronize trusted game state by uploading each phone's local save. Long-running strategy matches keep running while a player is offline and restore from durable state after a restart. These server rules and the lobby/matchmaker are planned, not implemented by the account adapter.

At the research date Supabase Pro starts at USD $25/month, with 100,000 monthly active users and daily backups; that is account/database pricing, not a multiplayer capacity guarantee. The total also includes simulation hosting, transactional email, downloads/storage and the domain. No server cost/capacity quote is justified before load tests. Use budget alerts and provider spending controls where available; schedule independent backup/restore tests before shared tester matches.

## Source and verification

Native UI: game/scripts/accounts/account_panel.gd. Transport: player_auth.gd. Preview: game/scenes/accounts/account_preview.tscn (opens directly when run; the default panel remains hidden in game). Test: Godot --headless --path game --script res://tests/test_player_accounts.gd. This test uses simulated service responses and checks validation, confirmation/recovery isolation, session expiry/refresh/logout, request serialization and screen construction. The native render script is tests/render_accounts.gd.

Official references consulted:
- https://supabase.com/docs/guides/auth/passwords
- https://supabase.com/docs/guides/auth/auth-smtp
- https://supabase.com/docs/guides/auth/auth-email-templates
- https://supabase.com/docs/reference/javascript/auth-verifyotp
- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/auth/managing-user-data
- https://supabase.com/pricing

Claude handoff: new accounts files/backend/docs plus a small More-menu signal in hud.gd, lazy panel creation/map-input guard in main.gd, and Android internet=true in export_presets.cfg. Preserve existing map, cities, units and main campaign. Do not re-enable archived infantry. Actual hosting configuration, SMTP, live integration and Android signing remain open.

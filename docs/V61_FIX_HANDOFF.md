# Version 61 fixes for Claude — 17 October 2026

User's final direction: add these fixes to 61; Claude will finish the build/release.
This is source work on top of `claude/v0.61` at `912b2e279e7466c236aee88b945b2bcb5617cc87`.
While validation was underway, 61 received the tutorial/film repairs in PR #22. Those newer repairs were retained in full; the overlapping preliminary training implementation was dropped before rebasing this patch.
No APK, AAB, web export, or production match-server deployment was started by this handoff.
Keep the existing 61 loading changes, films, models, maps, music, and other Claude work.

## Changes included

- The latest 61 tutorial repairs are preserved, including accepted-order progress, city/garrison selection, real-action feature lessons, film recovery, and frame-budgeted training startup.
- Regular multiplayer requires completed training and commander level 10, checked against the account database by both client and authoritative match server. Client fields and editable user metadata do not authorize admission. Previewing a match does not claim a country.
- The once-only training award remains 10 XP. This is level 1, not level 10; the reward screen now explains continued progression. Do not silently grant 8,100 XP.
- Regional admission refuses an occupied requested country instead of assigning the other country.
- A match browser probes configured servers for real day, speed, capacity, country availability, finished/full/unreachable status, and the signed-in account's existing seat. Each saved online round has its own server/map/match identity and Resume.
- Match records are account-scoped and contain public match metadata only. Existing seats can be rediscovered on configured servers after signing in on another device. This is not a dynamic server allocator; add real rounds to the configured catalog as they are provisioned.
- The signed-in auth object survives campaign scene changes. The chosen match survives OAuth reload without saving account tokens. Both regional and Europe entry use the same eligibility path; alliance operations preserve their match and side.
- Website intent handling supports `?mode=training`, `online`, `practice`, `resume`, and `new-games`. Apply `docs/V61_WEBSITE_ACTIONS.patch` to the current website branch (`claude/website-home-20261017`, audited head `c39033ce235d5093157e00f0d9f1b42058b3e431`) to connect the actual website buttons. Its design/assets are preserved in that branch; this commit does not roll them back to the older website in 61.
- Optional railway models wait for the relevant web pack; the detached source model is freed on scene exit. Training supply registration also tolerates legacy test catalogs without research tiers.

## Database already applied

`backend/migrations/20261017131549_multiplayer_access.sql` was applied successfully to project `wrnmscdtwbezcmrlukvg` as migration `multiplayer_access`.
It adds only a read-only, security-invoker RPC using the caller's own profile and training achievement under existing RLS. Anonymous execution is revoked; authenticated execution is granted.
Do not run it a second time just to build. No player XP, rewards, seats, or existing schema fields were changed.

## Validation

Godot 4.6.3 official Linux binary, checksum `d0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3` (download archive).
Headless import succeeds. Focused checks:

- `test_training_match.gd`: 97 checks, 0 failures, on the final merged 61 source.
- `test_training_interaction.gd`: 13 checks, 0 failures.
- `test_training_cinema.gd`: 23 checks, 0 failures.
- `test_online_flow.gd`: 28 checks, 0 failures. Includes a real local HTTP account fixture plus real WebSocket admission: 8,099 XP refused despite forged level-99 metadata; high XP without training refused; trained 8,100-XP account admitted.
- `test_multiplayer.gd`: all checks passed, including occupied-country refusal.
- `test_player_accounts.gd`: 58 checks, 0 failures.
- Home button and air-defense research-tree checks pass.

The broader legacy suite is not release-clean in this source-only environment: missing original building/launcher assets cause failures, old map-feature expectations report 8 failures, and the air-defense-model test does not complete successfully with the audit's asset fixture. Do not report the entire required suite as passed. Restore the original assets with the existing private build pipeline and rerun the required tests before publishing. Campaign/touch tests pass their assertions; their legacy-catalog research-tier error was guarded in this patch.

## Claude's remaining build/release work

1. Pull the new `claude/v0.61` head. Preserve any concurrent changes and use one exact source SHA for export and server.
2. Apply the website CTA patch to the current website branch and preview the buttons. The game export must contain the intent handler before those URLs become live.
3. Restore every original asset with the existing private build pipeline; import, run the focused tests above and the required regression suite, then export 61 using its existing split-pack tooling. Verify both tutorial films and all model inventory across core and extra packs.
4. Deploy the match server as well as the web files; the server's auto-updater follows its checked-out branch, so updating 61 alone does not prove the live server has these admission checks.
5. Verify live VERSION/source SHA and measure compressed initial payload for 61. The audit's 103.71 MB wire measurement was for live 0.60, not 61.
6. Check on the actual Samsung phone: training as each side, tapping a capital with a garrison, movement after deselection, sign-in return to the selected match, real country selection, separate Resume targets, films, and returning after backgrounding.

## Still outstanding from the full audit

The full audit is in `docs/WEBSITE_FLOW_AUDIT_2026-10-17.md`. This handoff is not a claim that all 16 findings are resolved. Remaining work includes a genuine shared two-player training mode, automatic reconnect/resync, confirming replacement of a training save, and browser/support recovery polish. The incoming PR #22 already strengthens the real-action feature lessons and film recovery; retain those repairs. There is no automatic creation of new multiplayer server processes in this patch.

The cloud review browser lacks WebGL2, so in-browser battle rendering and physical-phone performance were not verified here.

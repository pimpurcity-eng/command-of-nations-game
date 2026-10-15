# ChatGPT handoff - 15 October 2026

## Scope and owner steering

All work is on `chatgpt/...` branches based on source `6e32091`. Matthew reserved
`city_system.gd`, `unit_system.gd`, `main.gd`, `strategic_map.gd`, `web_extras.gd` and
`tools/split_web_pack.py` for Claude. All six remain unchanged.

Matthew confirmed the Android app is ALREADY on Google Play and running. This is work on
updates to that existing app/listing. Do not recreate the app or reset signing/upload keys.
He approved the existing website page and said to leave it. Website edits were withdrawn;
no website, existing hosting branch, live game, Supabase config or Android build was changed.

## Ready for documentation / marketing-asset review and merge

Branch: `chatgpt/release-support-20261015`.

- `docs/play-store/`: replacement 512 x 512 icon, 1024 x 500 feature graphic, separate listing
  fields, reviewer instructions and detailed form guide for the existing Play app.
- `docs/GOOGLE_SIGN_IN_2026_10_15.md`: full Google Cloud + Supabase setup, exact callback/origin,
  `https://play.warfrontmandate.com/**` allow-list and success checks. Read-only live provider
  check returned Google false, email true. User completes secret entry in their dashboards.
- `docs/qa/LIVE_TEST_2026_10_15.md`: numbered observed findings, source-review concern and
  untested match coverage. The illustrated PDF and original screenshots are in Drive Notes.

No runtime-code or schema change is part of this branch. Merging it does not submit Play forms,
replace the live listing, turn on Google or deploy anything. Keep existing Play screenshots
unless genuine replacements from the corresponding Android build are approved.

Validation: title 21/30, short description 78/80, full description 2215/4000 characters;
icon RGBA/512, feature RGB/1024x500, images opened/visually inspected; diff whitespace and
all six protected-file comparisons pass. PDF report rendered and all four pages inspected.

## City branch - waiting for Matthew's approval

Branch: `chatgpt/city-concepts-20261015`.
Images in `docs/concepts/cities-2026-10-15/`: occupied skyline with a large tank overlay and
matching full city after the tank leaves. These are separate AI concept images, not models
or game screenshots. Do not integrate or start models until Matthew approves.
After approval, actual model previews must be verified in the real game camera and at unit scale.

## Remaining work requiring another capability or decision

- Full live match was not completed: this browser reports WebGL2 unavailable before the menu.
  The existing Android app's working status is not contradicted by this test environment.
- Account-deletion email is obscured and its link opens Cloudflare Email Protection. Reported,
  not changed, because the owner said to leave the website.
- Online chat belongs in Other in-app messages. Verify the current Play form and privacy
  policy against server match/seat/message records and their deletion/retention behaviour.
  No end-to-end deletion was attempted.
- Google provider configuration and a successful OAuth login remain pending. Android Google
  sign-in additionally needs an app return link; the current implementation is web-only.

Claude performs all merges and any later deployment/release. No protected branch was pushed.

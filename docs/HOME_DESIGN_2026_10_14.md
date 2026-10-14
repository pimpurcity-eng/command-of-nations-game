# Warfront Mandate shared home redesign — 14 October 2026

Owner request: make the existing website, Android home and browser/game home professional
and visually consistent. Lead with AI defence while away, economic gameplay and economic
victory, real trains/ships/tankers carrying trade, and the other implemented systems.
The website stays silent; the app/game retain their existing music and sound.

## Website
- Existing Cloudflare branch `chatgpt/warfront-mandate-hosting`, folder `website/`.
- Published commit `ba3c149390e21a62d8ffc9d25bd9badeb60d6928`.
- Verified live at https://warfrontmandate.com/ with Play buttons targeting
  https://play.warfrontmandate.com/ and functioning local artwork, font and legal URLs.
- Navy/brass visual system, original Warfront art, three leading differentiators,
  equipment illustrations, twelve feature explanations, play options and dated updates.
- No website audio, video or script. Local fonts and their OFL licences are included.
- Do not describe larger Europe/world scenarios or weapon markets as currently playable.

## Shared app/game home
- `game/scripts/mobile_start_panel.gd` remains the ONE home screen for Android and Web.
- Home, Features, News and Settings pages; real local-save Resume; nation/doctrine cards;
  campaign, online, weapons range, account entry; six-language selector; loading/progress.
- Account signal is connected to the existing AccountPanel, with commander name refresh.
- Music/Sound switches still use GameAudio's stored settings. The existing custom track
  and artist credit are retained whenever the base build includes that track.
- No game rules, armies, city renderer, model sizing, accounts backend or signing identity
  were replaced. Preserve the newer Play Store release documentation and game changes.
- Feature data is shared in `game/data/home_features.json`; `tools/sync_homepage.py`
  generates the website feature/news text from it. Mirror website changes onto the
  actual hosting branch when editing this copy.
- Actual native renderer previews: `docs/review/home-design/`. These are engine previews,
  not proof of physical Android installation or browser rendering.

## Validation
- Godot 4.6.3 import and export compile cleanly.
- `game/tests/review_homepage.gd`: native portrait/desktop rendering, navigation,
  real music/sound preferences, country/doctrine selection, account signal, saved/unsaved
  campaign states, loading lock and cancellation pass.
- Actual campaign start was exercised through mouse input in test_startup_progress.
  Updated that test's catalogue expectation to omit the four retired equipment families,
  matching the existing weapons-range code. This changes no gameplay.
- Website static asset/anchor/feature/Play-link checks and git diff --check pass.
- Full browser rendering and physical Android verification were not performed in this task.

## Browser delivery
The private builds repo has the current engine, original start/extras packs and music.
A small `web/home.pck` overlays only main/mobile-start scripts and feature JSON BEFORE
startup.tscn loads; `web/home_boot.gd` is preloaded through the standard Godot Engine API.
The existing model/music packs are unchanged. The same deployed base PCK was tested with
this overlay in the native runtime; it opens the new 12-feature lobby with menu music.
`tools/make_home_overlay.py` creates the overlay from a fresh export.
The Droplet's existing web-sync updater picks up the builds commit on its normal timer.
A future FULL web export from this source uses the normal generated index.html and already
contains the new home. It need not retain the overlay launcher; do not keep an outdated
main.gdc overlay when publishing later gameplay changes.

## Android delivery — still needs a new installed build
No APK/AAB is created or signed by this UI task. Build the next app from the active branch
INCLUDING this home redesign and all newer work, with the private original assets and
existing licensed music. Follow docs/PLAY_STORE_RELEASE.md for the real package/key.
Do not claim the owner's installed app has updated until the new build is installed.

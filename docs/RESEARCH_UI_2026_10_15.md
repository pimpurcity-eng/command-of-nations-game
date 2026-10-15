# Research and city artwork readability — 15 October 2026

Owner screenshots showed dark city production portraits, research thumbnails that were hard to inspect, and a yellow control crowding the active-job countdown.

- Removed the 55% brightness multiplier from unresearched city unit portraits. Locked state remains explicit in the label and action state. Enlarged city unit portraits from 96×80 to 112×96.
- City unit pictures now request the research unit card. Research tree pictures, refinement cards, and the selected research portrait also open an inspection dialog with a larger image, role, tier details, baseline combat values, applicable special ranges/damage, costs, research duration, and a validated research action. Researched and unavailable tiers remain inspectable; their research action is disabled with a reason.
- The yellow control is the paid gold speed-up button, not a progress indicator. Moved it below the countdown/progress inside each status box, labelled it “Finish now”, and allowed the countdown label to wrap instead of truncating behind a fixed-width side button.

Validation: Godot 4.6 parses main.gd and the referenced UI scripts. A temporary headless UI smoke fixture opened the inspection dialog, exercised its research action, and checked speed-up button placement and caption. git diff --check passes. Android touch/layout and full rendered appearance still require device testing. No APK or production deployment was made for this follow-up.

Claude: include this follow-up when integrating PR #14; do not replace newer artwork assets or ongoing city work. The brightness fix is in CityPanel._refresh_units, not in the artwork image files.

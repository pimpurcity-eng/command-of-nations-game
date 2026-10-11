# Command of Nations 0.19

Same Godot game, existing com.commandofnations.test package and signing key.
Version code 19, version name 0.19-fixes. Install over the existing app.

- Selection names have a separate full-width 28 px heading above the commands.
  Detail text is 18 px, status text 16 px, and the portrait is enlarged without
  cropping. Long headings wrap without a line limit. Units, cities and provinces
  update the heading; clearing a selection removes the previous name.
- Every friendly flying unit on patrol has a cyan circle and aircraft symbol at
  its patrol centre. It stays at that centre as the aircraft flies and disappears
  on Return, a replacement order or unit removal. This includes fighters,
  bombers, helicopters, drones and loitering aircraft.
- Missile launchers and silos show a red target reticle while attacking. The
  marker follows a moving visible target and clears on cancellation/destruction.
  Missile movement and attack orders render no connecting route lines.
- Ukrainian units initially point at the nearest Russian city. Moving units
  retain their order direction; idle restored Ukrainian units receive the new
  country-facing bearing.

Source checks: selection headings 8/0, mission markers and country facing 306/0,
phone feedback 67/0. Compiled APK tests are recorded in the release validation.
Original version 18 drone-selection, launcher-origin and helicopter-order fixes
are retained. Android hardware validation remains for the owner.

Built with Godot 4.6.3 by replacing exported script bytecode/remaps and manifest
version in the existing 0.17 APK. Original Android engine, model and texture
resource bytes are retained. APK alignment and matching v2/v3 signature are
verified. No new signing key or store publication.

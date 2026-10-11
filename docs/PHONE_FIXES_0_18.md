# Command of Nations 0.18 phone fixes

Same existing Godot game and package com.commandofnations.test. Version code 18,
version name 0.18-fixes. The original signing certificate is retained.

- Drone and aircraft picking uses projected model bounds, including wings, with
  model-centre distance resolving overlapping silhouettes. Direct model taps
  take priority over the forgiving base-marker tap area.
- Missile source models retain a launch marker at their original Nose geometry
  before merging. Silos use their top centre. Combat effects begin at the world
  position of that marker after aiming the launcher.
- Fly orders to a city execute the flight instead of opening city inspection.
- Accepted movement orders in all-weapons inspection start the simulation.
  Normal campaign pause behaviour is preserved.

Validation: source regression 96 checks, all-weapons map 572 checks, phone
feedback 67 checks, army selection 10 checks, and touch controls passed.
The final APK is verified for v2/v3 signatures and 16 KiB native library
alignment; its certificate matches the installed 0.14–0.17 app. Android hardware
validation remains for the owner. A raster review could not run because the
current environment cannot connect Godot to the available X11 server.

Build used the original 0.17 APK resources and Android engine, replacing the
106 script bytecode/remap entries with Godot 4.6.3 exports of this source and
updating the Android manifest version. All other APK resource bytes are retained.
Do not publish assets or sign with a new key. Install over the existing app.

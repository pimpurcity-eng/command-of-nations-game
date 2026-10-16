# Russia–Ukraine training match — 16 October 2026

Source implementation for review on chatgpt/russia-ukraine-training-20261016, based on
claude/v0.26-fixes at 700b7b775f4cb2a94d0a8e6303e49cd95505c386. The unfinished
claude/wip-oct16 work was not folded into this change. No live deployment or Play upload.

## Final requested sequence

1. Watch the owner's 30-second war-opening film, including its original sound.
2. Enter the real Russia–Ukraine map. Learn controls and new features through actual actions.
3. After 5–10 foreground, unpaused minutes, watch the 30-second ship/train film.
4. Return to a loaded American ship at Odesa and a European weapons train at Lviv.
5. Inspect and unload each manifest, then move reinforcements and continue the full match.

The owner's latest change supersedes the earlier twenty-unit proposal: **five weapons on each
vehicle, ten in total; one of the ship's five is a plane**. All start and aid units are level 1.
Three routes remain: Full training, New features only, and Skip introduction / Play now.
Skipping all or the logistics lessons settles remaining aid once. Skipping pre-arrival lessons
retains the second film and its five-minute gate. Both playable countries see the same films;
the aid belongs to Ukraine even when the human commands Russia.

## Starting preset

| Units | Russia | Ukraine |
| --- | ---: | ---: |
| Tanks | 5 | 3 |
| Infantry | 4 | 4 |
| Artillery | 2 | 1 |
| Air defence | 2 | 1 |
| Drones | 2 | 2 |
| Light attack aircraft | 1 | 1 |
| Total | 16 | 12 |

Each city has a level-1 airbase, drone factory, tank plant, barracks and ordnance factory.
Lviv and Kyiv have rail stations; Odesa has a naval base. Basic infantry research is known at
level 1 only in this preset, allowing production to be taught while another family researches.
Every aircraft has an operational home airport. Russia starts with 1.5× stocks and a persistent
1.5× scenario income factor. The opponent AI waits during guided teaching and starts at Take command.

This is a compressed game scenario. The numbers, direct Odesa resupply and mixed modern hardware
are balance choices, not a precise February 2022 order of battle or historical shipment record.

## Loaded aid after film two

| Destination | Route | Five level-1 weapons | Other aid |
| --- | --- | --- | --- |
| Odesa | American ship | 1 M1A1 Abrams, 1 M109A7 Paladin, 1 Avenger, 1 MQ-9A Reaper, **1 F-16AM plane** | 25,000 funds; 12,000 materials; 9,000 fuel; 5,000 electronics; 8,000 food |
| Lviv | European train | 2 tanks, 1 artillery, 1 air defence, 1 drone from Ukraine's existing European families | 15,000 financial assistance; no physical resource crates |

The ship visibly carries five equipment models and resource crates. The train carries five equipment
models. Each has a selectable manifest and a separate unload action. Unloading removes that vehicle's
visible cargo, creates its five real units at the terminal, and credits its resources exactly once.
The F-16 has Odesa as its home airbase. Scripted transport vehicles are the story's destination displays;
ordinary attackable trade convoys continue using TradeNetwork. This change does not replace trade rules.

American equipment identities are registered separately from domestic research/production, using the
existing equipment-family balance and model paths. The F-16 uses the existing F-16AM model identity.
Unit inspection and save validation understand imported identities; domestic catalogues remain intact.
Private models are not committed. Visible transport geometry is provided when those assets are absent.

Cargo does not count as earned economic-victory income. A lost receiving city or required terminal
keeps its requested cargo pending until Ukraine recovers it. Reloading or repeating a video callback
cannot duplicate equipment or money. Before unloading there are 28 units; after the ship, 33; after
both vehicles, 38. Aid is a single arrival, not a recurring or staggered grant.

## Actual tutorial actions

Eight basics: select an owned tank, issue a movement order, open an owned city, inspect a unit card,
start research, queue infantry, order a drone patrol, and queue construction.
Five feature actions: physical trade, Transport market prices, Guard, Victory progress, and Diplomacy.
Seven logistics steps: inspect ship, unload ship, inspect train, unload train, move owned reinforcements
(or Russia's own tank), inspect trade, then Take command.

Next stays disabled until the relevant action occurs. Completed actions are saved. Show me focuses
an appropriate unit/city/vehicle or opens the actual panel. A gold control outline and in-panel
instructions guide the player while leaving menus usable. Objectives progress after completed actions
when the map is visible. The final Take command is explicit. Lessons can be skipped independently.

Training progress, active time, video position, action flags and requested/received/pending cargo live
in user://training_save.json. Ordinary campaign saves are preserved. Background and paused time do not
advance the arrival timer. Training overlays step aside on Home and full-screen menus. Normal campaigns,
weapons range and online mode do not retain the training income factor.

## Verification and release work

Godot 4.6.3:

- Training integration: **85 checks, zero failures**. Covers both sides, installed films, action gating,
  real selection/orders/research/queues/patrol/panels, 5+5 manifests, ship plane and airbase, per-vehicle
  unload, money, idempotence, pending-cargo save/resume, captured terminals, and ordinary-state restoration.
- Economy balance: **9,030 checks, zero failures**.
- Multiplayer: **35 passing assertions, zero failures**.
- Project import and script compilation: no script errors.
- Both converted films fully decode with original audio and are 30.033333 seconds.
- Portrait desktop captures exercise both films, map teaching, menus, ship/train and manifests.

The source checkout lacks private rail/arsenal models. The existing rail renderer logs missing
rail_straight.glb errors; tutorial assertions pass. Desktop geometry and fallback models do not establish
how the complete private asset pack looks or performs on a phone. Restore private assets, build the
portrait Android app, check both complete videos with sound and play through the tutorial on the
owner's Samsung before publishing. No APK/AAB or live web build is supplied by this source update.

Separate requests for mandatory account training, a level-10 multiplayer gate and two-player training
are not implemented in this local scenario change. The full offline match continues after guidance.

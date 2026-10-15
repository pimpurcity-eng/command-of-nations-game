# Warfront Mandate unit balance review — 15 October 2026

Owner request: full-width photos in army/unit/research details; differentiated HP, attack, defence,
terrain and national strengths; consult Call of War (including its doctrines wiki) and Conflict of Nations.
Later steering also authorizes longer construction/research/production times, a price review, and a push.
All base times are balanced at 1×; 4× and 10× shorten actual waits without multiplying prices.
The latest owner instruction authorizes applying this pass on a review branch. Claude still owns merge,
app/server builds and release. This is a first playable balance pass, not a claim of proven PvP parity.

## References and what they establish

| Primary source | Verified lesson used here |
|---|---|
| [Call of War units](https://wiki.callofwar.com/wiki/UNITS) | Infantry, artillery, light/heavy armour and naval units have different durability and specialist roles. |
| [Call of War combat](https://wiki.callofwar.com/wiki/COMBAT) | Damage varies by target class, attack/defence, terrain, remaining condition and the strongest-ten limit. Its worked example uses 20 HP per light tank; that example is not a complete current stat table. |
| [Call of War construction and production](https://wiki.callofwar.com/wiki/CONSTRUCTION_%26_PRODUCTION) | Higher models take more production work, factories mitigate that work, low morale slows work, and displayed prices are charged when work starts. Warfront uses its own pacing and factory increments. |
| [Call of War research](https://wiki.callofwar.com/wiki/RESEARCH) | Modernizing an existing army uses half the target model’s production cost and time. |
| [CON research](https://wiki.conflictnations.com/Research) | Hierarchical research, doctrine availability and refunds proportional to unused research work. |
| [Call of War doctrines](https://wiki.callofwar.com/wiki/DOCTRINES) | Axis, Allies, Comintern and Pan-asian doctrines combine general strengths/weaknesses with iconic-unit bonuses and research timing. Warfront keeps its own four modern doctrines. |
| [Conflict of Nations units](https://wiki.conflictnations.com/Units) | HP and attack/defence are separate attributes. Its attack/defence ratings are explicitly described as ratings, not guaranteed flat damage. |
| [Conflict of Nations doctrines](https://wiki.conflictnations.com/Military_Doctrine) | Eastern emphasis on MBTs, SAMs and gunships; European emphasis on mechanized infantry, tank destroyers and strike fighters; Western early armoured combat vehicles, theatre defence, attack helicopters and AWACS. |
| [Conflict of Nations combat](https://wiki.conflictnations.com/Combat) | Terrain changes attack, defence and speed; stacked force size and air-defence timing matter. |
| [CON motorised infantry](https://wiki.conflictnations.com/Motorised_Infantry) | Affordable city defenders need supporting arms and remain vulnerable to artillery. |
| [CON main battle tank](https://wiki.conflictnations.com/Main_Battle_Tank) | Heavy protection and direct fire, with difficulties in urban and rough terrain. |
| [CON support](https://wiki.conflictnations.com/Support) | Towed/mobile artillery, rocket artillery and the AA layers have distinct target roles. |
| [Rheinmetall Leopard](https://www.rheinmetall.com/en/products/tracked-armoured-vehicles/main-battle-tank-leopard-trademark-of-knds-deutschland) | Real tank capabilities combine firepower, protection and mobility; this does not supply a national superiority ranking or a literal HP value. |
| [MBDA ASTER family](https://www.mbda-systems.com/products/area-protection/aster-family) | Different interceptors serve short/medium/long-range air and missile defence roles; upgrades change capability. |

Public official text does not expose a complete current numerical matrix for every level in both games.
No missing competitor values were guessed. All exact numbers below and in the CSV are original Warfront
values informed by those roles. HP and percentages are game abstractions, not measured real-world vehicle
survivability; doctrine advantages are balance choices, not blanket claims about nations' actual forces.

## Applied system

- All 94 live equipment families have explicit mappings to 47 role profiles; all five levels are covered
  (470 unit/level entries). Six target classes remain unchanged: infantry, light armour, heavy armour, air,
  ships and submarines. No new weapon models, arsenal duplicates or separate country-trait system.
- HP varies by role, research level and the existing doctrine. Research increases durability as well as damage.
  Example Russian level I stack from the screenshot: light tank 35 + motor infantry 25 + motor infantry 25 +
  Strela short AA 25 = 110 HP, replacing 400 generic condition points shown as HP.
- Damage is now actual HP per event. Saved `health` remains a 0–100 condition percentage: conversion occurs
  exactly once on the receiving unit. An old unit at 37.5% stays at 37.5%; its damage is not reset or healed.
  Upgrading preserves the percentage and changes capacity. Daily percentage recovery and forced march keep
  their old percentage meaning; medics/recovery/hospitals now heal their advertised actual HP amounts.
- Attack/defence are different for each role and target. Fighters excel against air, attack helicopters against
  armour, bombers against soft ground targets, escorts against submarines, submarines against surface ships.
  Recon drones, transports, cargo/oil ships and support vehicles are unarmed. Strategic launchers show their
  separate nuclear-blast rule instead of pretending their area blast is ordinary direct fire.
- Both land and air enforce the strongest-ten contribution limit. Patrol damage is 65% once per target stack,
  shared across its units; it no longer multiplies by the target's unit count. A defensive AA volley is shared
  across the attacking squadron, respecting each aircraft's engagement layer.
- Damage efficiency is applied once to the displayed strength. Previously the army panel multiplied health
  twice. Army HP and map-tag bars are weighted by actual total capacity; unit list and split panel use real HP.
- Terrain keeps separate attack, defence and movement effects. Tanks lose defence in cities (-15%) and forests
  (-10%) as well as offensive effectiveness. Light tanks, snipers, special forces, marines and light mortars
  have their own terrain overrides. HP capacity does not change when crossing terrain, avoiding free healing.
- Nuclear stack pool changed from 1000 old condition points to 250 actual HP; a lone army is wiped out while
  a 14-infantry stack can survive. The chemical strike is 12 HP with its existing protection/falloff rules.

## Four existing doctrines, one national system

| Doctrine | Strengths retained | HP addition in this pass | Tradeoffs retained |
|---|---|---|---|
| Russian | AA, artillery, rockets and missiles +15% damage | Those roles +5% HP | Aircraft -10% damage; research -10% speed; units 10% cheaper |
| European (Ukraine) | Tanks/aircraft +10% damage; all defence +10%; research time -15% | Tanks/aircraft +8% HP | AA/missiles -5%; production -10% speed; manpower -10%; drones 15% cheaper |
| American | Aircraft/navy +15% damage, existing stealth | Aircraft/navy +5% HP | Units 20% dearer; ground forces -5% damage |
| Chinese | Production +25% speed; units 10% cheaper | HP -5% | Damage -10% |

European tank/air defence retains the existing multiplicative 1.10 × 1.10 = 1.21 rule; this is Warfront's rule,
not Call of War's additive stacking. Russia remains Russian and Ukraine remains European. Ukraine's European
weapon restriction and the starting troop/layout work in PR #15 are unaffected. Cost and research differences
matter when comparing equal budgets; same-unit duels alone do not establish match balance.

## Base role values before doctrine, level I

Numbers are original HP damage per combat event. Target order in each six-number list:
**infantry / light / heavy / air / ship / submarine**. Level and doctrine adjusted values for every family,
plus prices, range, speed and terrain modifiers, are in [unit-stats.csv](qa/unit-balance-2026-10-15/unit-stats.csv).

| Role | HP | Attack by target | Defence by target | Intended use / weakness |
|---|---:|---|---|---|
| Motorized infantry | 25 | 4 / 2 / 1 / 0 / 0 / 0 | 6 / 3 / 1.5 / 0 / 0 / 0 | Affordable city defence; needs armour and artillery support. |
| Airborne infantry | 22 | 4.5 / 2 / 1 / 0 / 0 / 0 | 4 / 2 / 1 / 0 / 0 / 0 | Light assault troops; less durable than motorized infantry. |
| Special forces | 28 | 6 / 3 / 2 / 0 / 0 / 0 | 5 / 3 / 2 / 0 / 0 / 0 | Strong in forests, hills and mountains; vulnerable in open ground. |
| Naval infantry | 28 | 5.5 / 2.5 / 1.5 / 0 / 0 / 0 | 5 / 2.5 / 1.5 / 0 / 0 / 0 | Urban assault troops; loses effectiveness in mountains. |
| Snipers | 18 | 5 / 0.5 / 0 / 0 / 0 / 0 | 7 / 0.5 / 0 / 0 / 0 / 0 | Anti-infantry specialist in cover; ineffective against heavy armour. |
| Main battle tank | 55 | 8 / 12 / 10 / 0 / 0 / 0 | 7 / 10 / 9 / 0 / 0 / 0 | Heavy direct fire in open country; vulnerable in cities and mountains. |
| Next-generation tank | 65 | 9 / 13 / 12 / 0 / 0 / 0 | 8 / 11 / 11 / 0 / 0 / 0 | More protection and anti-armour firepower; expensive to field. |
| Light tank | 35 | 6 / 5 / 2.5 / 0 / 0 / 0 | 4 / 4 / 2 / 0 / 0 / 0 | Mobile infantry support; cannot trade evenly with main battle tanks. |
| Armoured personnel carrier | 32 | 4 / 3 / 1 / 0 / 0 / 0 | 4 / 3 / 1 / 0 / 0 / 0 | Protected infantry transport; limited anti-tank capability. |
| Infantry fighting vehicle | 40 | 6 / 5 / 2.5 / 0 / 0 / 0 | 5 / 4 / 3 / 0 / 0 / 0 | Infantry support and light-armour combat; weaker than tanks against heavy armour. |
| Airborne fighting vehicle | 28 | 5 / 4 / 2 / 0 / 0 / 0 | 4 / 3 / 2 / 0 / 0 / 0 | Lighter fighting vehicle; trades protection for deployability. |
| Self-propelled artillery | 24 | 4.5 / 6 / 6.5 / 0 / 0 / 0 | 1 / 0.6 / 0.4 / 0 / 0 / 0 | Ranged anti-armour support; weak if caught in close combat. |
| Rocket artillery | 22 | 7 / 6 / 4.5 / 0 / 0 / 0 | 0.7 / 0.4 / 0.2 / 0 / 0 / 0 | Long-range area fire; vulnerable while reloading. |
| Light mortar | 14 | 3.5 / 1.5 / 0.4 / 0 / 0 / 0 | 0.6 / 0.2 / 0.1 / 0 / 0 / 0 | Light anti-infantry support; low protection and little anti-tank effect. |
| Heavy mortar | 18 | 4.5 / 2 / 0.8 / 0 / 0 / 0 | 0.7 / 0.3 / 0.1 / 0 / 0 / 0 | Heavier indirect infantry support; weaker against armoured targets. |
| Towed artillery | 18 | 5.5 / 3.5 / 3 / 0 / 0 / 0 | 0.8 / 0.4 / 0.2 / 0 / 0 / 0 | Economical indirect fire; very vulnerable at close range. |
| Short-range air defence | 24 | 1.5 / 0.6 / 0.2 / 3.5 / 0 / 0 | 2 / 0.8 / 0.3 / 4 / 0 / 0 | Protects against drones and low attack runs; cannot engage high bombers. |
| Long-range air defence | 22 | 0.5 / 0.3 / 0.1 / 5 / 0 / 0 | 0.8 / 0.4 / 0.2 / 5.5 / 0 / 0 | Area air defence against larger aircraft; short-range cover counters drones. |
| Tactical ballistic missile | 20 | 6 / 10 / 12 / 0 / 0 / 0 | 0.5 / 0.3 / 0.2 / 0 / 0 / 0 | Powerful strike followed by a long reload; needs protection. |
| Missile silo | 70 | 8 / 12 / 16 / 0 / 0 / 0 | 0.3 / 0.2 / 0.1 / 0 / 0 / 0 | Hardened long-range strike site; little direct defensive fire. |
| Coastal anti-ship missile | 24 | 0 / 0 / 0 / 0 / 14 / 0 | 0 / 0 / 0 / 0 / 1 / 0 | Anti-surface-ship specialist; cannot engage submerged submarines or land armies. |
| Strategic missile launcher | 22 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Single nuclear launch uses the separate area-blast damage pool and consumes the launcher. |
| Air superiority fighter | 28 | 1.5 / 1 / 0.5 / 9 / 0.5 / 0 | 0.5 / 0.5 / 0.2 / 8 / 0 / 0 | Air-to-air specialist; limited ground attack. |
| Strike fighter | 30 | 7 / 6 / 5 / 4 / 3 / 0 | 1 / 1 / 0.5 / 3.5 / 0 / 0 | Multirole ground attack; loses air duels to dedicated fighters. |
| Interceptor | 24 | 0.8 / 0.5 / 0.2 / 11 / 0 / 0 | 0.3 / 0.2 / 0.1 / 9 / 0 / 0 | Fast air interception; almost no ground-strike capability. |
| Strategic bomber | 38 | 9 / 5 / 3.5 / 1 / 4 / 0 | 0 / 0 / 0 / 1 / 0 / 0 | Long-range ground strike; vulnerable without fighter and air-defence support. |
| Attack helicopter | 22 | 6 / 8 / 9 / 1 / 1.5 / 0 | 0.5 / 0.5 / 0.3 / 1 / 0 / 0 | Strong against armour; vulnerable to fighters and short-range air defence. |
| Transport helicopter | 26 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Transport, not a gunship; requires an escort. |
| Light attack aircraft | 20 | 4 / 2 / 1 / 1.5 / 0.5 / 0 | 0.2 / 0.1 / 0 / 1 / 0 / 0 | Economical infantry attack; vulnerable to fighters and SAMs. |
| Reconnaissance drone | 10 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Reconnaissance platform; no offensive weapon loadout. |
| Strike drone | 14 | 4 / 4.5 / 3.5 / 0 / 0.5 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Precision ground support; fragile and needs short-range-AA suppression. |
| Loitering munition | 6 | 4 / 7 / 8 / 0 / 1 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Single-use anti-armour strike; consumed even when the target survives. |
| One-way attack drone | 8 | 6 / 3 / 1.5 / 0 / 2 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Single-use long-range attack on soft targets; weaker against heavy armour. |
| Transport aircraft | 30 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Cargo and logistics aircraft; unarmed. |
| Airborne early warning | 32 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Radar and surveillance aircraft; unarmed and needs fighter cover. |
| Frigate | 80 | 2 / 1.5 / 1 / 5 / 6 / 12 | 0 / 0 / 0 / 6 / 6 / 12 | Fleet air-defence and anti-submarine escort; moderate surface firepower. |
| Destroyer | 100 | 4 / 3 / 2 / 4 / 11 / 11 | 0 / 0 / 0 / 5 / 10 / 8 | Strong surface combatant and anti-submarine escort; expensive. |
| Corvette | 60 | 1.5 / 1 / 0.5 / 1.5 / 5 / 3 | 0 / 0 / 0 / 2 / 4 / 3 | Light coastal escort; weaker protection than ocean-going warships. |
| Submarine | 65 | 0 / 0 / 0 / 0 / 14 / 6 | 0 / 0 / 0 / 0 / 11 / 6 | Surface-ship ambush specialist; threatened by sonar escorts and other submarines. |
| Aircraft carrier | 150 | 0 / 0 / 0 / 4 / 1 / 0 | 0 / 0 / 0 / 5 / 2 / 0 | Durable aircraft platform; relies on escorts for surface and submarine defence. |
| Cargo ship | 90 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Unarmed freight ship; escort it through hostile waters. |
| Oil tanker | 120 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Unarmed fuel transport; high capacity does not provide defensive firepower. |
| Supply truck | 18 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Army support, not a combat unit; must be protected. |
| Recovery vehicle | 34 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Army support, not a combat unit; must be protected. |
| Combat engineers | 32 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Army support, not a combat unit; must be protected. |
| Bridge layer | 36 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Army support, not a combat unit; must be protected. |
| Field medics | 16 | 0 / 0 / 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 / 0 / 0 | Army support, not a combat unit; must be protected. |

## Timings and prices applied after the owner’s follow-up

The old construction helper converted `hours: 2/3/4` into 15/20/30 **minutes**, capping explicit minutes
at 30. That mapping is removed. Active buildings now take 2–6 hours for level I before local modifiers,
and each later level requires 1.5× the previous level’s work. Costs now rise at every level: 1 / 1.5 / 2 /
2.5 / 3 times the base price. Previously level II incorrectly cost the same as level I.

| Item | Previous level-I base time at 1× | New level-I base time at 1× |
|---|---:|---:|
| Barracks | 30 min | 2 h |
| Road infrastructure / recruitment | 15 min | 2 h |
| Factory | 15 min | 4 h |
| Airbase / tank plant | 20 min | 4 h |
| Naval base | 30 min | 6 h |
| Missile factory | 15 min | 6 h |
| Main battle tank production | 1.5 h | 6 h |
| Recon drone production | 2 h 40 min | 3 h |
| Corvette / carrier production | Both 2 h 40 min | 8 h / 24 h |

Production work rises 25% of the level-I work per model level (1 / 1.25 / 1.5 / 1.75 / 2), purchase costs
rise 20% (1 / 1.2 / 1.4 / 1.6 / 1.8), and daily upkeep rises 10% (1 / 1.1 / 1.2 / 1.3 / 1.4).
All resource bills round up to whole units. A production building adds its existing 25% speed per level
above I. Morale, sabotage, infrastructure and existing doctrine modifiers apply through the same backend
used by the city menus and gold quotes. Province construction now uses that same calculation; it previously
omitted doctrine and economic-research bonuses.

Research’s neutral base hours are **2 / 4 / 8 / 12 / 18** for levels I–V (previously 1 / 2 / 4 / 6 / 8).
Multiply by the role’s complexity factor below, then divide by the doctrine research rate. Refinements use
2 / 3 / 5 / 8 hours for I–IV and the same complexity and doctrine. Europe now takes **exactly 15% less time**
(`base × 0.85`, rate `1 / 0.85`); the previous rate of 1.15 meant only 13.04% less time. This is Warfront’s
European rule, not a claim that the Call of War Allies doctrine has the same percentage. Russia retains its
0.9 research rate. Research costs are 0.4 / 0.65 / 0.95 / 1.3 / 1.7 of the level-I unit bill, after the
existing doctrine purchase modifier. Refinements cost 0.2 / 0.3 / 0.4 / 0.5 of that level-I bill.
Modernization charges 50% of the **target level’s** production bill and base time; the UI and backend agree,
and the confirmation checks the selected country’s funds rather than always checking Russia.

Examples at full morale with a level-I production building and no infrastructure: European motorized-infantry
research takes 1 h 16 min 30 s at 1×, 19 min 7.5 s at 4×, or 7 min 39 s at 10×. European light-tank production
takes 4 h 26 min 40 s / 1 h 6 min 40 s / 26 min 40 s. An otherwise neutral 10-hour job takes 10 h / 2.5 h / 1 h.
The clock, HUD speed cycle, More menu and save validator support 1×, 2×, 4× and 10×. Costs, HP and damage do
not change when switching speed. Gold speed-up prices remain based on game hours of unfinished work, so
changing speed cannot discount the same job’s gold price.

### Resource budgets and prices

Forty-seven role price profiles replace copied costs: e.g. recon drones and strategic launchers no longer
both cost 4,800 base funds, and corvettes and carriers no longer have the same bill. Base unit funds now range
from 900 (loitering munition) to 16,800 (carrier), with different manpower/material/electronics/fuel/food mixes.
Russian and Chinese units retain their 10% purchase discount, American units their 20% premium, and European
drones their 15% discount. These apply once while loading the catalogue. The role profile survives catalogue
regeneration; no new country-bonus system was added.

The six-resource starting stock is unchanged. Both countries can fund a recruitment centre, barracks, tank
plant, infantry/light-tank research, eight infantry and two light tanks without new income. The test checks
all six resources, not just funds. At 100% morale and industry level 0, the seven cities produce 68,040 funds
per day before army upkeep and province funds; 5,184 materials/day in either country, 1,728/3,456 electronics
(Russia/Ukraine), 4,536/1,512 fuel, and 2,160/4,320 food. One recruitment centre produces 4,320 manpower/day
before doctrine (3,888 for Europe). Without recruitment centres, manpower income is zero; starting manpower
allows them to be built first. No income or starting-army rule was changed by this pass.

For the current base’s 22 infantry / 4 light tanks / 4 short AA / 1 light-attack aircraft per side, the new
level-I daily maintenance is 3,870 funds, 246 manpower, 492 food and 260 fuel. Food/fuel income remains
positive for both countries. These are opening-budget checks, not proof that an arbitrarily large fleet or
army is sustainable. The pending starting-force PR has a different roster and must be playtested after merge.

World equipment minimums now value the same six-resource, level-adjusted purchase bill used by production;
they no longer add a separate 12%-per-level premium. Static and live floors use one price book. Real net
trade demand, decay, escrow, safe delivery and the seller’s ability to ask more are retained. Commodity
floors remain food 1, materials 2, electronics 5 and fuel 2 funds per unit; the supply exchange keeps its
positive buy/sell spread. Worn-equipment price floors keep their existing full-model policy.
Strategic warheads were reviewed and retained: chemical 60,000 funds plus resources / 12 h, nuclear 250,000
plus resources / 48 h, with day-12/day-25 gates. Annexation prices are retained. The owner's later gold/menu
follow-up supersedes this pass's original premium-price decision: see [gold and menu review](GOLD_AND_MENUS_REVIEW.md)
for higher resource/time/hack prices, missing-resource purchases and the proposed CA$10 / 10,000 gold basis.
Live payment checkout remains unconnected.

Paid production fixes its model, work and paid bill when it starts; research cannot retroactively give a
finished order a free higher model. Unpaid orders buy the latest researched model when they start. New paid
jobs save their actual resource bill. Old paid building/research/production orders keep accumulated work and
use their original bill for refunds, avoiding refunds at newly increased prices. Increasing work requirements
can lower an old job’s percentage complete; work is never reset. Client and authoritative server must update
together, and older clients should not load saves with a new paid-bill/locked-model order.

All 470 family/level bills and 1×/4×/10× times are in [unit-economy.csv](qa/unit-balance-2026-10-15/unit-economy.csv).
All 53 active building/level bills and times are in [building-economy.csv](qa/unit-balance-2026-10-15/building-economy.csv).
Unit CSV production times assume a level-I factory, full morale and no infrastructure; role base times are
also included. Freight rows are capacity research, not buildable combat units, and have zero unit upkeep.

### Neutral level-I economy profiles

Prices below precede doctrine. Resource order is **funds / manpower / food / materials / fuel / electronics**.
Daily upkeep order is **funds / manpower / food / fuel**. These are original game values, not real procurement
prices or a transcription of either competitor’s price list.

| Role | Production h | Research complexity | Six-resource purchase bill | Daily upkeep |
|---|---:|---:|---|---|
| Motorized infantry | 2 | 0.75 | 1200 / 600 / 300 / 240 / 60 / 60 | 100 / 10 / 20 / 4 |
| Airborne infantry | 3 | 1 | 1800 / 650 / 340 / 300 / 120 / 150 | 140 / 11 / 22 / 6 |
| Special forces | 4 | 1.25 | 2400 / 500 / 300 / 360 / 120 / 300 | 180 / 9 / 18 / 6 |
| Naval infantry | 3 | 1 | 2000 / 700 / 360 / 420 / 150 / 180 | 160 / 12 / 24 / 8 |
| Snipers | 3 | 1 | 1500 / 350 / 220 / 180 / 60 / 240 | 120 / 6 / 12 / 3 |
| Main battle tank | 6 | 1.25 | 3600 / 180 / 180 / 1200 / 480 / 480 | 280 / 3 / 6 / 32 |
| Next-generation tank | 8 | 1.5 | 5400 / 180 / 200 / 1560 / 600 / 960 | 380 / 3 / 6 / 40 |
| Light tank | 4 | 1 | 2400 / 150 / 150 / 780 / 300 / 300 | 190 / 3 / 6 / 20 |
| Armoured personnel carrier | 3 | 0.85 | 1800 / 240 / 200 / 600 / 240 / 180 | 140 / 4 / 8 / 16 |
| Infantry fighting vehicle | 4 | 1 | 2400 / 240 / 220 / 780 / 300 / 360 | 180 / 4 / 8 / 20 |
| Airborne fighting vehicle | 4.5 | 1.1 | 2700 / 220 / 200 / 720 / 300 / 480 | 190 / 4 / 8 / 20 |
| Self-propelled artillery | 5 | 1.1 | 3000 / 240 / 200 / 960 / 360 / 480 | 240 / 4 / 8 / 24 |
| Rocket artillery | 6 | 1.25 | 3800 / 240 / 220 / 1080 / 420 / 780 | 300 / 4 / 8 / 28 |
| Light mortar | 2 | 0.75 | 1100 / 360 / 220 / 240 / 40 / 60 | 90 / 6 / 12 / 2 |
| Heavy mortar | 2.5 | 0.85 | 1600 / 400 / 240 / 420 / 60 / 120 | 120 / 7 / 14 / 4 |
| Towed artillery | 3 | 0.9 | 2100 / 420 / 260 / 600 / 100 / 180 | 150 / 7 / 14 / 6 |
| Short-range air defence | 4 | 1 | 2400 / 180 / 160 / 720 / 240 / 660 | 180 / 3 / 6 / 16 |
| Long-range air defence | 6 | 1.4 | 4200 / 180 / 180 / 1080 / 300 / 1500 | 300 / 3 / 6 / 20 |
| Tactical ballistic missile | 8 | 1.5 | 4800 / 200 / 180 / 1200 / 600 / 1200 | 320 / 3 / 6 / 32 |
| Missile silo | 12 | 1.75 | 6600 / 300 / 240 / 2400 / 480 / 1560 | 400 / 5 / 10 / 24 |
| Coastal anti-ship missile | 6 | 1.25 | 3600 / 200 / 180 / 960 / 360 / 960 | 260 / 3 / 6 / 24 |
| Strategic missile launcher | 18 | 2 | 10800 / 300 / 240 / 2400 / 1800 / 2400 | 600 / 5 / 10 / 60 |
| Air superiority fighter | 8 | 1.4 | 4200 / 120 / 140 / 960 / 720 / 1080 | 300 / 2 / 4 / 48 |
| Strike fighter | 9 | 1.5 | 4800 / 120 / 140 / 1080 / 840 / 1200 | 340 / 2 / 4 / 56 |
| Interceptor | 8 | 1.4 | 4500 / 120 / 140 / 1020 / 840 / 1140 | 320 / 2 / 4 / 56 |
| Strategic bomber | 12 | 1.75 | 7200 / 180 / 180 / 1560 / 1440 / 1560 | 500 / 3 / 6 / 96 |
| Attack helicopter | 6 | 1.2 | 3300 / 180 / 180 / 720 / 480 / 780 | 250 / 3 / 6 / 32 |
| Transport helicopter | 5 | 1 | 2400 / 180 / 180 / 600 / 360 / 420 | 180 / 3 / 6 / 24 |
| Light attack aircraft | 5 | 1.05 | 2700 / 120 / 140 / 660 / 420 / 540 | 190 / 2 / 4 / 28 |
| Reconnaissance drone | 3 | 0.85 | 1500 / 60 / 60 / 240 / 120 / 540 | 90 / 1 / 2 / 8 |
| Strike drone | 5 | 1.1 | 2600 / 60 / 80 / 420 / 180 / 840 | 150 / 1 / 2 / 12 |
| Loitering munition | 2 | 0.8 | 900 / 40 / 40 / 180 / 60 / 300 | 50 / 1 / 1 / 4 |
| One-way attack drone | 2.5 | 0.9 | 1200 / 40 / 40 / 240 / 120 / 360 | 60 / 1 / 1 / 6 |
| Transport aircraft | 7 | 1.15 | 3600 / 180 / 180 / 1080 / 720 / 600 | 260 / 3 / 6 / 48 |
| Airborne early warning | 10 | 1.6 | 6000 / 180 / 180 / 1200 / 840 / 1800 | 400 / 3 / 6 / 56 |
| Frigate | 12 | 1.4 | 6600 / 360 / 300 / 2400 / 900 / 1500 | 440 / 6 / 12 / 60 |
| Destroyer | 16 | 1.6 | 9600 / 480 / 380 / 3600 / 1320 / 2100 | 620 / 8 / 16 / 88 |
| Corvette | 8 | 1.1 | 4200 / 240 / 220 / 1440 / 600 / 840 | 280 / 4 / 8 / 40 |
| Submarine | 16 | 1.6 | 8400 / 240 / 240 / 3000 / 1080 / 1800 | 520 / 4 / 8 / 72 |
| Aircraft carrier | 24 | 1.9 | 16800 / 800 / 600 / 6000 / 1800 / 3000 | 1000 / 14 / 28 / 120 |
| Cargo ship | 8 | 1.1 | 3600 / 0 / 0 / 1440 / 480 / 240 | 0 / 0 / 0 / 0 |
| Oil tanker | 10 | 1.2 | 4200 / 0 / 0 / 1680 / 600 / 300 | 0 / 0 / 0 / 0 |
| Supply truck | 2.5 | 0.8 | 1200 / 180 / 160 / 480 / 240 / 120 | 90 / 3 / 6 / 16 |
| Recovery vehicle | 4 | 1 | 2100 / 180 / 180 / 780 / 300 / 240 | 150 / 3 / 6 / 20 |
| Combat engineers | 3 | 0.9 | 1800 / 360 / 240 / 600 / 180 / 240 | 140 / 6 / 12 / 12 |
| Bridge layer | 4 | 1 | 2400 / 180 / 180 / 1080 / 360 / 180 | 170 / 3 / 6 / 24 |
| Field medics | 2.5 | 0.85 | 1500 / 300 / 240 / 300 / 120 / 300 | 120 / 5 / 10 / 8 |

## UI and integration

`UnitDetailPanel` is the shared native Godot card. The photo fills its width with aspect preserved; the photo
in Army Details fills the header too. Research thumbnails, city/army `open_unit` links, and the selected
research picture open the same card. Five level buttons allow inspection; locked/enemy cards remain viewable
and cannot start unauthorized research. The card has actual HP, all six attack/defence rows, independent
terrain attack/defence/speed columns, doctrine strengths/weaknesses, range, production and upkeep bills,
research costs/countdowns and a working research button.
The action remains on screen while details scroll. Photos are existing unit artwork, not generated mockups.

All changes are on `chatgpt/unit-photos-hp-20261015`, based on Claude `98d83cf42d457c8751c801cdea9439172732e936`.
No changes to `main.gd`, `unit_system.gd`, `city_system.gd`, `strategic_map.gd`, `web_extras.gd`,
`tools/split_web_pack.py`, signing keys, export presets, website or live services.

The new JSON matches the existing `data/*.json` export include filter. Integrate client and authoritative
server from the same commit: an old server must not calculate old percentage damage for a new-UI client.
Keep Claude's later work and merge/review this branch; do not replace his branch with this checkout.

## Validation and release limits

See [QA results](qa/unit-balance-2026-10-15/RESULTS.md). New roster/combat and native-card tests have zero
failures. This establishes arithmetic, mechanics and layout consistency, not overall long-match PvP balance.
Several broad legacy suites still fail or abort identically on the untouched base because private model
files are not in this checkout or fixtures assume old game rules. No claim that the full regression suite
or Android/network playtest has passed. Claude must run the asset-complete project and playtest equal-budget
combined-arms armies before release. No new APK, server deployment or live web update was produced here.

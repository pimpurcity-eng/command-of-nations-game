# Call of War: design reference for Command of Nations

Studied 2026-10-08 from the official Call of War wiki (https://wiki.callofwar.com) and its
in-game screenshots. The aim is to match Call of War's gameplay loop and interface closely
first, then improve on it.

**Rule for copying:** we copy *mechanics, layout and feel*. We do **not** copy Bytro's art,
icons, unit images, text or the "Call of War" name. Those are copyrighted or trademarked.
All visuals must be our own assets (our T-90, Su-57, etc.). Game rules and UI patterns are
fine to reproduce.

Screenshots referenced below (open them on the wiki):
- Mobile main screen: https://wiki.callofwar.com/wiki/MAIN_INTERFACE
- Army bar: https://wiki.callofwar.com/wiki/ARMY_CONTROLS
- Province bar and urban/rural map: https://wiki.callofwar.com/wiki/PROVINCES
- Terrain and unit details: https://wiki.callofwar.com/wiki/TERRAIN
- Research tree: https://wiki.callofwar.com/wiki/RESEARCH

---

## 1. Core loop

1. Tap an army, press **Move**, tap a destination. The army walks there in real time (minutes
   to hours), following a visible path.
2. An army that reaches the **center point** of an enemy province captures it immediately,
   unless defenders are standing on that point. If they are, combat starts and the province
   is captured only when the defenders are destroyed.
3. Provinces produce resources. Resources pay for buildings, research and units.
4. Urban provinces (cities) hold **Victory Points**. The first player or coalition to pass the
   VP threshold wins at the next day change.
5. The game runs in real time. One "game day" is a real day at 1× speed. Day change
   recalculates morale, VP and so on.

## 2. Map

### Look (from screenshots)
- **Parchment-style relief map.** Land is a beige or sand paper texture with hand-drawn
  relief: small pine trees for forest, soft shaded bumps for hills, sharp shaded peaks for
  mountains, dune ripples for desert-like plains, and a dense block-pattern of tiny buildings
  for cities.
- **Sea** is deep blue with a lighter, glowing coastal edge.
- **Own territory** is bright and clear. **Foreign territory** is shown in muted grey-brown.
  Country borders are thick dark lines; province borders are thin dark lines.
- Each province has a small **grey dot at its center**, joined to neighbouring centers by
  faint thin lines (the road network units move along).
- **City labels** are white uppercase letter-spaced text on a semi-transparent dark plate.
  Under the label there is a small plate showing the resource icon(s) and a star with the VP
  number (e.g. ★10).
- **Capitals** show a large country flag to the left of the city name.
- **Core vs non-core:** conquered (non-core) provinces get **diagonal stripes** over their
  texture.
- **Resource icons** sit on resource-producing provinces. Urban provinces show a double icon.
- **Uprising risk** is shown by a column of smoke and glowing red stripes.
- **Selected province:** highlighted outline, with a ring of circular action buttons around
  it (Construction, Production, Morale boost, Rally, Espionage, Close).

### Terrain
Call of War has 5 terrain types. Terrain changes both speed and combat strength.

| Terrain | Movement | Who fights better |
|---|---|---|
| Plains | Motorized and tanks fast | Tanks/motorized (e.g. heavy tank +50%) |
| Forest & Hills (one type in CoW) | Motorized and tanks slow | Ordnance, ambush units (militia, AT, artillery) |
| Mountains | Everything slow | Infantry (+25%), commandos, ordnance |
| Urban | Normal | Infantry (+50%), counter units |
| Sea | Ships only | Land units turn into weak transport ships |

Example from the unit details panel:
- **Heavy Tank Lvl1:** speed 43 on plains, 26 in hills/forest, 17 in mountains, 34 in urban,
  44 at sea as a transport.
- **Infantry Lvl1:** speed 32 on plains, hills and urban, 16 in mountains, 40 at sea.

**Our improvement:** 7 terrain types (urban, forest, hills, mountains, plains, desert,
water). This splits CoW's combined Forest & Hills into two and adds Desert.

## 3. Provinces

- **Urban** provinces are the few big cities. They are the only places with production
  buildings, they produce large amounts of resources, money and manpower, and they hold VP.
- **Rural** provinces surround the cities. They have support buildings only, some produce one
  resource, and all produce money and manpower.
- **Core** provinces are your original territory. They produce at 100% efficiency and give
  the **Home Defence bonus**: +15% damage and −15% damage taken.
- **Non-core** provinces are conquered territory. They produce at **25%** efficiency, have no
  home bonus, and are striped on the map.
- **Capital:** losing it costs all your provinces −20% morale, and the conqueror takes 50% of
  your money. Capturing one gives +10% morale to all the conqueror's provinces. A Capitol
  building can be built elsewhere to move the capital.

### Morale (0–100%)
- Morale scales resource output, money, manpower, production speed and construction speed.
  Construction is slower when morale is under 80%.
- Target morale = 102 − negative influences + positive influences. At each day change,
  morale moves 15% of the way toward the target.
- Negative influences: distance to the capital, neighbouring provinces under 80% morale,
  enemy neighbours, total empire size, enemy armies present, resource shortages.
- A captured province is set to **25%** morale. Below 30% it has a chance of an **uprising**
  at day change: about 14% with no garrison at 25% morale, and 0% with a garrison strength of
  10 or more.

## 4. Resources

| Resource | Main use |
|---|---|
| Food | Infantry, unarmored units, ships |
| Goods | Ordnance, light vehicles, aircraft |
| Metal | Tanks, vehicles, ships |
| Oil | Heavy armor, motorized units, aircraft, ships |
| Rare materials | Aircraft, secret weapons, heavy armor |
| Manpower | Every unit |
| Money | Everything, plus market trading |
| Gold (premium) | Speed-ups, healing, morale boosts |

- Every unit and building costs about 3 resources plus money (and manpower for units).
- Units cost **daily upkeep**.
- There is a **stock market** with player buy and sell offers.
- Top bar: each stock amount with a +rate/hour figure beneath it.

## 5. Buildings

- **Urban only:**
  - Barracks (infantry)
  - Ordnance Foundry (artillery, AT, AA)
  - Tank Plant
  - Aircraft Factory
  - Naval Base (on a coast)
  - Secret Lab
  - Industry (resource output)
  - Bunkers (damage reduction)
  - Capitol
- **Rural only:**
  - Local Industry
  - Airstrip
  - Fortifications
  - Local Port
- **Anywhere:**
  - Infrastructure (movement speed)
  - Propaganda Office (morale)
  - Recruiting Station (manpower)
- Each level of a production building **halves** production time, down to the unit's minimum.
- Bunkers and Fortifications at level 3 or higher hide the composition of the army inside.

## 6. Units

Each unit has an **armor class**:
- Unarmored
- Light armor
- Heavy armor
- Aircraft
- Ship
- Submarine
- Buildings (as a target only)

Every unit has a separate **attack value and defence value against each class**, plus HP,
speed per terrain, view range and (for some) attack range.

Example values:
- **Heavy Tank Lvl1:** 72 HP. Attack 5.0 vs unarmored, 9.0 vs light armor, 8.4 vs heavy
  armor, 3.6 vs buildings, 2.3 vs ships.
- **Infantry Lvl1:** 15 HP. Urban +50%, Mountains +25%.

The CoW (WW2) unit roster, mapped to our modern Russia–Ukraine setting:

| CoW category (building) | CoW units | Our modern equivalents |
|---|---|---|
| Infantry (Barracks) | Militia, Infantry, Motorized Inf, Mechanized Inf, Commandos, Paratroopers | Territorial defence, Motor rifles, Truck-mounted inf, BMP/BTR mech inf, Spetsnaz/SOF, VDV/Air assault |
| Ordnance (Foundry) | Anti-Tank, Artillery, SP Artillery, Anti-Air, SP Anti-Air | ATGM team, Towed artillery (D-30/M777), SP artillery (2S19 Msta), MANPADS/towed AA, Pantsir/Tor/Buk (SAM) |
| Tanks (Tank Plant) | Armored Car, Light Tank, Medium Tank, Heavy Tank, Tank Destroyer | Recon vehicle (BRDM/Tigr), Light tank/IFV, **T-72/T-80**, **T-90M**, ATGM carrier (Khrizantema) |
| Aircraft (Aircraft Factory) | Interceptor, Tactical Bomber, Attack Bomber, Strategic Bomber, Naval Bomber | Fighter (**Su-57**, Su-35), Strike aircraft (Su-34), Attack (Su-25), Attack helicopter (Ka-52/Mi-28), Strategic bomber (Tu-22M/Tu-95), Drones |
| Naval (Naval Base) | Destroyer, Submarine, Cruiser, Battleship, Carrier, Transport | Corvette, Submarine (Kilo), Frigate, Cruiser (Slava), Landing ship |
| Secret (Secret Lab) | Rocket artillery, SP rocket art., Railroad gun, Flying bomb, Rocket, Rocket fighter, Nuclear | MLRS (BM-21, TOS-1), HIMARS-type MLRS, Long-range artillery, Loitering munitions/Shahed-type, Ballistic missile (Iskander), Cruise missile; nuclear left out or optional |

**Counter triangle** (keep this exactly):
- Infantry is strong in cities.
- AT and artillery beat heavy armor.
- Tanks beat light armor and infantry on plains.
- AA beats aircraft.
- Aircraft beat ground units that have no AA.
- Artillery fires from range without taking return fire.
- Light/fast units are good at grabbing empty land.

### Unit levels and upgrades
- Each unit has about 4 levels plus an **Elite** level. Elite needs collected blueprints.
- New units spawn at your highest researched level.
- Existing units can be **upgraded** on the map for 50% of the production cost and 50% of the
  production time. While upgrading they cannot move and can only defend.

## 7. Research

- **2 research slots** run at the same time.
- Tabs per category (Infantry, Ordnance, Tanks, Air, Naval, Secret) match the build menu.
- The tree is a **grid**: columns are unit types and rows are **game days**. A line for "today"
  moves down the grid as the game progresses, and research below it is locked until that day.
- Node states:
  - available (white ring)
  - researching (blue ring filling up)
  - done (solid blue)
  - locked (grey)
  - elite (star badge, gold)
- Research costs resources and time. The first level unlocks production; higher levels make
  the unit stronger.

## 8. Doctrines (faction modifiers)

| Doctrine | Bonuses | Penalties |
|---|---|---|
| Axis "Power" | +15% HP, +15% damage | +10% production cost |
| Allies "Optimization" | −30% production time, −25% research cost/time, −20% upgrade cost/time | −10% move speed |
| Comintern "Quantity" | −15% production cost, −30% upkeep | −10% damage |
| Pan-Asian "Surprise" | +20% speed, +30% view range, +20% terrain bonus | −10% HP |

**For us:** a Russia doctrine (mass and firepower) vs a Ukraine/NATO-supplied doctrine
(precision, drones, efficiency). Use our own names and numbers.

## 9. Combat rules (exact)

- **Melee** starts when hostile armies come within **5 distance units** of each other, or
  when an army walks into a defended province center. Both sides are locked in combat until
  one is destroyed.
- **Ranged** units (artillery, ships, MLRS) attack anything inside their range circle. They
  are not locked in and can walk away. Fire-control modes:
  - Aggressive
  - Offensive
  - Fire at Will (default)
  - Return Fire
  - Hold Fire
- **Air**: aircraft fly to the target, strike once, fly home to refuel, then repeat. **Patrol**
  mode does 50% damage every 15 minutes to everything in a radius. If the home airbase is
  lost, the plane diverts to another base or crash-lands and loses 25% HP.
- **Ticks:** damage is exchanged every **30 minutes** (game time). If the target dies in one
  hit, the attacker can strike another target 1 minute later.
- **Attacking vs defending:** attack values are used by the moving or attacking army, defence
  values by the idle army. An army attacks only one target but defends against any number.
  Attack damage splashes onto every enemy army within radius 5 of the target.

### Damage per tick
1. Damage potential = sum over units of (base damage vs each armor class × count × terrain
   bonus × home-defence 1.15).
2. Multiply by a **random factor of 0.8–1.2**.
3. Multiply by **efficiency**, which comes from two things:
   - HP: 100% at full HP, falling linearly to 20% at 0 HP.
   - Stack size: only the **10 strongest** units per armor class count, so a stack over 10
     units loses efficiency.
4. Reduce by the target's **protection** (fortification/bunker level, plus 15% home defence).
5. **Distribute** damage by the target's composition. Example: an army of 40% heavy armor and
   60% unarmored receives 40% of the incoming anti-heavy damage and 60% of the anti-unarmored
   damage. Within each class, damage is split by unit-type share.
6. HP is spread evenly across units of a type. Units **only die once their type is below 50%
   total HP**, and then whenever a hit exceeds one unit's remaining HP.

Other combat effects:
- Melee damage is applied to both sides at the same time. For air vs ground, the ground
  defender's damage lands first.
- Capturing a province damages its buildings and sets its morale to 25%.

## 10. Army commands (mobile army bar)

- Move
- Attack
- Patrol (air)
- Add Army (multi-select)
- Delay (synchronise arrivals)
- Add Target (waypoints)
- **Forced March** (+50% speed, −5% HP per hour)
- Stop
- **Split**
- Upgrade
- Convert (paratroopers)
- Fire Control

Army speed = the speed of its slowest unit. Units below 50% HP move slower.

## 11. Mobile interface layout (portrait). Match this first.

```
┌───────────────────────────────────────────┐
│ 🌾57k 📦81k ⛑30k ⛓81k 🛢47k 💎27k 💵601k [Gold+] │  ← thin resource bar, numbers only
├───────────────────────────────────────────┤
│[offer]                         (🌍)        │  ← round icon buttons at the side
│                                (🔔)        │
│                                           │
│            FULL-SCREEN MAP                │  ← pinch zoom, drag pan
│      units = small 3D model + count       │
│      city = label plate + ★VP             │
│                                           │
│[last army]                                │
│                   "Next day starts in 4h" │  ← day-change timer, small, bottom-right
├───────────────────────────────────────────┤
│ Diplomacy  Provinces  Market  Research  More │  ← bottom tab bar, icons + small labels
└───────────────────────────────────────────┘
```

### Army selected
- The map shows the unit model with a small count badge, flag and armor-class icons.
- The path is a **red/white dashed line moving toward the destination**, with an order icon at
  the end (move, attack or patrol).
- A **bottom sheet** slides up:
  - a row of 5 big square command buttons (More, Move, Attack, Stop, Split)
  - a header with army name, flag and info button
  - the current activity with a timer ("Relocating to: Smolensk — 47min 42s")
  - unit cards, each with portrait, count and HP bar
  - a status line with best damage vs class, protection %, units /10 and speed
  - a heal button

### Province selected
- A **top sheet** shows:
  - name, flag, core/non-core status
  - terrain icon and ★VP
  - building icons with their levels
  - resource, money and manpower rates, plus a morale bar
- **Radial buttons** around the province center: Construction, Production, Morale, Rally,
  Espionage, Close.

### Build menu
- Full-screen list.
- Category tabs: buildings, infantry, ordnance, tanks, air, naval, secret.
- Each row has a unit portrait, name, level, cost icons with amounts, build time, and a
  Produce/Queue button.

### Visual style
- **Muted military parchment**: dark olive/charcoal panels with a subtle texture, cream text.
- **Small, clean icon buttons**: round or slightly rounded square, never oversized.

## 11b. Current mobile interface (2025 app). **This is the target.**

Notes from the owner's own gameplay screenshots of the current Android app. These are newer
than the wiki images above; where the two differ, follow this section. The screenshots are
not stored in this repo because it is public and they show Bytro's art.

### Top bar (fixed)
- **Commander portrait**: an illustrated officer in a shield-shaped frame, top-left, slightly
  overlapping the map.
- **Resource row**: a large illustrated icon with a short number under it
  (`59k`, `9.6k`, `2.2m`). In order:
  - money (banknotes)
  - manpower (helmet)
  - food (wheat)
  - metal (steel bar)
  - oil (red jerry can)
  - a capped resource shown as `current/max` (`677/36k`)
- **Second row**:
  - small country flag
  - `9,011 Gold` with a yellow **+** button
  - calendar icon with **game day** (`1`, `22`)
  - `» 4` (**game speed 4×**)
- **Rank tab** hanging under the bar: `★ 1st` / `★ 2nd`.
- Style: dark charcoal panels, white bold numbers, gold accents. Compact; it takes about the
  top 13% of the screen.

### Right edge
A vertical column of dark square buttons with gold line icons:
- globe (zoom to world view)
- tasks clipboard (with red number badge)
- map filters
- FREE video (rewarded ad)
- inventory backpack
- reward chest
- profile/advisor

### Left edge
- Floating diamond offer badge (gold bars with a % tag and a gift icon).

### Bottom bar
- 6 tabs: **Diplomacy · Produce · Provinces · Market · Research · More**.
- Gold icons above white labels, on a dark bar. Red square number badges, e.g. Research `2`
  and Diplomacy `18`.

### Map: two zoom levels (LOD)

**Strategic zoom (zoomed out)**
- Political colours:
  - own nation: pale sand/khaki
  - neutral nations: muted sage green
  - enemy at war: salmon/brick red
- Big **curved serif country names** follow the shape of the country (KOREA, JAPAN, SIBERIA,
  KAMCHATKA).
- Thin dark province borders, thicker country borders.
- Sea: deep teal-blue with a painted texture and a light glow along coasts.
- **Concentric pale-cyan rings** around own territory and units show **view/radar range**
  (the fog-of-war edge).
- **Units become diamond tokens**: a rotated square with a black silhouette of the unit type
  (soldier, tank, plane, anchor) and the unit count under it.
  - **white/grey** = own
  - **yellow** = selected
  - **red** = enemy
  - **dark grey with "?"** = enemy army whose composition is unknown (fog)
- At full world zoom, grey soldier-bust markers sit on nations; probably a player or AI marker.

**Tactical zoom (zoomed in)**
- Terrain becomes **realistic shaded relief** (hills and mountains in sand/olive, desert dunes
  in pink-sand).
- Province **center dots** (small grey ovals) are joined by **thin dashed brown road lines**
  to neighbouring centers. This is the movement graph.
- **Units are small 3D-rendered figures** (soldier group, AA gun, armored car) standing on the
  map. Next to each is a **pennant tag** containing:
  - unit-type icon
  - count
  - **segmented green HP bar** (vertical bars)
  The tag is yellow when selected, white for own units, and stacks one row per unit type for
  mixed armies.
- **Cities** are a dense 3D-looking block of buildings drawn into the terrain. When the city
  has buildings, you also see an airstrip runway with a windsock and factory smokestacks.
- **City label**:
  - flag + **letter-spaced serif capitals** on a translucent dark plate (`T O K Y O`)
  - under it, small dark boxes for the resource icon and `★10` VP
- **Rural resource provinces**: a dark rounded-square icon (wheat, steel, oil can) placed on
  the province.
- **Non-core (conquered) land**: wide diagonal light stripes.
- **Front line / fortified border**: **anti-tank hedgehogs** drawn along the border line.
- **Range circles**: a large translucent circle around ranged, AA or radar units.

### Orders on the map
- **Move path**: dashed line in **yellow and dark-brown alternating dashes**, ending in a
  **yellow chevron arrowhead** at the destination. Long sea routes use the same style.
- **Attack path**: short **red curved arc** from army to target.
- **Selected army**: blue-violet circle around it.
- **Enemy weapon range**: translucent red/orange disc, visible when an enemy army has ranged
  units.

### Army panel (army selected)
- **Command row** across the screen above the panel:
  - **Stop** (grey square)
  - **Split** (branch arrows)
  - **Attack** (large **red** button, lightning bolt)
  - **Move** (large **green** button, curved arrow)
  - **Add army** (yellow-outlined +)
  - **More** (≡)
- **Header**:
  - big flag tile
  - `7TH INFANTRY REGIMENT (FR 7)`
  - nation name
  - square **i** (info) and **X** (close) buttons
- **Stats row**:
  - units `20/10` (red when over the 10-unit limit)
  - strength `53.8` (fist icon)
  - speed `36` (»)
  - protection `0%` (shield)
  - status `Idle` (map-pin icon)
- **Unit cards**: illustrated portrait, **level chevron badge** at the top-right, segmented
  green HP bar, armor-class icon and count.
- **Right block**: `294 / 294` HP with a medkit icon and segmented bar, plus a large green
  **HEAL ARMY** button (disabled grey-green at full HP).
- **Multi-select mode**:
  - top banner `7 units selected`
  - panel line `Tap To Select Armies`
  - big red **CANCEL** and green **ACCEPT** buttons

### What to copy and what to drop
- **Copy:**
  - the layout
  - the two-level zoom (tokens far out, 3D figures close in)
  - the pennant HP tags
  - the colour language (sand own / green neutral / red enemy, yellow selection)
  - the dashed yellow path with chevron
  - the red attack arc and Attack/Move button colours
  - the stats row and HEAL ARMY
- **Drop or tone down:** ad clutter (FREE video, offer diamond, chest) and the oversized
  commander portrait. Our version keeps the map cleaner.
- **Our own art:** a modern Russian/Ukrainian commander portrait, a T-90M figure in blue
  camouflage instead of WW2 armour, and modern icons.

## 12. What "a lot better" can mean (after we match it)

1. **Real 3D map** instead of painted parchment: actual terrain relief, 3D cities, and our own
   3D unit models (T-90M with Su-57-style blue camo) sitting on the map. CoW uses small 2D
   sprites.
2. **7 terrain types** instead of 5, with distinct textures and real bonuses.
3. **Modern warfare layer:** drones/loitering munitions, layered air defence (SHORAD vs
   long-range SAM), electronic warfare and recon.
4. **Cleaner mobile UI:** CoW's mobile UI is cramped and uses heavy textured buttons. Keep the
   same layout but make it crisper.
5. **Clearer combat feedback:** show the expected battle outcome before attacking. CoW hides
   this behind an info popup.
6. **Faster onboarding:** a guided first day. CoW's early game is confusing.

## 13. Build order for Command of Nations (matching CoW first)

1. **Map:**
   - provinces with center points and a road graph
   - terrain per province
   - urban vs rural provinces
   - city labels with VP
   - own vs foreign shading
   - pinch zoom and drag in portrait
2. **Armies:**
   - tap to select
   - bottom-sheet army bar
   - Move with an animated dashed path
   - real-time travel along the road graph at terrain-dependent speed
3. **Province capture:** walking into an undefended center flips ownership; morale goes to 25%.
4. **Combat:** a 30-minute tick using the formula in section 9 (armor classes, terrain bonus,
   home defence, HP-based efficiency, 50% death rule).
5. **Economy:** 5 resources plus money and manpower, a top resource bar with rates, day
   change, upkeep.
6. **Buildings and production:** urban production buildings, build menu with tabs and queue.
7. **Research:** a 2-slot, day-gated tree, unit levels, upgrading on the map.
8. Morale and uprisings, doctrines, AI opponents, victory points.
9. Later: diplomacy, market, espionage, coalitions, multiplayer server.

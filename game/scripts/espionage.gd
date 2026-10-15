class_name Espionage
extends RefCounted
## Espionage (owner request 2026-10-14, Call of War style). Spies are trained for money and sent
## to a city. After a short journey each spy works on one mission until it is recalled or caught:
##   intel     - shows every enemy army near the city
##   steal     - takes part of the enemy's stock of money and metal every day
##   sabotage  - halves building and production speed in the city
##   army      - wounds the enemy armies standing in the city
##   morale    - lowers the morale of the city's province
##   counter   - (in your own city) makes enemy spies there much more likely to be caught
## Owner 2026-10-14 ("usually it's day end", as in Call of War): spies do their work - and risk
## being caught - once, at the end of each game day. Intelligence and sabotage work all the time.
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND  # one real hour
const TRAVEL: = HOUR * 0.5  # half an hour to reach the city
const MAX_SPIES: = 6
const COST: = {"funds": 3000.0, "manpower": 100.0}
const CATCH_CHANCE: = 0.20       # per day end, per enemy spy
const COUNTER_FACTOR: = 2.5      # with a counter-spy in the city
const GARRISON_BONUS: = 0.10     # with an army in the city
const INTEL_RADIUS: = 6.0  # owner 2026-10-14: "can only see local armies" - the city and the land around it
const STEAL_SHARE: = 0.10        # of the target's money and metal, per day
const STEAL_CAP: = 15000.0       # per resource, per day
const SABOTAGE_FACTOR: = 0.5
const ARMY_DAMAGE: = 20.0        # health per day
const ARMY_FLOOR: = 25.0         # spies never finish an army off
const MORALE_LOSS: = 20.0        # per day
const MORALE_FLOOR: = 20.0
const MISSIONS: = {
	"intel": {"name": "Intelligence", "text": "See every enemy army near the city.", "icon": "research", "enemy": true},
	"steal": {"name": "Steal resources", "text": "At the end of each day, takes 10% of the enemy's money and metal.", "icon": "market", "enemy": true},
	"sabotage": {"name": "Sabotage", "text": "Building and production in the city run at half speed.", "icon": "hammer", "enemy": true},
	"army": {"name": "Attack the army", "text": "At the end of each day, enemy armies in the city lose health.", "icon": "attack", "enemy": true},
	"morale": {"name": "Lower morale", "text": "At the end of each day, the province's morale drops.", "icon": "provinces", "enemy": true},
	"counter": {"name": "Counter-spy", "text": "Guard one of your cities: enemy spies there are caught far more often.", "icon": "stop", "enemy": false},
}

## Hackers (owner 2026-10-14): paid with gold, they work at once or for a few hours. Owner: "never
## the whole map, maybe a small area, but prices must be way higher".
const HACKS: = {
	"blackout": {"name": "Power blackout", "text": "Cuts the power in an enemy city: building and production almost stop for 3 hours.", "gold": GoldWallet.HACK_PRICE.blackout, "hours": 3.0, "target": "city", "icon": "hammer"},
	"satellite": {"name": "Satellite hack", "text": "Shows the enemy armies in a small area around an enemy city for 1 hour.", "gold": GoldWallet.HACK_PRICE.satellite, "hours": 1.0, "target": "city", "icon": "research"},
	"bank": {"name": "Bank hack", "text": "Takes 5% of the enemy's money and metal at once (up to 2,000 each).", "gold": GoldWallet.HACK_PRICE.bank, "hours": 0.0, "target": "none", "icon": "market"},
	"firewall": {"name": "Firewall", "text": "Blocks every enemy hack against you for 6 hours.", "gold": GoldWallet.HACK_PRICE.firewall, "hours": 6.0, "target": "none", "icon": "stop"},
}
const SATELLITE_RADIUS: = 3.0
const BLACKOUT_FACTOR: = 0.1
const BANK_SHARE: = 0.05
## At most 6,000 gold of resources for a 7,500-gold tactical action. No cheap resource bypass.
const BANK_CAP: = 2000.0
var hacks: Array = []   # active {country, kind, city, remaining}
static var satellite_zones: Array = []  # [country, Vector2] while a satellite hack runs
static var blacked_out: Dictionary = {}          # city id -> true

var spies: Array = []   # {id, country, city, mission, travel}
var last_day: = 0       # game day the spies last worked
var next_id: = 1
var rng: = RandomNumberGenerator.new()
## Read every frame by the fog of war and every build tick: kept as simple lists.
static var intel_zones: Array = []      # [country, Vector2]
static var sabotaged: Dictionary = {}   # city id -> true

func owned(country: String) -> Array:
	return spies.filter(func(spy: Dictionary): return spy.country == country)

func reason(country: String, city: Dictionary, mission: String, city_owner: String, stockpile: Dictionary) -> String:
	if not MISSIONS.has(mission): return "Choose a mission"
	if city.is_empty(): return "Choose a city"
	if owned(country).size() >= MAX_SPIES: return "You already have %d spies" % MAX_SPIES
	var enemy_mission: bool = MISSIONS[mission].enemy
	if enemy_mission and city_owner == country: return "Send this spy to an enemy city"
	if not enemy_mission and city_owner != country: return "Counter-spies guard your own cities"
	for spy in spies:
		if spy.country == country and spy.city == city.id and spy.mission == mission: return "A spy is already on that mission there"
	for resource in COST:
		if float(stockpile.get(resource, 0.0)) < COST[resource]: return "Needs %d %s" % [roundi(COST[resource]), "money" if resource == "funds" else resource]
	return ""

func send(country: String, city: Dictionary, mission: String, city_owner: String, stockpile: Dictionary) -> String:
	var why: = reason(country, city, mission, city_owner, stockpile)
	if not why.is_empty(): return why
	for resource in COST: stockpile[resource] = float(stockpile.get(resource, 0.0)) - COST[resource]
	spies.append({"id": next_id, "country": country, "city": str(city.id), "mission": mission, "travel": TRAVEL})
	next_id += 1
	return ""

func firewall(country: String) -> bool:
	return hacks.any(func(active: Dictionary): return active.country == country and active.kind == "firewall")

static func bank_haul(stockpile: Dictionary) -> Dictionary:
	var haul: Dictionary = {}
	for resource in ["funds", "materials"]: haul[resource] = minf(maxf(0.0,float(stockpile.get(resource,0.0))) * BANK_SHARE, BANK_CAP)
	return haul

func hack_price(kind: String, _enemy: String, _world: Dictionary) -> int:
	if not HACKS.has(kind): return 0
	return int(HACKS[kind].gold)

func hack_reason(country: String, kind: String, city: Dictionary, city_owner: String, gold: int, price: int = -1) -> String:
	if not HACKS.has(kind): return "Choose a hack"
	if HACKS[kind].target == "city" and (city.is_empty() or city_owner == country): return "Choose an enemy city"
	for active in hacks:
		if active.country == country and active.kind == kind and (HACKS[kind].target != "city" or active.city == city.get("id", "")): return "That hack is already running"
	var required: int = int(HACKS[kind].gold) if price < 0 else price
	if gold < required: return "Needs %d gold" % required
	return ""

## Starts a hack. `spend_gold` takes (country, amount) and returns "" when paid. Returns "" on
## success, or why it failed. A hack blocked by the enemy's firewall still costs its gold.
func hack(country: String, kind: String, city: Dictionary, city_owner: String, enemy: String, gold: int, spend_gold: Callable, world: Dictionary, max_gold: int = -1) -> String:
	var price: = hack_price(kind,enemy,world)
	if MatchClient.active != null: return MatchClient.active.send("gold_hack", {"kind":kind,"city":city.get("id",""),"enemy":enemy,"max_gold":price if max_gold < 0 else max_gold})
	var why: = hack_reason(country, kind, city, city_owner, gold, price)
	if not why.is_empty(): return why
	if max_gold >= 0 and price > max_gold: return "Price changed; review the new gold total"
	var paid: String = spend_gold.call(country, price)
	if not paid.is_empty(): return paid
	if kind != "firewall" and firewall(enemy): return "BLOCKED: the enemy's firewall stopped the hack"
	if kind == "bank":
		var theirs: Dictionary = world.stockpile.call(enemy)
		var ours: Dictionary = world.stockpile.call(country)
		var haul: = bank_haul(theirs)
		for resource in haul:
			var amount: float = haul[resource]
			theirs[resource] = float(theirs.get(resource, 0.0)) - amount
			ours[resource] = float(ours.get(resource, 0.0)) + amount
	else:
		var at: Array = [city.point.x, city.point.y] if city.has("point") else []
		hacks.append({"country": country, "kind": kind, "city": str(city.get("id", "")), "at": at, "remaining": float(HACKS[kind].hours) * HOUR})
	_refresh_static(world)
	return ""

func recall(country: String, id: int) -> bool:
	for spy in spies:
		if spy.country == country and int(spy.id) == id:
			spies.erase(spy)
			return true
	return false

## Runs the spies for `seconds` of game time. `world` gives the game state:
##   city(id) -> Dictionary, owner(city) -> String, stockpile(country) -> Dictionary,
##   armies_in(city) -> Array of units, territory(city) -> Dictionary, garrisoned(city, country) -> bool
## Returns report lines for the player.
func advance(seconds: float, world: Dictionary, player: String, day: int = 0) -> Array:
	var reports: Array = []
	if last_day == 0: last_day = day
	for active in hacks.duplicate():
		active.remaining -= seconds
		if active.remaining <= 0.0:
			hacks.erase(active)
			if active.country == player: reports.append(HACKS[active.kind].name + " ended")
	for spy in spies.duplicate():
		var city: Dictionary = world.city.call(spy.city)
		var city_owner: String = world.owner.call(city) if not city.is_empty() else ""
		# The city changed hands: an enemy spy is now home, a counter-spy has lost its city.
		if city.is_empty() or (MISSIONS[spy.mission].enemy and city_owner == spy.country) or (not MISSIONS[spy.mission].enemy and city_owner != spy.country):
			spies.erase(spy)
			if spy.country == player: reports.append("Our spy left %s: the city changed hands" % _city_name(city, spy))
			continue
		if spy.travel > 0.0:
			spy.travel = maxf(0.0, spy.travel - seconds)
			if spy.travel == 0.0 and spy.country == player: reports.append("Our spy reached %s · %s" % [city.name, MISSIONS[spy.mission].name])
	if day > last_day:
		last_day = day
		reports.append_array(end_of_day(world, player))
	_refresh_static(world)
	return reports

## The day ends: every spy at work tries its mission, and enemy spies may be caught.
func end_of_day(world: Dictionary, player: String) -> Array:
	var reports: Array = []
	var stolen: Dictionary = {}
	for spy in spies.duplicate():
		if spy.travel > 0.0 or not spies.has(spy): continue
		var city: Dictionary = world.city.call(spy.city)
		if city.is_empty(): continue
		var city_owner: String = world.owner.call(city)
		if MISSIONS[spy.mission].enemy and rng.randf() < catch_chance(spy, city_owner, world.garrisoned.call(city, city_owner)):
			spies.erase(spy)
			reports.append(("Our spy was caught in %s" if spy.country == player else "Enemy spy caught in %s") % city.name + " · " + MISSIONS[spy.mission].name.to_lower())
			continue
		var taken: = _daily(spy, city, city_owner, world)
		if spy.country == player and taken > 0.0: stolen[city.name] = taken
		elif spy.country != player and taken > 0.0: reports.append("Enemy spies stole %s money and metal in %s" % [StrategyHUD._thousands(int(taken)), city.name])
	for name in stolen: reports.append("Our spy stole %s money and metal in %s" % [StrategyHUD._thousands(int(stolen[name])), name])
	_refresh_static(world)
	return reports

func catch_chance(spy: Dictionary, city_owner: String, garrison: bool) -> float:
	var chance: = CATCH_CHANCE + (GARRISON_BONUS if garrison else 0.0)
	for other in spies:
		if other.mission == "counter" and other.city == spy.city and other.country == city_owner and other.travel <= 0.0:
			chance *= COUNTER_FACTOR
			break
	return minf(chance, 0.8)

## One day's work of a spy. Returns the money and metal it took (steal missions).
func _daily(spy: Dictionary, city: Dictionary, city_owner: String, world: Dictionary) -> float:
	var total: = 0.0
	match spy.mission:
		"steal":
			var theirs: Dictionary = world.stockpile.call(city_owner)
			var ours: Dictionary = world.stockpile.call(spy.country)
			for resource in ["funds", "materials"]:
				var amount: = minf(maxf(0.0, float(theirs.get(resource, 0.0))) * STEAL_SHARE, STEAL_CAP)
				theirs[resource] = float(theirs.get(resource, 0.0)) - amount
				ours[resource] = float(ours.get(resource, 0.0)) + amount
				total += amount
		"army":
			for unit in world.armies_in.call(city):
				if unit.country == city_owner and unit.health > ARMY_FLOOR: unit.health = maxf(ARMY_FLOOR, unit.health - ARMY_DAMAGE)
		"morale":
			var territory: Dictionary = world.territory.call(city)
			if not territory.is_empty():
				var morale: = float(territory.get("morale", 100.0))
				territory.morale = maxf(MORALE_FLOOR, morale - MORALE_LOSS)
	return total

func _refresh_static(world: Dictionary) -> void:
	intel_zones.clear()
	sabotaged.clear()
	_refresh_hacks()
	for spy in spies:
		if spy.travel > 0.0: continue
		if spy.mission == "intel":
			var city: Dictionary = world.city.call(spy.city)
			if not city.is_empty(): intel_zones.append([spy.country, city.point])
		elif spy.mission == "sabotage":
			sabotaged[spy.city] = true

func _refresh_hacks() -> void:
	satellite_zones.clear()
	blacked_out.clear()
	for active in hacks:
		if active.kind == "satellite" and active.get("at", []).size() == 2:
			satellite_zones.append([active.country, Vector2(float(active.at[0]), float(active.at[1]))])
		elif active.kind == "blackout": blacked_out[active.city] = true

static func reveals(point: Vector2, country: String) -> bool:
	for zone in satellite_zones:
		if zone[0] == country and point.distance_to(zone[1]) <= SATELLITE_RADIUS: return true
	for zone in intel_zones:
		if zone[0] == country and point.distance_to(zone[1]) <= INTEL_RADIUS: return true
	return false

static func sabotage_factor(city_id: String) -> float:
	if blacked_out.has(city_id): return BLACKOUT_FACTOR
	return SABOTAGE_FACTOR if sabotaged.has(city_id) else 1.0

func _city_name(city: Dictionary, spy: Dictionary) -> String:
	return str(city.get("name", spy.city))

## The computer opponent trains a spy now and then: one counter-spy at home, the rest against
## the player's cities nearest the front.
func ai_turn(country: String, targets: Array, home: Dictionary, world: Dictionary) -> void:
	if owned(country).size() >= 3 or targets.is_empty(): return
	var stockpile: Dictionary = world.stockpile.call(country)
	if not owned(country).any(func(spy: Dictionary): return spy.mission == "counter") and not home.is_empty():
		send(country, home, "counter", country, stockpile)
		return
	var missions: = ["steal", "sabotage", "army", "morale", "intel"]
	var target: Dictionary = targets[rng.randi_range(0, mini(2, targets.size() - 1))]
	send(country, target, missions[rng.randi_range(0, missions.size() - 1)], world.owner.call(target), stockpile)

## The computer opponent's hackers: keeps a firewall up when it can, otherwise hacks the player.
## Returns the hack used ("" for none, "blocked" when the player's firewall stopped it).
func ai_hack(country: String, enemy: String, targets: Array, gold: int, spend_gold: Callable, world: Dictionary) -> String:
	if not firewall(country) and gold >= int(HACKS.firewall.gold) * 3:
		return "firewall" if hack(country, "firewall", {}, "", enemy, gold, spend_gold, world).is_empty() else ""
	var kinds: = ["blackout", "satellite", "bank"]
	var target: Dictionary = targets[0] if not targets.is_empty() else {}
	kinds = kinds.filter(func(kind): return hack_reason(country,kind,target,enemy,gold,hack_price(kind,enemy,world)).is_empty())
	if kinds.is_empty(): return ""
	var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
	var result: = hack(country, kind, target, enemy, enemy, gold, spend_gold, world)
	return kind if result.is_empty() else ("blocked" if result.begins_with("BLOCKED") else "")

func snapshot() -> Dictionary:
	return {"spies": spies.duplicate(true), "next_id": next_id, "hacks": hacks.duplicate(true), "last_day": last_day}

func restore(state: Dictionary) -> void:
	spies.clear()
	for spy in state.get("spies", []):
		if spy is Dictionary and MISSIONS.has(str(spy.get("mission", ""))) and str(spy.get("country", "")) in ["russia", "ukraine"]:
			spies.append({"id": int(spy.get("id", 0)), "country": str(spy.country), "city": str(spy.get("city", "")), "mission": str(spy.mission), "travel": clampf(float(spy.get("travel", 0.0)), 0.0, TRAVEL)})
	last_day = maxi(0, int(state.get("last_day", 0)))
	next_id = maxi(int(state.get("next_id", 1)), spies.reduce(func(top: int, spy: Dictionary): return maxi(top, int(spy.id) + 1), 1))
	hacks.clear()
	for active in state.get("hacks", []):
		if active is Dictionary and HACKS.has(str(active.get("kind", ""))) and str(active.get("country", "")) in ["russia", "ukraine"]:
			var at: Array = []
			if active.get("at") is Array and active.at.size() == 2: at = [float(active.at[0]), float(active.at[1])]
			hacks.append({"country": str(active.country), "kind": str(active.kind), "city": str(active.get("city", "")), "at": at, "remaining": clampf(float(active.get("remaining", 0.0)), 0.0, 6.0 * HOUR)})
	intel_zones.clear()
	sabotaged.clear()
	_refresh_hacks()

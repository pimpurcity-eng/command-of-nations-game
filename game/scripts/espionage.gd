class_name Espionage
extends RefCounted
## Espionage (owner request 2026-10-14, Call of War style). Spies are trained for money and sent
## to a city. After a short journey each spy works on one mission until it is recalled or caught:
##   intel     - shows every enemy army near the city
##   steal     - takes part of the enemy's stock of money and metal every hour
##   sabotage  - halves building and production speed in the city
##   army      - wounds the enemy armies standing in the city
##   morale    - lowers the morale of the city's province
##   counter   - (in your own city) makes enemy spies there much more likely to be caught
## Every enemy spy has a small chance each hour of being caught; counter-spies and garrisons raise it.
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND  # one real hour
const TRAVEL: = HOUR * 0.5  # half an hour to reach the city
const MAX_SPIES: = 6
const COST: = {"funds": 3000.0, "manpower": 100.0}
const CATCH_CHANCE: = 0.04       # per hour, per enemy spy
const COUNTER_FACTOR: = 3.0      # with a counter-spy in the city
const GARRISON_BONUS: = 0.02     # with an army in the city
const INTEL_RADIUS: = 2.6
const STEAL_SHARE: = 0.01        # of the target's money and metal, per hour
const STEAL_CAP: = 1500.0        # per resource, per hour
const SABOTAGE_FACTOR: = 0.5
const ARMY_DAMAGE: = 3.0         # health per hour
const ARMY_FLOOR: = 25.0         # spies never finish an army off
const MORALE_LOSS: = 4.0         # per hour
const MORALE_FLOOR: = 20.0
const MISSIONS: = {
	"intel": {"name": "Intelligence", "text": "See every enemy army near the city.", "icon": "research", "enemy": true},
	"steal": {"name": "Steal resources", "text": "Take money and metal from the enemy every hour.", "icon": "market", "enemy": true},
	"sabotage": {"name": "Sabotage", "text": "Building and production in the city run at half speed.", "icon": "hammer", "enemy": true},
	"army": {"name": "Attack the army", "text": "Enemy armies in the city lose health every hour.", "icon": "attack", "enemy": true},
	"morale": {"name": "Lower morale", "text": "The province's morale drops every hour.", "icon": "provinces", "enemy": true},
	"counter": {"name": "Counter-spy", "text": "Guard one of your cities: enemy spies there are caught far more often.", "icon": "stop", "enemy": false},
}

var spies: Array = []   # {id, country, city, mission, travel, hour}
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
	spies.append({"id": next_id, "country": country, "city": str(city.id), "mission": mission, "travel": TRAVEL, "hour": HOUR})
	next_id += 1
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
func advance(seconds: float, world: Dictionary, player: String) -> Array:
	var reports: Array = []
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
			continue
		spy.hour -= seconds
		while spy.hour <= 0.0 and spies.has(spy):
			spy.hour += HOUR
			if MISSIONS[spy.mission].enemy and rng.randf() < catch_chance(spy, city_owner, world.garrisoned.call(city, city_owner)):
				spies.erase(spy)
				reports.append(("Our spy was caught in %s" if spy.country == player else "Enemy spy caught in %s") % city.name + " · " + MISSIONS[spy.mission].name.to_lower())
				break
			_hourly(spy, city, city_owner, world)
	_refresh_static(world)
	return reports

func catch_chance(spy: Dictionary, city_owner: String, garrison: bool) -> float:
	var chance: = CATCH_CHANCE + (GARRISON_BONUS if garrison else 0.0)
	for other in spies:
		if other.mission == "counter" and other.city == spy.city and other.country == city_owner and other.travel <= 0.0:
			chance *= COUNTER_FACTOR
			break
	return minf(chance, 0.6)

func _hourly(spy: Dictionary, city: Dictionary, city_owner: String, world: Dictionary) -> void:
	match spy.mission:
		"steal":
			var theirs: Dictionary = world.stockpile.call(city_owner)
			var ours: Dictionary = world.stockpile.call(spy.country)
			for resource in ["funds", "materials"]:
				var amount: = minf(maxf(0.0, float(theirs.get(resource, 0.0))) * STEAL_SHARE, STEAL_CAP)
				theirs[resource] = float(theirs.get(resource, 0.0)) - amount
				ours[resource] = float(ours.get(resource, 0.0)) + amount
		"army":
			for unit in world.armies_in.call(city):
				if unit.country == city_owner and unit.health > ARMY_FLOOR: unit.health = maxf(ARMY_FLOOR, unit.health - ARMY_DAMAGE)
		"morale":
			var territory: Dictionary = world.territory.call(city)
			if not territory.is_empty():
				var morale: = float(territory.get("morale", 100.0))
				territory.morale = maxf(MORALE_FLOOR, morale - MORALE_LOSS)

func _refresh_static(world: Dictionary) -> void:
	intel_zones.clear()
	sabotaged.clear()
	for spy in spies:
		if spy.travel > 0.0: continue
		if spy.mission == "intel":
			var city: Dictionary = world.city.call(spy.city)
			if not city.is_empty(): intel_zones.append([spy.country, city.point])
		elif spy.mission == "sabotage":
			sabotaged[spy.city] = true

static func reveals(point: Vector2, country: String) -> bool:
	for zone in intel_zones:
		if zone[0] == country and point.distance_to(zone[1]) <= INTEL_RADIUS: return true
	return false

static func sabotage_factor(city_id: String) -> float:
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

func snapshot() -> Dictionary:
	return {"spies": spies.duplicate(true), "next_id": next_id}

func restore(state: Dictionary) -> void:
	spies.clear()
	for spy in state.get("spies", []):
		if spy is Dictionary and MISSIONS.has(str(spy.get("mission", ""))) and str(spy.get("country", "")) in ["russia", "ukraine"]:
			spies.append({"id": int(spy.get("id", 0)), "country": str(spy.country), "city": str(spy.get("city", "")), "mission": str(spy.mission), "travel": clampf(float(spy.get("travel", 0.0)), 0.0, TRAVEL), "hour": clampf(float(spy.get("hour", HOUR)), 0.0, HOUR)})
	next_id = maxi(int(state.get("next_id", 1)), spies.reduce(func(top: int, spy: Dictionary): return maxi(top, int(spy.id) + 1), 1))
	intel_zones.clear()
	sabotaged.clear()

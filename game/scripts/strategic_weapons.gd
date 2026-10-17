class_name StrategicWeapons
extends RefCounted
## Weapons of mass destruction (owner request 2026-10-12, Conflict of Nations style): chemical
## and nuclear missiles, built at great cost late in a match and launched at a province.
## Long-range SAM batteries near the target can shoot them down (see interception_chance). Nuclear strikes leave fallout: output in nearby provinces drops to
## FALLOUT_OUTPUT for the fallout time. Damage hits every army in the radius, your own too.
const DAY: = VictoryRules.DAY
const WEAPONS: = {
	"chemical": {"name": "Chemical missile", "unlock_day": 12, "build": DAY * 0.5, "radius": 1.0, "damage": 12.0, "armor_factor": 0.3, "fallout": 0.0,
		"cost": {"funds": 60000.0, "materials": 15000.0, "electronics": 8000.0, "fuel": 6000.0, "manpower": 0.0}},
	"nuclear": {"name": "Nuclear missile", "unlock_day": 25, "build": DAY * 2.0, "radius": 1.6, "damage": 90.0, "stack_pool": 250.0, "armor_factor": 0.85, "fallout": DAY * 3.0,
		"cost": {"funds": 250000.0, "materials": 50000.0, "electronics": 40000.0, "fuel": 25000.0, "manpower": 5000.0}},
}
const ABM_RANGE: = 3.5
const ABM_LEVEL: = 3
const ABM_CHANCE: = 0.35
const ABM_MAX: = 0.85
const FALLOUT_OUTPUT: = 0.2

var stock: Dictionary = {}      # country -> {kind: count}
var jobs: Array = []            # {country, kind, remaining}
var fallout: Dictionary = {}    # territory id -> sim seconds left
var rng: = RandomNumberGenerator.new()

func count(country: String, kind: String) -> int:
	return int(stock.get(country, {}).get(kind, 0))

func reason(country: String, kind: String, day: int, stockpile: Dictionary) -> String:
	var weapon: Dictionary = WEAPONS[kind]
	if day < weapon.unlock_day: return "Available on day %d" % weapon.unlock_day
	for job in jobs:
		if job.country == country and job.kind == kind: return "Already being built"
	for resource in weapon.cost:
		if float(stockpile.get(resource, 0.0)) < float(weapon.cost.get(resource, 0.0)): return "Needs %d %s" % [roundi(float(weapon.cost.get(resource, 0.0))), resource]
	return ""

func build(country: String, kind: String, day: int, stockpile: Dictionary) -> String:
	if MatchClient.active != null: return MatchClient.active.send("strategic_build", {"kind": kind})
	var why: = reason(country, kind, day, stockpile)
	if not why.is_empty(): return why
	for resource in WEAPONS[kind].cost: stockpile[resource] -= float(WEAPONS[kind].cost.get(resource, 0.0))
	jobs.append({"country": country, "kind": kind, "remaining": WEAPONS[kind].build})
	return ""

## Returns the weapons finished this step as [country, kind].
func advance(seconds: float) -> Array:
	var done: = []
	for i in range(jobs.size() - 1, -1, -1):
		jobs[i].remaining -= seconds
		if jobs[i].remaining <= 0:
			var job: Dictionary = jobs[i]
			if not stock.has(job.country): stock[job.country] = {}
			stock[job.country][job.kind] = count(job.country, job.kind) + 1
			done.append([job.country, job.kind])
			jobs.remove_at(i)
	for id in fallout.keys():
		fallout[id] -= seconds
		if fallout[id] <= 0: fallout.erase(id)
	return done

func output(territory_id: String) -> float:
	return FALLOUT_OUTPUT if fallout.has(territory_id) else 1.0

## Chance that the target's air defence shoots the missile down (owner 2026-10-14: counters
## must exist before the threat and be strong enough). Only long-range SAM batteries (the
## S-300/S-400 and Patriot families, unlocked from day 6) intercept strategic missiles:
## chemical missiles at any level, nuclear missiles from ABM_LEVEL. Higher levels hit more often.
const ABM_BY_LEVEL: = {1: 0.15, 2: 0.2, 3: 0.3, 4: 0.4, 5: 0.55}
func interception_chance(country: String, target: Vector2, armies: UnitSystem, kind: String = "nuclear") -> float:
	var miss: = 1.0
	for unit in armies.units:
		if unit.country == country or unit.health <= 0 or unit.visual_kind != "air_defense": continue
		if not str(unit.get("equipment_id", "")).begins_with("patriot"): continue
		if not MapDefinition.is_regional() and armies.diplomacy != null and not armies.diplomacy.at_war(country,unit.country): continue
		var level: = int(unit.get("level", 1))
		if kind == "nuclear" and level < ABM_LEVEL: continue
		if Vector2(unit.node.position.x, unit.node.position.z).distance_to(target) > ABM_RANGE: continue
		miss *= 1.0 - float(ABM_BY_LEVEL.get(level, 0.3)) * unit.health / 100.0
	return minf(1.0 - miss, ABM_MAX)

## Launches at a map point. Returns {"ok", "message", "intercepted", "hits", "kind"}.
func launch(country: String, kind: String, target: Vector2, armies: UnitSystem, territories: Array) -> Dictionary:
	if count(country, kind) <= 0: return {"ok": false, "message": "No %s ready" % WEAPONS[kind].name.to_lower()}
	stock[country][kind] -= 1
	var weapon: Dictionary = WEAPONS[kind]
	if rng.randf() < interception_chance(country, target, armies, kind):
		return {"ok": true, "intercepted": true, "hits": 0, "kind": kind, "message": weapon.name + " shot down by missile defence"}
	var damage: = blast(kind, target, armies.units)
	for unit in armies.units:
		if damage.has(unit.id): unit.health = maxf(0.0, unit.health - float(damage[unit.id]))
	var hits: = damage.size()
	if weapon.fallout > 0:
		for t in territories:
			if t.playable and t.center.distance_to(target) <= weapon.radius * 1.5: fallout[t.id] = weapon.fallout
	return {"ok": true, "intercepted": false, "hits": hits, "kind": kind, "message": "%s struck · %d armies hit" % [weapon.name, hits]}

## Damage (unit id -> saved condition percentage lost; pool is actual HP) from a nuclear or chemical blast at `target`.
static func blast(kind: String, target: Vector2, units: Array) -> Dictionary:
	var weapon: Dictionary = WEAPONS[kind]
	var result: = {}
	# Owner 2026-10-14 ("do calculations ... if it's a big stack they might survive"): each army
	# in the blast takes a damage pool shared by its units (STACK_POOL at ground zero, half at
	# the edge); tanks and ships shrug off part of it. A small army is wiped out, a big stack
	# keeps some units.
	var stacks: Dictionary = {}
	for unit in units:
		if unit.health <= 0 or not unit.has("node"): continue
		var distance: = Vector2(unit.node.position.x, unit.node.position.z).distance_to(target)
		if distance > weapon.radius: continue
		var key: String = str(unit.country) + ":" + str(unit.get("stack_id", unit.id))
		if not stacks.has(key): stacks[key] = {"units": [], "distance": distance}
		stacks[key].units.append(unit)
		stacks[key].distance = minf(stacks[key].distance, distance)
	for key in stacks:
		var members: Array = stacks[key].units
		var falloff: float = 1.0 - 0.5 * float(stacks[key].distance) / float(weapon.radius)
		var share: float = float(weapon.get("stack_pool", weapon.damage)) * falloff / members.size() if weapon.has("stack_pool") else weapon.damage * falloff
		for unit in members:
			result[unit.id] = UnitStats.condition_damage(unit, share * (weapon.armor_factor if unit.visual_kind in ["armor", "naval"] else 1.0))
	return result

func snapshot() -> Dictionary:
	return {"stock": stock.duplicate(true), "jobs": jobs.duplicate(true), "fallout": fallout.duplicate()}

func restore(state: Dictionary) -> void:
	stock = state.get("stock", {}).duplicate(true)
	jobs = state.get("jobs", []).duplicate(true)
	fallout = state.get("fallout", {}).duplicate()

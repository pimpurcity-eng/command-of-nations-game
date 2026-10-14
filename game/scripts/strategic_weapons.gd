class_name StrategicWeapons
extends RefCounted
## Weapons of mass destruction (owner request 2026-10-12, Conflict of Nations style): chemical
## and nuclear missiles, built at great cost late in a match and launched at a province.
## Air defence of level 3 or higher near the target can shoot them down (ABM_CHANCE each, at
## most ABM_MAX). Nuclear strikes leave fallout: output in nearby provinces drops to
## FALLOUT_OUTPUT for the fallout time. Damage hits every army in the radius, your own too.
const DAY: = VictoryRules.DAY
const WEAPONS: = {
	"chemical": {"name": "Chemical missile", "unlock_day": 12, "build": DAY * 0.5, "radius": 1.0, "damage": 45.0, "armor_factor": 0.3, "fallout": 0.0,
		"cost": {"funds": 60000.0, "materials": 15000.0, "electronics": 8000.0, "fuel": 6000.0, "manpower": 0.0}},
	"nuclear": {"name": "Nuclear missile", "unlock_day": 25, "build": DAY * 2.0, "radius": 1.6, "damage": 90.0, "armor_factor": 0.85, "fallout": DAY * 3.0,
		"cost": {"funds": 250000.0, "materials": 50000.0, "electronics": 40000.0, "fuel": 25000.0, "manpower": 5000.0}},
}
const ABM_RANGE: = 3.5
const ABM_LEVEL: = 3
const ABM_CHANCE: = 0.35
const ABM_MAX: = 0.75
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

## Chance that the target's air defence shoots the missile down.
func interception_chance(country: String, target: Vector2, armies: UnitSystem) -> float:
	var chance: = 0.0
	for unit in armies.units:
		if unit.country == country or unit.health <= 0 or unit.visual_kind != "air_defense" or int(unit.get("level", 1)) < ABM_LEVEL: continue
		if Vector2(unit.node.position.x, unit.node.position.z).distance_to(target) <= ABM_RANGE: chance += ABM_CHANCE
	return minf(chance, ABM_MAX)

## Launches at a map point. Returns {"ok", "message", "intercepted", "hits", "kind"}.
func launch(country: String, kind: String, target: Vector2, armies: UnitSystem, territories: Array) -> Dictionary:
	if count(country, kind) <= 0: return {"ok": false, "message": "No %s ready" % WEAPONS[kind].name.to_lower()}
	stock[country][kind] -= 1
	var weapon: Dictionary = WEAPONS[kind]
	if rng.randf() < interception_chance(country, target, armies):
		return {"ok": true, "intercepted": true, "hits": 0, "kind": kind, "message": weapon.name + " shot down by missile defence"}
	var hits: = 0
	for unit in armies.units:
		if unit.health <= 0 or not unit.has("node"): continue
		var distance: = Vector2(unit.node.position.x, unit.node.position.z).distance_to(target)
		if distance > weapon.radius: continue
		var falloff: float = 1.0 - 0.5 * distance / float(weapon.radius)
		var damage: float = weapon.damage * falloff * (weapon.armor_factor if unit.visual_kind in ["armor", "naval"] else 1.0)
		# Owner 2026-10-14: nothing inside a nuclear blast survives.
		if kind == "nuclear": damage = unit.health
		unit.health = maxf(0.0, unit.health - damage)
		hits += 1
	if weapon.fallout > 0:
		for t in territories:
			if t.playable and t.center.distance_to(target) <= weapon.radius * 1.5: fallout[t.id] = weapon.fallout
	return {"ok": true, "intercepted": false, "hits": hits, "kind": kind, "message": "%s struck · %d armies hit" % [weapon.name, hits]}

func snapshot() -> Dictionary:
	return {"stock": stock.duplicate(true), "jobs": jobs.duplicate(true), "fallout": fallout.duplicate()}

func restore(state: Dictionary) -> void:
	stock = state.get("stock", {}).duplicate(true)
	jobs = state.get("jobs", []).duplicate(true)
	fallout = state.get("fallout", {}).duplicate()

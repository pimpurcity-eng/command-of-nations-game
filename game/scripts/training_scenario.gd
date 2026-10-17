class_name TrainingScenario
extends RefCounted
## A small, asymmetric training preset; ordinary campaigns and online matches keep their rules.
const SAVE_PATH := "user://training_save.json"
const OPENING_VIDEO := "res://assets/cinematics/training_opening.ogv"
const SUPPLY_VIDEO := "res://assets/cinematics/training_supply.ogv"
const MIN_PLAY_SECONDS := 300.0
const MAX_PLAY_SECONDS := 600.0
const STARTING_FORCES := {
	"russia": {"tanks": 6, "infantry": 4, "artillery": 2, "skyguard": 2, "drones": 3, "yak130": 2, "missiles": 2},
	"ukraine": {"tanks": 3, "infantry": 4, "artillery": 1, "skyguard": 1, "drones": 2, "hawk_t2": 1},
}
## Where each family starts (owner 2026-10-17): identical units share one stack instead of being
## spread across every city; infantry stays as single units. Russia's 6-tank column waits on the
## Russian side of the border west of Belgorod, facing Ukraine, with drones and missiles behind it. Each entry: [family, place, count]
## where place is a city id or [longitude, latitude] for a field position (snapped to a road).
const FORMATIONS := {
	"russia": [["tanks", [36.0, 50.55], 6], ["drones", "belgorod", 3], ["missiles", "belgorod", 2],
		["artillery", "belgorod", 2], ["infantry", "belgorod", 2], ["infantry", "kursk", 2],
		["skyguard", "kursk", 2], ["yak130", "kursk", 2]],
	"ukraine": [["tanks", "kharkiv", 3], ["artillery", "kharkiv", 1], ["infantry", "kharkiv", 2],
		["infantry", "kyiv", 2], ["skyguard", "kyiv", 1], ["drones", "kyiv", 2], ["hawk_t2", "kyiv", 1]],
}
## Scenario balance, not a historical GDP ratio. The bonus follows the controlling country.
const INCOME_FACTORS := {"russia": 1.5, "ukraine": 1.0}
const AID_LOADS := {
	# Owner 2026-10-17: five on the ship, "mainly tanks", one of them a plane; five on the train.
	"odesa": {"donor": "America", "mode": "sea", "equipment": {"tanks": 4, "fighters": 1},"resources": {"funds": 25000.0, "materials": 12000.0, "fuel": 9000.0, "electronics": 5000.0, "food": 8000.0}},
	"lviv": {"donor": "Europe", "mode": "rail", "equipment": {"tanks": 2, "artillery": 1, "skyguard": 1, "drones": 1}, "resources": {"funds": 15000.0}},
}
const AMERICAN_HARDWARE := {
	"tanks": ["M1A1 Abrams", "usa_m1a1_abrams"],
	"artillery": ["M109A7 Paladin", "usa_m109a7_paladin"],
	"skyguard": ["AN/TWQ-1 Avenger", "usa_avenger"],
	"drones": ["MQ-9A Reaper", "usa_mq9a_reaper"],
	"fighters": ["F-16AM Fighting Falcon", "euro_f16am_belgium"],
}
const PHASES := ["choice", "opening", "side", "basics", "features", "practice", "supply_video", "logistics", "reward", "free"]

static func aid_equipment(destination: String, family: String) -> String:
	return "aid_american_%s_ukraine" % family if destination == "odesa" else family + "_ukraine"

static func equipment_count(destination: String) -> int:
	var count := 0
	for quantity in AID_LOADS[destination].equipment.values(): count += int(quantity)
	return count

static func ensure_supplied_equipment() -> void:
	for family in AMERICAN_HARDWARE:
		var id := aid_equipment("odesa", family)
		if EquipmentIdentity.supplied_catalog.has(id): continue
		var spec := EquipmentIdentity.spec(family + "_ukraine").duplicate(true)
		if spec.is_empty(): continue
		spec.id = id
		spec.name = AMERICAN_HARDWARE[family][0]
		spec.supplied_only = true
		var tier: Dictionary = spec.research_tiers[0].duplicate(true)
		tier.name = spec.name
		tier.model = "res://assets/library/arsenal/%s.glb" % AMERICAN_HARDWARE[family][1]
		tier.erase("preview")
		spec.research_tiers = [tier]
		EquipmentIdentity.supplied_catalog[id] = spec

static func initial_state() -> Dictionary:
	return {"version": 1, "phase": "opening", "players": 1, "route": "full", "step": 0, "active_seconds": 0.0, "aid_received": [], "aid_pending": [], "aid_requested": [], "aid_unload_requested": false, "actions": {}, "video_position": 0.0}

static func valid_state(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.get("version") != 1 or value.get("phase") not in PHASES or value.get("route") not in ["full", "features", "skip"]: return false
	var step = value.get("step")
	var seconds = value.get("active_seconds")
	if not (step is int or step is float) or not is_finite(float(step)) or step != floor(step) or step < 0 or step > 20: return false
	if not (seconds is int or seconds is float) or not is_finite(float(seconds)) or seconds < 0 or seconds > 1000000000: return false
	var video_position = value.get("video_position", 0.0)
	if not (video_position is int or video_position is float) or not is_finite(float(video_position)) or video_position < 0 or video_position > 3600: return false
	if not value.get("aid_unload_requested", false) is bool: return false
	if value.get("players", 1) not in [1, 2]: return false
	var actions = value.get("actions", {})
	if not actions is Dictionary or actions.size() > 32: return false
	for key in actions:
		if not key is String or key.length() > 40 or not actions[key] is bool: return false
	for key in ["aid_received", "aid_pending", "aid_requested"]:
		var ids = value.get(key, [])
		if not ids is Array or ids.size() > AID_LOADS.size(): return false
		var seen := {}
		for id in ids:
			if not id is String or not AID_LOADS.has(id) or seen.has(id): return false
			seen[id] = true
	for id in value.aid_pending:
		if id in value.aid_received: return false
	return true

static func prepare(game: Node) -> void:
	ensure_supplied_equipment()
	game.session.training = initial_state()
	game.production.scenario_income_factors = INCOME_FACTORS.duplicate()
	game.units.restore([])
	for country in STARTING_FORCES:
		# One known family lets the player queue production while another family researches.
		game.research.levels["infantry_" + country] = 1
		var homes: Array = game.production.cities.filter(func(c: Dictionary): return c.country.to_lower() == country)
		var capital: Dictionary = game.buildings.capital(country)
		homes.sort_custom(func(a: Dictionary, b: Dictionary): return a.id == capital.id and b.id != capital.id)
		for home in homes:
			for facility in ["airbase", "drone_factory", "tank_plant", "barracks", "factory"]:
				game.buildings.levels[home.id][facility] = 1
		for resource in ProductionSystem.RESOURCES:
			game.production.stockpiles[country][resource] *= 1.5 if country == "russia" else 1.0
		var numbers := {}
		for entry in FORMATIONS[country]:
			var family: String = entry[0]
			var place = entry[1]
			var city: Dictionary = game.buildings.city(place) if place is String else _nearest_city(homes, place)
			if city.is_empty(): city = capital
			var point: Vector2 = city.point if place is String else GeographicProjection.project(place[0], place[1])
			for _i in int(entry[2]):
				var number: int = numbers.get(family, 0)
				numbers[family] = number + 1
				var id := "training_%s_%s_%d" % [country, family, number]
				# Infantry are separate armies; every other family shares one stack per place.
				var stack := id if family == "infantry" else "training_%s_%s_%s" % [country, family, str(place) if place is String else "field"]
				_spawn(game, "%s_%s" % [family, country], city, id, point, stack)
	for id in ["lviv", "kyiv"]:
		if game.buildings.levels.has(id): game.buildings.levels[id].train_station = 1
	if game.buildings.levels.has("odesa"): game.buildings.levels.odesa.naval_base = 1
	game.match_rules.ai_enabled = false
	game.match_rules.declare_war()
	game.clock.paused = true
	game.buildings.changed.emit()
	game.production.changed.emit()
	game.cities.sync_buildings()
	game.apply_player_country()
	game.units.selected = -1
	game.units.command_ids.clear()
	game.hud.clear_unit_selection()

static func _nearest_city(cities: Array, lon_lat: Array) -> Dictionary:
	var target := GeographicProjection.project(lon_lat[0], lon_lat[1])
	var best: Dictionary = {}
	for city in cities:
		if best.is_empty() or (city.point as Vector2).distance_to(target) < (best.point as Vector2).distance_to(target): best = city
	return best

## city is the unit's home/base (aircraft refuel there); point is where it stands on the map.
static func _spawn(game: Node, equipment: String, city: Dictionary, id: String, point = null, stack: String = "") -> void:
	if not game.units.find_id(id).is_empty(): return
	var spec := EquipmentIdentity.spec(equipment)
	if spec.is_empty():
		push_error("Unknown training equipment: " + equipment)
		return
	if stack.is_empty(): stack = id if spec.visual_kind == "infantry" else "training_%s_%s" % [equipment, city.id]
	var data := {"id": id, "name": EquipmentIdentity.research_title(equipment, 1), "country": spec.country, "equipment_id": equipment, "visual_kind": spec.visual_kind, "level": 1, "base_city": city.id, "flight_mode": "grounded", "stack_id": stack}
	# Aircraft stand on their airbase and stack only with the same type at the same base.
	var stand: Vector2 = city.point if point == null or spec.visual_kind == "fighter" else point
	game.units._spawn(data, stand, Color("ef827c") if spec.country == "russia" else Color("73bcff"))
	# A field position (the border column) stays exactly where it was placed instead of being
	# drawn back to the nearest city's roads.
	if point != null and spec.visual_kind != "fighter" and (point as Vector2).distance_to(city.point) > UnitSystem.CITY_RADIUS:
		var unit: Dictionary = game.units.find_id(id)
		if not unit.is_empty(): unit.node.position = game.units.footprint_ground(point)

## Called only when the supply cinematic ends (or the player explicitly skips it).
## Aid is never income for economic victory, and reloading cannot deliver it twice.
static func release_aid(game: Node, auto_unload: bool = false) -> void:
	for id in AID_LOADS:
		if id in game.session.training.aid_received or id in game.session.training.aid_pending: continue
		game.session.training.aid_pending.append(id)
	if auto_unload: request_unload(game)

static func request_unload(game: Node, destination: String = "") -> void:
	var state: Dictionary = game.session.training
	if destination.is_empty():
		state.aid_unload_requested = true
	else:
		if not state.has("aid_requested"): state.aid_requested = []
		if destination not in state.aid_requested: state.aid_requested.append(destination)
	try_unload(game, destination)

static func try_unload(game: Node, destination: String = "") -> void:
	for id in game.session.training.aid_pending.duplicate():
		if not destination.is_empty() and destination != id: continue
		if not game.session.training.get("aid_unload_requested", true) and id not in game.session.training.get("aid_requested", []): continue
		var city: Dictionary = game.buildings.city(id)
		if city.is_empty() or not game.production.controlled(city, "ukraine"): continue
		var load: Dictionary = AID_LOADS[id]
		var facility := "naval_base" if load.mode == "sea" else "train_station"
		if game.buildings.level(id, facility) < 1 or game.buildings.level(id, "airbase") < 1: continue
		# Mark before spawning: callbacks and autosaves must see one committed delivery.
		game.session.training.aid_pending.erase(id)
		game.session.training.aid_received.append(id)
		for family in load.equipment:
			for number in int(load.equipment[family]):
				_spawn(game, aid_equipment(id, family), city, "training_aid_%s_%s_%d" % [id, family, number])
		for resource in load.resources:
			game.production.stockpiles.ukraine[resource] += load.resources[resource]
	game.production.changed.emit()
	game.units.stacks.invalidate()

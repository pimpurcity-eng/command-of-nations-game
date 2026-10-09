class_name GameSession
extends RefCounted
static var player_country: String = "russia"
static var weapons_test: bool = false
## Scenario file (tests point this at data/archive/... while the arsenal is empty).
static var scenario_path: String = "res://data/scenario_regional.json"
static func opponent_country() -> String:
	return "ukraine" if player_country == "russia" else "russia"
const SAVE_VERSION: = 4
var scenario: Dictionary
var countries: Dictionary = {}
var production: ProductionSystem
var match_rules: MatchSystem
func _init() -> void :
	scenario = JSON.parse_string(FileAccess.get_file_as_string(scenario_path))
	for country in scenario.countries: countries[country.id] = country.duplicate(true)
func capture(clock: SimulationClock, map: StrategicMap, units: UnitSystem, rig: StrategyCamera) -> Dictionary:
	var territory_state: Dictionary = {}
	for territory in map.territories:
		if territory.playable:
			territory_state[territory.id] = {"owner": territory.owner, "controller": territory.controller}
	return {"player_country": player_country, "weapons_test": weapons_test, "match": match_rules.snapshot(), "version": SAVE_VERSION, "scenario": scenario.id, "clock": clock.snapshot(), "countries": countries.duplicate(true), "territories": territory_state, "units": units.snapshot(), "production": production.snapshot(), "camera": {"target": [rig.target.x, rig.target.z], "distance": rig.distance, "yaw": rig.yaw, "pitch": rig.pitch}}
func write_save(path: String, state: Dictionary) -> String:
	var file: = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return "Could not open save storage"
	file.store_string(JSON.stringify(state))
	var error: = file.get_error()
	file.close()
	if error != OK: return "Could not write save"
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return "Could not finish save"
	return ""
func read_save(path: String, map: StrategicMap, units: UnitSystem) -> Dictionary:
	if not FileAccess.file_exists(path): return {"error": "No saved game yet"}
	var parser: = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return {"error": "Save file is damaged"}
	var state = parser.data

	if state is Dictionary and state.get("version") == 3 and state.get("territories") is Dictionary and state.get("clock") is Dictionary:
		state.version = SAVE_VERSION
		state.match = {"winner": "", "decision_timer": 0.0, "recruitment_timer": 0.0, "capture_progress": {}}
		var score: = {"russia": 0, "ukraine": 0}
		for city in production.cities:
			var region = state.territories.get(city.sector)
			if region is Dictionary and region.get("controller") in ["russia", "ukraine"] and region.controller != city.country.to_lower(): score[region.controller] += 1
		for country in score:
			if score[country] >= 3:
				state.match .winner = country
				state.clock.paused = true
	migrate_geography(state, map)
	var error: = validate(state, map, units)
	return {"error": error} if not error.is_empty() else {"state": state}
func migrate_geography(state: Variant, map: StrategicMap) -> void :
	if not state is Dictionary or not state.get("territories") is Dictionary: return
	var legacy: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/legacy_provinces_v39.json"))
	if state.territories.size() != legacy.size(): return
	for old in legacy:
		var control = state.territories.get(old.id)
		if not control is Dictionary or control.get("owner") not in ["russia", "ukraine"] or control.get("controller") not in ["russia", "ukraine"]: return
	var migrated: Dictionary = {}
	for region in map.territories:
		if not region.playable: continue
		var selected: Dictionary = {}
		var nearest: = INF
		for old in legacy:
			if old.country != region.country: continue
			var polygon: = PackedVector2Array()
			for point in old.polygon: polygon.append(Vector2(point[0], point[1]))
			if Geometry2D.is_point_in_polygon(region.center, polygon):
				selected = state.territories[old.id]
				break
			for i in polygon.size():
				var point: = Geometry2D.get_closest_point_to_segment(region.center, polygon[i], polygon[(i + 1) % polygon.size()])
				if point.distance_to(region.center) < nearest:
					nearest = point.distance_to(region.center)
					selected = state.territories[old.id]
		if selected.is_empty(): return
		migrated[region.id] = selected.duplicate(true)
	state.territories = migrated
	if state.get("match") is Dictionary: state.match .capture_progress = {}
	state.map_revision = "natural_earth_adm1_v40"
func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= minimum and value <= maximum
func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0], -60, 60) and _number(value[1], -60, 60)
func validate(state: Variant, map: StrategicMap, units: UnitSystem) -> String:
	if not state is Dictionary: return "Invalid save format"
	if state.get("player_country", "russia") not in ["russia", "ukraine"]: return "Invalid player country"
	if not state.get("weapons_test", false) is bool: return "Invalid test mode"
	if state.get("version") != SAVE_VERSION or state.get("scenario") != scenario.id: return "Save belongs to another version or scenario"
	var time = state.get("clock")
	if not time is Dictionary or not _number(time.get("elapsed"), 0, 1000000000000.0) or time.get("speed") not in [1.0, 2.0, 4.0] or not time.get("paused") is bool: return "Invalid saved clock"
	var saved_countries = state.get("countries")
	if not saved_countries is Dictionary or saved_countries.size() != countries.size(): return "Invalid saved countries"
	for id in countries:
		if not saved_countries.get(id) is Dictionary or saved_countries[id].get("id") != id or saved_countries[id].get("name") != countries[id].name or saved_countries[id].get("color") != countries[id].color or not saved_countries[id].get("statistics") is Dictionary or not saved_countries[id].get("relations") is Dictionary: return "Invalid saved country"
	var regions = state.get("territories")
	if not regions is Dictionary: return "Invalid saved territories"
	var count: = 0
	for territory in map.territories:
		if not territory.playable: continue
		count += 1
		var region = regions.get(territory.id)
		if not region is Dictionary or not countries.has(region.get("owner")) or not countries.has(region.get("controller")): return "Invalid saved territory control"
	if regions.size() != count: return "Saved territory set does not match scenario"
	var saved_units = state.get("units")
	if not saved_units is Array or saved_units.size() < 0 or saved_units.size() > 2000: return "Invalid saved units"
	var unit_ids: Dictionary = {}
	var stack_state: Dictionary = {}
	for unit in saved_units:
		if not unit is Dictionary or not unit.get("id") is String or unit_ids.has(unit.id) or not countries.has(unit.get("country")) or not unit.get("name") is String or unit.name.length() > 80 or unit.get("visual_kind") not in ["armor", "ifv", "artillery", "fighter", "air_defense", "naval", "missile_launcher"] or not _point(unit.get("position")) or not _point(unit.get("target")) or not unit.get("moving") is bool: return "Invalid saved unit"
		if unit.get("fire_mode", "at_will") not in FireControlPanel.MODES or not unit.get("attack_target", "") is String or unit.get("attack_target", "").length() > 128: return "Invalid saved fire control"
		if not unit.get("forced_march", false) is bool or not _number(unit.get("delay_remaining", 0.0), 0, 720): return "Invalid saved movement settings"
		if unit.visual_kind == "fighter" and (unit.get("forced_march", false) or unit.get("delay_remaining", 0.0) > 0): return "Invalid aircraft movement settings"
		if unit.has("equipment_id"):
			var equipment: = EquipmentIdentity.spec(str(unit.equipment_id))
			if equipment.is_empty() or equipment.country != unit.country or equipment.visual_kind != unit.visual_kind: return "Invalid saved equipment identity"
		var level = unit.get("level", 1)
		var target_level = unit.get("upgrade_target", level)
		if not _number(level, 1, 5) or level != floor(level) or not _number(target_level, level, 5) or target_level != floor(target_level) or not _number(unit.get("upgrade_remaining", 0.0), 0, 1000): return "Invalid unit modernization"
		if unit.get("upgrade_remaining", 0.0) > 0 and (unit.moving or target_level <= level): return "Invalid active modernization"
		if unit.visual_kind == "fighter":
			if unit.get("flight_mode") not in ["grounded", "fly", "patrol", "return", "attack"] or not _number(unit.get("flight_used"), 0, 48) or not _number(unit.get("refuel_remaining"), 0, AirOperations.REFUEL_SECONDS) or not _number(unit.get("patrol_phase"), 0, TAU) or not _point(unit.get("patrol_center")): return "Invalid saved aircraft"
			var home: = production.buildings.city(str(unit.get("base_city", "")))
			if home.is_empty() or (unit.flight_mode != "attack" and (unit.flight_mode == "grounded") == unit.moving): return "Invalid aircraft home or orders"
		if unit.has("route"):
			if not unit.route is Array or unit.route.size() > 256: return "Invalid saved route"
			for waypoint in unit.route:
				if not _point(waypoint): return "Invalid saved waypoint"
		if unit.visual_kind == "naval":
			var previous: = Vector2(unit.position[0], unit.position[1])
			if not units.sea_navigation.on_sea(previous) or not units.sea_navigation.on_sea(Vector2(unit.target[0], unit.target[1])): return "Invalid naval position"
			for waypoint in unit.get("route", []):
				var point: = Vector2(waypoint[0], waypoint[1])
				if not units.sea_navigation.clear_segment(previous, point): return "Naval route crosses land"
				previous = point
		if unit.has("stack_id"):
			if not unit.stack_id is String or unit.stack_id.is_empty() or unit.stack_id.length() > 128: return "Invalid saved stack"
			if stack_state.has(unit.stack_id):
				var first: Dictionary = stack_state[unit.stack_id]
				if first.country != unit.country or (first.visual_kind == "fighter") != (unit.visual_kind == "fighter") or (first.visual_kind == "naval") != (unit.visual_kind == "naval") or Vector2(first.position[0], first.position[1]).distance_to(Vector2(unit.position[0], unit.position[1])) > 0.01: return "Invalid mixed or separated stack"
			else: stack_state[unit.stack_id] = unit
		unit_ids[unit.id] = true
	for unit in saved_units:
		if not _number(unit.get("health"), 0.001, 100): return "Invalid saved unit health"
	if not production.validate(state.get("production")): return "Invalid saved production"
	var match_state = state.get("match")
	if not match_state is Dictionary or match_state.get("winner") not in ["", "russia", "ukraine"] or not _number(match_state.get("decision_timer"), 0, 5) or not _number(match_state.get("recruitment_timer"), 0, 20) or not match_state.get("capture_progress") is Dictionary: return "Invalid saved match"
	if match_state.has("combat_cooldowns"):
		if not match_state.combat_cooldowns is Dictionary or match_state.combat_cooldowns.size() > 1000: return "Invalid battle timers"
		for id in match_state.combat_cooldowns:
			if not id is String or not _number(match_state.combat_cooldowns[id], 0, CombatSystem.MAX_ROUND_SECONDS): return "Invalid battle timer"
	if match_state.has("at_war") and not match_state.at_war is bool: return "Invalid diplomatic state"
	if match_state.has("air_cooldowns"):
		if not match_state.air_cooldowns is Dictionary or match_state.air_cooldowns.size() > 2000: return "Invalid air battle timers"
		for id in match_state.air_cooldowns:
			if not id is String or not _number(match_state.air_cooldowns[id], 0, AirBattleSystem.ROUND_SECONDS): return "Invalid air battle timer"
	if not match_state.winner.is_empty() and not time.paused: return "Finished match must be paused"
	for id in match_state.capture_progress:
		var progress = match_state.capture_progress[id]
		if not regions.has(id) or not progress is Dictionary or not countries.has(progress.get("country")) or not _number(progress.get("seconds"), 0, 6): return "Invalid capture progress"
	var camera = state.get("camera")
	if not camera is Dictionary or not _point(camera.get("target")) or not _number(camera.get("distance"), 4.5, 60) or not _number(camera.get("yaw"), -1.1, 1.1) or not _number(camera.get("pitch"), 0.35, 1.35): return "Invalid saved camera"
	return ""
func restore(state: Dictionary, clock: SimulationClock, map: StrategicMap, units: UnitSystem, rig: StrategyCamera) -> void :
	player_country = state.get("player_country", "russia")
	weapons_test = state.get("weapons_test", false)
	countries = state.countries.duplicate(true)
	for territory in map.territories:
		if not territory.playable: continue
		territory.owner = state.territories[territory.id].owner
		territory.controller = state.territories[territory.id].controller
	units.restore(state.units)
	production.restore(state.production)
	rig.target = Vector3(state.camera.target[0], 0, state.camera.target[1])
	rig.distance = state.camera.distance
	rig.yaw = state.camera.yaw
	rig.pitch = state.camera.pitch
	rig._snap(1.0)
	clock.restore(state.clock)
	match_rules.restore(state.match )
	map.relation_signature = ""
	map.update_relations(match_rules.at_war)

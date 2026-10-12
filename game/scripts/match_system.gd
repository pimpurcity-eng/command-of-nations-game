class_name MatchSystem
extends Node
signal report(message: String)
signal finished(country: String)
signal unit_destroyed(unit: Dictionary)
## Countries that have had at least one army on the map.
var fielded: Dictionary = {}
var production: ProductionSystem
var ai: = CountryAI.new()
var combat: = CombatSystem.new()
var air_combat: = AirBattleSystem.new()
var terrain: StrategicMap
var armies: UnitSystem
var cities: Array
var clock: SimulationClock
var ai_enabled: = true
var decision_timer: = 0.0
var winner: = ""
## How the match was won: domination, economic, elimination or points (VictoryRules).
var victory_type: = ""
var victory: = VictoryRules.new()
## Battle reports and the daily newspaper.
var chronicle: = WarChronicle.new()
## Occupied and annexed land.
var annexation: = Annexation.new()
## Chemical and nuclear missiles.
var strategic: = StrategicWeapons.new()
## Entrenchment (Conflict of Nations style): an army that has stood still for ENTRENCH_TIME at
## the centre of a province its country holds digs in and defends ENTRENCH_BONUS harder.
const ENTRENCH_TIME: = VictoryRules.DAY / 12.0
const ENTRENCH_BONUS: = 1.25
var at_war: = false
func declare_war() -> void :
	if at_war or not winner.is_empty(): return
	at_war = true
	armies.at_war = true
	report.emit("WAR DECLARED · " + GameSession.opponent_country().capitalize() + " AI will defend and counterattack")
func ceasefire() -> void :
	if not at_war or not winner.is_empty(): return
	at_war = false
	armies.at_war = false
	capture_progress.clear()
	for unit in armies.units:
		unit.engaged = false
		unit.firing_halt = false
		if not unit.get("attack_target", "").is_empty():
			unit.attack_target = ""
			unit.moving = false
			unit.waypoints.clear()
			unit.target = Vector2(unit.node.position.x, unit.node.position.z)
	terrain.update_relations(false)
	report.emit("CEASEFIRE · Combat and occupation stopped; existing control retained")
const CAPTURE_RADIUS: = 0.6
var capture_progress: Dictionary = {}
func setup(map: StrategicMap, units: UnitSystem, city_data: Array, time: SimulationClock) -> void :
	terrain = map
	armies = units
	cities = city_data
	clock = time
	chronicle.setup(self)

func advance_battles(seconds: float) -> void :
	if not is_finite(seconds) or seconds <= 0 or not armies.at_war: return
	var remaining: = seconds
	var initial: = true
	while remaining > 0 or initial:
		var step: = 0.0
		if not initial:
			step = remaining
			for timers in [combat.cooldowns, air_combat.cooldowns]:
				for timer in timers.values():
					if timer > 0: step = minf(step, timer)
		initial = false
		var damage: Dictionary = {}
		combat.advance(step, armies, damage, true)
		air_combat.advance(step, armies, damage, true)
		for unit in armies.units:
			var factor: = production.buildings.incoming_damage_factor(unit) if production != null and production.buildings != null else 1.0
			unit.health = maxf(0, unit.health - damage.get(unit.id, 0.0) * factor)
		remaining = maxf(0, remaining - step)
func advance(seconds: float) -> void :
	if not winner.is_empty() or seconds <= 0: return
	chronicle.advance(seconds)
	for title in annexation.advance(seconds, terrain.territories): report.emit(title + " annexed")
	for done in strategic.advance(seconds):
		report.emit("%s completed a %s" % [str(done[0]).capitalize(), StrategicWeapons.WEAPONS[done[1]].name.to_lower()])
	_update_entrenchment(seconds)
	# Victory is checked in peace too (economic victory, time limit).
	var result: = victory.evaluate(self, seconds)
	if not result.is_empty():
		end_match(result[0], result[1])
		return
	if not at_war: return
	advance_battles(seconds)
	var selected_stack: = ""
	var selected_country: = ""
	if armies.selected >= 0:
		selected_stack = armies.units[armies.selected].stack_id
		selected_country = armies.units[armies.selected].country
	var casualties: = false
	for index in range(armies.units.size() - 1, -1, -1):
		if armies.units[index].health > 0: continue
		casualties = true
		unit_destroyed.emit(armies.units[index])
		report.emit(armies.units[index].name + " destroyed")
		armies.units[index].node.queue_free()
		armies.units.remove_at(index)
		if armies.selected == index: armies.selected = -1
		elif armies.selected > index: armies.selected -= 1
	if casualties:
		if armies.selected < 0:
			for index in armies.units.size():
				if armies.units[index].stack_id == selected_stack and armies.units[index].country == selected_country:
					armies.select_unit(index)
					break
		armies._draw_route()
	for territory in terrain.territories:
		if not territory.playable: continue
		var occupant: = ""
		var contested: = false
		for unit in armies.units:
			if unit.visual_kind in ["fighter", "naval"]: continue
			var point: = Vector2(unit.node.position.x, unit.node.position.z)
			if not RegionData.contains(territory, point): continue

			if point.distance_to(territory.center) > CAPTURE_RADIUS: continue
			if occupant.is_empty(): occupant = unit.country
			elif occupant != unit.country: contested = true
		if contested or occupant.is_empty() or occupant == territory.controller:
			capture_progress.erase(territory.id)
			continue
		var progress: Dictionary = capture_progress.get(territory.id, {"country": occupant, "seconds": 0.0})
		if progress.country != occupant: progress = {"country": occupant, "seconds": 0.0}
		progress.seconds += seconds
		capture_progress[territory.id] = progress
		if progress.seconds < 6: continue
		territory.controller = occupant
		terrain.update_relations(at_war)
		capture_progress.erase(territory.id)
		report.emit(territory.title + " captured by " + occupant.capitalize())
	for country in ["ukraine", "russia"]:
		var living: = false
		for unit in armies.units:
			if unit.country == country:
				living = true
				fielded[country] = true
		# A side is only eliminated after it has fielded armies (the arsenal can be empty
		# while new weapons are being made).
		if not fielded.has(country): continue
		if production != null:
			for job in production.jobs:
				if production.equipment(job.equipment).country != country: continue
				for city in cities:
					if city.name == job.city and production.controlled(city, country): living = true
		if not living:
			end_match("russia" if country == "ukraine" else "ukraine", "elimination")
			return
	if not ai_enabled: return
	decision_timer += seconds
	if decision_timer < 0.05: return
	if clock.elapsed >= 2.5: ai.decide(armies, terrain, cities, production, decision_timer)
	decision_timer = 0
func _update_entrenchment(seconds: float) -> void:
	for unit in armies.units:
		if unit.get("moving", false) or unit.visual_kind in ["fighter", "naval"] or not unit.has("node"):
			unit.dug_in = 0.0
			unit.entrenched = false
			continue
		var point: = Vector2(unit.node.position.x, unit.node.position.z)
		var at_centre: = false
		for title in terrain.province_hubs:
			if terrain.province_hubs[title].distance_to(point) <= CAPTURE_RADIUS:
				at_centre = true
				break
		unit.dug_in = unit.get("dug_in", 0.0) + seconds if at_centre else 0.0
		unit.entrenched = unit.dug_in >= ENTRENCH_TIME
## Retreat (Conflict of Nations style): the army pulls back to the nearest province centre its
## country holds, at the cost of RETREAT_DAMAGE of its health, and stops firing on the way.
const RETREAT_DAMAGE: = 0.1
func retreat(group: Array, from: Vector2) -> Vector2:
	var best: = Vector2.INF
	for t in terrain.territories:
		if not t.playable or t.controller != group[0].country or not terrain.province_hubs.has(t.title): continue
		var hub: Vector2 = terrain.province_hubs[t.title]
		if hub.distance_to(from) < 0.8: continue
		if best == Vector2.INF or hub.distance_to(from) < best.distance_to(from): best = hub
	if best == Vector2.INF: return best
	for unit in group:
		if at_war and unit.get("engaged", false): unit.health = maxf(1.0, unit.health * (1.0 - RETREAT_DAMAGE))
		unit.attack_target = ""
		unit.fire_mode = "hold"
		unit.entrenched = false
		unit.dug_in = 0.0
	return best
func city_score() -> Dictionary:
	var score: = {"russia": 0, "ukraine": 0}
	for city in cities:
		for territory in terrain.territories:
			if territory.id == city.sector and territory.controller != city.country.to_lower(): score[territory.controller] += 1
	return score
const VICTORY_NAMES: = {"domination": "DOMINATION VICTORY", "economic": "ECONOMIC VICTORY", "elimination": "VICTORY BY ELIMINATION", "points": "VICTORY ON POINTS"}
func end_match(country: String, kind: String = "elimination") -> void :
	winner = country
	victory_type = kind
	clock.paused = true
	clock.state_changed.emit()
	report.emit(VICTORY_NAMES.get(kind, "VICTORY") + " · " + country.capitalize() + " wins. Choose New match to play again.")
	finished.emit(country)
func snapshot() -> Dictionary:
	return {"air_cooldowns": air_combat.snapshot(), "combat_cooldowns": combat.snapshot(), "at_war": at_war, "winner": winner, "decision_timer": decision_timer, "recruitment_timer": ai.recruitment_timer, "capture_progress": capture_progress.duplicate(true), "victory_type": victory_type, "victory": victory.snapshot(), "chronicle": chronicle.snapshot(), "annexation": annexation.snapshot(), "strategic": strategic.snapshot(), "doctrines": Doctrine.snapshot()}
func restore(state: Dictionary) -> void :
	combat.restore(state.get("combat_cooldowns", {}))
	air_combat.restore(state.get("air_cooldowns", {}))
	at_war = state.get("at_war", true)
	armies.at_war = at_war
	winner = state.winner
	decision_timer = state.decision_timer
	ai.recruitment_timer = state.recruitment_timer
	capture_progress = state.capture_progress.duplicate(true)
	victory_type = state.get("victory_type", "")
	victory.restore(state.get("victory", {}))
	chronicle.restore(state.get("chronicle", {}))
	annexation.restore(state.get("annexation", {}))
	strategic.restore(state.get("strategic", {}))
	if state.has("doctrines"): Doctrine.restore(state.doctrines)

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
var at_war: = false
var last_day: = 1
func daily_provinces() -> void:
	var today: = 1 + int(clock.elapsed/ProductionSystem.DAY_SECONDS)
	while last_day < today:
		last_day += 1
		var seen: Dictionary = {}
		for territory in terrain.territories:
			if not territory.playable or seen.has(territory.title): continue
			seen[territory.title] = true
			var morale: = float(territory.get("morale",100.0 if territory.controller == territory.owner else 25.0))
			var garrison: = armies.units.any(func(u):return u.health>0 and u.country == territory.controller and u.visual_kind not in ["fighter","naval"] and Vector2(u.node.position.x,u.node.position.z).distance_to(territory.center)<CAPTURE_RADIUS)
			if at_war and territory.controller != territory.owner and morale < 30.0 and not garrison:
				var random: = RandomNumberGenerator.new()
				random.seed = abs((territory.id+str(last_day)).hash())
				if random.randf()<0.2:
					change_control(territory,territory.owner)
					report.emit(territory.title+" revolted · station a garrison while morale is low")
			var target: = 100.0 if territory.controller == territory.owner else 80.0
			if production != null and production.buildings != null:
				var capital: = production.buildings.capital(territory.controller)
				if not capital.is_empty() and not production.controlled(capital,territory.controller): target -= 20.0
			var next_morale: = clampf(morale+(target-morale)*0.15,0,100)
			for part in terrain.territories:
				if part.playable and part.title == territory.title: part.morale = next_morale
		for unit in armies.units:
			if unit.engaged or unit.get("flight_mode", "grounded") != "grounded": continue
			var point: = Vector2(unit.node.position.x,unit.node.position.z)
			if unit.visual_kind == "naval" or terrain.territories.any(func(t):return t.playable and t.controller == unit.country and RegionData.contains(t,point)):
				unit.health = minf(100,unit.health+(100-unit.health)*0.15)
		report.emit("Day "+str(last_day)+" · province morale and army recovery updated")
func change_control(territory: Dictionary, country: String) -> void:
	for part in terrain.territories:
		if not part.playable or part.title != territory.title: continue
		part.controller = country
		part.morale = 25.0
		capture_progress.erase(part.id)
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
	if seconds > 0: daily_provinces()
	if not winner.is_empty() or seconds <= 0 or not at_war: return
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
		change_control(territory,occupant)
		terrain.update_relations(at_war)
		capture_progress.erase(territory.id)
		report.emit(territory.title + " captured by " + occupant.capitalize())
	var score: = city_score()
	for country in ["ukraine", "russia"]:
		if score[country] >= 3:
			end_match(country)
			return
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
			end_match("russia" if country == "ukraine" else "ukraine")
			return
	if not ai_enabled: return
	decision_timer += seconds
	if decision_timer < 0.05: return
	if clock.elapsed >= 2.5: ai.decide(armies, terrain, cities, production, decision_timer)
	decision_timer = 0
func city_score() -> Dictionary:
	var score: = {"russia": 0, "ukraine": 0}
	for city in cities:
		for territory in terrain.territories:
			if territory.id == city.sector and territory.controller != city.country.to_lower(): score[territory.controller] += 1
	return score
func end_match(country: String) -> void :
	winner = country
	clock.paused = true
	clock.state_changed.emit()
	report.emit(country.capitalize() + " wins. Choose New match to play again.")
	finished.emit(country)
func snapshot() -> Dictionary:
	return {"last_day": last_day, "air_cooldowns": air_combat.snapshot(), "combat_cooldowns": combat.snapshot(), "at_war": at_war, "winner": winner, "decision_timer": decision_timer, "recruitment_timer": ai.recruitment_timer, "capture_progress": capture_progress.duplicate(true)}
func restore(state: Dictionary) -> void :
	last_day = int(state.get("last_day",1+int(clock.elapsed/ProductionSystem.DAY_SECONDS)))
	combat.restore(state.get("combat_cooldowns", {}))
	air_combat.restore(state.get("air_cooldowns", {}))
	at_war = state.get("at_war", true)
	armies.at_war = at_war
	winner = state.winner
	decision_timer = state.decision_timer
	ai.recruitment_timer = state.recruitment_timer
	capture_progress = state.capture_progress.duplicate(true)

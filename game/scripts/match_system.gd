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
## Online matches: country -> CountryAI for every seat the AI is playing (empty seats and
## players who have been away too long). Empty = the single-player opponent `ai`.
var seat_ai: Dictionary = {}
var online: = false
## Guard mode (sleep defence): country -> DefenceAI. Defends only, never attacks or spends.
var guards: Dictionary = {}
signal guard_changed(country: String, on: bool)
func set_guard(country: String, on: bool) -> void:
	if on == guards.has(country): return
	if on:
		guards[country] = DefenceAI.new()
		guards[country].country = country
	else: guards.erase(country)
	guard_changed.emit(country, on)
func guarded(country: String) -> bool: return guards.has(country)
func set_ai_countries(countries: Array) -> void:
	for country in seat_ai.keys():
		if not country in countries: seat_ai.erase(country)
	for country in countries:
		if not seat_ai.has(country):
			seat_ai[country] = CountryAI.new()
			seat_ai[country].country = country
	ai_enabled = not seat_ai.is_empty()
	diplomacy.ai_countries = countries.duplicate()
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
## Trade routes (TradeNetwork, set by main) — saved with the match.
var trade: TradeNetwork
## Relations, coalitions and messages.
var diplomacy: = Diplomacy.new()
## Entrenchment (Conflict of Nations style): an army that has stood still for ENTRENCH_TIME at
## the centre of a province its country holds digs in and defends ENTRENCH_BONUS harder.
const ENTRENCH_TIME: = VictoryRules.DAY / 12.0
const ENTRENCH_BONUS: = 1.25
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
## Keeps the campaign's war flag in step with diplomacy (an accepted peace ends the war).
func _sync_war() -> void:
	var war: = diplomacy.at_war(GameSession.player_country, GameSession.opponent_country())
	if war and not at_war: declare_war()
	elif not war and at_war: ceasefire()
func declare_war() -> void :
	if MatchClient.active != null:
		MatchClient.active.send("declare_war")
		return
	if at_war or not winner.is_empty(): return
	diplomacy.set_war(GameSession.player_country, GameSession.opponent_country(), true)
	at_war = true
	armies.at_war = true
	report.emit("WAR DECLARED · " + GameSession.opponent_country().capitalize() + " AI will defend and counterattack")
func ceasefire() -> void :
	if not at_war or not winner.is_empty(): return
	at_war = false
	diplomacy.set_war(GameSession.player_country, GameSession.opponent_country(), false)
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
	armies.diplomacy = diplomacy
	diplomacy.changed.connect(_sync_war)

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
			if not damage.has(unit.id) or damage[unit.id] <= 0.0: continue
			var factor: = production.buildings.incoming_damage_factor(unit) if production != null and production.buildings != null else 1.0
			unit.health = maxf(0, unit.health - damage.get(unit.id, 0.0) * factor)
		remaining = maxf(0, remaining - step)
func advance(seconds: float) -> void :
	if seconds > 0: daily_provinces()
	if not winner.is_empty() or seconds <= 0: return
	diplomacy.now = clock.elapsed if clock != null else diplomacy.now + seconds
	diplomacy.ai_countries = seat_ai.keys() if online else [GameSession.opponent_country()]
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
	# Capture only tests armies beside the hub, rather than every army in every province.
	var nearby: Dictionary = {}
	for unit in armies.units:
		if unit.visual_kind in ["fighter", "naval"]: continue
		var cell: = Vector2i(floori(unit.node.position.x / CAPTURE_RADIUS), floori(unit.node.position.z / CAPTURE_RADIUS))
		if not nearby.has(cell): nearby[cell] = []
		nearby[cell].append(unit)
	for territory in terrain.territories:
		if not territory.playable: continue
		var occupant: = ""
		var contested: = false
		var cell: = Vector2i(floori(territory.center.x / CAPTURE_RADIUS), floori(territory.center.y / CAPTURE_RADIUS))
		var candidates: Array = []
		for dx in range(-1,2):
			for dy in range(-1,2): candidates.append_array(nearby.get(cell + Vector2i(dx,dy), []))
		for unit in candidates:
			var point: = Vector2(unit.node.position.x, unit.node.position.z)
			if point.distance_squared_to(territory.center) > CAPTURE_RADIUS * CAPTURE_RADIUS: continue
			if not RegionData.contains(territory, point): continue
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
	if clock.elapsed >= 2.5 and MatchClient.active == null:  # online, the server runs guard mode
		for country in guards:
			var said: String = guards[country].decide(armies, cities, production, seconds)
			if not said.is_empty() and country == GameSession.player_country: report.emit(said)
	if not ai_enabled: return
	decision_timer += seconds
	if decision_timer < 0.05: return
	if clock.elapsed >= 2.5:
		if seat_ai.is_empty(): ai.decide(armies, terrain, cities, production, decision_timer)
		else:
			for country in seat_ai:
				# A guarded player who is away is defended, not sent on the attack.
				if not guards.has(country): seat_ai[country].decide(armies, terrain, cities, production, decision_timer)
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
	return {"last_day": last_day, "air_cooldowns": air_combat.snapshot(), "combat_cooldowns": combat.snapshot(), "at_war": at_war, "winner": winner, "decision_timer": decision_timer, "recruitment_timer": ai.recruitment_timer, "capture_progress": capture_progress.duplicate(true), "victory_type": victory_type, "victory": victory.snapshot(), "chronicle": chronicle.snapshot(), "annexation": annexation.snapshot(), "strategic": strategic.snapshot(), "trade": trade.snapshot() if trade != null else {}, "doctrines": Doctrine.snapshot(), "diplomacy": diplomacy.snapshot(), "guards": guards.keys()}
func restore(state: Dictionary) -> void :
	last_day = int(state.get("last_day",1+int(clock.elapsed/ProductionSystem.DAY_SECONDS)))
	combat.restore(state.get("combat_cooldowns", {}))
	air_combat.restore(state.get("air_cooldowns", {}))
	at_war = state.get("at_war", true)
	for country in guards.keys(): set_guard(country, false)
	for country in state.get("guards", []):
		if country is String and country in ["russia", "ukraine"]: set_guard(country, true)
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
	if trade != null: trade.restore(state.get("trade", {}))
	if state.has("doctrines"): Doctrine.restore(state.doctrines)
	diplomacy.restore(state.get("diplomacy", {}))
	diplomacy.relation(GameSession.player_country, GameSession.opponent_country()).war = at_war

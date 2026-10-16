class_name CountryAI
extends RefCounted
var country: = "ukraine"
var strategy: = "balanced" # optional external advisor chooses high-level policy
const CASUAL_REACTION: = 30.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
const CASUAL_MAX_ARMIES: = 10
const CASUAL_ORDERS: = 2
var difficulty: = "casual" # owner: a little below medium, same rules for API and fallback
var reaction_timer: = 0.0
var recruitment_timer: = 0.0
func decide(armies: UnitSystem, terrain: StrategicMap, cities: Array, production: ProductionSystem, seconds: float) -> void :
	recruitment_timer += seconds
	if production != null and recruitment_timer >= 20:
		recruitment_timer = 0
		var count: = 0
		for unit in armies.units:
			if unit.country == country: count += 1
		if count < (8 if strategy == "economy" else CASUAL_MAX_ARMIES if difficulty == "casual" else 16):
			for city in cities:
				if not production.controlled(city, country): continue
				var queued: = false
				for job in production.jobs:
					if job.city == city.name and production.equipment(job.equipment).country == country: queued = true
				if queued: continue
				# Build something researched; rotate through the options instead of always the first.
				var options: Array = production.catalog.filter(func(e: Dictionary): return e.country == country and production.research_lock(e).is_empty() and not e.get("requires_port", false))
				if options.is_empty():
					# Backup AI must still develop a legal army when every technology starts locked.
					if production.research != null:
						for family in production.catalog:
							if family.country != country or family.get("retired",false) or family.get("research_only",false): continue
							var next_level: int = production.research.level(family.id) + 1
							if next_level <= 5 and production.research.reason(family.id,next_level,country).is_empty():
								production.research.start(family.id,next_level,country)
								break
					break
				var choice: Dictionary = options[(count + city.name.length()) % options.size()]
				# Cities start with only a train station: build the factory first, then the unit.
				var system: BuildingSystem = production.buildings
				if system != null:
					for building_id in choice.get("building_requirements", {}):
						if system.level(city.id, building_id) < int(choice.building_requirements[building_id]):
							if not system.jobs.any(func(j: Dictionary): return j.city == city.id and j.building == building_id):
								system.schedule(city.id, building_id, country)
							choice = {}
							break
				if not choice.is_empty(): production.enqueue(choice.id, city.name)
				break
	reaction_timer += seconds
	if difficulty == "casual" and reaction_timer < CASUAL_REACTION: return
	reaction_timer = 0.0
	var issued: = 0
	for group in armies.stacks.groups():
		if difficulty == "casual" and issued >= CASUAL_ORDERS: break
		var unit: = armies.stacks.leader(group)
		if unit.country != country or unit.moving or unit.engaged: continue
		var point: = Vector2(unit.node.position.x, unit.node.position.z)
		# Keep the capital's final army at home; no perfectly timed mass evacuation.
		if difficulty == "casual" and production != null:
			var capital: Dictionary = production.buildings.capital(country) if production.buildings != null else {}
			if not capital.is_empty() and production.controlled(capital,country) and point.distance_to(capital.point) < 1.0:
				var garrison: int = armies.stacks.groups().filter(func(g): return g[0].country == country and g.any(func(u): return u.health > 0 and Vector2(u.node.position.x,u.node.position.z).distance_to(capital.point) < 1.0)).size()
				if garrison <= 1: continue
		var targets: Array = []

		for enemy in armies.units:
			if not MapDefinition.is_regional() and armies.diplomacy != null and not armies.diplomacy.at_war(country,enemy.country): continue
			var enemy_point: = Vector2(enemy.node.position.x, enemy.node.position.z)
			if enemy.health > 0 and enemy.country != country and armies.unit_visible(enemy, country) and ( not armies.is_naval(unit) or armies.is_naval(enemy)) and point.distance_to(enemy_point) < 6: targets.append(enemy_point)
		if strategy in ["economy","defensive"]:
			targets = targets.filter(func(p): return armies.navigation.controller_at(p) == country)
			if targets.is_empty(): continue
		if targets.is_empty():
			for city in cities:
				for territory in terrain.territories:
					if territory.id == city.sector and territory.controller != country and (MapDefinition.is_regional() or armies.diplomacy == null or armies.diplomacy.at_war(country,territory.controller)): targets.append(city.point)
		if targets.is_empty():
			for territory in terrain.territories:
				if territory.playable and territory.controller != country and (MapDefinition.is_regional() or armies.diplomacy == null or armies.diplomacy.at_war(country,territory.controller)): targets.append(territory.center)
		targets.sort_custom( func(a: Vector2, b: Vector2): return point.distance_squared_to(a) < point.distance_squared_to(b))
		for target in targets:
			if unit.visual_kind == "fighter":
				if armies.air.order(unit, target, "patrol").is_empty(): issued += 1; break
				continue
			var path: Array = armies.path_for(unit, point, target)
			if path.is_empty(): continue
			unit.waypoints = path
			unit.target = target
			unit.moving = true
			for member in group:
				member.target = target
				member.waypoints = path.duplicate()
				member.moving = true
			armies._update_heading(unit)
			issued += 1
			break

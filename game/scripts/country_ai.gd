class_name CountryAI
extends RefCounted
var country: = "ukraine"
var recruitment_timer: = 0.0
func decide(armies: UnitSystem, terrain: StrategicMap, cities: Array, production: ProductionSystem, seconds: float) -> void :
	recruitment_timer += seconds
	if production != null and recruitment_timer >= 20:
		recruitment_timer = 0
		var count: = 0
		for unit in armies.units:
			if unit.country == country: count += 1
		if count < 16:
			for city in cities:
				if not production.controlled(city, country): continue
				var queued: = false
				for job in production.jobs:
					if job.city == city.name and production.equipment(job.equipment).country == country: queued = true
				if queued: continue
				for equipment in production.catalog:
					if equipment.country == country:
						production.enqueue(equipment.id, city.name)
						break
				break
	for group in armies.stacks.groups():
		var unit: = armies.stacks.leader(group)
		if unit.country != country or unit.moving or unit.engaged: continue
		var point: = Vector2(unit.node.position.x, unit.node.position.z)
		var targets: Array = []

		for enemy in armies.units:
			var enemy_point: = Vector2(enemy.node.position.x, enemy.node.position.z)
			if enemy.health > 0 and enemy.country != country and armies.point_visible(enemy_point, country) and ( not armies.is_naval(unit) or armies.is_naval(enemy)) and point.distance_to(enemy_point) < 6: targets.append(enemy_point)
		if targets.is_empty():
			for city in cities:
				for territory in terrain.territories:
					if territory.id == city.sector and territory.controller != country: targets.append(city.point)
		if targets.is_empty():
			for territory in terrain.territories:
				if territory.playable and territory.controller != country: targets.append(territory.center)
		targets.sort_custom( func(a: Vector2, b: Vector2): return point.distance_squared_to(a) < point.distance_squared_to(b))
		for target in targets:
			if unit.visual_kind == "fighter":
				if armies.air.order(unit, target, "patrol").is_empty(): break
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
			break

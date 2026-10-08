class_name ProductionSystem
extends RefCounted
signal changed
signal unit_ready(spec: Dictionary)
const RESOURCES: = ["funds", "materials", "electronics", "fuel", "manpower"]
var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
var stockpiles: Dictionary = {}
var jobs: Array = []
var next_id: = 1
const PLAN_LIMIT: = 8
var rally_points: Dictionary = {}
var cities: Array
var terrain: StrategicMap
var _building_ref: WeakRef
var buildings: BuildingSystem:
	get: return _building_ref.get_ref() if _building_ref != null else null
	set(value): _building_ref = weakref(value) if value != null else null
var _research_ref: WeakRef
var research: ResearchSystem:
	get: return _research_ref.get_ref() if _research_ref != null else null
	set(value): _research_ref = weakref(value) if value != null else null
func setup(map: StrategicMap, city_data: Array, countries: Dictionary) -> void :
	terrain = map
	cities = city_data
	for id in countries:
		stockpiles[id] = {"funds": 1000.0, "materials": 400.0, "electronics": 150.0, "fuel": 250.0, "manpower": 200.0}
func equipment(id: String) -> Dictionary:
	for spec in catalog:
		if spec.id == id: return spec
	return {}
func controller(city: Dictionary) -> String:
	for territory in terrain.territories:
		if territory.id == city.sector: return territory.controller
	return ""
func controlled(city: Dictionary, country: String = "") -> bool:
	return controller(city) == (city.country.to_lower() if country.is_empty() else country)
func enqueue(equipment_id: String, city_name: String) -> String:
	var spec: = equipment(equipment_id)
	if spec.is_empty(): return "Unknown equipment"
	var city: Dictionary = {}
	for entry in cities:
		if entry.name == city_name: city = entry
	if city.is_empty() or not controlled(city, spec.country): return "Choose a controlled city for this country"
	if spec.get("requires_port", false) and not city.has("naval_spawn"): return "Naval production requires a coastal launch city (Odesa or Rostov-on-Don)"
	for building_id in spec.get("building_requirements", {}):
		if buildings == null or buildings.level(city.id, building_id) < spec.building_requirements[building_id]: return "Requires " + building_id + " level " + str(spec.building_requirements[building_id]) + " in this city"
	var count: = 0
	for job in jobs:
		if job.city == city_name: count += 1
	if count >= 5: return "City queue is full (5 orders)"
	for resource in RESOURCES:
		if stockpiles[spec.country][resource] < spec.cost[resource]: return "Insufficient " + resource
	for resource in RESOURCES: stockpiles[spec.country][resource] -= spec.cost[resource]
	jobs.append({"id": next_id, "equipment": equipment_id, "city": city_name, "progress": 0.0})
	next_id += 1
	changed.emit()
	return ""
func cancel(id: int) -> void :
	for i in jobs.size():
		if jobs[i].id != id: continue
		var spec: = equipment(jobs[i].equipment)
		if jobs[i].get("paid", true):
			for resource in RESOURCES: stockpiles[spec.country][resource] += spec.cost[resource]
		jobs.remove_at(i)
		changed.emit()
		return
func advance(seconds: float) -> void :
	if seconds <= 0: return
	var income: = {"funds": 1.0, "materials": 0.18, "electronics": 0.08, "fuel": 0.12, "manpower": 0.1}
	for city in cities:
		var country: = controller(city)
		if not stockpiles.has(country): continue
		var multiplier: = buildings.rate(city.id, "industry") if buildings != null else 1.0
		if country != city.country.to_lower(): multiplier *= 0.25
		for resource in RESOURCES: stockpiles[country][resource] += income[resource] * seconds * multiplier

	for city in cities:
		var remaining: = seconds
		while remaining > 0:
			var active: = -1
			for i in jobs.size():
				if jobs[i].city == city.name and controlled(city, equipment(jobs[i].equipment).country):
					active = i
					break
			if active < 0: break
			var job: Dictionary = jobs[active]
			var spec: = equipment(job.equipment)
			if not job.get("paid", true):
				var ready: = true
				for resource in RESOURCES:
					if stockpiles[spec.country][resource] < spec.cost[resource]: ready = false
				for building_id in spec.get("building_requirements", {}):
					if buildings == null or buildings.level(city.id, building_id) < spec.building_requirements[building_id]: ready = false
				if not ready: break
				for resource in RESOURCES: stockpiles[spec.country][resource] -= spec.cost[resource]
				job.paid = true
			var multiplier: = buildings.rate(city.id, "factory") if buildings != null else 1.0
			var step: = minf(remaining, (spec.seconds - job.progress) / multiplier)
			job.progress += step * multiplier
			remaining -= step
			if job.progress < spec.seconds - 1e-06: break
			jobs.remove_at(active)
			var spawn: Vector2 = GeographicProjection.project(city.naval_spawn.longitude, city.naval_spawn.latitude) if spec.visual_kind == "naval" else city.point + Vector2(0.8 + (int(job.id) % 3) * 0.3, 0.8)
			var completed_unit: = {"base_city": city.id, "level": research.level(spec.id) if research != null else 1, "equipment_id": spec.id, "id": "produced_" + str(int(job.id)), "name": spec.name, "country": spec.country, "visual_kind": spec.visual_kind, "point": spawn}
			if rally_points.has(city.id) and rally_points[city.id].country == spec.country: completed_unit.rally_point = rally_points[city.id].point.duplicate()
			unit_ready.emit(completed_unit)
	changed.emit()
func snapshot() -> Dictionary:
	var state: = {"stockpiles": stockpiles.duplicate(true), "jobs": jobs.duplicate(true), "next_id": next_id, "rally_points": rally_points.duplicate(true)}
	if research != null: state.research = research.snapshot()
	if buildings != null: state.buildings = buildings.snapshot()
	return state
func validate(state: Variant) -> bool:
	if not state is Dictionary or not state.get("stockpiles") is Dictionary or not state.get("jobs") is Array: return false
	if research != null and state.has("research") and not research.validate(state.research): return false
	if buildings != null and state.has("buildings") and not buildings.validate(state.buildings): return false
	if not (state.get("next_id") is float or state.get("next_id") is int) or not is_finite(float(state.next_id)) or state.next_id < 1 or state.next_id != floor(state.next_id): return false
	if state.stockpiles.size() != stockpiles.size() or state.jobs.size() > cities.size() * PLAN_LIMIT: return false
	for country in stockpiles:
		if not state.stockpiles.get(country) is Dictionary: return false
		for resource in RESOURCES:
			var value = state.stockpiles[country].get(resource)
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 1000000000000.0: return false
	if not state.get("rally_points", {}) is Dictionary or state.get("rally_points", {}).size() > cities.size(): return false
	for id in state.get("rally_points", {}):
		var found: = false
		for place in cities:
			if place.id == id: found = true
		var rally = state.rally_points[id]
		if not found or not rally is Dictionary or rally.get("country") not in stockpiles: return false
		var point = rally.get("point")
		if not point is Array or point.size() != 2: return false
		for value in point:
			if not (value is float or value is int) or not is_finite(float(value)) or absf(value) > 60: return false
	var ids: Dictionary = {}
	var counts: Dictionary = {}
	for job in state.jobs:
		if not job is Dictionary or not (job.get("id") is float or job.get("id") is int) or job.id < 1 or job.id >= state.next_id or job.id != floor(job.id) or ids.has(job.id): return false
		ids[job.id] = true
		var spec: = equipment(str(job.get("equipment", "")))
		if spec.is_empty(): return false
		var found: = false
		for city in cities:
			if city.name == job.get("city") and ( not spec.get("requires_port", false) or city.has("naval_spawn")): found = true
		if not found: return false
		counts[job.city] = counts.get(job.city, 0) + 1
		if counts[job.city] > PLAN_LIMIT: return false
		if not job.get("paid", true) is bool or ( not job.get("paid", true) and job.get("progress") != 0): return false
		var progress = job.get("progress")
		if not (progress is float or progress is int) or not is_finite(float(progress)) or progress < 0 or progress >= spec.seconds: return false
	return true
func restore(state: Dictionary) -> void :
	rally_points = state.get("rally_points", {}).duplicate(true)
	stockpiles = state.stockpiles.duplicate(true)
	jobs = state.jobs.duplicate(true)
	next_id = int(state.next_id)
	if buildings != null: buildings.restore(state.get("buildings", {}))
	if research != null: research.restore(state.get("research", {}))
	changed.emit()

func schedule(equipment_id: String, city_name: String) -> String:
	var spec: = equipment(equipment_id)
	if spec.is_empty(): return "Choose equipment"
	var place: Dictionary = {}
	for entry in cities:
		if entry.name == city_name: place = entry
	if place.is_empty() or not controlled(place, spec.country): return "Choose a controlled city"
	if spec.get("requires_port", false) and not place.has("naval_spawn"): return "Ships require a coastal city"
	if jobs.filter( func(job: Dictionary): return job.city == city_name).size() >= PLAN_LIMIT: return "City plan is full (8 orders)"
	jobs.append({"id": next_id, "equipment": equipment_id, "city": city_name, "progress": 0.0, "paid": false})
	next_id += 1
	changed.emit()
	return ""
func reorder(id: int, direction: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var index: = -1
	for i in jobs.size():
		if jobs[i].id == id: index = i;break
	if index < 0 or direction not in [-1, 1]: return "Select an order"
	var job: Dictionary = jobs[index]
	if equipment(job.equipment).country != country: return "This order belongs to another country"
	var peers: Array[int] = []
	for i in jobs.size():
		if jobs[i].city == job.city and equipment(jobs[i].equipment).country == country: peers.append(i)
	var row: = peers.find(index)
	var target: = row + direction
	if target < 0 or target >= peers.size(): return "Already at the end of the queue"
	var other: Dictionary = jobs[peers[target]]
	if (row == 0 and job.get("paid", true)) or (target == 0 and other.get("paid", true)) or job.progress > 0 or other.progress > 0: return "Active production cannot be reordered"
	jobs[index] = other
	jobs[peers[target]] = job
	changed.emit()
	return ""
func set_rally(city_id: String, point: Vector2, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	if not point.is_finite() or absf(point.x) > 60 or absf(point.y) > 60: return "Invalid rally location"
	var place: Dictionary = {}
	for entry in cities:
		if entry.id == city_id: place = entry
	if place.is_empty() or not controlled(place, country): return "Choose a controlled city"
	rally_points[city_id] = {"country": country, "point": [point.x, point.y]}
	changed.emit()
	return ""
func clear_rally(city_id: String, country: String = "") -> void :
	if country.is_empty(): country = GameSession.player_country
	if rally_points.has(city_id) and rally_points[city_id].country == country: rally_points.erase(city_id);changed.emit()

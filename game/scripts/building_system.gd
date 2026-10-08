class_name BuildingSystem
extends RefCounted
signal changed
signal completed(city_id: String, building_id: String)
const QUEUE_LIMIT: = 8
var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
var economy: ProductionSystem
var capitals: Dictionary = {}
var levels: Dictionary = {}
var jobs: Array = []
var next_id: = 1

func setup(production: ProductionSystem, countries: Dictionary) -> void :
	economy = production
	for country in countries: capitals[country] = countries[country].get("capital_city", "")
	_reset_levels()
func _reset_levels() -> void :
	levels.clear()
	for city in economy.cities:
		levels[city.id] = {}
		for definition in catalog: levels[city.id][definition.id] = initial_level(city, definition)
func initial_level(place: Dictionary, definition: Dictionary) -> int:
	if definition.capital_only and not is_capital(place): return 0
	return int(definition.get("capital_starting_level", definition.get("starting_level", 1))) if is_capital(place) else int(definition.get("starting_level", 1))
func city(id: String) -> Dictionary:
	for entry in economy.cities:
		if entry.id == id: return entry
	return {}
func capital(country: String) -> Dictionary:
	return city(capitals.get(country, ""))
func is_capital(place: Dictionary) -> bool:
	return place.id == capitals.get(place.country.to_lower(), "")
func spec(id: String) -> Dictionary:
	for entry in catalog:
		if entry.id == id: return entry
	return {}
func level(city_id: String, building_id: String) -> int:
	return int(levels.get(city_id, {}).get(building_id, 0))
func rate(city_id: String, building_id: String) -> float:
	return 1.0 + 0.25 * maxi(0, level(city_id, building_id) - 1)
func research_rate(country: String) -> float:
	var place: = capital(country)
	if place.is_empty() or not economy.controlled(place) or level(place.id, "research_center") < 1: return 0.0
	return rate(place.id, "research_center")
func cost(building_id: String, target: int) -> Dictionary:
	var bill: Dictionary = {}
	var definition: = spec(building_id)
	if definition.is_empty(): return bill
	for resource in ProductionSystem.RESOURCES: bill[resource] = ceili(definition.cost[resource] * (1.0 + 0.5 * maxi(0, target - 2)))
	return bill
func duration(building_id: String, target: int) -> float:
	return spec(building_id).hours * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND * maxi(1, target - 1)
func reason(city_id: String, building_id: String, country: String = "", check_resources: bool = true) -> String:
	if country.is_empty(): country = GameSession.player_country
	var place: = city(city_id)
	var definition: = spec(building_id)
	if place.is_empty() or definition.is_empty(): return "Choose a city and building"
	if not economy.controlled(place, country): return "Recover control of this city first"
	if definition.capital_only and place.id != capitals.get(country, ""): return "Research centers are built in your capital"
	var target: = level(city_id, building_id) + 1
	if target > definition.max_level: return "Maximum level reached"
	var count: = 0
	for job in jobs:
		if job.city != city_id: continue
		count += 1
		if job.building == building_id: return "This building already has a construction order"
	if count >= QUEUE_LIMIT: return "City construction queue is full"
	for resource in ProductionSystem.RESOURCES:
		if check_resources and economy.stockpiles[country][resource] < cost(building_id, target)[resource]: return "Insufficient " + resource
	return ""
func enqueue(city_id: String, building_id: String, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var error: = reason(city_id, building_id, country)
	if not error.is_empty(): return error
	var target: = level(city_id, building_id) + 1
	var bill: = cost(building_id, target)
	for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] -= bill[resource]
	jobs.append({"id": next_id, "city": city_id, "building": building_id, "level": target, "progress": 0.0, "country": country})
	next_id += 1
	economy.changed.emit()
	changed.emit()
	return ""
func cancel(id: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	for i in jobs.size():
		var job: Dictionary = jobs[i]
		if job.id != id: continue
		if job.get("country", city(job.city).country.to_lower()) != country: return "This order belongs to another country"
		var remaining: float = 1.0 - job.progress / duration(job.building, job.level)
		var bill: = cost(job.building, job.level)
		if job.get("paid", true):
			for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] += floor(bill[resource] * remaining)
		jobs.remove_at(i)
		economy.changed.emit()
		changed.emit()
		return "Construction cancelled; unused resources refunded"
	return "This construction order is no longer queued"
func advance(seconds: float) -> void :
	if seconds <= 0: return
	for place in economy.cities:
		var remaining: = seconds
		while remaining > 0:
			var index: = -1
			for i in jobs.size():
				if jobs[i].city == place.id and economy.controlled(place, jobs[i].get("country", place.country.to_lower())):
					index = i
					break
			if index < 0: break
			var job: Dictionary = jobs[index]
			if not job.get("paid", true):
				var bill: = cost(job.building, job.level)
				var country: String = job.get("country", place.country.to_lower())
				var ready: = true
				for resource in ProductionSystem.RESOURCES:
					if economy.stockpiles[country][resource] < bill[resource]: ready = false
				if not ready: break
				for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] -= bill[resource]
				job.paid = true
			var total: = duration(job.building, job.level)
			var step: = minf(remaining, total - job.progress)
			job.progress += step
			remaining -= step
			if job.progress < total: break
			levels[place.id][job.building] = int(job.level)
			jobs.remove_at(index)
			completed.emit(place.id, job.building)
			changed.emit()
func snapshot() -> Dictionary:
	return {"levels": levels.duplicate(true), "jobs": jobs.duplicate(true), "next_id": next_id}
func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high
func validate(state: Variant) -> bool:
	if not state is Dictionary or not state.get("levels") is Dictionary or not state.get("jobs") is Array or not _integer(state.get("next_id"), 1, 1000000000): return false
	if state.levels.size() != economy.cities.size() or state.jobs.size() > economy.cities.size() * QUEUE_LIMIT: return false
	for place in economy.cities:
		var saved = state.levels.get(place.id)
		if not saved is Dictionary or saved.size() > catalog.size(): return false
		for key in saved:
			if spec(key).is_empty(): return false
		for definition in catalog:
			var value = saved.get(definition.id, initial_level(place, definition) if definition.id == "airbase" else null)
			if not _integer(value, initial_level(place, definition), definition.max_level): return false
			if definition.capital_only and not is_capital(place) and value != 0: return false
	var ids: Dictionary = {}
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for job in state.jobs:
		if not job is Dictionary or not _integer(job.get("id"), 1, int(state.next_id) - 1) or ids.has(job.id): return false
		ids[job.id] = true
		if not job.get("city") is String or not job.get("building") is String: return false
		var place: = city(job.city)
		var definition: = spec(job.building)
		if place.is_empty() or definition.is_empty() or (definition.capital_only and not is_capital(place)): return false
		if job.get("country", place.country.to_lower()) not in economy.stockpiles: return false
		if not _integer(job.get("level"), 1, definition.max_level) or job.level != state.levels[place.id].get(definition.id, initial_level(place, definition)) + 1: return false
		var key: String = job.city + ":" + job.building
		if seen.has(key): return false
		seen[key] = true
		counts[job.city] = counts.get(job.city, 0) + 1
		if counts[job.city] > QUEUE_LIMIT: return false
		if not job.get("paid", true) is bool or ( not job.get("paid", true) and job.get("progress") != 0): return false
		var progress = job.get("progress")
		if not (progress is float or progress is int) or not is_finite(float(progress)) or progress < 0 or progress >= duration(job.building, int(job.level)): return false
	return true
func restore(state: Dictionary) -> void :
	if state.is_empty():
		_reset_levels()
		jobs.clear()
		next_id = 1
	else:
		_reset_levels()
		for place in economy.cities:
			for id in state.levels[place.id]: levels[place.id][id] = int(state.levels[place.id][id])
		jobs = state.jobs.duplicate(true)
		next_id = int(state.next_id)
	changed.emit()

func schedule(city_id: String, building_id: String, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var error: = reason(city_id, building_id, country, false)
	if not error.is_empty(): return error
	jobs.append({"id": next_id, "city": city_id, "building": building_id, "level": level(city_id, building_id) + 1, "progress": 0.0, "country": country, "paid": false})
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
	if job.get("country", city(job.city).country.to_lower()) != country: return "This order belongs to another country"
	var peers: Array[int] = []
	for i in jobs.size():
		if jobs[i].city == job.city and jobs[i].get("country", city(job.city).country.to_lower()) == country: peers.append(i)
	var row: = peers.find(index)
	var target: = row + direction
	if target < 0 or target >= peers.size(): return "Already at the end of the queue"
	var other: Dictionary = jobs[peers[target]]
	if (row == 0 and job.get("paid", true)) or (target == 0 and other.get("paid", true)) or job.progress > 0 or other.progress > 0: return "Active construction cannot be reordered"
	jobs[index] = other
	jobs[peers[target]] = job
	changed.emit()
	return ""

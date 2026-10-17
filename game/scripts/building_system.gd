class_name BuildingSystem
extends RefCounted
signal changed
signal completed(city_id: String, building_id: String)
## Owner 2026-10-13 (later): one building at a time per city - finish it before the next.
## Owner 2026-10-15 ("is there a spot you can queue the units and buildings?"): a city builds one
## thing at a time and up to five wait in line; each is paid when it starts.
const QUEUE_LIMIT: = 5
var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
var economy: ProductionSystem
var capitals: Dictionary = {}
var levels: Dictionary = {}
var jobs: Array = []
var next_id: = 1
var provinces: = ProvinceConstruction.new()

func setup(production: ProductionSystem, countries: Dictionary) -> void :
	economy = production
	for country in countries: capitals[country] = countries[country].get("capital_city", "")
	_reset_levels()
	provinces.setup(self)
func _reset_levels() -> void :
	levels.clear()
	for city in economy.cities:
		levels[city.id] = {}
		for definition in catalog: levels[city.id][definition.id] = initial_level(city, definition)
func initial_level(place: Dictionary, definition: Dictionary) -> int:
	if definition.capital_only and not is_capital(place): return 0
	if definition.get("coastal_only", false) and not place.has("naval_spawn"): return 0
	return int(definition.get("capital_starting_level", definition.get("starting_level", 1))) if is_capital(place) else int(definition.get("starting_level", 1))
func city(id: String) -> Dictionary:
	for entry in economy.cities:
		if entry.id == id: return entry
	return provinces.place(id)
func capital(country: String) -> Dictionary:
	return city(capitals.get(country, ""))
func is_capital(place: Dictionary) -> bool:
	return place.id in capitals.values()
func spec(id: String) -> Dictionary:
	for entry in catalog:
		if entry.id == id: return entry
	return {}
func level(city_id: String, building_id: String) -> int:
	if city_id.begins_with("province:"): return provinces.level(city_id,building_id)
	return int(levels.get(city_id, {}).get(building_id, 0))
func rate(city_id: String, building_id: String) -> float:
	if building_id == "industry": return 1.0 + 0.25 * level(city_id, building_id)
	return 1.0 + 0.25 * maxi(0, level(city_id, building_id) - 1)
func research_rate(country: String) -> float:
	var place: = capital(country)
	if place.is_empty() or not economy.controlled(place) or level(place.id, "research_center") < 1: return 0.0
	return rate(place.id, "research_center")
func cost(building_id: String, target: int) -> Dictionary:
	var bill: Dictionary = {}
	var definition: = spec(building_id)
	if definition.is_empty(): return bill
	for resource in ProductionSystem.RESOURCES: bill[resource] = ceili(float(definition.cost.get(resource, 0.0)) * (1.0 + 0.5 * maxi(0, target - 1)))
	return bill
## Owner 2026-10-15: construction times were too short. Honour actual data hours,
## and grow each level by 1.5; the city/province's live construction rate applies once.
## Owner 2026-10-16: "Make all factories 30 minutes at one time speed for level one, and then make
## them harder after that." Every building's level 1 is 30 real minutes at 1x (data "minutes");
## each further level takes twice as long (1 h, 2 h, 4 h, 8 h).
const LEVEL_GROWTH: = 2.0
const LEVEL_ONE_MINUTES: = 30.0
static func level_one_minutes(building: Dictionary) -> float:
	return float(building.minutes) if building.has("minutes") else float(building.get("hours", LEVEL_ONE_MINUTES / 60.0)) * 60.0
func duration(building_id: String, target: int) -> float:
	var minutes: float = level_one_minutes(spec(building_id)) * pow(LEVEL_GROWTH, maxi(0, target - 1))
	return minutes * 60.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func previous_cost(building_id: String, target: int) -> Dictionary:
	var definition: = spec(building_id)
	var source: Dictionary = definition.get("previous_cost", definition.get("cost", {}))
	var bill: Dictionary = {}
	for resource in ProductionSystem.RESOURCES: bill[resource] = ceili(float(source.get(resource, 0.0)) * (1.0 + 0.5 * maxi(0, target - 2)))
	return bill
func paid_cost(job: Dictionary) -> Dictionary:
	var source: Dictionary = job.get("paid_cost", previous_cost(str(job.building), int(job.level)))
	var bill: Dictionary = {}
	for resource in ProductionSystem.RESOURCES: bill[resource] = source.get(resource, 0.0)
	return bill
func reason(city_id: String, building_id: String, country: String = "", check_resources: bool = true) -> String:
	if city_id.begins_with("province:"): return provinces.reason(city_id,building_id,country,check_resources)
	if country.is_empty(): country = GameSession.player_country
	var place: = city(city_id)
	var definition: = spec(building_id)
	if place.is_empty() or definition.is_empty(): return "Choose a city and building"
	if definition.get("retired",false): return "This building has been retired"
	if building_id == "capitol" and capitals.get(country,"") == city_id: return "This is already your capital"
	if not economy.controlled(place, country): return "Recover control of this city first"
	if definition.capital_only and place.id != capitals.get(country, ""): return "Research centers are built in your capital"
	if definition.get("coastal_only", false) and not place.has("naval_spawn"): return "Naval bases require a coastal city"
	var target: = level(city_id, building_id) + 1
	if target > definition.max_level: return "Maximum level reached"
	var count: = 0
	for job in jobs:
		if job.city != city_id: continue
		count += 1
		if job.building == building_id: return "This building already has a construction order"
	if count >= QUEUE_LIMIT: return "The construction queue is full (5)"
	for resource in ProductionSystem.RESOURCES:
		if check_resources and economy.stockpiles[country][resource] < cost(building_id, target)[resource]: return "Insufficient " + resource
	return ""
func enqueue(city_id: String, building_id: String, country: String = "") -> String:
	if MatchClient.active != null: return MatchClient.active.send("build", {"city": city_id, "building": building_id})
	if city_id.begins_with("province:"): return provinces.enqueue(city_id,building_id,country)
	if country.is_empty(): country = GameSession.player_country
	var error: = reason(city_id, building_id, country)
	if not error.is_empty(): return error
	var target: = level(city_id, building_id) + 1
	var bill: = cost(building_id, target)
	for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] -= bill[resource]
	jobs.append({"id": next_id, "city": city_id, "building": building_id, "level": target, "progress": 0.0, "country": country, "paid_cost": bill})
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
		var bill: = paid_cost(job)
		if job.get("paid", true):
			for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] += floor(bill[resource] * remaining)
		jobs.remove_at(i)
		economy.changed.emit()
		changed.emit()
		return "Construction cancelled; unused resources refunded"
	return "This construction order is no longer queued"
func advance(seconds: float) -> void :
	if seconds <= 0: return
	provinces.advance(seconds)
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
				job.paid_cost = bill
				job.paid = true
			var total: = duration(job.building, job.level)
			var speed: = construction_rate(place.id)
			var step: = minf(remaining, (total - job.progress) / speed)
			job.progress += step * speed
			remaining -= step
			if job.progress < total: break
			levels[place.id][job.building] = int(job.level)
			jobs.remove_at(index)
			if job.building == "capitol":
				capitals[job.get("country",place.country.to_lower())] = place.id
				for other in economy.cities:
					if economy.controlled(other,job.get("country",place.country.to_lower())): other.capital = other.id == place.id
			completed.emit(place.id, job.building)
			changed.emit()
func snapshot() -> Dictionary:
	return {"levels": levels.duplicate(true), "jobs": jobs.duplicate(true), "next_id": next_id, "capitals":capitals.duplicate(), "provinces":provinces.snapshot()}
func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high
func validate(state: Variant) -> bool:
	if not state is Dictionary or not state.get("levels") is Dictionary or not state.get("jobs") is Array or not _integer(state.get("next_id"), 1, 1000000000): return false
	if not provinces.validate(state.get("provinces",{})): return false
	var saved_capitals = state.get("capitals",capitals)
	if not saved_capitals is Dictionary: return false
	for country in saved_capitals:
		if country not in economy.stockpiles or city(str(saved_capitals[country])).is_empty(): return false
	if state.levels.size() != economy.cities.size() or state.jobs.size() > economy.cities.size() * 8: return false  # older saves queued up to eight
	for place in economy.cities:
		var saved = state.levels.get(place.id)
		if not saved is Dictionary or saved.size() > catalog.size(): return false
		for key in saved:
			if spec(key).is_empty(): return false
		for definition in catalog:
			var value = saved.get(definition.id, initial_level(place, definition) if definition.id == "airbase" or definition.get("save_default", false) else null)
			if not _integer(value, 0, definition.max_level): return false
			if definition.capital_only and not definition.get("retired",false) and not is_capital(place) and value != 0: return false
			if definition.get("coastal_only", false) and not place.has("naval_spawn") and value != 0: return false
	var ids: Dictionary = {}
	var counts: Dictionary = {}
	var seen: Dictionary = {}
	for job in state.jobs:
		if not job is Dictionary or not _integer(job.get("id"), 1, int(state.next_id) - 1) or ids.has(job.id): return false
		ids[job.id] = true
		if not job.get("city") is String or not job.get("building") is String: return false
		var place: = city(job.city)
		var definition: = spec(job.building)
		if place.is_empty() or place.get("rural",false) or definition.is_empty() or (definition.capital_only and not is_capital(place)): return false
		if definition.get("coastal_only", false) and not place.has("naval_spawn"): return false
		if job.get("country", place.country.to_lower()) not in economy.stockpiles: return false
		if not _integer(job.get("level"), 1, definition.max_level) or job.level != state.levels[place.id].get(definition.id, initial_level(place, definition)) + 1: return false
		var key: String = job.city + ":" + job.building
		if seen.has(key): return false
		seen[key] = true
		counts[job.city] = counts.get(job.city, 0) + 1
		if counts[job.city] > 8: return false  # older saves queued up to eight
		if not job.get("paid", true) is bool or ( not job.get("paid", true) and job.get("progress") != 0): return false
		if job.has("paid_cost") and not EquipmentEconomy.valid_paid_cost(job.paid_cost): return false
		var progress = job.get("progress")
		if not (progress is float or progress is int) or not is_finite(float(progress)) or progress < 0 or progress >= duration(job.building, int(job.level)): return false
	return true
func restore(state: Dictionary) -> void :
	capitals = state.get("capitals",capitals).duplicate()
	for place in economy.cities: place.capital = place.id in capitals.values()
	provinces.restore(state.get("provinces",{}))
	if state.is_empty():
		_reset_levels()
		jobs.clear()
		next_id = 1
	else:
		_reset_levels()
		for place in economy.cities:
			for id in state.levels[place.id]: levels[place.id][id] = int(state.levels[place.id][id])
		jobs = state.jobs.duplicate(true)
		for job in jobs:
			if job.get("paid", true) and not job.has("paid_cost"): job.paid_cost = previous_cost(str(job.building), int(job.level))
		next_id = int(state.next_id)
	changed.emit()

func schedule(city_id: String, building_id: String, country: String = "") -> String:
	if MatchClient.active != null: return MatchClient.active.send("build_queue", {"city":city_id,"building":building_id})
	if city_id.begins_with("province:"): return provinces.schedule(city_id,building_id,country)
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

# Public effect helpers for the city screen: use these for income, production and ETAs.
func resource_rate(city_id: String, resource: String) -> float:
	for definition in catalog:
		if definition.get("resource", "") == resource: return 1.0 + 0.25 * level(city_id, definition.id)
	return 1.0
func production_rate(city_id: String, equipment: Dictionary) -> float:
	if not equipment.has("production_building"):
		var old_special: String = {"Armor":"tank_plant","Mechanized":"barracks","Infantry":"barracks","Navy":"naval_base"}.get(equipment.get("category",""),"")
		return rate(city_id,"factory")*(1.0+0.25*level(city_id,old_special))*morale_speed(city_id)
	var special: String = ProductionGroups.building(equipment)
	return rate(city_id, special) * morale_speed(city_id) * CountryTraits.build_factor(str(equipment.get("country", "")))
func morale_speed(city_id: String) -> float:
	# An enemy saboteur in the city halves its building and production speed.
	return clampf(economy.morale_factor(city(city_id))/0.8,0.25,1.0) * Espionage.sabotage_factor(city_id)
func construction_rate(city_id: String) -> float:
	var owner: String = economy.controller(city(city_id))
	return (1.0 + 0.15 * level(city_id, "infrastructure")) * morale_speed(city_id) * EconomyResearch.factor(owner,"infrastructure") * CountryTraits.build_factor(owner)
func construction_time(city_id: String, building_id: String, target: int, progress: float = 0.0) -> float:
	return maxf(0, duration(building_id, target) - progress) / construction_rate(city_id)
func incoming_damage_factor(unit: Dictionary) -> float:
	if unit.get("visual_kind", "") in ["fighter", "drone", "naval"]: return 1.0
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	var protection: = provinces.protection(unit)
	for place in economy.cities:
		if economy.controlled(place, unit.country) and point.distance_to(place.point) <= 0.6:
			protection = maxf(protection, 0.2 * level(place.id, "bunker"))
	return 1.0 - minf(0.6, protection)

## Gold to finish the construction running in a city now (its first job), or 0 if none.
func speedup_price(city_id: String) -> int:
	return int(gold_quote(city_id).total)
func gold_quote(city_id: String) -> Dictionary:
	for job in jobs:
		if job.city != city_id: continue
		var country: String = job.get("country", economy.controller(city(city_id)))
		var bill: = cost(job.building, job.level) if not job.get("paid", true) else {}
		return GoldWallet.quote((duration(job.building, job.level) - float(job.progress)) / maxf(construction_rate(city_id), 0.001), bill, economy.stockpiles.get(country, {}))
	return GoldWallet.quote(0)

## Finishes the construction running in a city now, for gold.
func finish_now(city_id: String, country: String, max_gold: int = -1, expected_job: int = -1) -> String:
	if MatchClient.active != null: return MatchClient.active.send("gold_building", {"city":city_id,"max_gold":speedup_price(city_id) if max_gold < 0 else max_gold,"job":expected_job})
	for job in jobs:
		if job.city != city_id: continue
		if expected_job >= 0 and int(job.id) != expected_job: return "The order changed; review it again"
		if job.get("country", country) != country: return "Not your construction"
		if not economy.controlled(city(city_id), country): return "Recover control of this city first"
		var bill: = cost(job.building, job.level)
		var error: = economy.pay_gold_quote(country, gold_quote(city_id), max_gold)
		if not error.is_empty(): return error
		if not job.get("paid", true):
			GoldWallet.consume_available(economy.stockpiles[country], bill)
			job.paid_cost = bill
			job.paid = true
		job.progress = duration(job.building, job.level)
		advance(0.000001)
		return ""
	return "Nothing is being built here"

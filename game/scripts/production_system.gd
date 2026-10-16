class_name ProductionSystem
extends RefCounted
signal changed
signal unit_ready(spec: Dictionary)
## Call of War order: money, manpower, food, metal, oil, rare earths. Food added 2026-10-13.
const RESOURCES: = ["funds", "manpower", "food", "materials", "fuel", "electronics"]
var catalog: Array = EquipmentIdentity.catalog  # one shared catalogue
var stockpiles: Dictionary = {}
## Gross income earned so far per country and resource (economic victory, newspaper).
var earned: Dictionary = {}
## Occupied land produces less until annexed (MatchSystem.annexation, set by main).
var annexation: Annexation
## Nuclear fallout cuts output (MatchSystem.strategic, set by main).
var strategic: StrategicWeapons
var jobs: Array = []
var next_id: = 1
## Owner 2026-10-13 (later): one unit at a time per city.
const PLAN_LIMIT: = 5  # owner 2026-10-15: queue up to five units per city, built one after another
const SAVED_PLAN_LIMIT: = 8  # older saves may still hold up to eight orders
var rally_points: Dictionary = {}
var cities: Array
var terrain: StrategicMap
var armies: UnitSystem
## Owner 2026-10-13: resources come from the seven cities per country (one specialty each);
## money from city industry, provinces and trade; manpower from recruitment centres. The whole
## economy was scaled up (income x10, starting stock x30, unit costs x12) to Call of War sizes.
## Owner 2026-10-16 ("it needs balanced ... how many can you buy?"; "the city only produces what it
## has"): each city produces money and only its own speciality. Money was about 85,000 a day, far ahead
## of what units cost against the other resources; it is now about 19,000 a day.
## Owner 2026-10-16 (later): "Every city produces money and manpower and the resource it has ... it's
## all shared": every city also recruits base manpower; recruitment centres add more on top. All of it
## goes into the one national stockpile.
const CITY_BASE: = {"funds": 3.0, "materials": 2.4, "electronics": 1.6, "fuel": 1.4, "manpower": 1.5, "food": 2.0}
## Manpower per recruitment-centre level, as a multiple of CITY_BASE.manpower.
const RECRUITMENT_PER_LEVEL: = 4.0
## Money per elapsed unit from each held province without a city.
const PROVINCE_FUNDS: = 0.25
## Owner 2026-10-14: "give yourself more money" and "more starting resources" (every country).
const START_STOCK: = {"funds": 60000.0, "manpower": 12000.0, "food": 15000.0, "materials": 20000.0, "fuel": 12000.0, "electronics": 8000.0}
const DAY_SECONDS: = 86400.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
var shortage_resources: Dictionary = {}
## Gold per country for this match only (GoldWallet.START at the start).
var gold: Dictionary = {}
## Territory by id, cached (performance 2026-10-13: these lookups ran for every city every tick).
var _territory_by_id: Dictionary = {}
func _territory(id: String) -> Dictionary:
	if _territory_by_id.size() != terrain.territories.size():
		_territory_by_id.clear()
		for territory in terrain.territories: _territory_by_id[territory.id] = territory
	return _territory_by_id.get(id, {})
func province(city: Dictionary) -> Dictionary:
	return _territory(str(city.get("sector", "")))
func morale_factor(city: Dictionary) -> float:
	var region: = province(city)
	return float(region.get("morale",100.0 if controller(city) == city.country.to_lower() else 25.0))/100.0
func city_income(city: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var multiplier: = buildings.rate(city.id,"industry") if buildings != null else 1.0
	if controller(city) != city.country.to_lower(): multiplier *= annexation.output(city.get("sector",""),city.country.to_lower(),controller(city)) if annexation != null else 0.25
	if strategic != null: multiplier *= strategic.output(city.get("sector",""))
	multiplier *= morale_factor(city) * EconomyResearch.factor(controller(city),"industry")
	var specialties: = ResourceSites.city_resources(city.name)
	for resource in RESOURCES:
		var facility: = buildings.resource_rate(city.id,resource) if buildings != null and resource != "manpower" else 1.0
		if resource == "manpower":
			# Every city recruits some manpower; each recruitment-centre level adds more.
			var centre: = buildings.level(city.id,"recruitment_center") if buildings != null else 1
			result[resource] = CITY_BASE.manpower * (1.0 + RECRUITMENT_PER_LEVEL * centre) * multiplier * EconomyResearch.factor(controller(city),"recruitment_center") * CountryTraits.manpower_factor(controller(city))
			continue
		result[resource] = CITY_BASE[resource] * multiplier * facility * (1.0 if resource == "funds" else 1.5 if resource in specialties else 0.0)
	return result
func gross_income() -> Dictionary:
	var result: Dictionary = {}
	for country in stockpiles:
		result[country] = {}
		for resource in RESOURCES: result[country][resource] = 0.0
	for city in cities:
		var country: = controller(city)
		if not result.has(country): continue
		var income: = city_income(city)
		for resource in RESOURCES: result[country][resource] += income[resource]
	# Provinces pay money only (owner 2026-10-13: "money is created in industries, provinces
	# and by trade"); their resources were moved to the cities.
	var counted: Dictionary = {}
	for city in cities: counted[province(city).get("title","")] = true
	for region in terrain.territories:
		if not region.playable or counted.has(region.title): continue
		counted[region.title] = true
		if not result.has(region.controller): continue
		result[region.controller].funds += province_income({"region": region}).funds
	return result
## Provinces pay money only; all other resources come from cities.
func province_income(place: Dictionary) -> Dictionary:
	var result: = {}
	for resource in RESOURCES: result[resource] = 0.0
	var region: Dictionary = place.region
	var owner_factor: float = (1.0 if region.controller == region.owner else 0.25) if annexation == null else annexation.output(region.id, region.owner, region.controller)
	result.funds = PROVINCE_FUNDS * owner_factor * float(region.get("morale", 100.0 if region.controller == region.owner else 25.0)) / 100.0
	if strategic != null: result.funds *= strategic.output(region.id)
	return result
func upkeep() -> Dictionary:
	var result: Dictionary = {}
	for country in stockpiles:
		result[country] = {}
		for resource in RESOURCES: result[country][resource] = 0.0
	if armies == null or GameSession.weapons_test: return result
	for unit in armies.units:
		if unit.health <= 0 or not result.has(unit.country): continue
		var spec: = equipment(unit.equipment_id)
		if spec.is_empty(): continue
		var maintenance: = EquipmentEconomy.upkeep(spec, int(unit.get("level", 1)))
		for resource in RESOURCES: result[unit.country][resource] += float(maintenance[resource])/DAY_SECONDS
	return result
func net_income(gross: Dictionary = {}) -> Dictionary:
	var result: = gross.duplicate(true) if not gross.is_empty() else gross_income()
	var maintenance: = upkeep()
	for country in result:
		for resource in RESOURCES: result[country][resource] -= maintenance[country][resource]
	return result
## Resource sites in the provinces (oil fields, mines, plants, farmland); optional.
var resource_sites: ResourceSites
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
		stockpiles[id] = START_STOCK.duplicate()
		gold[id] = GoldWallet.START
func equipment(id: String) -> Dictionary:
	if id.begins_with("economy_"): return EconomyResearch.spec(id)
	for spec in catalog:
		if spec.id == id: return spec
	return {}
func production_level(id: String) -> int:
	return clampi(research.level(id), 1, 5) if research != null else 1
func cost(id: String, target: int = 0) -> Dictionary:
	return EquipmentEconomy.cost(equipment(id), production_level(id) if target == 0 else target)
func duration(id: String, target: int = 0) -> float:
	return EquipmentEconomy.duration(equipment(id), production_level(id) if target == 0 else target)
func job_level(job: Dictionary) -> int:
	return int(job.get("level", production_level(str(job.equipment))))
func job_duration(job: Dictionary) -> float:
	return duration(str(job.equipment), job_level(job))
func _pay_job(job: Dictionary) -> void:
	job.level = job_level(job)
	job.paid_cost = cost(str(job.equipment), int(job.level))
	var country: String = equipment(str(job.equipment)).country
	for resource in RESOURCES: stockpiles[country][resource] -= float(job.paid_cost.get(resource, 0.0))
	job.paid = true
func controller(city: Dictionary) -> String:
	return str(_territory(str(city.get("sector", ""))).get("controller", ""))
func controlled(city: Dictionary, country: String = "") -> bool:
	return controller(city) == (city.country.to_lower() if country.is_empty() else country)
func enqueue(equipment_id: String, city_name: String) -> String:
	if MatchClient.active != null: return MatchClient.active.send("produce", {"equipment": equipment_id, "city": city_name})
	var spec: = equipment(equipment_id)
	if spec.is_empty(): return "Unknown equipment"
	var locked: = research_lock(spec)
	if not locked.is_empty(): return locked
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
	if count >= PLAN_LIMIT: return "The production queue is full (5)"
	var bill: = cost(equipment_id)
	for resource in RESOURCES:
		if stockpiles[spec.country][resource] < float(bill[resource]): return "Insufficient " + resource
	var job: = {"id": next_id, "equipment": equipment_id, "city": city_name, "progress": 0.0}
	_pay_job(job)
	jobs.append(job)
	next_id += 1
	changed.emit()
	return ""
## Weapons must be researched (level 1+) before they can be built; retired ones never.
func research_lock(spec: Dictionary) -> String:
	if spec.get("research_only",false): return "Freight research upgrades shipments in Transport market"
	if spec.get("retired", false): return "No longer in service"
	if research != null and not str(spec.get("id", "")).begins_with("economy_") and research.level(spec.id) < 1: return "Research " + str(spec.get("research_branch", spec.name)) + " first"
	return ""
func cancel(id: int) -> void :
	for i in jobs.size():
		if jobs[i].id != id: continue
		var spec: = equipment(jobs[i].equipment)
		if jobs[i].get("paid", true):
			var bill: = jobs[i].get("paid_cost", EquipmentEconomy.previous_cost(spec)) as Dictionary
			for resource in RESOURCES: stockpiles[spec.country][resource] += float(bill.get(resource, 0.0))
		jobs.remove_at(i)
		changed.emit()
		return
func advance(seconds: float) -> void :
	if seconds <= 0: return
	var gross := gross_income()
	for country in gross:
		for resource in RESOURCES: _earn(country,resource,gross[country][resource]*seconds)
	var income: = net_income(gross)
	shortage_resources.clear()
	for country in stockpiles:
		shortage_resources[country] = []
		for resource in RESOURCES:
			var balance: float = stockpiles[country][resource] + income[country][resource]*seconds
			if balance < 0: shortage_resources[country].append(resource)
			stockpiles[country][resource] = maxf(0.0,balance)

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
				var bill: = cost(str(job.equipment), job_level(job))
				for resource in RESOURCES:
					if stockpiles[spec.country][resource] < float(bill[resource]): ready = false
				for building_id in spec.get("building_requirements", {}):
					if buildings == null or buildings.level(city.id, building_id) < spec.building_requirements[building_id]: ready = false
				if not ready: break
				_pay_job(job)
			# A paid order keeps the level bought when it started, even if research finishes.
			if not job.has("level"): job.level = production_level(str(job.equipment))
			if not job.has("paid_cost"): job.paid_cost = EquipmentEconomy.previous_cost(spec)
			var total: = job_duration(job)
			var multiplier: = buildings.production_rate(city.id, spec) if buildings != null else 1.0
			var step: = minf(remaining, maxf(0.0, total - job.progress) / multiplier)
			job.progress += step * multiplier
			remaining -= step
			if job.progress < total - 1e-06: break
			jobs.remove_at(active)
			var spawn: Vector2 = GeographicProjection.project(city.naval_spawn.longitude, city.naval_spawn.latitude) if spec.visual_kind == "naval" else city.point + Vector2(0.8 + (int(job.id) % 3) * 0.3, 0.8)
			var completed_unit: = {"base_city": city.id, "level": job_level(job), "equipment_id": spec.id, "id": "produced_" + str(int(job.id)), "name": spec.name, "country": spec.country, "visual_kind": spec.visual_kind, "point": spawn}
			if rally_points.has(city.id) and rally_points[city.id].country == spec.country: completed_unit.rally_point = rally_points[city.id].point.duplicate()
			unit_ready.emit(completed_unit)
	changed.emit()
func _earn(country: String, resource: String, amount: float) -> void:
	if not earned.has(country): earned[country] = {}
	earned[country][resource] = earned[country].get(resource, 0.0) + amount
func snapshot() -> Dictionary:
	var state: = {"stockpiles": stockpiles.duplicate(true), "jobs": jobs.duplicate(true), "next_id": next_id, "rally_points": rally_points.duplicate(true), "gold": gold.duplicate()}
	if research != null: state.research = research.snapshot()
	if buildings != null: state.buildings = buildings.snapshot()
	return state
func validate(state: Variant) -> bool:
	if not state is Dictionary or not state.get("stockpiles") is Dictionary or not state.get("jobs") is Array: return false
	if research != null and state.has("research") and not research.validate(state.research): return false
	if buildings != null and state.has("buildings") and not buildings.validate(state.buildings): return false
	if not (state.get("next_id") is float or state.get("next_id") is int) or not is_finite(float(state.next_id)) or state.next_id < 1 or state.next_id != floor(state.next_id): return false
	if state.stockpiles.size() != stockpiles.size() or state.jobs.size() > cities.size() * SAVED_PLAN_LIMIT: return false
	for country in stockpiles:
		if not state.stockpiles.get(country) is Dictionary: return false
		for resource in RESOURCES:
			# Saves from before food existed have none; restore() gives them the starting amount.
			var value = state.stockpiles[country].get(resource, 0.0 if resource == "food" else null)
			if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > 1000000000000.0: return false
	if not state.get("gold", {}) is Dictionary: return false
	for country in state.get("gold", {}):
		var amount = state.gold[country]
		if country not in stockpiles or not (amount is float or amount is int) or amount < 0 or amount > 1000000000: return false
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
		if counts[job.city] > SAVED_PLAN_LIMIT: return false
		if not job.get("paid", true) is bool or ( not job.get("paid", true) and job.get("progress") != 0): return false
		if job.has("level"):
			var target = job.level
			if not (target is int or target is float) or not is_finite(float(target)) or target != floor(target) or target < 1 or target > 5: return false
		if job.has("paid_cost") and not EquipmentEconomy.valid_paid_cost(job.paid_cost): return false
		var progress = job.get("progress")
		if not (progress is float or progress is int) or not is_finite(float(progress)) or progress < 0 or progress >= job_duration(job): return false
	return true
func restore(state: Dictionary) -> void :
	rally_points = state.get("rally_points", {}).duplicate(true)
	stockpiles = state.stockpiles.duplicate(true)
	for country in stockpiles:
		if not stockpiles[country].has("food"): stockpiles[country].food = START_STOCK.food
	jobs = state.jobs.duplicate(true)
	next_id = int(state.next_id)
	for country in stockpiles: gold[country] = int(state.get("gold", {}).get(country, GoldWallet.START))
	if buildings != null: buildings.restore(state.get("buildings", {}))
	if research != null: research.restore(state.get("research", {}))
	for job in jobs:
		if job.get("paid", true):
			if not job.has("level"): job.level = production_level(str(job.equipment))
			if not job.has("paid_cost"): job.paid_cost = EquipmentEconomy.previous_cost(equipment(str(job.equipment)))
	changed.emit()

func schedule(equipment_id: String, city_name: String) -> String:
	if MatchClient.active != null: return MatchClient.active.send("produce_queue", {"equipment":equipment_id, "city":city_name})
	var spec: = equipment(equipment_id)
	if spec.is_empty(): return "Choose equipment"
	var locked: = research_lock(spec)
	if not locked.is_empty(): return locked
	var place: Dictionary = {}
	for entry in cities:
		if entry.name == city_name: place = entry
	if place.is_empty() or not controlled(place, spec.country): return "Choose a controlled city"
	if spec.get("requires_port", false) and not place.has("naval_spawn"): return "Ships require a coastal city"
	if jobs.filter( func(job: Dictionary): return job.city == city_name).size() >= PLAN_LIMIT: return "The production queue is full (5)"
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

# ---------------------------------------------------------------- gold (GoldWallet)

func spend_gold(country: String, amount: int) -> String:
	if country not in stockpiles or amount < 0: return "Invalid gold payment"
	if int(gold.get(country, 0)) < amount: return "Not enough gold (%d needed)" % amount
	gold[country] = int(gold[country]) - amount
	changed.emit()
	return ""
func pay_gold_quote(country: String, price: Dictionary, max_gold: int = -1) -> String:
	if max_gold >= 0 and int(price.total) > max_gold: return "Price changed; review the new gold total"
	return spend_gold(country, int(price.total))

## The unit being built in `city_name` now (the first in its queue), or {}.
func active_job(city_name: String) -> Dictionary:
	for job in jobs:
		if job.city == city_name: return job
	return {}

func unit_gold_quote(job: Dictionary) -> Dictionary:
	if not job.has("equipment"): return GoldWallet.quote(0)
	var spec: = equipment(job.equipment)
	var city: Dictionary = {}
	for place in cities:
		if place.name == job.city: city = place
	var rate: = buildings.production_rate(city.get("id", ""), spec) if buildings != null else 1.0
	var bill: = cost(str(job.equipment), job_level(job)) if not job.get("paid", true) else {}
	return GoldWallet.quote((job_duration(job) - float(job.progress)) / maxf(rate, 0.001), bill, stockpiles.get(spec.country, {}))
func unit_speedup_price(job: Dictionary) -> int:
	return int(unit_gold_quote(job).total)

## Finishes the unit being built in a city now, for gold.
func finish_unit_now(city_name: String, country: String, max_gold: int = -1, expected_job: int = -1) -> String:
	if MatchClient.active != null:
		var price: = unit_speedup_price(active_job(city_name)) if max_gold < 0 else max_gold
		return MatchClient.active.send("gold_unit", {"city":city_name,"max_gold":price,"job":expected_job if expected_job >= 0 else int(active_job(city_name).get("id",-1))})
	var job: = active_job(city_name)
	if job.is_empty(): return "Nothing is being built here"
	if expected_job >= 0 and int(job.id) != expected_job: return "The order changed; review it again"
	var spec: = equipment(job.equipment)
	if spec.country != country: return "Not your production"
	var producing_city: Dictionary = {}
	for city in cities:
		if city.name == city_name: producing_city = city
	if producing_city.is_empty() or not controlled(producing_city, country): return "Recover control of this city first"
	if not job.get("paid", true):
		for building_id in spec.get("building_requirements", {}):
			if buildings == null or buildings.level(str(producing_city.id), building_id) < spec.building_requirements[building_id]: return "Requires " + building_id
	var error: = pay_gold_quote(country, unit_gold_quote(job), max_gold)
	if not error.is_empty(): return error
	if not job.get("paid", true):
		job.level = job_level(job)
		job.paid_cost = cost(str(job.equipment), int(job.level))
		GoldWallet.consume_available(stockpiles[country], job.paid_cost)
		job.paid = true
	job.progress = job_duration(job)
	advance(0.000001)
	return ""

## Buys `quantity` of a resource with gold.
func buy_with_gold(country: String, resource: String, quantity: int) -> String:
	if MatchClient.active != null: return MatchClient.active.send("gold_resource", {"resource":resource,"quantity":quantity})
	if resource not in RESOURCES or quantity <= 0 or quantity > 1000000: return "Choose a resource and amount"
	var error: = spend_gold(country, GoldWallet.resource_price(resource, quantity))
	if not error.is_empty(): return error
	stockpiles[country][resource] += float(quantity)
	changed.emit()
	return ""

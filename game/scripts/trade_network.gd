class_name TradeNetwork
extends Node3D
## Trade instead of a market (owner request 2026-10-13).
## - A trade route runs from one of your cities to a trade partner:
##     by rail  - the city needs a train station, the line runs over your own land to the border;
##     by sea   - the city needs a naval base (coastal), tankers carry fuel, container ships the rest.
## - Partners: neutral neighbours (always willing while you are not at war with them) and the
##   other player when both have agreed a "trade" deal in Diplomacy and are at peace.
## - Trains and ships really travel the route; each arrival delivers cargo, counted as income
##   (so trade helps towards the economic victory). Bigger stations / naval bases carry more.
## - Rail transport: ground armies move twice as fast through friendly provinces that have a
##   train station (own provinces, coalition members and right-of-way partners).
signal changed
signal delivered(country: String, partner: String, cargo: String, amount: float)

const DAY: = VictoryRules.DAY
const DEPARTURE_EVERY: = DAY / 4.0           # a convoy leaves every 6 game hours
const RAIL_SPEED: = 6.0                       # map units per game day ... scaled below
const SEA_SPEED: = 4.0
const CARGO: = {"food": 80.0, "materials": 60.0, "electronics": 20.0, "fuel": 45.0}
const SEA_BONUS: = 1.6
const PARTNER_SHARE: = 0.25                   # a player partner also earns this share as funds
const MAX_ROUTES_PER_COUNTRY: = 4
## Neutral trade partners on the regional map. "cross" is where the line leaves your land,
## "goal" is the partner's city the convoy heads for after the border (off the playable map).
const PARTNERS: = {
	"belarus": {"name": "Belarus", "mode": "rail", "for": ["russia", "ukraine"], "cross": {"russia": [31.8, 54.6], "ukraine": [31.0, 51.9]}, "goal": [27.56, 53.9]},
	"kazakhstan": {"name": "Kazakhstan", "mode": "rail", "for": ["russia"], "cross": {"russia": [46.0, 50.5]}, "goal": [51.4, 51.2]},
	"poland": {"name": "Poland", "mode": "rail", "for": ["ukraine"], "cross": {"ukraine": [23.9, 50.2]}, "goal": [21.0, 52.2]},
	"romania": {"name": "Romania", "mode": "rail", "for": ["ukraine"], "cross": {"ukraine": [26.0, 48.2]}, "goal": [26.1, 44.4]},
	"turkey": {"name": "Turkey", "mode": "sea", "for": ["russia", "ukraine"], "goal": [31.0, 42.2]},
}

static var active: TradeNetwork

var map: StrategicMap
var armies: UnitSystem
var production: ProductionSystem
var buildings: BuildingSystem
var diplomacy: Diplomacy
var routes: Array = []          # {id, country, partner, city, mode, cargo, path, timer}
var convoys: Array = []         # {route, node, path, progress, length, cargo, amount}
var next_id: = 1
var ai_countries: Array = []
var _ai_timer: = 0.0
var _station_cells: Dictionary = {}   # Vector2i -> territory id (lookup cache)
var _station_territories: Dictionary = {}
var _models: Dictionary = {}

func setup(terrain: StrategicMap, units: UnitSystem, economy: ProductionSystem, building_system: BuildingSystem, talks: Diplomacy) -> void:
	map = terrain
	armies = units
	production = economy
	buildings = building_system
	diplomacy = talks
	active = self
	buildings.changed.connect(_refresh_stations)
	_refresh_stations()

func _exit_tree() -> void:
	if active == self: active = null

# ---------------------------------------------------------------- partners and routes

## Everyone `country` could trade with: neutral partners plus the other player(s).
func partners_for(country: String) -> Array:
	var result: Array = []
	for id in PARTNERS:
		if country in PARTNERS[id]["for"]: result.append(id)
	for other in ["russia", "ukraine"]:
		if other != country: result.append(other)
	return result

func partner_name(id: String) -> String:
	return PARTNERS[id].name if PARTNERS.has(id) else id.capitalize()

func partner_mode(id: String) -> String:
	return PARTNERS[id].mode if PARTNERS.has(id) else "rail"

func agreement(country: String, partner: String) -> bool:
	if PARTNERS.has(partner): return true
	if diplomacy == null: return false
	return not diplomacy.at_war(country, partner) and bool(diplomacy.relation(country, partner).get("trade", false))

func _cities_of(country: String) -> Array:
	return production.cities.filter(func(c: Dictionary): return production.controlled(c, country))

## The best city to start a route to `partner` (and the path), or {"error": reason}.
func plan(country: String, partner: String, city_id: String = "") -> Dictionary:
	if not agreement(country, partner):
		return {"error": "Agree a trade deal with " + partner_name(partner) + " in Diplomacy first" if not PARTNERS.has(partner) else "No trade while at war"}
	if diplomacy != null and not PARTNERS.has(partner) and diplomacy.embargoed(partner, country): return {"error": partner_name(partner) + " has an embargo on you"}
	var mode: = partner_mode(partner)
	var best: Dictionary = {}
	for city in _cities_of(country):
		if not city_id.is_empty() and city.id != city_id: continue
		var level: = buildings.level(city.id, "train_station" if mode == "rail" else "naval_base")
		if level <= 0: continue
		var path: = _route_path(country, partner, city, mode)
		if path.size() < 2: continue
		var length: = _length(path)
		if best.is_empty() or level > best.level or (level == best.level and length < best.length):
			best = {"city": city, "path": path, "length": length, "level": level, "mode": mode}
	if best.is_empty():
		return {"error": ("Build a train station in a city with a rail line to " if mode == "rail" else "Build a naval base in a coastal city to ship to ") + partner_name(partner)}
	return best

func _route_path(country: String, partner: String, city: Dictionary, mode: String) -> Array:
	var start: Vector2 = city.point
	if mode == "sea":
		if not city.has("naval_spawn"): return []
		var port: = GeographicProjection.project(city.naval_spawn.longitude, city.naval_spawn.latitude)
		var goal: = GeographicProjection.project(PARTNERS[partner].goal[0], PARTNERS[partner].goal[1])
		var sea_goal: = armies.sea_navigation.coastal_destination(goal)
		var path: Array = armies.sea_navigation.find_path(port, sea_goal)
		if path.is_empty(): return []
		return [port] + path + [goal]
	var finish: Vector2
	if PARTNERS.has(partner):
		var cross: Array = PARTNERS[partner].cross[country]
		finish = _border_hub(country, GeographicProjection.project(cross[0], cross[1]))
	else:
		# Another player: their nearest city with a train station.
		var best: = INF
		finish = Vector2.INF
		for other in _cities_of(partner):
			if buildings.level(other.id, "train_station") <= 0: continue
			var d: float = other.point.distance_to(start)
			if d < best: best = d; finish = other.point
		if finish == Vector2.INF: return []
	var path: Array = armies.navigation.find_path(start, finish)
	if path.is_empty() or path[-1].distance_to(finish) > 0.3: return []
	# A rail line only runs over the trading countries' own land.
	for point in path:
		var owner: = armies.navigation.controller_at(point)
		if owner != country and owner != partner: return []
	var full: Array = [start] + path
	if PARTNERS.has(partner):
		full.append(GeographicProjection.project(PARTNERS[partner].goal[0], PARTNERS[partner].goal[1]))
	return full

## The province centre of `country` closest to a border crossing.
func _border_hub(country: String, point: Vector2) -> Vector2:
	var best: = Vector2.INF
	for t in map.territories:
		if not t.playable or t.controller != country or not map.province_hubs.has(t.title): continue
		var hub: Vector2 = map.province_hubs[t.title]
		if best == Vector2.INF or hub.distance_to(point) < best.distance_to(point): best = hub
	return best

func _length(path: Array) -> float:
	var total: = 0.0
	for i in path.size() - 1: total += path[i].distance_to(path[i + 1])
	return total

func routes_of(country: String) -> Array:
	return routes.filter(func(r: Dictionary): return r.country == country)

func open_route(country: String, partner: String, cargo: String, city_id: String = "") -> String:
	if not CARGO.has(cargo): return "Choose food, fuel, materials or electronics"
	if routes_of(country).size() >= MAX_ROUTES_PER_COUNTRY: return "At most %d trade routes" % MAX_ROUTES_PER_COUNTRY
	for r in routes_of(country):
		if r.partner == partner: return "You already trade with " + partner_name(partner)
	var p: = plan(country, partner, city_id)
	if p.has("error"): return p.error
	routes.append({"id": next_id, "country": country, "partner": partner, "city": p.city.id, "mode": p.mode, "cargo": cargo, "path": p.path, "timer": 0.0})
	next_id += 1
	changed.emit()
	return ""

func close_route(id: int) -> void:
	for i in range(routes.size() - 1, -1, -1):
		if routes[i].id == id: routes.remove_at(i)
	changed.emit()

func set_cargo(id: int, cargo: String) -> void:
	for r in routes:
		if r.id == id and CARGO.has(cargo): r.cargo = cargo
	changed.emit()

func delivery_amount(route: Dictionary) -> float:
	var level: = buildings.level(route.city, "train_station" if route.mode == "rail" else "naval_base")
	return CARGO[route.cargo] * maxi(1, level) * (SEA_BONUS if route.mode == "sea" else 1.0)

## Funds-equivalent value of a delivery (for income share / economic victory).
static func value_of(cargo: String, amount: float) -> float:
	return amount * float(SupplyExchange.PRICES.get(cargo, {"sell": 2.0}).sell)

# ---------------------------------------------------------------- simulation

func advance(seconds: float) -> void:
	if seconds <= 0: return
	# Routes stop when their city is lost, the station is gone or the deal ends (war, embargo).
	for i in range(routes.size() - 1, -1, -1):
		var r: Dictionary = routes[i]
		var city: = buildings.city(r.city)
		var level: = buildings.level(r.city, "train_station" if r.mode == "rail" else "naval_base")
		if city.is_empty() or not production.controlled(city, r.country) or level <= 0 or not agreement(r.country, r.partner):
			routes.remove_at(i)
			changed.emit()
			continue
		r.timer -= seconds
		if r.timer <= 0:
			r.timer += DEPARTURE_EVERY
			_depart(r)
	for i in range(convoys.size() - 1, -1, -1):
		var c: Dictionary = convoys[i]
		var speed: float = (RAIL_SPEED if c.mode == "rail" else SEA_SPEED) * 10.0 / DAY
		c.progress += speed * seconds
		if c.progress >= c.length:
			_arrive(c)
			if is_instance_valid(c.node): c.node.queue_free()
			convoys.remove_at(i)
			continue
		_place(c)
	_ai_timer += seconds
	if _ai_timer >= DAY / 24.0:
		_ai_timer = 0.0
		for country in ai_countries: _ai_trade(country)

func _depart(route: Dictionary) -> void:
	var node: = _convoy_visual(route.mode, route.cargo)
	add_child(node)
	var c: = {"route": route.id, "country": route.country, "partner": route.partner, "mode": route.mode, "cargo": route.cargo, "amount": delivery_amount(route), "node": node, "path": route.path, "progress": 0.0, "length": _length(route.path)}
	convoys.append(c)
	_place(c)

func _arrive(c: Dictionary) -> void:
	var stock: Dictionary = production.stockpiles.get(c.country, {})
	if stock.is_empty(): return
	stock[c.cargo] = float(stock.get(c.cargo, 0.0)) + c.amount
	production._earn(c.country, "funds", value_of(c.cargo, c.amount))
	if not PARTNERS.has(c.partner) and production.stockpiles.has(c.partner):
		var share: = value_of(c.cargo, c.amount) * PARTNER_SHARE
		production.stockpiles[c.partner].funds += share
		production._earn(c.partner, "funds", share)
	production.changed.emit()
	delivered.emit(c.country, c.partner, c.cargo, c.amount)

func _place(c: Dictionary) -> void:
	if not is_instance_valid(c.node): return
	var travelled: float = c.progress
	var path: Array = c.path
	for i in path.size() - 1:
		var seg: float = path[i].distance_to(path[i + 1])
		if travelled <= seg or i == path.size() - 2:
			var p: Vector2 = path[i].lerp(path[i + 1], clampf(travelled / maxf(seg, 0.0001), 0.0, 1.0))
			var height: float = 0.08 if c.mode == "sea" else map.position_at(p).y + 0.03
			c.node.position = Vector3(p.x, height, p.y)
			var dir: Vector2 = path[i + 1] - path[i]
			if dir.length() > 0.0001: c.node.rotation.y = atan2(-dir.x, -dir.y)
			c.node.visible = c.country == GameSession.player_country or c.partner == GameSession.player_country or armies == null or armies.point_visible(p)
			return
		travelled -= seg

func _ai_trade(country: String) -> void:
	if routes_of(country).size() >= 2: return
	var needs: Dictionary = production.stockpiles.get(country, {})
	var cargo: = "fuel"
	var lowest: = INF
	for resource in CARGO:
		if float(needs.get(resource, 0.0)) / CARGO[resource] < lowest:
			lowest = float(needs.get(resource, 0.0)) / CARGO[resource]
			cargo = resource
	for partner in partners_for(country):
		if not PARTNERS.has(partner): continue
		if routes_of(country).any(func(r: Dictionary): return r.partner == partner): continue
		if open_route(country, partner, cargo).is_empty(): return

# ---------------------------------------------------------------- rail transport for armies

func _refresh_stations() -> void:
	_station_territories.clear()
	_station_cells.clear()
	for city in production.cities:
		if buildings.level(city.id, "train_station") > 0: _station_territories[str(city.sector)] = true
	for id in buildings.provinces.levels:
		if buildings.provinces.level(id, "train_station") > 0:
			var place: Dictionary = buildings.provinces.place(id)
			if place.has("region"): _station_territories[str(place.region.id)] = true
	changed.emit()

func _territory_at(point: Vector2) -> Dictionary:
	var key: = Vector2i(floori(point.x * 4.0), floori(point.y * 4.0))
	var cached: Variant = _station_cells.get(key)
	if cached is Dictionary and RegionData.contains(cached, point): return cached
	for t in map.territories:
		if t.playable and RegionData.contains(t, point):
			_station_cells[key] = t
			return t
	return {}

## 2.0 when a ground army moves through a friendly province a railway line runs through
## (owner 2026-10-13: no rails until a second station is connected to the capital).
func rail_factor(point: Vector2, country: String) -> float:
	var t: = _territory_at(point)
	var rail: Dictionary = RailwayMap.active.served if RailwayMap.active != null and is_instance_valid(RailwayMap.active) else _station_territories
	if t.is_empty() or not rail.has(str(t.id)): return 1.0
	var owner: String = t.controller
	if owner == country: return 2.0
	if diplomacy != null and not diplomacy.at_war(country, owner) and diplomacy.right_of_way(country, owner): return 2.0
	return 1.0

# ---------------------------------------------------------------- visuals

func _model(path: String, length: float) -> Node3D:
	if not _models.has(path):
		var scene: = load(path) as PackedScene
		if scene == null: return null
		var merged: = UnitVisual.merged(scene.instantiate() as Node3D)
		var bounds: = UnitVisual.model_bounds(merged, 0.0)
		# Models face different axes; turn each so its long side runs along the track (z).
		_models[path] = [merged, length / maxf(bounds.get_longest_axis_size(), 0.001), bounds.size.x > bounds.size.z]
	var entry: Array = _models[path]
	var copy: Node3D = entry[0].duplicate()
	copy.scale = Vector3.ONE * entry[1]
	if entry[2]: copy.rotation.y = PI * 0.5
	var holder: = Node3D.new()
	holder.add_child(copy)
	return holder

func _convoy_visual(mode: String, cargo: String) -> Node3D:
	var root: = Node3D.new()
	if mode == "sea":
		var ship: = _model("res://assets/library/transport/civil_tanker_t1_coastal.glb" if cargo == "fuel" else "res://assets/library/transport/civil_container_t1_feeder.glb", 0.55)
		if ship != null: root.add_child(ship)
		return root
	var cars: = ["res://assets/library/transport/train_diesel_locomotive.glb",
		"res://assets/library/transport/train_tank_car.glb" if cargo == "fuel" else "res://assets/library/transport/train_container_flatcar.glb",
		"res://assets/library/transport/train_tank_car.glb" if cargo == "fuel" else "res://assets/library/transport/train_container_flatcar.glb"]
	for i in cars.size():
		var car: = _model(cars[i], 0.22)
		if car == null: continue
		car.position = Vector3(0, 0, 0.225 * i)
		root.add_child(car)
	return root

# ---------------------------------------------------------------- saving

func snapshot() -> Dictionary:
	var saved: = []
	for r in routes:
		var copy: Dictionary = r.duplicate()
		copy.erase("path")
		saved.append(copy)
	return {"routes": saved, "next_id": next_id}

func restore(state: Dictionary) -> void:
	for c in convoys:
		if is_instance_valid(c.node): c.node.queue_free()
	convoys.clear()
	routes.clear()
	next_id = int(state.get("next_id", 1))
	for r in state.get("routes", []):
		var p: = plan(str(r.country), str(r.partner), str(r.city))
		if p.has("error"): continue
		var route: Dictionary = r.duplicate()
		route.path = p.path
		route.id = int(r.id)
		route.timer = float(r.get("timer", 0.0))
		routes.append(route)
	changed.emit()

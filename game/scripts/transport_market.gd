class_name TransportMarket
extends RefCounted
## Physical player-to-player sales. Money is escrowed until delivery; lost cargo is lost,
## and payment returns to the buyer. No infantry or strategic weapons may be sold.
signal changed
var network: TradeNetwork
var offers: Array = []
var requests: Array = []
var shipments: Array = []
var history: Array = []
var next_id: = 1
const MODES: = ["rail", "sea", "air"]
const CAPACITY: = {"rail": 12, "sea": 30, "air": 2}
const SPEED: = {"rail": 60.0, "sea": 40.0, "air": 180.0}
const RESOURCE_LOAD: = 100.0
const ATTACK_PERIOD: = CombatSystem.ROUND_SECONDS
var _combat: = CombatSystem.new()
var _air_combat: = AirBattleSystem.new()

static func sale_allowed(unit: Dictionary) -> bool:
	return UnitClasses.of(unit) != "infantry" and not CombatSystem.nuclear(unit) and not EquipmentIdentity.spec(str(unit.get("equipment_id", ""))).is_empty()

static func minimum_price(unit: Dictionary) -> int:
	return WorldMarketPrices.new().equipment(unit)

static func load_size(unit: Dictionary) -> int:
	return 4 if UnitClasses.of(unit) == "heavy" else 2 if UnitClasses.of(unit) == "air" else 1

func facility(mode: String) -> String:
	return {"rail": "train_station", "sea": "naval_base", "air": "airbase"}.get(mode, "")

## Owner 2026-10-16: "It doesn't have how much the train and shipping carry, so every level
## should be higher." One table drives what the panels show and what convoys really carry:
## each terminal level carries clearly more than the last (train stations and naval bases have
## three levels, airbases five).
const LEVEL_SCALE: = [0.0, 1.0, 2.0, 3.5, 5.0, 7.0]
## Owner 2026-10-16: cargo ship / oil tanker research adds +50% per level above I on top of the
## port level. Level 0 (not researched) means the country has no merchant ships yet.
const VESSEL_SCALE: = [0.0, 1.0, 1.5, 2.0, 2.5, 3.0]
const TRANSPORT_NAME: = {"rail": "train", "sea": "ship", "air": "cargo plane"}

static func level_scale(level: int) -> float:
	return float(LEVEL_SCALE[clampi(level, 0, LEVEL_SCALE.size() - 1)])

static func vessel_scale(level: int) -> float:
	return float(VESSEL_SCALE[clampi(level, 0, VESSEL_SCALE.size() - 1)])

## Market cargo slots per trip (100 resources or one light vehicle per slot).
static func capacity_at(mode: String, level: int, vessel: int = 1) -> int:
	return roundi(float(CAPACITY.get(mode, 0)) * level_scale(level) * (vessel_scale(vessel) if mode == "sea" else 1.0))

static func per_level_text(mode: String, max_level: int, vessel: int = 1) -> String:
	var parts: Array = []
	for level in range(1, max_level + 1):
		parts.append("Lv%d %s" % [level, _thousands(capacity_at(mode, level, vessel) * int(RESOURCE_LOAD))])
	return "Each %s carries %s cargo per trip" % [TRANSPORT_NAME.get(mode, mode), " · ".join(parts)]

static func _thousands(value: int) -> String:
	var digits: = str(absi(value))
	var out: = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out

func facility_level(city: String, mode: String) -> int:
	return clampi(network.buildings.level(city, facility(mode)), 0, LEVEL_SCALE.size() - 1)

## Research level of the ships that sail from this port (cargo ships, or oil tankers for fuel).
func vessel_level(city: String, cargo: String) -> int:
	var research: ResearchSystem = network.production.research
	if research == null: return 1
	var country: String = network.production.controller(network.buildings.city(city))
	return clampi(research.level(("tankers_" if cargo == "fuel" else "cargo_") + country), 0, VESSEL_SCALE.size() - 1)

## Capacity multiplier shared by the transport market and trade-route deliveries.
func scale(city: String, mode: String, cargo: String = "materials") -> float:
	var result: = level_scale(facility_level(city, mode))
	if mode == "sea": result *= vessel_scale(vessel_level(city, cargo))
	return result

func capacity(city: String, mode: String, cargo: String = "materials") -> int:
	return roundi(float(CAPACITY.get(mode, 0)) * scale(city, mode, cargo))

func _offer(id: int) -> Dictionary:
	for offer in offers:
		if int(offer.id) == id: return offer
	return {}

func list_resource(country: String, city_id: String, cargo: String, amount: int, price: int) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_resource", {"city": city_id, "cargo": cargo, "amount": amount, "price": price})
	var city: = network.buildings.city(city_id)
	if city.is_empty() or not network.production.controlled(city, country): return "Choose one of your cities"
	if not TradeNetwork.CARGO.has(cargo) or amount <= 0 or amount > 100000: return "Choose 1–100,000 cargo units"
	if price < ceili(network.world_prices.resource(cargo) * amount) or price > 100000000: return "Price must meet the resource minimum"
	var stock: Dictionary = network.production.stockpiles.get(country, {})
	if float(stock.get(cargo, 0.0)) < amount: return "Insufficient cargo"
	stock[cargo] -= amount
	offers.append({"id": next_id, "seller": country, "city": city_id, "cargo": cargo, "amount": amount, "price": price, "unit": {}})
	next_id += 1
	network.production.changed.emit()
	changed.emit()
	return ""

func list_unit(country: String, city_id: String, unit_id: String, price: int) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_unit", {"city": city_id, "unit": unit_id, "price": price})
	var city: = network.buildings.city(city_id)
	var unit: = network.armies.find_id(unit_id)
	if city.is_empty() or not network.production.controlled(city, country): return "Choose one of your cities"
	if unit.is_empty() or unit.country != country or unit.health <= 0: return "Choose your own equipment"
	if not sale_allowed(unit): return "Infantry and strategic weapons cannot be sold"
	if unit.get("moving", false) or unit.get("engaged", false) or float(unit.get("upgrade_remaining", 0.0)) > 0 or str(unit.get("flight_mode", "grounded")) != "grounded" or float(unit.get("refuel_remaining", 0.0)) > 0: return "Stop the unit and finish combat or upgrades first"
	if Vector2(unit.node.position.x, unit.node.position.z).distance_to(city.point) > 1.5: return "Move the equipment to the selling city first"
	if price < unit_floor(unit) or price > 100000000: return "World minimum equipment price: %d" % unit_floor(unit)
	var saved: Dictionary = {}
	for entry in network.armies.snapshot():
		if entry.id == unit_id: saved = {"id": entry.id, "name": entry.name, "equipment_id": entry.equipment_id, "visual_kind": entry.visual_kind, "country": entry.country, "health": entry.health, "level": entry.level}
	if saved.is_empty(): return "Equipment is unavailable"
	# Remove from active armies without recording a combat death. The offer owns it now.
	network.armies.units.erase(unit)
	unit.node.queue_free()
	network.armies.selected = -1
	network.armies.command_ids.erase(unit_id)
	network.armies.stacks.invalidate()
	offers.append({"id": next_id, "seller": country, "city": city_id, "cargo": "equipment", "amount": 1, "price": price, "unit": saved})
	next_id += 1
	changed.emit()
	return ""

func cancel(country: String, id: int) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_cancel", {"id": id})
	var offer: = _offer(id)
	if offer.is_empty() or offer.seller != country: return "Choose your own unsold offer"
	# Keep escrow recoverable if the source city has been captured.
	var city: = network.buildings.city(str(offer.city))
	if city.is_empty() or not network.production.controlled(city, country): return "Recover the selling city before withdrawing cargo"
	if offer.unit.is_empty(): network.production.stockpiles[country][offer.cargo] += offer.amount
	else: _deliver_unit(offer.unit, country, city)
	offers.erase(offer)
	network.production.changed.emit()
	changed.emit()
	return ""

func unit_floor(unit: Dictionary) -> int:
	return network.world_prices.equipment(unit)

func offer_floor(offer: Dictionary) -> int:
	return ceili(network.world_prices.resource(offer.cargo) * float(offer.amount)) if offer.unit.is_empty() else unit_floor(offer.unit)

func reprice(country: String, id: int, price: int) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_reprice", {"id":id,"price":price})
	var offer: = _offer(id)
	if offer.is_empty() or offer.seller != country: return "Choose your own unsold offer"
	if price < offer_floor(offer) or price > 100000000: return "Current world minimum: %d" % offer_floor(offer)
	offer.price = price
	changed.emit()
	return ""

func quote(offer: Dictionary, buyer: String, destination: String, mode: String) -> Dictionary:
	if float(offer.get("price",0.0)) < offer_floor(offer): return {"error": "World minimum changed to %d; the seller must update this offer" % offer_floor(offer)}
	if not mode in MODES: return {"error": "Choose rail, ship or cargo plane"}
	var origin: = network.buildings.city(str(offer.get("city", "")))
	var target: = network.buildings.city(destination)
	var seller: String = offer.get("seller", "")
	if buyer == seller or not network.production.stockpiles.has(buyer): return {"error": "Choose another country's offer"}
	if origin.is_empty() or not network.production.controlled(origin, seller): return {"error": "The selling city is unavailable"}
	if target.is_empty() or not network.production.controlled(target, buyer): return {"error": "Choose your receiving city"}
	if not network.agreement(seller, buyer): return {"error": "Agree a trade deal in Diplomacy first"}
	if network.diplomacy != null and (network.diplomacy.embargoed(seller, buyer) or network.diplomacy.embargoed(buyer, seller)): return {"error": "Trade is blocked by an embargo"}
	var load: int = ceili(float(offer.amount) / RESOURCE_LOAD) if offer.unit.is_empty() else load_size(offer.unit)
	if network.buildings.level(target.id,facility(mode)) < 1: return {"error": "Build a receiving terminal first"}
	var limit: = capacity(origin.id, mode, str(offer.cargo))
	if mode == "sea" and vessel_level(origin.id, str(offer.cargo)) < 1: return {"error": "The seller has no %s yet; research them first" % ("oil tankers" if offer.cargo == "fuel" else "cargo ships")}
	if load > limit: return {"error": "Load %d slots exceeds this %s's %d (%s cargo); upgrade the departure %s%s or use another transport" % [load, TRANSPORT_NAME[mode], limit, _thousands(limit * int(RESOURCE_LOAD)), {"rail": "train station", "sea": "naval base", "air": "airbase"}[mode], " or ship research" if mode == "sea" else ""]}
	if not offer.unit.is_empty() and UnitClasses.of(offer.unit) in ["naval", "submarine"] and mode != "sea": return {"error": "Naval equipment can only transfer between ports by sea"}
	var path: Array = []
	if mode == "air":
		path = [origin.point, target.point]
	elif mode == "sea":
		if not origin.has("naval_spawn") or not target.has("naval_spawn"): return {"error": "Sea shipments need two coastal ports"}
		var start: = GeographicProjection.project(origin.naval_spawn.longitude, origin.naval_spawn.latitude)
		var finish: = GeographicProjection.project(target.naval_spawn.longitude, target.naval_spawn.latitude)
		path = [start] + network.armies.sea_navigation.find_path(start, finish)
		if path.size() < 2 or path[-1].distance_to(finish) > 0.5: return {"error": "No sea route connects these ports"}
	else:
		path = safe_rail(origin.point, target.point, seller, buyer)
		if path.size() < 2: return {"error": "No accessible railway; use coastal ports and a ship overseas, or a small air shipment"}
	return {"path": path, "load": load, "capacity": limit, "duration": network._length(path) * TradeNetwork.DAY / SPEED[mode]}

## Route only over built railway links and borders with access rights. Visible hostile armies
## make nearby links more expensive; never inspect hidden armies to choose a safer route.
func safe_rail(start: Vector2, finish: Vector2, seller: String, buyer: String) -> Array:
	var rail: RailwayMap = RailwayMap.active
	if rail == null or not is_instance_valid(rail): return []
	var graph: = AStar2D.new()
	var points: Array = []
	var edges: Dictionary = {}
	for link in rail.links:
		var owner: String = link.country
		if owner not in [seller, buyer] and (network.diplomacy == null or network.diplomacy.at_war(seller,owner) or not network.diplomacy.right_of_way(seller, owner)): continue
		var route: Array = link.route
		if route.size() < 2 or not rail_access(route,seller,buyer): continue
		var ids: Array = []
		for point in [route[0], route[-1]]:
			var id: = -1
			for i in points.size():
				if points[i].distance_to(point) < 0.1: id = i; break
			if id < 0:
				id = points.size(); points.append(point); graph.add_point(id, point)
			ids.append(id)
		graph.connect_points(ids[0], ids[1])
		edges["%d:%d" % ids] = route
		var reversed: Array = route.duplicate(); reversed.reverse()
		edges["%d:%d" % [ids[1], ids[0]]] = reversed
	# Adjacent border rail terminals can join countries' networks, never an ocean.
	for i in points.size():
		for j in range(i + 1, points.size()):
			if graph.are_points_connected(i, j) or points[i].distance_to(points[j]) > 1.0: continue
			if not network.armies.navigation.clear_segment(points[i], points[j]) or not rail_access([points[i],points[j]],seller,buyer): continue
			graph.connect_points(i, j)
			edges["%d:%d" % [i,j]] = [points[i],points[j]]
			edges["%d:%d" % [j,i]] = [points[j],points[i]]
	if points.is_empty(): return []
	var a: = graph.get_closest_point(start); var b: = graph.get_closest_point(finish)
	if points[a].distance_to(start) > 0.2 or points[b].distance_to(finish) > 0.2: return []
	for i in points.size():
		var danger: = 1.0
		for unit in network.armies.units:
			if unit.health <= 0 or not network.armies.unit_visible(unit, seller): continue
			if network.diplomacy == null or not network.diplomacy.at_war(seller, unit.country): continue
			var hostile_point: = Vector2(unit.node.position.x, unit.node.position.z)
			if points[i].distance_to(hostile_point) < 3.0: danger += 10.0
			else:
				for connected in graph.get_point_connections(i):
					var edge: Array = edges["%d:%d" % [i,connected]]
					if edge.any(func(p): return p.distance_to(hostile_point) < 3.0): danger += 10.0; break
		graph.set_point_weight_scale(i, danger)
	var ids: = graph.get_id_path(a,b)
	var result: Array = [start]
	for i in ids.size() - 1: result.append_array(edges["%d:%d" % [ids[i],ids[i+1]]])
	return result if ids.size() > 1 else []

func buy(country: String, id: int, destination: String, mode: String) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_buy", {"id": id, "city": destination, "mode": mode})
	var offer: = _offer(id)
	if offer.is_empty(): return "This offer has already been bought or withdrawn"
	var plan: = quote(offer, country, destination, mode)
	if plan.has("error"): return plan.error
	if float(network.production.stockpiles[country].funds) < float(offer.price): return "Insufficient funds"
	network.production.stockpiles[country].funds -= offer.price
	var shipment: Dictionary = offer.duplicate(true)
	shipment.merge({"buyer": country, "destination": destination, "mode": mode, "path": plan.path, "progress": 0.0, "health": 100.0, "attack_timer": 0.0, "status": "In transit"})
	shipment.vessel_level = network.production.research.level(("tankers_" if offer.cargo == "fuel" else "cargo_") + offer.seller) if network.production.research != null else 1
	shipment.node = network._convoy_visual(mode, offer.cargo,offer.seller,shipment.vessel_level)
	network.add_child(shipment.node)
	shipments.append(shipment)
	offers.erase(offer)
	network.production.changed.emit()
	changed.emit()
	return ""

func advance(seconds: float) -> void:
	if seconds <= 0: return
	for shipment in shipments.duplicate():
		var target: = network.buildings.city(shipment.destination)
		# Enemy occupation, war or lost facilities hold cargo instead of handing it to an enemy.
		if target.is_empty() or not network.production.controlled(target, shipment.buyer) or not network.agreement(shipment.seller, shipment.buyer) or network.buildings.level(shipment.destination, facility(shipment.mode)) == 0 or (shipment.mode == "rail" and not rail_access(shipment.path,shipment.seller,shipment.buyer)) or (network.diplomacy != null and (network.diplomacy.embargoed(shipment.seller,shipment.buyer) or network.diplomacy.embargoed(shipment.buyer,shipment.seller))):
			shipment.status = "Held: destination or trade access unavailable"
		else:
			shipment.status = "In transit"
			shipment.progress += SPEED[shipment.mode] * seconds / TradeNetwork.DAY
		_place(shipment)
		shipment.attack_timer += seconds
		if shipment.attack_timer >= ATTACK_PERIOD:
			shipment.attack_timer = fmod(shipment.attack_timer, ATTACK_PERIOD)
			_raid(shipment)
		if shipment.health <= 0:
			_finish(shipment, false)
		elif shipment.status == "In transit" and shipment.progress >= network._length(shipment.path):
			_finish(shipment, true)

func _place(shipment: Dictionary) -> void:
	var left: float = shipment.progress
	for i in shipment.path.size() - 1:
		var a: Vector2 = shipment.path[i]; var b: Vector2 = shipment.path[i+1]
		var length: = a.distance_to(b)
		if left <= length or i == shipment.path.size()-2:
			var point: = a.lerp(b, clampf(left / maxf(length,0.00001),0,1))
			shipment.node.position = Vector3(point.x, 2.0 if shipment.mode == "air" else 0.08 if shipment.mode == "sea" else network.map.position_at(point).y + 0.03, point.y)
			shipment.node.rotation.y = atan2(a.x-b.x, a.y-b.y)
			shipment.node.visible = GameSession.player_country in [shipment.seller,shipment.buyer] or network.armies.point_visible(point)
			return
		left -= length

func _raid(shipment: Dictionary) -> void:
	var point: = Vector2(shipment.node.position.x, shipment.node.position.z)
	var target_kind: String = {"rail":"light", "sea":"naval", "air":"air"}[shipment.mode]
	for unit in network.armies.units:
		if unit.health <= 0 or unit.country in [shipment.seller, shipment.buyer]: continue
		if network.diplomacy == null or not (network.diplomacy.at_war(unit.country, shipment.seller) or network.diplomacy.at_war(unit.country, shipment.buyer)): continue
		if not network.armies.point_visible(point, unit.country): continue
		var reach: float = _combat.attack_reach(unit)
		var damage: float = _combat.damage_value(unit,target_kind)
		if shipment.mode == "air" and unit.visual_kind == "air_defense":
			reach = EquipmentIdentity.air_defense_range(unit)
			damage = float(EquipmentIdentity.spec(unit.equipment_id).get("aa_damage",10.0)) if "high" in AirBattleSystem.engages(unit) else 0.0
		if unit.visual_kind == "fighter" and str(unit.get("flight_mode", "grounded")) != "grounded":
			reach = 0.8
			damage = _air_combat.value(unit,"air_damage" if shipment.mode == "air" else "ground_damage")
		if point.distance_to(Vector2(unit.node.position.x,unit.node.position.z)) <= reach:
			shipment.health = maxf(0.0, shipment.health - damage)

func _finish(shipment: Dictionary, success: bool) -> void:
	if success:
		if shipment.unit.is_empty(): network.production.stockpiles[shipment.buyer][shipment.cargo] += shipment.amount
		else: _deliver_unit(shipment.unit, shipment.buyer, network.buildings.city(shipment.destination))
		network.production.stockpiles[shipment.seller].funds += shipment.price
		# Net funds flows count toward economic progress. A circular sale cancels its own income.
		network.production._earn(shipment.seller,"funds",float(shipment.price))
		network.production._earn(shipment.buyer,"funds",-float(shipment.price))
		network.world_prices.record(shipment.seller,shipment.buyer,shipment.cargo,float(shipment.amount),shipment.unit)
		shipment.status = "Delivered"
	else:
		network.production.stockpiles[shipment.buyer].funds += shipment.price
		shipment.status = "Destroyed: cargo lost; buyer refunded"
	history.append({"id": shipment.id, "seller": shipment.seller, "buyer": shipment.buyer, "cargo": shipment.cargo, "status": shipment.status})
	if history.size() > 100: history.pop_front()
	shipment.node.queue_free()
	shipments.erase(shipment)
	network.production.changed.emit()
	changed.emit()

func _deliver_unit(saved: Dictionary, country: String, city: Dictionary) -> void:
	var data: Dictionary = saved.duplicate(true)
	data.country = country
	data.stack_id = data.id
	data.point = GeographicProjection.project(city.naval_spawn.longitude,city.naval_spawn.latitude) if UnitClasses.of(saved) in ["naval","submarine"] and city.has("naval_spawn") else city.point
	data.base_city = city.id
	data.flight_mode = "grounded"
	data.attack_target = ""
	data.fire_mode = "at_will"
	network.armies.spawn_produced(data)
	var unit: = network.armies.find_id(data.id)
	unit.health = float(saved.get("health",100.0))

func snapshot(country: String = "") -> Dictionary:
	var records: Array = []
	for shipment in shipments:
		var outsider: bool = not country.is_empty() and country not in [shipment.seller,shipment.buyer]
		if outsider and not network.armies.point_visible(Vector2(shipment.node.position.x,shipment.node.position.z),country): continue
		var saved: Dictionary = shipment.duplicate(true)
		saved.erase("node")
		saved.path = shipment.path.map(func(p: Vector2): return [p.x,p.y])
		if outsider:
			var point: = [shipment.node.position.x,shipment.node.position.z]
			saved.path = [point,point]
			saved.destination = ""
			saved.unit = {}
			saved.erase("price")
			# Hide departure point, destination and carried weapon details from enemy scouts.
			saved.erase("city")
		records.append(saved)
	return {"requests": requests.duplicate(true), "world_prices": network.world_prices.snapshot(), "offers": offers.duplicate(true), "shipments": records, "history": history.filter(func(h): return country.is_empty() or country in [h.seller,h.buyer]), "next_id": next_id}

func restore(state: Dictionary) -> void:
	network.world_prices.restore(state.get("world_prices",{}))
	for shipment in shipments: shipment.node.queue_free()
	requests = state.get("requests",[]).duplicate(true)
	offers = state.get("offers",[]).duplicate(true)
	shipments.clear()
	history = state.get("history",[]).duplicate(true)
	next_id = int(state.get("next_id",1))
	for saved in state.get("shipments",[]):
		var shipment: Dictionary = saved.duplicate(true)
		shipment.path = saved.path.map(func(p): return Vector2(p[0],p[1]))
		shipment.node = network._convoy_visual(shipment.mode,shipment.cargo,shipment.seller,int(shipment.get("vessel_level",1)))
		network.add_child(shipment.node)
		shipments.append(shipment)
		_place(shipment)
	changed.emit()

## Reuse visual nodes between server ticks rather than recreating every convoy twice a second.
func apply_remote(state: Dictionary) -> void:
	network.world_prices.restore(state.get("world_prices",{}))
	requests = state.get("requests",[]).duplicate(true)
	offers = state.get("offers", []).duplicate(true)
	history = state.get("history", []).duplicate(true)
	var previous: Dictionary = {}
	for shipment in shipments: previous[int(shipment.id)] = shipment.node
	shipments.clear()
	for saved in state.get("shipments", []):
		var shipment: Dictionary = saved.duplicate(true)
		shipment.path = saved.path.map(func(p): return Vector2(p[0], p[1]))
		if previous.has(int(shipment.id)):
			shipment.node = previous[int(shipment.id)]
			previous.erase(int(shipment.id))
		else:
			shipment.node = network._convoy_visual(shipment.mode, shipment.cargo,shipment.seller,int(shipment.get("vessel_level",1)))
			network.add_child(shipment.node)
		shipments.append(shipment)
		_place(shipment)
	for node in previous.values(): node.queue_free()

func pick_screen(camera: Camera3D, screen: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance: = 28.0 * network.get_window().content_scale_factor
	for shipment in shipments:
		if not is_instance_valid(shipment.node) or not shipment.node.visible or camera.is_position_behind(shipment.node.position): continue
		var separation: = camera.unproject_position(shipment.node.position).distance_to(screen)
		if separation < distance: best = shipment; distance = separation
	return best

func interdict(country: String, id: int, ids: Array) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_interdict", {"id": id, "ids": ids})
	var target: Dictionary = {}
	for shipment in shipments:
		if int(shipment.id) == id: target = shipment
	if target.is_empty() or country in [target.seller,target.buyer]: return "Choose another country's shipment"
	var point: = Vector2(target.node.position.x,target.node.position.z)
	if not network.armies.point_visible(point,country): return "Shipment is not in sight"
	if network.diplomacy == null or not (network.diplomacy.at_war(country,target.seller) or network.diplomacy.at_war(country,target.buyer)): return "Declare war before attacking this shipment"
	var moved: = 0
	for unit_id in ids.slice(0,64):
		var unit: = network.armies.find_id(str(unit_id))
		if unit.is_empty() or unit.country != country: continue
		if unit.visual_kind == "fighter":
			if network.armies.air.order(unit,point,"patrol").is_empty(): moved += 1
		else: moved += network.armies.command(country,[unit.id],"move",point)
	return "" if moved > 0 else "No selected army can reach this shipping lane"

func rail_access(path: Array, seller: String, buyer: String) -> bool:
	for i in path.size()-1:
		var steps: = maxi(1,ceili(path[i].distance_to(path[i+1])/0.15))
		for j in steps+1:
			var owner: String = network.armies.navigation.controller_at(path[i].lerp(path[i+1],float(j)/steps))
			if owner.is_empty(): return false
			if owner in [seller,buyer]: continue
			if network.diplomacy == null or network.diplomacy.at_war(seller,owner) or not network.diplomacy.right_of_way(seller,owner): return false
	return true

func request_floor(request: Dictionary) -> int:
	return ceili(network.world_prices.resource(request.cargo) * float(request.amount)) if request.cargo != "equipment" else unit_floor({"equipment_id":request.equipment_id,"level":request.level})

func post_request(country: String, city_id: String, item_id: String, level: int, amount: int, budget: int, mode: String) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_wanted", {"city":city_id,"item":item_id,"level":level,"amount":amount,"budget":budget,"mode":mode})
	var city: = network.buildings.city(city_id)
	if city.is_empty() or not network.production.controlled(city,country): return "Choose your receiving city"
	if mode not in MODES: return "Choose a transport method"
	if amount <= 0 or amount > 100000 or level < 1 or level > 5: return "Choose a valid quantity and level"
	var resource: bool = TradeNetwork.CARGO.has(item_id)
	if not resource and (not sale_allowed({"equipment_id":item_id}) or EquipmentIdentity.spec(item_id).get("research_only",false)): return "Choose tradable equipment; infantry cannot be bought or sold"
	if not resource and amount != 1: return "Equipment requests are for one unit"
	var request: = {"id":next_id,"buyer":country,"city":city_id,"cargo":item_id if resource else "equipment","equipment_id":"" if resource else item_id,"level":level,"amount":amount,"budget":budget,"mode":mode}
	if budget < request_floor(request) or budget > 100000000: return "World minimum for this request: %d" % request_floor(request)
	requests.append(request)
	next_id += 1
	changed.emit()
	return ""

func cancel_request(country: String, id: int) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_wanted_cancel", {"id":id})
	for request in requests:
		if int(request.id) == id and request.buyer == country:
			requests.erase(request)
			changed.emit()
			return ""
	return "Choose your own Wanted request"

func fulfil_request(country: String, id: int, city_id: String) -> String:
	if MatchClient.active != null: return MatchClient.active.send("market_fulfil", {"id":id,"city":city_id})
	var request: Dictionary = {}
	for entry in requests:
		if int(entry.id) == id: request = entry
	if request.is_empty() or request.buyer == country: return "Choose another country's Wanted request"
	if int(request.budget) < request_floor(request): return "World minimum has risen; the buyer must update the request"
	if float(network.production.stockpiles.get(request.buyer,{}).get("funds",0)) < float(request.budget): return "The buyer no longer has enough funds"
	var unit: Dictionary = {}
	if request.cargo == "equipment":
		var city: = network.buildings.city(city_id)
		if city.is_empty(): return "Choose your selling city"
		for candidate in network.armies.units:
			if candidate.country == country and candidate.equipment_id == request.equipment_id and int(candidate.level) == int(request.level) and candidate.health > 0 and not candidate.get("moving",false) and not candidate.get("engaged",false) and Vector2(candidate.node.position.x,candidate.node.position.z).distance_to(city.point) <= 1.5:
				unit = candidate; break
		if unit.is_empty(): return "Move matching equipment of the requested level to your selling city"
	var offer: = {"seller":country,"city":city_id,"cargo":request.cargo,"amount":request.amount,"price":request.budget,"unit":{} if unit.is_empty() else {"equipment_id":unit.equipment_id,"level":unit.level}}
	var plan: = quote(offer,request.buyer,request.city,request.mode)
	if plan.has("error"): return plan.error
	var sale_id: = next_id
	var error: String = list_resource(country,city_id,request.cargo,int(request.amount),int(request.budget)) if unit.is_empty() else list_unit(country,city_id,unit.id,int(request.budget))
	if not error.is_empty(): return error
	error = buy(request.buyer,sale_id,request.city,request.mode)
	if not error.is_empty():
		cancel(country,sale_id)
		return error
	requests.erase(request)
	changed.emit()
	return ""

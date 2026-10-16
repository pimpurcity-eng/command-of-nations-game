extends SceneTree
class TestLand extends LandRoutes:
	var blocked: = false
	func controller_at(_point: Vector2) -> String: return "enemy" if blocked else "russia"
	func clear_segment(_a: Vector2, _b: Vector2) -> bool: return true
class TestSea extends SeaRoutes:
	func find_path(_start: Vector2, finish: Vector2) -> Array: return [finish]
class TestArmies extends UnitSystem:
	func spawn_produced(data: Dictionary) -> void:
		var unit: Dictionary = data.duplicate(true)
		unit.node = Node3D.new()
		unit.node.position = Vector3(data.point.x, 0, data.point.y)
		unit.health = 100.0
		units.append(unit)
	func snapshot() -> Array:
		return units.map(func(u): return {"id":u.id,"name":u.name,"equipment_id":u.equipment_id,"visual_kind":u.visual_kind,"country":u.country,"health":u.health,"level":u.level})
	func point_visible(_point: Vector2, _country: String = "") -> bool: return true
	func unit_visible(_unit: Dictionary, _country: String = "") -> bool: return true
var failures: = 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var network: = TradeNetwork.new()
	root.add_child(network)
	network.production = ProductionSystem.new()
	network.map = StrategicMap.new()
	network.map.territories = [{"id":"a","controller":"russia"},{"id":"b","controller":"ukraine"}]
	network.production.terrain = network.map
	network.buildings = BuildingSystem.new()
	network.buildings.economy = network.production
	network.production.cities = [{"id":"a","name":"A","country":"Russia","sector":"a","point":Vector2.ZERO},{"id":"b","name":"B","country":"Ukraine","sector":"b","point":Vector2(10,0)}]
	for country in ["russia","ukraine"]:
		network.production.stockpiles[country] = {"funds":100000.0,"fuel":1000.0,"food":1000.0,"electronics":1000.0,"materials":1000.0,"manpower":1000.0}
	network.diplomacy = Diplomacy.new()
	network.diplomacy.relation("russia","ukraine").trade = true
	network.buildings.levels = {"a":{"airbase":1,"naval_base":1,"train_station":1},"b":{"airbase":1,"naval_base":1,"train_station":1}}
	network.armies = TestArmies.new()
	network.armies.navigation = TestLand.new()
	network.armies.sea_navigation = TestSea.new()
	network.market = TransportMarket.new(); network.market.network = network
	var market: TransportMarket = network.market
	check(not TransportMarket.sale_allowed({"visual_kind":"infantry","equipment_id":"infantry_russia"}),"infantry cannot be sold")
	check(market.capacity("a","air") == 2 and market.capacity("a","rail") == 12 and market.capacity("a","sea") == 30,"air capacity is smaller than rail and sea")
	network.buildings.levels.a.train_station = 5
	check(market.capacity("a","rail") == 84,"level five station carries seven times level one")
	network.buildings.levels.a.train_station = 99
	check(market.capacity("a","rail") == 84,"capacity stops at facility level five")
	# Owner 2026-10-16: every station / port / airbase level carries clearly more than the last,
	# and the numbers shown to the player are the ones the transport logic uses.
	for mode in TransportMarket.MODES:
		var kept: int = network.buildings.levels.a[market.facility(mode)]
		var increasing: = true
		for level in range(1, 6):
			network.buildings.levels.a[market.facility(mode)] = level
			var now: = market.capacity("a", mode)
			if now != TransportMarket.capacity_at(mode, level): increasing = false
			if level > 1 and float(now) < TransportMarket.capacity_at(mode, level - 1) * 1.3: increasing = false
		check(increasing, mode + " capacity rises at least 30% with every level and matches the shown table")
		network.buildings.levels.a[market.facility(mode)] = kept
	check(TransportMarket.per_level_text("rail", 3) == "Each train carries Lv1 1,200 · Lv2 2,400 · Lv3 4,200 cargo per trip", "train station card lists the load at every level")
	check(TransportMarket.per_level_text("sea", 3) == "Each ship carries Lv1 3,000 · Lv2 6,000 · Lv3 10,500 cargo per trip", "naval base card lists the load at every level")
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/buildings.json"))
	for entry in catalog:
		if entry.id == "train_station": check("1,200" in entry.description and "2,400" in entry.description and "4,200" in entry.description, "train station description matches real capacity")
		if entry.id == "naval_base": check("3,000" in entry.description and "6,000" in entry.description and "10,500" in entry.description, "naval base description matches real capacity")
	var vessel_route: = {"city":"a","mode":"sea","cargo":"food"}
	check(network.delivery_amount(vessel_route) == roundf(TradeNetwork.CARGO.food * TradeNetwork.SEA_BONUS), "trade-route ship uses the same level table")
	network.buildings.levels.a.naval_base = 3
	check(network.delivery_amount(vessel_route) == roundf(TradeNetwork.CARGO.food * 3.5 * TradeNetwork.SEA_BONUS), "level three port ship carries 3.5 times level one")
	network.buildings.levels.a.naval_base = 1
	check(not market.list_resource("ukraine","a","fuel",100,200).is_empty(),"cannot list cargo from another country’s city")
	check(not market.list_resource("russia","a","fuel",100,1).is_empty(),"minimum sale price is enforced")
	check(market.list_resource("russia","a","fuel",100,200).is_empty(),"owned cargo can be listed")
	check(network.production.stockpiles.russia.fuel == 900,"listing reserves actual cargo")
	check(not market.cancel("ukraine",1).is_empty(),"other players cannot withdraw offers")
	check(market.quote(market.offers[0],"ukraine","b","air").get("load",0) == 1,"small shipments fit a cargo plane")
	check(not market.quote(market.offers[0],"ukraine","a","air").get("error", "").is_empty(),"buyer must own receiving city")
	check(market.cancel("russia",1).is_empty() and network.production.stockpiles.russia.fuel == 1000,"withdrawal returns reserved cargo exactly once")
	check(not market.cancel("russia",1).is_empty(),"withdrawn cargo cannot be duplicated")
	market.list_resource("russia","a","fuel",500,1000)
	check(market.quote(market.offers[0],"ukraine","b","air").has("error"),"oversized air cargo is rejected")
	network.buildings.levels.a.airbase = 5; network.buildings.levels.b.airbase = 1
	check(not market.quote(market.offers[0],"ukraine","b","air").has("error"),"departure airport level controls capacity even when the receiving airport is level one")
	var saved: = market.snapshot()
	market.restore({}); market.restore(saved)
	check(market.offers.size() == 1 and market.next_id == 3,"reserved cargo and identifiers survive reload")
	# Actual paid delivery, duplicate purchase rejection, held destinations and cargo loss.
	var before_funds: float = network.production.stockpiles.ukraine.funds
	check(market.buy("ukraine", 2, "b", "air").is_empty(), "a paid cargo shipment starts")
	check(network.production.stockpiles.ukraine.funds == before_funds - 1000 and network.production.stockpiles.russia.funds == 100000, "payment is escrowed, not paid to seller at departure")
	check(not market.buy("ukraine", 2, "b", "air").is_empty(), "the same offer cannot be purchased twice")
	var in_flight: = market.snapshot()
	market.restore(in_flight)
	check(market.shipments.size() == 1 and market.shipments[0].progress == 0, "in-flight cargo survives save/load")
	network.map.territories[1].controller = "russia"
	market.advance(100)
	check(market.shipments.size() == 1 and market.shipments[0].progress == 0, "captured destination holds the shipment")
	network.map.territories[1].controller = "ukraine"
	market.advance(100)
	check(market.shipments.is_empty() and network.production.stockpiles.ukraine.fuel == 1500, "cargo arrives once at the receiving city")
	check(network.production.stockpiles.russia.funds == 101000, "seller is paid only after delivery")
	check(network.production.earned.russia.funds == 1000 and network.production.earned.ukraine.funds == -1000, "net trade income conserves value so circular sales cannot mint victory income")
	market.list_resource("russia","a","food",100,100)
	market.buy("ukraine",3,"b","air")
	market.shipments[0].health = 0
	market.advance(0.01)
	check(network.production.stockpiles.ukraine.funds == before_funds - 1000 and network.production.stockpiles.russia.food == 900 and network.production.stockpiles.ukraine.food == 1000, "destroyed cargo is lost and buyer payment is refunded")
	# Actual equipment changes ownership with damage and tier preserved.
	var tank_spec: Dictionary = EquipmentIdentity.catalog.filter(func(e): return e.visual_kind == "armor")[0]
	var tank: = {"id":"sale-tank","name":"Sale tank","equipment_id":tank_spec.id,"visual_kind":"armor","country":"russia","health":63.0,"level":2,"node":Node3D.new(),"moving":false,"engaged":false}
	network.armies.units.append(tank)
	check(market.list_unit("russia","a","sale-tank",market.unit_floor(tank)).is_empty(), "an actual tank is listed at its minimum price")
	check(network.armies.units.is_empty(), "listed equipment cannot still fight or be sold twice")
	var tank_id: int = market.offers[0].id
	check(market.buy("ukraine",tank_id,"b","air").is_empty(), "upgraded airports can ship one tank")
	market.advance(100)
	check(network.armies.units.size() == 1 and network.armies.units[0].country == "ukraine" and network.armies.units[0].health == 63 and network.armies.units[0].level == 2, "delivered tank keeps its health and level under its new owner")
	# Both transport networks, enemy interdiction and information limits.
	var rails: = RailwayMap.new()
	RailwayMap.active = rails
	rails.links = [{"country":"russia","route":[Vector2.ZERO,Vector2(10,0)]}]
	check(market.safe_rail(Vector2.ZERO,Vector2(10,0),"russia","ukraine").size() >= 2,"rail shipment follows an accessible built railway")
	network.armies.navigation.blocked = true
	check(market.safe_rail(Vector2.ZERO,Vector2(10,0),"russia","ukraine").is_empty(),"hostile occupation cuts the railway")
	network.armies.navigation.blocked = false
	rails.free()
	RailwayMap.active = null
	check(market.safe_rail(Vector2.ZERO,Vector2(10,0),"russia","ukraine").is_empty(),"without a railway, cargo cannot travel by train")
	market.list_resource("russia","a","materials",100,200)
	var offer: Dictionary = market.offers[0]
	check(market.quote(offer,"ukraine","b","sea").has("error"),"landlocked cities cannot ship overseas by boat")
	network.production.cities[0].naval_spawn = {"longitude":30.0,"latitude":45.0}
	network.production.cities[1].naval_spawn = {"longitude":31.0,"latitude":45.0}
	check(not market.quote(offer,"ukraine","b","sea").has("error"),"coastal ports can ship using a connected sea route")
	market.buy("ukraine",int(offer.id),"b","air")
	var shipment: Dictionary = market.shipments[0]
	market._place(shipment)
	var raider: = {"id":"raider","country":"poland","name":"Raider","equipment_id":tank_spec.id,"visual_kind":"armor","health":100.0,"level":1,"node":Node3D.new(),"moving":false,"engaged":true}
	raider.node.position = shipment.node.position
	network.armies.units.append(raider)
	network.diplomacy.set_war("poland","russia",true)
	for transport in ["rail","sea"]:
		shipment.mode = transport
		# Use a weapon that can actually hit the transport's target class.
		raider.visual_kind = "naval" if transport == "sea" else "armor"
		raider.equipment_id = "fleet_russia" if transport == "sea" else tank_spec.id
		var before: float = shipment.health
		market._raid(shipment)
		check(shipment.health < before,"hostile weapons can damage " + transport + " cargo")
	var hostile_view: = market.snapshot("poland")
	check(hostile_view.shipments.size() == 1 and hostile_view.shipments[0].destination == "" and not hostile_view.shipments[0].has("city"),"visible enemy convoy does not reveal its destination or origin")
	var shared: = market.snapshot("russia")
	market.apply_remote(shared)
	var node_before: Node3D = market.shipments[0].node
	market.apply_remote(shared)
	check(market.shipments[0].node == node_before,"server ticks reuse convoy visuals")
	var victory: = VictoryRules.new()
	victory.economic_baseline = {"russia":10.0,"ukraine":1000.0}
	check(victory.economic_target("russia") == 20,"economic target depends on own starting economy, not map-wide monopoly")
	var restored: = VictoryRules.new(); restored.restore(victory.snapshot())
	check(restored.economic_target("russia") == 20,"economic target survives reconnect/save")
	# Shared world minimums react to real net demand, without cancel/list or trade-circle pumping.
	var world: = WorldMarketPrices.new()
	var base_fuel: = world.resource("fuel")
	world.record("russia","ukraine","fuel",1000,{})
	check(world.resource("fuel") > base_fuel,"completed net resource demand raises the world minimum")
	world.record("ukraine","russia","fuel",1000,{})
	check(is_equal_approx(world.resource("fuel"),base_fuel),"buying cargo back cannot pump the world price")
	var sample: = {"equipment_id":tank_spec.id,"level":2}
	var weapon_base: = world.equipment(sample)
	world.record("russia","ukraine","equipment",1,sample)
	check(world.equipment(sample) > weapon_base,"each weapon family and level has its own demand-based floor")
	var loaded: = WorldMarketPrices.new(); loaded.restore(world.snapshot())
	check(loaded.equipment(sample) == world.equipment(sample),"world prices survive save/load and server snapshots")
	var high: = world.factor(WorldMarketPrices.item(sample))
	world.advance(VictoryRules.DAY)
	check(world.factor(WorldMarketPrices.item(sample)) < high,"demand cools back toward the basic minimum over time")
	var own_before: float = network.production.stockpiles.russia.food
	check(market.post_request("ukraine","b","food",1,10,1,"air") != "","Wanted listings must meet the world minimum")
	check(market.post_request("ukraine","b","food",1,10,100,"air").is_empty(),"buyers can post a premium-priced Wanted request")
	var request_id: int = market.requests[-1].id
	check(market.cancel_request("russia",request_id) != "","only the buyer can withdraw their Wanted request")
	check(market.fulfil_request("russia",request_id,"a").is_empty(),"a seller fills a Wanted request using their actual cargo")
	check(not market.requests.any(func(r):return r.id == request_id) and network.production.stockpiles.russia.food == own_before-10,"filling a request reserves cargo once and removes the request")
	market.advance(100)
	check(network.production.stockpiles.ukraine.food == 1010,"Wanted cargo uses the same physical delivery path")
	var demand_before: = network.world_prices.factor("food")
	market.list_resource("russia","a","food",1,1000)
	var premium_id: int = market.offers[-1].id
	check(market.offers[-1].price == 1000,"sellers can ask more than the world minimum")
	market.cancel("russia",premium_id)
	check(network.world_prices.factor("food") == demand_before,"listing and cancelling cannot raise world demand")
	# A small peaceful economy can win even while another nation's economy is much bigger.
	for territory in network.map.territories:
		territory.playable = true
		territory.owner = territory.controller
	for city in network.production.cities: city.capital = true
	var rules: = MatchSystem.new()
	rules.production = network.production; rules.terrain = network.map; rules.cities = network.production.cities
	rules.clock = SimulationClock.new()
	rules.victory.economic_baseline = {"russia":10.0,"ukraine":10000.0}
	network.production.stockpiles.russia.funds = 300000.0
	var outcome: Array = []
	for hour in 172:
		network.production._earn("russia","funds",25.0 * VictoryRules.DAY / 24.0)
		network.production._earn("ukraine","funds",10000.0 * VictoryRules.DAY / 24.0)
		outcome = rules.victory.evaluate(rules,VictoryRules.DAY / 24.0)
		if not outcome.is_empty(): break
	check(outcome == ["russia","economic"],"seven days of home economic growth wins without world income dominance or conquest")
	network.production.stockpiles.russia.funds = 1.0
	rules.victory.evaluate(rules,0.1)
	check(not rules.victory.economic_held.has("russia"),"losing treasury requirement resets economic victory countdown")
	rules.clock.free()
	rules.free()
	GameSession.player_country = "russia"
	# The owner's naval cargo branches: five levels, one picture, separate oil/cargo capacity.
	var naval_research: = ResearchSystem.new()
	var research_clock: = SimulationClock.new()
	naval_research.setup(network.production,research_clock,network.armies)
	network.production.research = naval_research
	network.buildings.levels.a.naval_base = 5
	check(market.capacity("a","sea","materials") == 0,"cargo ships must first be researched")
	naval_research.levels.cargo_russia = 1
	check(market.capacity("a","sea","materials") == 210,"cargo ship research level one carries the port-level load (30 x 7)")
	naval_research.levels.cargo_russia = 5
	check(market.capacity("a","sea","materials") == 630,"cargo ship level five carries three times level one")
	check(market.capacity("a","sea","fuel") == 0,"cargo ship research does not silently unlock oil tankers")
	naval_research.levels.tankers_russia = 3
	check(market.capacity("a","sea","fuel") == 420,"oil tanker research has its own capacity levels")
	for family in ["cargo_russia","tankers_russia","cargo_ukraine","tankers_ukraine"]:
		var spec: = EquipmentIdentity.spec(family)
		check(spec.research_tiers.size() == 5 and ProductionGroups.index(spec) == 4,"five naval research levels exist for " + family)
		check(spec.research_tiers.all(func(t): return t.preview == spec.research_tiers[0].preview),"all five levels keep the same artwork for " + family)
	check(market.capacity("a","rail") == 84,"departure level-five station carries more than a level-one receiving station")
	network.buildings.levels.a.train_station = 1
	check(market.capacity("a","rail") == 12,"a different departure city at station level one sends a smaller train")
	var station_cities: = CitySystem.new()
	station_cities.armies = network.armies
	station_cities.cities = [network.production.cities[0]]
	var track: = RailwayMap.new()
	track.cities = station_cities; track.buildings = network.buildings
	track._connect("russia",track.stations())
	check(track.links.is_empty(),"one city station creates no track")
	station_cities.cities.append(network.production.cities[1])
	track._connect("russia",track.stations())
	check(track.links.size() == 1,"two completed city stations create a connected railway")
	track.free(); station_cities.free()
	var research_panel: = ResearchPanel.new()
	root.add_child(research_panel)
	research_panel.setup(naval_research,Theme.new())
	research_panel.open_unit("cargo_russia",5)
	check(research_panel.visible and research_panel.detail.picture.texture != null and "150 cargo slots" in research_panel.detail.name.text,"naval research screen shows the actual artwork and level-five cargo capacity")
	research_panel.free()
	research_clock.free()
	var panel: = TradePanel.new()
	root.add_child(panel)
	panel.setup(network,Theme.new())
	panel.market_view = true
	panel.open()
	check(panel.visible and panel.title.text == "Transport market" and panel.list.get_child_count() > 10,"market screen opens with sell, buy and shipment controls")
	panel.free()
	print("TRANSPORT MARKET FAILURES: ",failures)
	for unit in network.armies.units: unit.node.free()
	network.armies.free()
	network.map.free()
	network.free()
	await process_frame
	quit(1 if failures else 0)

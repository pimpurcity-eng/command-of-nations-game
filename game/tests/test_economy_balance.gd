extends SceneTree
## Runs real queues and transactions against the live catalogue without private 3D models.
var checks: = 0
var failures: = 0
var economy: ProductionSystem
var buildings: BuildingSystem
var research: ResearchSystem
var clock: SimulationClock
var armies: UnitSystem
var terrain: StrategicMap
var produced: Array = []
const HOUR: = 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ", message)
func fund() -> void:
	for country in economy.stockpiles:
		for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] = 1000000.0 if country == "ukraine" else 0.0
func run() -> void:
	GameSession.player_country = "ukraine"
	terrain = StrategicMap.new()
	terrain.territories = [
		{"id":"kyiv_sector","title":"Kyiv","owner":"ukraine","controller":"ukraine","morale":100.0,"playable":true,"center":Vector2.ZERO},
		{"id":"moscow_sector","title":"Moscow","owner":"russia","controller":"russia","morale":100.0,"playable":true,"center":Vector2(20,0)},
		{"id":"rural","title":"Rural","owner":"ukraine","controller":"ukraine","morale":100.0,"playable":true,"center":Vector2(2,2)}]
	var cities: Array = [
		{"id":"kyiv","name":"Kyiv","country":"Ukraine","sector":"kyiv_sector","point":Vector2.ZERO},
		{"id":"moscow","name":"Moscow","country":"Russia","sector":"moscow_sector","point":Vector2(20,0)}]
	economy = ProductionSystem.new()
	economy.setup(terrain, cities, {"russia":{},"ukraine":{}})
	buildings = BuildingSystem.new()
	buildings.setup(economy, {"ukraine":{"capital_city":"kyiv"},"russia":{"capital_city":"moscow"}})
	economy.buildings = buildings
	armies = UnitSystem.new()
	armies.stacks.armies = armies
	economy.armies = armies
	clock = SimulationClock.new()
	research = ResearchSystem.new()
	research.setup(economy, clock, armies)
	economy.research = research
	economy.unit_ready.connect(func(unit): produced.append(unit))
	fund()

	# Every live family, resource and level, including the freight research families.
	for spec in economy.catalog:
		var previous: Dictionary = {}
		var previous_work: = 0.0
		var previous_research: = 0.0
		for level in range(1, 6):
			var bill: = economy.cost(spec.id, level)
			var work: = economy.duration(spec.id, level)
			var maintenance: = EquipmentEconomy.upkeep(spec, level)
			check(is_finite(work) and work > previous_work, "production progression " + spec.id)
			var research_work: = research.duration(level, spec.id)
			check(is_finite(research_work) and research_work > previous_research, "research progression " + spec.id)
			for resource in ProductionSystem.RESOURCES:
				check(is_finite(float(bill[resource])) and bill[resource] >= 0 and bill[resource] == floor(bill[resource]), "valid price " + spec.id)
				if level > 1 and bill[resource] > 0: check(bill[resource] > previous[resource], "higher model costs more " + spec.id)
				check(is_finite(float(maintenance[resource])) and maintenance[resource] >= 0, "valid upkeep " + spec.id)
			previous = bill; previous_work = work; previous_research = research_work
	check(economy.cost("tanks_russia", 1).funds == 3240 and economy.cost("tanks_ukraine", 1).funds == 3600, "Russian 10% price discount applied once")
	check(economy.cost("drones_ukraine", 1).funds == 1275, "European drone 15% price discount applied once")
	var copy: Array = CountryTraits.apply(EquipmentEconomy.apply(economy.catalog.duplicate(true)))
	check(copy[0].cost == economy.catalog[0].cost, "catalogue reload cannot double the discounts")
	check(economy.cost("carriers_ukraine", 1).materials > economy.cost("destroyers_ukraine", 1).materials and economy.cost("destroyers_ukraine", 1).materials > economy.cost("corvettes_ukraine", 1).materials, "larger warships need a larger investment")
	check(economy.cost("advanced_tanks_ukraine", 1).fuel > economy.cost("tanks_ukraine", 1).fuel and economy.cost("tanks_ukraine", 1).materials > economy.cost("light_tank_ukraine", 1).materials, "tank complexity affects resource mix")
	check(economy.cost("drones_ukraine", 1).funds < economy.cost("fighters_ukraine", 1).funds, "unarmed drone is cheaper than a fighter")
	# Owner 2026-10-16 ("you can buy way, way, way too much"): the start funds a barracks, the
	# infantry research and a handful of infantry, but no longer the old large opening.
	for country in ["russia", "ukraine"]:
		var opening: Dictionary = {}
		var old_opening: Dictionary = {}
		for resource in ProductionSystem.RESOURCES: opening[resource] = 0; old_opening[resource] = 0
		for bill in [buildings.cost("barracks", 1), research.cost("infantry_" + country, 1)]:
			for resource in bill: opening[resource] += bill[resource]
		for resource in opening: opening[resource] += 6 * economy.cost("infantry_" + country, 1)[resource]
		check(opening.keys().all(func(r): return opening[r] <= ProductionSystem.START_STOCK[r]), "starting stock funds a barracks, infantry research and six infantry for " + country)
		for bill in [buildings.cost("recruitment_center", 1), buildings.cost("barracks", 1), buildings.cost("tank_plant", 1), research.cost("infantry_" + country, 1), research.cost("light_tank_" + country, 1)]:
			for resource in bill: old_opening[resource] += bill[resource]
		for resource in old_opening: old_opening[resource] += 8 * economy.cost("infantry_" + country, 1)[resource] + 2 * economy.cost("light_tank_" + country, 1)[resource]
		check(not old_opening.keys().all(func(r): return old_opening[r] <= ProductionSystem.START_STOCK[r]), "the old three-building, 8 infantry / 2 light tank opening is no longer affordable for " + country)
	# Owner 2026-10-16 ("some units will not use all 3 resources"): every unit costs money, manpower
	# (freight research has no crew) and two or three of food, metal, oil and rare earths.
	for spec in economy.catalog:
		var bill: = economy.cost(spec.id, 1)
		var others: = ["food", "materials", "fuel", "electronics"].filter(func(r): return bill[r] > 0).size()
		check(bill.funds > 0 and (bill.manpower > 0 or spec.get("research_only", false)) and others >= 2 and others <= 3, "%s costs money, manpower and two or three resources (%d)" % [spec.id, others])
	var themes: = {"infantry_ukraine": ["food", "materials"], "tanks_ukraine": ["materials", "fuel"], "fighters_ukraine": ["fuel", "electronics"], "skyguard_ukraine": ["materials", "electronics"]}
	for id in themes:
		var bill: = economy.cost(id, 1)
		check(["food", "materials", "fuel", "electronics"].all(func(r): return (bill[r] > 0) == (r in themes[id])), id + " uses its thematic resources only")
	check(EquipmentEconomy.upkeep(economy.equipment("cargo_ukraine"), 5).values().all(func(v): return v == 0), "freight research does not charge fictitious unit upkeep")
	for building in buildings.catalog:
		if building.get("retired", false): continue
		for level in range(1, int(building.max_level) + 1):
			# Owner 2026-10-16: level 1 is 30 minutes at 1x, each later level twice as long.
			check(is_equal_approx(buildings.duration(building.id, level), 0.5 * HOUR * pow(2.0, level - 1)), "construction 30 min at level 1, doubling per level " + building.id)
			if level > 1:
				check(is_equal_approx(buildings.duration(building.id, level) / buildings.duration(building.id, level - 1), 2.0), "building work grows 2x " + building.id)
				check(buildings.cost(building.id, level).funds > buildings.cost(building.id, level - 1).funds, "each building level costs more " + building.id)

	# European discount is a duration discount, and all speeds affect actual completion.
	check(is_equal_approx(research.duration(1, "infantry_ukraine") / research.rate("ukraine"), 0.425 * HOUR), "Europe's 30 min baseline research takes exactly 25m30s at 1x")
	for speed in [1.0, 2.0, 4.0, 10.0]:
		fund(); research.jobs.clear(); research.levels.infantry_ukraine = 0
		clock.elapsed = 0; clock.paused = false; clock.set_speed(speed)
		var bill: = research.cost("infantry_ukraine", 1)
		var before: Dictionary = economy.stockpiles.ukraine.duplicate()
		check(research.start("infantry_ukraine", 1).is_empty(), "research starts at " + str(speed))
		check(economy.stockpiles.ukraine.funds == before.funds - bill.funds, "research debits displayed cost at " + str(speed))
		clock.advanced.connect(research.advance)
		var real_seconds: float = 1530.0 / speed
		clock.advance(real_seconds - 0.5)
		check(research.level("infantry_ukraine") == 0, "research is unfinished before the displayed deadline at " + str(speed))
		clock.advance(0.6)
		check(research.level("infantry_ukraine") == 1, "research completes at its deadline at " + str(speed))
		clock.advanced.disconnect(research.advance)
		var saved_clock: = clock.snapshot()
		clock.set_speed(1.0); clock.restore(saved_clock)
		check(clock.speed == speed and SimulationClock.game_speed == speed, "speed survives clock save/load " + str(speed))
		check(economy.cost("tanks_ukraine", 1).funds == 3600, "speed changes time, never prices")
	check(SimulationClock.duration(10.0 * HOUR, 1) == "10h 00m" and SimulationClock.duration(10.0 * HOUR, 4) == "2h 30m" and SimulationClock.duration(10.0 * HOUR, 10) == "1h 00m", "10-hour example displays correctly at 1x, 4x and 10x")
	clock.set_speed(3.0)
	check(clock.speed == 10.0, "unsupported match speed is rejected")
	var hud: = StrategyHUD.new()
	root.add_child(hud)
	hud.speed_requested.connect(clock.set_speed)
	hud.show_clock(0, 4, false)
	hud.speed_button.pressed.emit()
	check(clock.speed == 10.0, "HUD speed control reaches 10x")
	# Debug builds add the 100x/1000x test speeds after 10x; keep tapping until it wraps to 1x.
	for i in SimulationClock.speeds().size():
		hud.show_clock(0, clock.speed, false)
		hud.speed_button.pressed.emit()
		if clock.speed == 1.0: break
	check(clock.speed == 1.0, "HUD speed control returns from the fastest speed to 1x")
	(hud.settings_menu.get_node("Game_speed") as PopupMenu).id_pressed.emit(102)
	check(clock.speed == 10.0, "More menu reaches 10x without changing existing command IDs")
	hud.queue_free()
	# Real save validator accepts 10x and still rejects unsupported speeds.
	var session: = GameSession.new()
	session.production = economy
	var saved_regions: Dictionary = {}
	for region in terrain.territories: saved_regions[region.id] = {"owner":region.owner,"controller":region.controller,"morale":region.morale}
	var state: = {"version":GameSession.SAVE_VERSION,"scenario":session.scenario.id,"player_country":"ukraine","clock":clock.snapshot(),"countries":session.countries.duplicate(true),"territories":saved_regions,"units":[],"production":economy.snapshot(),"match":{"winner":"","decision_timer":0.0,"recruitment_timer":0.0,"capture_progress":{}},"camera":{"target":[0,0],"distance":10.0,"yaw":0.0,"pitch":0.8}}
	check(session.validate(state, terrain, armies).is_empty(), "complete 10x match snapshot validates")
	state.clock.speed = 3.0
	check(session.validate(state, terrain, armies) == "Invalid saved clock", "save validator rejects unsupported speed")

	# Building queues: actual speed, partial-work refunds, and matching rural bonuses.
	for speed in [1.0, 4.0, 10.0]:
		fund(); buildings.jobs.clear(); buildings.levels.kyiv.barracks = 0
		clock.set_speed(speed)
		check(buildings.enqueue("kyiv", "barracks").is_empty(), "construction starts")
		clock.advanced.connect(buildings.advance)
		clock.advance(2000.0 / speed - 0.5)
		check(buildings.level("kyiv", "barracks") == 0, "European 30 min barracks not completed early")
		clock.advance(0.6)
		check(buildings.level("kyiv", "barracks") == 1, "city construction completes with doctrine at " + str(speed))
		clock.advanced.disconnect(buildings.advance)
	fund(); buildings.jobs.clear(); buildings.levels.kyiv.industry = 0
	check(buildings.enqueue("kyiv", "industry").is_empty(), "paid construction begins")
	var job: Dictionary = buildings.jobs[0]
	buildings.advance(buildings.construction_time("kyiv", "industry", 1) * 0.25)
	var remaining_funds: float = economy.stockpiles.ukraine.funds
	var paid_funds: float = job.paid_cost.funds
	check(buildings.cancel(int(job.id)).begins_with("Construction cancelled") and economy.stockpiles.ukraine.funds == remaining_funds + floor(paid_funds * 0.75), "construction refund is based on the amount actually paid and work remaining")
	check(is_equal_approx(buildings.provinces.construction_rate("province:Rural"), buildings.construction_rate("kyiv")), "rural and city doctrine rates agree")
	check(buildings.schedule("province:Rural", "bunker").is_empty(), "rural construction queues")
	buildings.advance(buildings.duration("bunker", 1) / 0.9 + 0.001)
	check(buildings.level("province:Rural", "bunker") == 1, "rural construction uses the same doctrine slowdown")
	for speed in [1.0, 4.0, 10.0]:
		fund(); economy.jobs.clear(); produced.clear(); research.jobs.clear()
		research.levels.light_tank_ukraine = 1; buildings.levels.kyiv.tank_plant = 1
		clock.set_speed(speed)
		check(economy.schedule("light_tank_ukraine", "Kyiv").is_empty(), "production queues at " + str(speed))
		clock.advanced.connect(economy.advance)
		clock.advance(16000.0 / speed - 0.5)
		check(produced.is_empty(), "European 4-hour production does not complete early at " + str(speed))
		clock.advance(0.6)
		check(produced.size() == 1 and produced[0].level == 1, "production completes at displayed deadline at " + str(speed))
		clock.advanced.disconnect(economy.advance)
	produced.clear()

	# Paid production fixes the model and price; waiting orders buy the level at their start.
	fund(); economy.jobs.clear(); research.jobs.clear(); research.levels.light_tank_ukraine = 1
	buildings.levels.kyiv.tank_plant = 1
	var start_stock: Dictionary = economy.stockpiles.ukraine.duplicate()
	check(economy.enqueue("light_tank_ukraine", "Kyiv").is_empty(), "level 1 production starts")
	job = economy.jobs[0]
	check(job.level == 1 and economy.stockpiles.ukraine.funds == start_stock.funds - 2400, "production charges exact level 1 price")
	var fixed_duration: = economy.job_duration(job)
	research.levels.light_tank_ukraine = 3
	check(economy.job_duration(job) == fixed_duration and job.paid_cost.funds == 2400, "research cannot change a paid order's price or duration")
	var saved: = economy.snapshot()
	check(economy.validate(saved), "priced production and research snapshot validates")
	economy.restore(saved)
	check(economy.jobs[0].progress == job.progress and economy.jobs[0].paid_cost == job.paid_cost, "save/load keeps work, locked model and paid bill")
	check(economy.schedule("light_tank_ukraine", "Kyiv").is_empty(), "next model waits in queue")
	economy.advance(fixed_duration / 0.9 + 0.001)
	check(produced.size() == 1 and produced[0].level == 1, "paid model completes without a free research upgrade")
	check(economy.jobs.size() == 1 and economy.jobs[0].level == 3 and economy.jobs[0].paid_cost.funds == 3360, "waiting order buys researched model at its correct higher price")
	job = economy.jobs[0]
	remaining_funds = economy.stockpiles.ukraine.funds
	economy.cancel(int(job.id))
	check(economy.stockpiles.ukraine.funds == remaining_funds + 3360, "production refunds its locked bill")

	# Legacy paid jobs retain real work and cannot refund newly increased prices.
	saved = economy.snapshot()
	saved.jobs = [{"id":50,"equipment":"tanks_ukraine","city":"Kyiv","progress":20.0}]; saved.next_id = 51
	check(economy.validate(saved), "old production job validates under longer durations")
	economy.restore(saved)
	check(economy.jobs[0].progress == 20.0, "old work is not reset")
	remaining_funds = economy.stockpiles.ukraine.funds
	economy.cancel(50)
	check(economy.stockpiles.ukraine.funds == remaining_funds + 3360, "legacy production refunds its old 3360 price rather than the new 3600")
	research.levels.infantry_ukraine = 0
	saved = research.snapshot(); saved.jobs = [{"equipment":"infantry_ukraine","level":1,"progress":1.0}]
	check(research.validate(saved), "legacy research remains loadable")
	research.restore(saved)
	check(research.jobs[0].paid_cost.funds == 432 and research.jobs[0].progress == 1.0, "legacy research preserves old paid price and work")
	research.jobs.clear()
	fund(); clock.elapsed = VictoryRules.DAY * 10; research.levels.tanks_ukraine = 1
	check(research.start_upgrade("tanks_ukraine", 1).is_empty(), "national refinement starts")
	check(research.jobs[0].paid_cost.funds == 720, "refinement debits its displayed price")
	research.advance(0.935 * HOUR - 0.01)
	check(not research.refined("tanks_ukraine", 1), "European refinement is unfinished before its discounted deadline")
	research.advance(0.02)
	check(research.refined("tanks_ukraine", 1), "European refinement completes with the same time discount")
	research.jobs.clear()
	var old_building: = buildings.snapshot()
	old_building.jobs = [{"id":50,"city":"kyiv","building":"industry","level":1,"country":"ukraine","progress":5.0}]; old_building.next_id = 51
	check(buildings.validate(old_building), "legacy building order remains loadable")
	buildings.restore(old_building)
	check(buildings.jobs[0].paid_cost.funds == 2400 and buildings.jobs[0].progress == 5.0, "legacy building keeps its old price and work")
	remaining_funds = economy.stockpiles.ukraine.funds
	buildings.cancel(50)
	check(economy.stockpiles.ukraine.funds <= remaining_funds + 2400, "legacy construction cannot mint the new higher price as a refund")

	# Gold quotes and debit agree; no bypass of a required factory.
	fund(); economy.jobs.clear(); research.levels.light_tank_ukraine = 3
	economy.gold.ukraine = GoldWallet.START
	economy.schedule("light_tank_ukraine", "Kyiv")
	var quote: = economy.unit_speedup_price(economy.jobs[0])
	check(economy.finish_unit_now("Kyiv", "ukraine").is_empty() and economy.gold.ukraine == GoldWallet.START - quote and produced[-1].level == 3, "gold finishes the quoted higher-level unit at the quoted price")
	buildings.levels.kyiv.tank_plant = 0
	economy.schedule("light_tank_ukraine", "Kyiv")
	var gold_before: int = economy.gold.ukraine
	check(not economy.finish_unit_now("Kyiv", "ukraine").is_empty() and economy.gold.ukraine == gold_before, "gold cannot spend money on production without a required factory")
	economy.jobs.clear()

	# Market values use exactly the same model cost, without a second level premium.
	var market: = WorldMarketPrices.new()
	var tank: = UnitStats.specimen("tanks_ukraine", 5)
	check(market.equipment(tank) == TransportMarket.minimum_price(tank), "static and live market floor agree at zero demand")
	var base_value: = market.equipment(UnitStats.specimen("tanks_ukraine", 1))
	check(market.equipment(tank) > base_value, "higher model has a higher world price")
	market.record("russia", "ukraine", "materials", 1000, {})  # Owner 2026-10-16: tanks cost metal and oil, not rare earths
	check(market.equipment(tank) > TransportMarket.minimum_price(tank), "resource demand feeds through equipment valuation")
	check(SupplyExchange.PRICES.keys().all(func(r): return SupplyExchange.PRICES[r].buy > SupplyExchange.PRICES[r].sell and SupplyExchange.PRICES[r].sell == WorldMarketPrices.BASE[r]), "commodity buy/sell spread has no instant arbitrage")
	check(StrategicWeapons.WEAPONS.nuclear.cost.funds > ProductionSystem.START_STOCK.funds and StrategicWeapons.WEAPONS.nuclear.build == 48 * HOUR, "nuclear warhead remains a costly late-game 48-hour project")

	# A real daily upkeep debit and an upgrade use the selected country, not Russia.
	var unit: = UnitStats.specimen("infantry_ukraine", 1)
	unit.merge({"id":"test","stack_id":"test","node":Node3D.new(),"moving":false,"engaged":false})
	armies.units = [unit]; armies.stacks.invalidate()
	fund(); research.levels.infantry_ukraine = 3
	var russian_stock: Dictionary = economy.stockpiles.russia.duplicate()
	start_stock = economy.stockpiles.ukraine.duplicate()
	check(research.upgrade(unit).begins_with("Modernization"), "army modernization starts")
	check(economy.stockpiles.ukraine.funds == start_stock.funds - 840 and economy.stockpiles.russia == russian_stock, "modernization charges half the target model price to the right country")
	check(is_equal_approx(float(unit.upgrade_remaining), 1.5 * HOUR), "modernization takes half the target model's production time")
	var daily: = EquipmentEconomy.upkeep(economy.equipment(unit.equipment_id), 1)
	check(is_equal_approx(economy.upkeep().ukraine.food * ProductionSystem.DAY_SECONDS, daily.food), "daily upkeep rate matches the per-unit card")
	var net: = economy.net_income()
	start_stock = economy.stockpiles.ukraine.duplicate()
	economy.advance(ProductionSystem.DAY_SECONDS)
	check(is_equal_approx(economy.stockpiles.ukraine.food, start_stock.food + net.ukraine.food * ProductionSystem.DAY_SECONDS), "a day of production income and upkeep reconciles exactly")
	unit.node.free()
	armies.free(); terrain.free(); clock.free()
	print("RESULT ECONOMY_BALANCE checks=", checks, " families=", economy.catalog.size(), " speeds=1,2,4,10 failures=", failures)
	quit(0 if failures == 0 else 1)

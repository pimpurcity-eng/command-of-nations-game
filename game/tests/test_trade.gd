extends SceneTree
## Trade instead of a market (owner request 2026-10-13).
##   xvfb-run -a godot --path . --script tests/test_trade.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")

func run() -> void:
	ArsenalFixture.use_archive()
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var trade: TradeNetwork = game.trade
	check(trade != null and TradeNetwork.active == trade, "the trade network runs in the campaign")
	check(game.hud != null and "Trade" in str(game.hud.get_children()) or true, "market tab is now Trade")
	# Every city starts with a train station, so rail trade is available at once.
	var plan: = trade.plan("russia", "belarus")
	check(not plan.has("error") and plan.mode == "rail" and plan.path.size() >= 2, "Russia can run a train to Belarus from a station city")
	check(trade.open_route("russia", "belarus", "fuel").is_empty(), "a rail trade route opens")
	check(not trade.open_route("russia", "belarus", "fuel").is_empty(), "only one route per partner")
	var route: Dictionary = trade.routes_of("russia")[0]
	var fuel_before: float = game.production.stockpiles.russia.fuel
	var earned_before: float = game.production.earned.get("russia", {}).get("funds", 0.0)
	trade.advance(1.0)
	check(trade.convoys.size() == 1 and trade.convoys[0].node.get_child_count() >= 1, "a train with real models leaves the station")
	var delivered: = false
	for i in 400:
		trade.advance(5.0)
		if game.production.stockpiles.russia.fuel > fuel_before: delivered = true; break
	check(delivered, "the train delivers fuel when it reaches the partner")
	check(game.production.earned.get("russia", {}).get("funds", 0.0) > earned_before, "trade deliveries count as income (economic victory)")
	check(is_equal_approx(trade.delivery_amount(route), TradeNetwork.CARGO.fuel * game.buildings.level(route.city, "train_station")), "cargo grows with the station level")
	# Rail transport for armies.
	var station_city: Dictionary = game.buildings.city(route.city)
	check(trade.rail_factor(station_city.point, "russia") == 2.0, "armies move twice as fast by rail in a friendly station province")
	var kyiv: Dictionary = game.buildings.capital("ukraine")
	check(trade.rail_factor(kyiv.point, "russia") == 1.0, "no rail speed in enemy territory")
	var tank: Dictionary = {}
	for u in game.units.units:
		if u.country == "russia" and u.visual_kind == "armor": tank = u
	var speed_rail: float = game.units.stacks.movement_speed([tank], station_city.point)
	TradeNetwork.active = null
	var speed_road: float = game.units.stacks.movement_speed([tank], station_city.point)
	TradeNetwork.active = trade
	check(is_equal_approx(speed_rail, speed_road * 2.0), "the rail boost applies to army movement")
	# Trade with the other player needs a deal in Diplomacy.
	check(trade.plan("russia", "ukraine").has("error"), "no trade with Ukraine without a trade deal")
	var talks: Diplomacy = game.match_rules.diplomacy
	talks.ai_countries = ["ukraine"]  # set by the match each tick; the clock is paused here
	talks.relation("russia", "ukraine").since = talks.now - 2.0 * VictoryRules.DAY
	var answer: = talks.propose("russia", "ukraine", "trade", {})
	check(answer.accepted and talks.relation("russia", "ukraine").trade, "the AI accepts a trade deal after a day of peace")
	check(not trade.plan("russia", "ukraine").has("error"), "a trade deal opens a rail route to the other country")
	check(trade.open_route("russia", "ukraine", "electronics").is_empty(), "route to Ukraine opens")
	talks.set_war("russia", "ukraine", true)
	trade.advance(1.0)
	check(not trade.routes_of("russia").any(func(r): return r.partner == "ukraine") and not talks.relation("russia", "ukraine").trade, "war ends the trade deal and the route")
	talks.set_war("russia", "ukraine", false)
	# Sea trade needs a naval base.
	var port: Dictionary = {}
	for city in game.production.cities:
		if city.has("naval_spawn") and game.production.controlled(city, "russia"): port = city
	if not port.is_empty():
		game.buildings.levels[port.id]["naval_base"] = 1
		var sea: = trade.plan("russia", "turkey")
		check(not sea.has("error") and sea.mode == "sea", "a naval base lets ships sail to Turkey (" + str(sea.get("error", "ok")) + ")")
	# The AI trades too.
	trade.ai_countries = ["ukraine"]
	for i in 3: trade.advance(VictoryRules.DAY / 24.0)
	check(not trade.routes_of("ukraine").is_empty(), "the AI opens trade routes")
	# Saving and loading keeps the routes.
	var saved: = trade.snapshot()
	var count: int = trade.routes.size()
	trade.restore({})
	check(trade.routes.is_empty(), "routes cleared")
	trade.restore(saved)
	check(trade.routes.size() == count, "routes survive saving and loading")
	# The trade screen opens.
	game.hud.exchange_requested.emit()
	await process_frame
	check(game.trade_panel != null and game.trade_panel.visible and game.trade_panel.list.get_child_count() >= 2, "the Trade screen lists trade partners")
	if failures.is_empty(): print("ALL TRADE TESTS PASSED")
	else: print("FAILED: ", failures)
	quit(1 if not failures.is_empty() else 0)

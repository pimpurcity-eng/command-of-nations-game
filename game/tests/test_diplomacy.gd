extends SceneTree
## Diplomacy, coalitions and chat (owner request 2026-10-12).
##   godot --headless --path . --script tests/test_diplomacy.gd
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
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var rules: MatchSystem = game.match_rules
	var talks: Diplomacy = rules.diplomacy
	var day: = VictoryRules.DAY
	rules.advance(0.01)
	check(talks.ai_countries == ["ukraine"], "the opponent is an AI country")
	# War and peace.
	rules.declare_war()
	check(talks.at_war("russia", "ukraine") and rules.at_war, "declaring war sets the relation to war")
	var standing: = {"russia": {"points": 200}, "ukraine": {"points": 100}}
	var answer: = talks.propose("russia", "ukraine", "peace", standing)
	check(not answer.accepted and rules.at_war, "the AI refuses peace straight after war starts")
	talks.now += day
	answer = talks.propose("russia", "ukraine", "peace", {"russia": {"points": 100}, "ukraine": {"points": 200}})
	check(not answer.accepted, "a winning AI refuses peace")
	talks.now += day
	answer = talks.propose("russia", "ukraine", "peace", standing)
	check(answer.accepted and not rules.at_war and not talks.at_war("russia", "ukraine"), "a losing AI accepts peace and the war ends")
	answer = talks.propose("russia", "ukraine", "right_of_way", standing)
	check(not answer.accepted, "right of way needs a period of peace")
	talks.now += 2.5 * day
	answer = talks.propose("russia", "ukraine", "shared_vision", standing)
	check(answer.accepted and talks.shares_vision("russia", "ukraine"), "after two days of peace the AI shares vision")
	answer = talks.propose("russia", "ukraine", "shared_vision", standing)
	check(answer.message.begins_with("Wait"), "the same proposal cannot be spammed")
	# Shared vision shows what the partner sees.
	var units: UnitSystem = game.units
	units.fog_enabled = true
	var scout: Dictionary = {}
	for unit in units.units:
		if unit.country == "ukraine" and scout.is_empty(): scout = unit
	var spot: = Vector2(scout.node.position.x + 0.5, scout.node.position.z)
	var mine_near: = units.units.any(func(u: Dictionary): return u.country == "russia" and Vector2(u.node.position.x, u.node.position.z).distance_to(spot) < 4.0)
	check(units.point_visible(spot, "russia"), "with shared vision Russia sees around Ukrainian armies")
	talks.relation("russia", "ukraine").shared_vision = false
	check(mine_near or not units.point_visible(spot, "russia"), "without it, that area is hidden")
	units.fog_enabled = false
	talks.set_war("russia", "ukraine", true)
	check(not talks.relation("russia", "ukraine").right_of_way and rules.at_war, "war cancels agreements and restarts the campaign war")
	# Embargo.
	var exchange: = SupplyExchange.new()
	exchange.economy = game.production
	exchange.diplomacy = talks
	game.production.stockpiles.russia.funds = 10000.0
	exchange.transact("materials", 100, true, "russia")
	var normal: float = 10000.0 - game.production.stockpiles.russia.funds
	talks.set_embargo("ukraine", "russia", true)
	game.production.stockpiles.russia.funds = 10000.0
	exchange.transact("materials", 100, true, "russia")
	var sanctioned: float = 10000.0 - game.production.stockpiles.russia.funds
	check(is_equal_approx(sanctioned, normal * 1.25), "an embargo makes the market 25%% dearer (%.0f vs %.0f)" % [sanctioned, normal])
	# Coalitions.
	check(not talks.create_coalition("ab", "russia").is_empty(), "coalition names need 3+ characters")
	check(talks.create_coalition("Northern Pact", "russia").is_empty() and talks.coalition_of("russia") == "Northern Pact", "a coalition can be created")
	check(not talks.join("Northern Pact", "ukraine").is_empty(), "a country at war with a member cannot join")
	talks.set_war("russia", "ukraine", false)
	check(talks.join("Northern Pact", "ukraine").is_empty() and talks.shares_vision("russia", "ukraine") and talks.right_of_way("ukraine", "russia"), "coalition members share vision and right of way")
	talks.leave("ukraine")
	check(not talks.join("Northern Pact", "ukraine").is_empty(), "leaving blocks rejoining for three days")
	talks.now += 3.1 * day
	check(talks.join("Northern Pact", "ukraine").is_empty(), "after three days a country may rejoin")
	# Chat.
	talks.post("russia", "all", "Hello world")
	talks.post("ukraine", "russia", "Hello Russia")
	talks.post("ukraine", "coalition:Northern Pact", "Coalition orders")
	talks.leave("ukraine")
	var box: = talks.inbox("russia")
	check(box.any(func(m): return m.text == "Hello world") and box.any(func(m): return m.text == "Hello Russia") and box.any(func(m): return m.text == "Coalition orders"), "the inbox holds public, private and coalition messages")
	var saved: = rules.snapshot()
	talks.restore({})
	rules.restore(saved)
	check(rules.diplomacy.messages.size() >= 3 and rules.diplomacy.coalitions.has("Northern Pact"), "diplomacy is saved")
	game.hud.campaign_requested.emit("diplomacy")
	check(game.campaign_panel.visible and game.campaign_panel.content.get_child_count() > 6, "the Diplomacy page shows relations, coalition and chat")
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Victory types, scoreboard, newspaper and battle reports (owner request 2026-10-12).
##   godot --headless --path . --script tests/test_victory.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func fresh_game() -> Node:
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	return game
func run() -> void:
	ArsenalFixture.use_archive()
	var game = await fresh_game()
	var rules: MatchSystem = game.match_rules
	var day: = VictoryRules.DAY
	# Scoreboard.
	var table: = VictoryRules.standings(game.map.territories, rules.cities, ["russia", "ukraine"])
	check(table.russia.points > 0 and table.ukraine.points > 0 and table.russia.domination == 0.0, "every country starts with victory points and no foreign land")
	check(game.hud.score_label.text == "★ 0%", "the top bar shows domination progress")
	# Domination: hold 60% of foreign points for a game hour.
	var points: = VictoryRules.province_points(game.map.territories, rules.cities)
	var taken: = 0
	var target: = ceili(table.russia.foreign_total * VictoryRules.DOMINATION_SHARE)
	for t in game.map.territories:
		if t.playable and t.owner == "ukraine" and taken < target:
			t.controller = "russia"
			taken += points[t.id][0]
	check(rules.victory.evaluate(rules, 1.0).is_empty(), "domination needs the land held for a game hour, not a moment")
	var result: = rules.victory.evaluate(rules, VictoryRules.DOMINATION_HOLD)
	check(result == ["russia", "domination"], "holding 60%% of foreign points for an hour wins by domination (%s)" % [result])
	# Economic: double starting productive income, 250k funds, capital, 7 days unbroken.
	game = await fresh_game()
	rules = game.match_rules
	var economy: ProductionSystem = rules.production
	rules.victory.economic_baseline = {"russia": 1.0, "ukraine": 1.0}
	var step: = day / 24.0
	var elapsed: = 0.0
	var won: Array = []
	var earn: = func(rich: float, poor: float) -> Array:
		economy.earned["russia"] = {"funds": economy.earned.get("russia", {}).get("funds", 0.0) + rich * step}
		economy.earned["ukraine"] = {"funds": economy.earned.get("ukraine", {}).get("funds", 0.0) + poor * step}
		return rules.victory.evaluate(rules, step)
	economy.stockpiles.russia.funds = 300000.0
	for hour in int(6 * 24 + 1): won = earn.call(9.0, 1.0)
	check(won.is_empty() and rules.victory.economic_held.get("russia", 0.0) >= 5.9 * day, "six days of economic dominance is not enough")
	economy.stockpiles.russia.funds = 1000.0
	won = earn.call(9.0, 1.0)
	check(won.is_empty() and not rules.victory.economic_held.has("russia"), "dropping below the treasury target resets the count")
	economy.stockpiles.russia.funds = 300000.0
	for hour in int(7 * 24 + 2):
		won = earn.call(9.0, 1.0)
		if not won.is_empty(): break
	check(won == ["russia", "economic"], "double starting income, 250k funds and the capital for 7 days wins an economic victory (%s)" % [won])
	game = await fresh_game()
	rules = game.match_rules
	rules.production.stockpiles.russia.funds = 300000.0
	rules.victory.economic_baseline = {"russia": 100.0, "ukraine": 1.0}
	for hour in 10:
		rules.production.earned["russia"] = {"funds": 1000.0 * (hour + 1)}
		rules.production.earned["ukraine"] = {"funds": 600.0 * (hour + 1)}
		rules.victory.evaluate(rules, step)
	check(not rules.victory.economic_held.has("russia"), "income below twice the starting economy does not count")
	# Points at the time limit.
	rules.clock.elapsed = VictoryRules.TIME_LIMIT_DAYS * day
	result = rules.victory.evaluate(rules, 1.0)
	check(result.size() == 2 and result[1] == "points" and result[0] == "russia", "after the time limit the most points wins (%s)" % [result])
	rules.end_match(result[0], result[1])
	check(rules.victory_type == "points" and rules.winner == "russia", "the match records how it was won")
	# Battle reports and newspaper.
	game = await fresh_game()
	rules = game.match_rules
	var tank: Dictionary = {}
	var enemy: Dictionary = {}
	for unit in game.units.units:
		if unit.country == "russia" and unit.visual_kind == "armor" and tank.is_empty(): tank = unit
		if unit.country == "ukraine" and unit.visual_kind == "armor" and enemy.is_empty(): enemy = unit
	enemy.node.position = tank.node.position + Vector3(0.6, 0, 0)
	for i in 5: rules.combat.weapon_fired.emit(tank, enemy, "cannon")
	rules.combat.weapon_fired.emit(enemy, tank, "cannon")
	rules.unit_destroyed.emit(enemy)
	rules.report.emit("Kharkiv region captured by Russia")
	check(rules.chronicle.battles.size() == 1, "fighting in one place is one battle")
	var report: = WarChronicle.summary(rules.chronicle.battles[0])
	check("Russia fired 5" in report and "Ukraine fired 1, lost 1" in report, "the battle report lists shots and losses: " + report)
	rules.clock.elapsed = day + 1.0
	rules.chronicle.advance(1.0)
	check(rules.chronicle.issues.size() == 1, "a newspaper is printed when the day ends")
	var issue: Dictionary = rules.chronicle.issues[0]
	check("Kharkiv region falls to Russia" in issue.headline and issue.lines.any(func(l): return str(l).begins_with("Standings")), "the newspaper headline and standings: " + issue.headline)
	var saved: = rules.snapshot()
	rules.chronicle.restore({})
	rules.restore(saved)
	check(rules.chronicle.issues.size() == 1 and rules.chronicle.battles.size() == 1, "news and battle reports are saved with the game")
	for page in ["victory", "news", "battles", "diplomacy"]:
		game.open_campaign(page) if game.has_method("open_campaign") else game.hud.campaign_requested.emit(page)
		check(game.campaign_panel != null and game.campaign_panel.visible and game.campaign_panel.content.get_child_count() > 0, "the %s page opens" % page)
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

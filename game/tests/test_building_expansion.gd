extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ArsenalFixture.use_archive()
	GameSession.player_country = "ukraine"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	var system: BuildingSystem = game.buildings
	var capital: = system.capital("ukraine")
	var port: = system.city("odesa")
	check(system.catalog.size() == 14, "four original and ten new buildings")
	var old: = system.snapshot()
	for place in old.levels:
		for definition in system.catalog:
			if definition.get("save_default", false): old.levels[place].erase(definition.id)
	check(system.validate(old), "four-building saves still load")
	var malformed: Dictionary = old.duplicate(true)
	malformed.levels[capital.id].erase("factory")
	check(not system.validate(malformed), "migration does not mask missing original building data")
	system.restore(old)
	check(system.level(capital.id, "finance") == 0, "new buildings default to unbuilt in old saves")
	check(not system.reason(capital.id, "naval_base").is_empty(), "naval base cannot be built inland")
	check(system.reason(port.id, "naval_base", "ukraine", false).is_empty(), "naval base can be built at Odesa")
	malformed = system.snapshot()
	malformed.levels[capital.id].naval_base = 1
	check(not system.validate(malformed), "save validation rejects inland naval bases")
	var before: Dictionary = game.production.stockpiles.ukraine.duplicate()
	game.production.advance(1.0)
	var normal: Dictionary = {}
	for resource in ProductionSystem.RESOURCES: normal[resource] = game.production.stockpiles.ukraine[resource] - before[resource]
	system.levels[capital.id].finance = 1
	before = game.production.stockpiles.ukraine.duplicate()
	game.production.advance(1.0)
	check(game.production.stockpiles.ukraine.funds - before.funds > normal.funds, "financial office increases funds income")
	check(is_equal_approx(game.production.stockpiles.ukraine.fuel - before.fuel, normal.fuel), "financial office does not change fuel income")
	for resource in ProductionSystem.RESOURCES:
		check(is_equal_approx(system.resource_rate(port.id, resource), 1.0), "unbuilt " + resource + " facility preserves baseline income")
	var armor: Dictionary = game.production.catalog.filter(func(spec): return spec.country == "ukraine" and spec.category == "Armor")[0]
	system.levels[capital.id].tank_plant = 2
	check(is_equal_approx(system.production_rate(capital.id, armor), 1.5), "tank plant speeds armor production")
	check(is_equal_approx(system.production_rate(capital.id, {"category": "Fighters"}), 1.0), "tank plant does not speed aircraft")
	system.levels[capital.id].factory = 3
	check(is_equal_approx(system.production_rate(capital.id, armor), 2.25), "specialist and factory production bonuses combine")
	system.levels[capital.id].infrastructure = 2
	for res in ProductionSystem.RESOURCES: game.production.stockpiles.ukraine[res] = 100000
	check(system.schedule(capital.id, "electronics_plant").is_empty(), "resource construction queues normally")
	var total: = system.duration("electronics_plant", 1)
	system.advance(total / 1.3 + 0.001)
	check(system.level(capital.id, "electronics_plant") == 1, "infrastructure accelerates actual construction")
	check(system.validate(system.snapshot()), "expanded building save validates")
	var a: Dictionary = game.units.units.filter(func(unit): return unit.country == "russia" and unit.visual_kind == "armor")[0]
	var b: Dictionary = game.units.units.filter(func(unit): return unit.country == "ukraine" and unit.visual_kind == "armor")[0]
	b.node.position = game.map.position_at(capital.point)
	a.node.position = b.node.position + Vector3(0.2, 0, 0)
	a.moving = true
	game.match_rules.declare_war()
	game.match_rules.advance_battles(0.01)
	var unprotected: float = 100 - b.health
	for unit in game.units.units: unit.health = 100
	game.match_rules.combat.cooldowns.clear()
	game.match_rules.air_combat.cooldowns.clear()
	system.levels[capital.id].bunker = 3
	game.match_rules.advance_battles(0.01)
	check(unprotected > 0 and is_equal_approx(100 - b.health, unprotected * 0.4), "bunker level 3 reduces actual garrison combat damage by 60%")
	b.node.position += Vector3(2, 0, 0)
	check(is_equal_approx(system.incoming_damage_factor(b), 1), "bunker protects only troops in the city")
	game.city_panel.open(capital)
	check(game.city_panel.rows.has("tank_plant") and game.city_panel.rows.has("finance"), "Claude's city screen discovers new buildings without screen edits")
	for definition in system.catalog:
		var appearance: = AssetRoster.appearance(definition.asset_roster_id, "ukraine")
		check(ResourceLoader.exists(appearance.model) and ResourceLoader.exists(appearance.preview), definition.name + " uses existing model and preview")
	game.queue_free()
	await process_frame
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

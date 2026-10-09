extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for country in ["ukraine", "russia"]:
		GameSession.player_country = country
		GameSession.weapons_test = false
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game); current_scene = game
		await process_frame
		game.mobile_start.hide()
		game.apply_player_country()
		game.clock.paused = true
		game.match_rules.ai_enabled = false
		check(game.units.units.size() == _scenario_armies(), country + " original %d armies" % _scenario_armies())
		check(game.map.territories.size() == 145, country + " original 145 territories")
		check(game.units.units[game.units.selected].country == country, country + " own army selected")
		check(game.match_rules.ai.country == GameSession.opponent_country(), country + " opponent AI")
		game.hud.move_requested.emit()
		check(game.order_mode, country + " Move UI accepted")
		var unit = game.units.units[game.units.selected]
		var start = Vector2(unit.node.position.x, unit.node.position.z)
		game.player_order(game.map.position_at(start + Vector2(0.35, 0.35)))
		check(unit.moving, country + " movement ordered")
		game.units.advance(1.0)
		check(start.distance_to(Vector2(unit.node.position.x, unit.node.position.z)) > 0, country + " army moved")
		game.hud.stop_requested.emit()
		check(not unit.moving, country + " Stop UI accepted")
		game.production_panel.open()
		check(game.production_panel._country() == country, country + " production country")
		check(game.production_panel.filtered.all(func(spec): return spec.country == country), country + " production filter")
		var first = game.production_panel.filtered[0]
		var base = game.buildings.capital(country)
		check(game.production.schedule(first.id, base.name).is_empty(), country + " production queues")
		game.research_panel.open()
		var research_spec = game.production.catalog.filter(func(spec): return spec.country == country)[0]
		check(game.research.start(research_spec.id, 2).is_empty(), country + " research starts")
		var cash = game.production.stockpiles[country].funds
		var exchange = SupplyExchange.new(); exchange.economy = game.production
		check(exchange.transact("fuel", 1, true).is_empty(), country + " market buys")
		check(game.production.stockpiles[country].funds == cash - 4, country + " market charges own funds")
		game.city_panel.open(base)
		check(game.city_panel.summary.text.contains("YOURS"), country + " capital ownership")
		var state = game.session.capture(game.clock, game.map, game.units, game.rig)
		check(game.session.validate(state, game.map, game.units).is_empty(), country + " state validates")
		var path = "user://recovery_test_" + country + ".json"
		check(game.session.write_save(path, state).is_empty(), country + " save writes")
		var saved = game.session.read_save(path, game.map, game.units)
		check(saved.has("state"), country + " save reads")
		GameSession.player_country = GameSession.opponent_country()
		game.session.restore(saved.state, game.clock, game.map, game.units, game.rig)
		game.apply_player_country(false)
		check(GameSession.player_country == country, country + " save restores country")
		game.populate_weapons_test()
		check(game.units.units.size() == EquipmentIdentity.catalog.size(), country + " exactly one of 34 weapons")
		var ids = {}
		for weapon in game.units.units:
			check(not ids.has(weapon.equipment_id), country + " unique " + weapon.equipment_id)
			ids[weapon.equipment_id] = true
			check(not weapon.node.get_child(0).get_meta("asset_path", "").begins_with("res://assets/vehicles/"), country + " original asset " + weapon.equipment_id)
			if weapon.visual_kind == "naval": check(game.units.sea_navigation.on_sea(Vector2(weapon.node.position.x, weapon.node.position.z)), country + " ship on sea " + weapon.equipment_id)
		game.match_rules.declare_war()
		var a = game.units.units.filter(func(x): return x.country == "russia" and x.visual_kind == "armor")[0]
		var b = game.units.units.filter(func(x): return x.country == "ukraine" and x.visual_kind == "armor")[0]
		b.node.position = a.node.position + Vector3(0.1, 0, 0)
		a.attack_target = b.id; b.attack_target = a.id
		game.match_rules.advance(1.0)
		check(a.health < 100 or b.health < 100, country + " combat damage")
		game.focus_player_army()
		game.open_army_selection()
		game.open_army_command("split")
		check(game.army_selection.visible, country + " selection panel opens")
		game.restore_campaign_forces()
		check(game.units.units.size() == _scenario_armies(), country + " test mode returns to original forces")
		check(game.units.fog_enabled, country + " campaign fog restored")
		game.queue_free()
		await process_frame
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
## Starting armies listed in the scenario (was a hard-coded 20; the owner's air-defence
## batteries added 4 on 2026-10-09).
func _scenario_armies() -> int:
	return (JSON.parse_string(FileAccess.get_file_as_string("res://data/scenario_regional.json")).units as Array).size()

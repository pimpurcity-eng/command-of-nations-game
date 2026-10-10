extends SceneTree
var failures: int = 0
var checks: int = 0
const NEW_FAMILIES: = ["fleet_russia", "fleet_ukraine", "submarines_russia", "carriers_russia", "carriers_ukraine", "missiles_russia", "missiles_ukraine", "silos_russia", "silos_ukraine", "drones_russia", "drones_ukraine", "loitering_russia"]
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "ukraine"
	GameSession.weapons_test = false
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	for id in NEW_FAMILIES:
		var spec: = EquipmentIdentity.spec(id)
		check(spec.research_tiers.size() == 5 and spec.research_days.map(func(day): return int(day)) == [1,4,8,12,18], id + " five real research tiers")
		for level in range(1, 6):
			var tier: = EquipmentIdentity.research_tier(id, level)
			check(ResourceLoader.exists(tier.model), tier.name + " original model exists")
			check(CowUI.research_picture(id, level) != null, tier.name + " original research picture loads")
	GameSession.weapons_test = true
	game.populate_weapons_test()
	game.apply_player_country(false)
	check(game.map.territories.size() == 145 and StrategicMap.road_graph(game.map.territories).edges.size() == 165, "all weapons use the real regional map and its complete roads")
	check(game.test_models == null, "every displayed weapon is a controllable army, without a separate display grid")
	check(game.clock.paused and not game.match_rules.ai_enabled and not game.units.fog_enabled, "safe planning start with all equipment visible")
	var expected: Dictionary = {}
	for spec in EquipmentIdentity.catalog:
		for tier in spec.research_tiers: expected[tier.model] = true
	var actual: Dictionary = {}
	var naval_points: Array[Vector2] = []
	for unit in game.units.units:
		var model: Node3D = unit.node.get_child(0)
		var path: String = model.get_meta("asset_path", "")
		actual[path] = true
		check(not model.get_meta("stand_in_model", false) and not model.get_meta("missing_original_model", true), unit.name + " supplied original, no stand-in")
		check(path == EquipmentIdentity.research_tier(unit.equipment_id, unit.level).model, unit.name + " correct actual tier")
		var role: String = EquipmentIdentity.spec(unit.equipment_id).get("role", unit.visual_kind)
		var fit: AABB = UnitVisual.model_bounds(model.get_node("ModelFit"), 0.0)
		check(absf(maxf(fit.size.x, fit.size.z) - float(UnitVisual.FOOTPRINT.get(role, 0.62))) < 0.02, unit.name + " consistent size for its role")
		if game.units.is_naval(unit):
			var point: = Vector2(unit.node.position.x, unit.node.position.z)
			check(game.units.sea_navigation.on_sea(point), unit.name + " real sea berth")
			check(not naval_points.any(func(other): return other.distance_to(point) < 2.09), unit.name + " separate selectable berth")
			naval_points.append(point)
		if game.units.air.is_air(unit):
			check(game.units.air.available(game.units.air.base(unit), unit.country), unit.name + " working friendly airbase")
			var point: = Vector2(unit.node.position.x,unit.node.position.z)
			check(game.map.territories.any(func(t): return t.playable and t.controller == unit.country and RegionData.contains(t,point)), unit.name + " on friendly playable land, not a neutral display grid")
			check(point.distance_to(game.units.air.base(unit).point) + 0.7 <= game.units.air.radius(unit), unit.name + " inside usable operating radius")
	check(expected.size() == 101 and actual.size() == expected.size() and expected.keys().all(func(path): return actual.has(path)), "all 101 unique live original weapon models represented")
	check(game.units.units.size() == 101, "each distinct original appears once; reused modernization models do not crowd the map")
	var heli: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "helicopters_russia")[0]
	var animator: HelicopterAnimator = heli.node.get_child(0).get_meta("helicopter_animator")
	var rest: Basis = animator.rotors[0].basis
	game.units._process(0.03)
	check(animator.rotors[0].basis == rest, "live grounded helicopter blades stop")
	var origin: = Vector2(heli.node.position.x, heli.node.position.z)
	check(game.units.air.order(heli, origin + Vector2(0.3,0.3)).is_empty(), "live helicopter accepts flight")
	game.units._process(0.03)
	check(animator.rotors[0].basis != rest, "actual UnitSystem update spins live helicopter blades")
	var drone: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "drones_russia" and u.level == 1)[0]
	var drone_animator: HelicopterAnimator = drone.node.get_child(0).get_meta("helicopter_animator")
	check(drone_animator.rotors.size() == 1, "separated Orlan has its original propeller and no launch catapult")
	check(not str(drone.node.get_child(0).get_meta("asset_path")).contains("catapult"), "flying drone uses supplied drone-only original")
	var before: Basis = drone_animator.rotors[0].basis
	check(game.units.air.order(drone, Vector2(drone.node.position.x,drone.node.position.z) + Vector2(0.2,0.2)).is_empty(), "drone accepts flight from its real airbase")
	game.units._process(0.03)
	check(drone_animator.rotors[0].basis != before, "actual UnitSystem update spins drone propeller")
	check(AirBattleSystem.new().value(drone, "ground_damage") == 0, "recon drone has no invented strike damage")
	var silo: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "silos_ukraine")[0]
	game.units.select_unit(game.units.units.find(silo))
	check(not game.units.order(silo.node.position + Vector3.RIGHT * 2), "fixed silo rejects movement orders")
	var carrier: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "carriers_ukraine")[0]
	check(game.units.is_naval(carrier), "carrier uses real sea navigation")
	var mobile: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "missiles_ukraine")[0]
	check(CombatSystem.new().shot_effect(mobile) == "missile" and CombatSystem.new().damage_value(mobile,"armor") > 0, "mobile missiles use working conventional missile combat")
	var projectile_target: Dictionary = game.units.units.filter(func(u): return u.equipment_id == "tanks_russia")[0]
	game.combat_effects.on_shot(mobile,projectile_target,"missile")
	check(game.combat_effects.projectiles.size() == 1, "actual missile shot loads original projectile geometry")
	game.combat_effects.clear()
	var preserved: Array = game.units.units
	var lancet: Dictionary = preserved.filter(func(u): return u.equipment_id == "loitering_russia")[0]
	var victim: Dictionary = preserved.filter(func(u): return u.equipment_id == "tanks_ukraine")[0]
	var original_victim_position: Vector3 = victim.node.position
	lancet.flight_mode = "patrol"
	lancet.patrol_center = Vector2(lancet.node.position.x, lancet.node.position.z)
	victim.node.position = lancet.node.position
	game.units.units = [lancet, victim]
	game.units.at_war = true
	var damage: Dictionary = {}
	AirBattleSystem.new().advance(0, game.units, damage, true)
	check(damage.get(victim.id,0.0) > 0 and damage.get(lancet.id,0.0) == lancet.health, "Lancet strikes one target and consumes its original drone")
	game.units.units = preserved
	game.units.at_war = false
	victim.node.position = original_victim_position
	lancet.flight_mode = "grounded"
	game.units.selected = -1
	game.rig.set_process(false)
	game.rig.target = Vector3(heli.node.position.x,0,heli.node.position.z)
	game.rig.distance = 10
	game.rig._snap(1.0)
	game._map_click(game.rig.camera.unproject_position(heli.node.position + Vector3.UP * 0.2),false)
	check(GameSession.player_country == "russia", "test map allows control of tapped Russian equipment")
	game.rig.target = Vector3(carrier.node.position.x,0,carrier.node.position.z)
	game.rig._snap(1.0)
	game._map_click(game.rig.camera.unproject_position(carrier.node.position + Vector3.UP * 0.2),false)
	check(GameSession.player_country == "ukraine", "test map switches control to tapped Ukrainian equipment")
	var tank: Dictionary = preserved.filter(func(u): return u.equipment_id == "tanks_russia" and u.level == 1)[0]
	tank.level = 2
	tank.upgrade_target = 2
	game.units._process(0.03)
	check(tank.node.get_child(0).get_meta("asset_path") == EquipmentIdentity.research_tier(tank.equipment_id,2).model, "live non-AA research upgrade replaces the actual original model")
	var saved: Dictionary = game.session.capture(game.clock,game.map,game.units,game.rig)
	check(game.session.validate(saved,game.map,game.units).is_empty(), "all-weapons real-map state passes save validation")
	GameSession.weapons_test = false
	game.restore_campaign_forces()
	check(game.units.units.size() == game.session.scenario.units.size(), "return from all-weapons map restores complete campaign forces")
	GameSession.player_country = "ukraine"
	game.apply_player_country()
	game.units.fog_enabled = false
	var city: Dictionary = game.cities.cities.filter(func(c): return c.id == "kyiv")[0]
	game.rig.set_process(false)
	game.rig.target = Vector3(city.point.x, 0, city.point.y)
	game.rig.distance = 10
	game.rig._snap(1.0)
	for i in 3: await process_frame
	var selected: Dictionary = game.units.units[game.units.selected]
	var city_screen: Vector2 = game.rig.camera.unproject_position(game.map.position_at(city.point) + Vector3.UP * 0.2)
	game._map_click(city_screen,false)
	check(game.units.selected == -1 and game.city_panel.visible, "tap city switches from selected unit to city inspection")
	check(not selected.moving, "city inspection does not move the previous unit")
	game.city_panel.hide()
	game.focus_player_army()
	game.cities.select_city(city)
	check(game.units.selected == -1, "city name tag and city shortcut also release the old unit")
	game.queue_free()
	await process_frame
	print("RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)

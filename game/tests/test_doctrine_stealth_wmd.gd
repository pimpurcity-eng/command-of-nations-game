extends SceneTree
## Doctrines, stealth/radar and weapons of mass destruction (owner request 2026-10-12).
##   godot --headless --path . --script tests/test_doctrine_stealth_wmd.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ArsenalFixture.use_archive()
	Doctrine.restore({})
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var rules: MatchSystem = game.match_rules
	var units: UnitSystem = game.units
	# Doctrines.
	check(Doctrine.of("russia") == "eastern" and Doctrine.of("ukraine") == "european", "countries start with their default doctrine")
	check(game.mobile_start.doctrine_picker.item_count == 4, "the start screen offers Western, European and Eastern doctrines")
	var tank: = {"country": "russia", "visual_kind": "armor"}
	check(is_equal_approx(Doctrine.combat_factor(tank, "attack"), 1.15) and is_equal_approx(Doctrine.combat_factor({"country": "ukraine", "visual_kind": "armor"}, "defense"), 1.10), "Eastern tanks attack +15%, European armies defend +10%")
	check(is_equal_approx(game.research.rate("ukraine"), 1.15) and is_equal_approx(game.research.rate("russia"), 1.0), "European research is 15% faster")
	Doctrine.choose("ukraine", "western")
	check(is_equal_approx(Doctrine.combat_factor({"country": "ukraine", "visual_kind": "fighter"}, "attack"), 1.15) and Doctrine.stealth({"country": "ukraine", "visual_kind": "fighter"}), "Western aircraft are stronger and stealthy")
	# Stealth and radar.
	units.fog_enabled = true
	var jet: Dictionary = {}
	var russian_ground: Dictionary = {}
	var russian_ad: Dictionary = {}
	for unit in units.units:
		if unit.country == "ukraine" and unit.visual_kind == "fighter" and jet.is_empty(): jet = unit
		if unit.country == "russia" and unit.visual_kind in ["armor", "ifv"] and russian_ground.is_empty(): russian_ground = unit
		if unit.country == "russia" and unit.visual_kind == "air_defense" and russian_ad.is_empty(): russian_ad = unit
	var far: = Vector3(500, 0, 500)
	for unit in units.units:
		if unit.country == "russia" and unit != russian_ground and unit != russian_ad: unit.node.position = far + Vector3(randf(), 0, randf())
	russian_ad.node.position = far + Vector3(-50, 0, -50)
	jet.node.position = russian_ground.node.position + Vector3(2.0, 0, 0)
	check(units.point_visible(Vector2(jet.node.position.x, jet.node.position.z), "russia") and not units.unit_visible(jet, "russia"), "a stealth jet inside normal vision stays hidden without radar")
	jet.node.position = russian_ground.node.position + Vector3(0.5, 0, 0)
	check(units.unit_visible(jet, "russia"), "up close a stealth jet is seen")
	jet.node.position = russian_ad.node.position + Vector3(4.0, 0, 0)
	check(units.unit_visible(jet, "russia"), "air-defence radar reveals stealth aircraft")
	var plain: = russian_ground.duplicate()
	plain.country = "ukraine"
	plain.erase("stealth")
	plain.node = Node3D.new()
	plain.node.position = russian_ground.node.position + Vector3(2.0, 0, 0)
	check(units.unit_visible(plain, "russia"), "ordinary units are seen by normal vision")
	var sub: = plain.duplicate()
	sub.equipment_id = "submarine_europe"
	sub.erase("stealth")
	sub.node = Node3D.new()
	sub.node.position = russian_ad.node.position + Vector3(2.0, 0, 0)
	check(not units.unit_visible(sub, "russia"), "submarines are not found by land radar (only by ships' sonar)")
	units.fog_enabled = false
	# Weapons of mass destruction.
	var strategic: StrategicWeapons = rules.strategic
	var stock: Dictionary = game.production.stockpiles.russia
	for resource in stock: stock[resource] = 100000.0
	check(strategic.reason("russia", "nuclear", 5, stock).begins_with("Available on day"), "nuclear missiles unlock late (day 25)")
	check(strategic.build("russia", "nuclear", 25, stock).is_empty() and stock.funds < 100000.0, "building a nuclear missile costs a fortune")
	strategic.advance(StrategicWeapons.WEAPONS.nuclear.build + 1.0)
	check(strategic.count("russia", "nuclear") == 1, "the missile is ready after two days")
	var target_unit: Dictionary = {}
	for unit in units.units:
		if unit.country == "ukraine" and unit.visual_kind in ["armor", "ifv", "artillery"] and target_unit.is_empty(): target_unit = unit
	var target: = Vector2(target_unit.node.position.x, target_unit.node.position.z)
	for unit in units.units:
		if unit.country == "ukraine" and unit.visual_kind == "air_defense": unit.level = 1
	check(is_zero_approx(strategic.interception_chance("russia", target, units)), "basic air defence cannot stop missiles")
	var health_before: float = target_unit.health
	rules.declare_war()
	units.select_unit(units.units.find(target_unit))
	game.launch_strategic("nuclear")
	check(target_unit.health < health_before * 0.3, "a nuclear strike devastates the army it hits (%.0f → %.0f)" % [health_before, target_unit.health])
	check(strategic.count("russia", "nuclear") == 0 and not strategic.fallout.is_empty(), "the missile is spent and leaves fallout")
	var fallout_id: String = strategic.fallout.keys()[0]
	check(is_equal_approx(strategic.output(fallout_id), StrategicWeapons.FALLOUT_OUTPUT), "fallout cuts output to 20%")
	var defender: Dictionary = {}
	for unit in units.units:
		if unit.country == "ukraine" and unit.visual_kind == "air_defense" and defender.is_empty(): defender = unit
	defender.level = 5
	defender.node.position = Vector3(target.x + 1.0, 0, target.y)
	check(strategic.interception_chance("russia", target, units) > 0.3, "upgraded air defence can shoot missiles down")
	strategic.stock["russia"] = {"chemical": 3}
	var results: = []
	for i in 3: results.append(strategic.launch("russia", "chemical", target, units, game.map.territories).intercepted)
	check(results.size() == 3 and strategic.count("russia", "chemical") == 0, "every launch spends a missile (intercepted: %s)" % [results])
	var saved: = rules.snapshot()
	strategic.restore({})
	Doctrine.restore({})
	rules.restore(saved)
	check(not strategic.fallout.is_empty() and Doctrine.of("ukraine") == "western", "fallout, stockpiles and doctrines are saved")
	game.hud.campaign_requested.emit("strategic")
	check(game.campaign_panel.visible and game.campaign_panel.content.get_child_count() > 4, "the Arsenal page shows doctrines and strategic weapons")
	Doctrine.restore({})
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

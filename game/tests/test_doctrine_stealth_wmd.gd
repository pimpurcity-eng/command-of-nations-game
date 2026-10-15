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
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	var rules: MatchSystem = game.match_rules
	var units: UnitSystem = game.units
	# Doctrines.
	check(Doctrine.of("russia") == "russian" and Doctrine.of("ukraine") == "european", "countries start with their default doctrine")
	check(not "doctrine_picker" in game.mobile_start, "the doctrine comes with the country (no separate doctrine choice)")
	# Owner 2026-10-15: Russian air defence and rockets beat Europe's; European tanks are better.
	var doctrine_ad_ru: = Doctrine.combat_factor({"country": "russia", "visual_kind": "air_defense"}, "attack")
	var doctrine_ad_eu: = Doctrine.combat_factor({"country": "ukraine", "visual_kind": "air_defense"}, "attack")
	check(is_equal_approx(doctrine_ad_ru, 1.15) and doctrine_ad_ru > doctrine_ad_eu and Doctrine.combat_factor({"country": "russia", "visual_kind": "missile_launcher"}, "attack") > Doctrine.combat_factor({"country": "ukraine", "visual_kind": "missile_launcher"}, "attack"), "Russian air defence and rockets beat European ones")
	check(Doctrine.combat_factor({"country": "ukraine", "visual_kind": "armor"}, "attack") > Doctrine.combat_factor({"country": "russia", "visual_kind": "armor"}, "attack") and is_equal_approx(Doctrine.combat_factor({"country": "ukraine", "visual_kind": "infantry"}, "defense"), 1.10), "European tanks are better; European armies defend +10%")
	check(Doctrine.DOCTRINES.keys() == ["russian", "european", "american", "chinese"], "four doctrines: Russian, European, American, Chinese")
	# Owner 2026-10-15: "Ukraine only gets European weapons."
	var foreign: Array = []
	for family in EquipmentIdentity.catalog:
		if family.get("country", "") != "ukraine" or family.get("retired", false): continue
		for tier in family.get("research_tiers", []):
			var file: String = str(tier.model).get_file()
			if not (file.begins_with("euro_") or file.begins_with("nato_") or file.begins_with("ukraine_") or file.ends_with("_european.glb")) or str(tier.model).contains("abrams") or str(tier.name).contains("NASAMS"): foreign.append(family.id + ": " + str(tier.name))
	check(foreign.is_empty(), "Ukraine has European weapons only " + str(foreign))
	check(is_equal_approx(game.research.rate("ukraine"), 1.15) and is_equal_approx(game.research.rate("russia"), 0.9), "European research is 15% faster; Russian research 10% slower (doctrine)")
	check(is_equal_approx(Doctrine.combat_factor({"country": "united_states", "visual_kind": "fighter"}, "attack"), 1.15) and Doctrine.stealth({"country": "united_states", "visual_kind": "fighter"}) and not Doctrine.stealth({"country": "ukraine", "visual_kind": "fighter"}), "Western aircraft are stronger and stealthy")
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
	jet.stealth = true  # a stealth fighter
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
	for resource in stock: stock[resource] = 1000000.0  # a nuke costs 250,000 funds at Call of War scale
	check(strategic.reason("russia", "nuclear", 5, stock).begins_with("Available on day"), "nuclear missiles unlock late (day 25)")
	check(strategic.build("russia", "nuclear", 25, stock).is_empty() and stock.funds <= 1000000.0 - 250000.0, "building a nuclear missile costs a fortune")
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
	# Owner 2026-10-14: only long-range SAMs (S-300/S-400/Patriot families) stop strategic
	# missiles, nuclear ones from level 3; short-range air defence cannot.
	var short_range: Dictionary = units.units.filter(func(u): return u.country == "ukraine" and u.visual_kind == "air_defense")[0]
	short_range.level = 5
	short_range.node.position = Vector3(target.x + 1.0, 0, target.y)
	check(is_zero_approx(strategic.interception_chance("russia", target, units)), "short-range air defence cannot stop a nuclear missile")
	units._spawn({"id": "abm", "name": "SAM", "country": "ukraine", "equipment_id": "patriot_ukraine", "level": 2, "visual_kind": "air_defense", "base_city": "kyiv"}, target + Vector2(1.0, 0.3), Color("73bcff"))
	var defender: Dictionary = units.find_id("abm")
	check(is_zero_approx(strategic.interception_chance("russia", target, units)) and strategic.interception_chance("russia", target, units, "chemical") > 0.0, "a level-2 SAM stops chemical but not nuclear missiles")
	defender.level = 5
	check(strategic.interception_chance("russia", target, units) > 0.5, "a level-5 SAM battery can shoot nuclear missiles down")
	# Counters come first: long-range SAMs at level 3 exist well before nuclear missiles.
	# Checked against the real weapons data (this test otherwise runs on the archived catalogue).
	var real_catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	for country in ["russia", "ukraine"]:
		var sam: Dictionary = real_catalog.filter(func(f): return f is Dictionary and f.get("id", "") == "patriot_" + country)[0]
		check(int(sam.research_days[2]) < int(StrategicWeapons.WEAPONS.nuclear.unlock_day) and int(sam.research_days[0]) < int(StrategicWeapons.WEAPONS.chemical.unlock_day), "%s: missile defence (day %d / L3 day %d) comes before chemical (day %d) and nuclear (day %d) missiles" % [country, sam.research_days[0], sam.research_days[2], StrategicWeapons.WEAPONS.chemical.unlock_day, StrategicWeapons.WEAPONS.nuclear.unlock_day])
	# A big stack survives a nuclear hit; a small army does not.
	var pool: = StrategicWeapons.new()
	pool.stock["russia"] = {"nuclear": 2}
	var ground_zero: Vector2 = game.buildings.city("lviv").point + Vector2(0.5, 0.5)
	for i in 14: units._spawn({"id": "big%d" % i, "name": "Inf", "country": "ukraine", "equipment_id": "infantry_ukraine", "level": 1, "visual_kind": "infantry", "base_city": "lviv", "stack_id": "bigstack"}, ground_zero, Color("73bcff"))
	pool.launch("russia", "nuclear", ground_zero, units, game.map.territories)
	var left: = units.units.filter(func(u): return str(u.id).begins_with("big") and u.health > 0).size()
	check(left == 14, "a 14-unit stack at ground zero is badly hurt but survives (%d left)" % left)
	var lone: Vector2 = game.buildings.city("odesa").point + Vector2(0.4, 0.4)
	units._spawn({"id": "lone", "name": "Inf", "country": "ukraine", "equipment_id": "infantry_ukraine", "level": 1, "visual_kind": "infantry", "base_city": "odesa"}, lone, Color("73bcff"))
	pool.launch("russia", "nuclear", lone, units, game.map.territories)
	check(units.find_id("lone").health <= 0.0, "a single army at ground zero is wiped out")
	strategic.stock["russia"] = {"chemical": 3}
	var results: = []
	for i in 3: results.append(strategic.launch("russia", "chemical", target, units, game.map.territories).intercepted)
	check(results.size() == 3 and strategic.count("russia", "chemical") == 0, "every launch spends a missile (intercepted: %s)" % [results])
	var saved: = rules.snapshot()
	strategic.restore({})
	Doctrine.restore({})
	rules.restore(saved)
	check(not strategic.fallout.is_empty() and Doctrine.of("ukraine") == "european" and Doctrine.of("russia") == "russian", "fallout and stockpiles are saved; doctrines stay with their country")
	game.hud.campaign_requested.emit("strategic")
	check(game.campaign_panel.visible and game.campaign_panel.content.get_child_count() > 4, "the Arsenal page shows doctrines and strategic weapons")
	Doctrine.restore({})
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

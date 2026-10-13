extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ",text)
func run() -> void:
	root.size = Vector2i(720,1440)
	GameSession.player_country = "russia"
	GameSession.weapons_test = false
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	current_scene = game
	for i in 5: await process_frame
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	check(game.units.units.size() == EquipmentIdentity.catalog.size()*3,"three units of each family")
	check(ProductionGroups.TITLES == ["Economy","Aircraft","Ordnance","Tanks","Naval","Barracks"],"six requested research groups")
	var schedules := {}
	for spec in EquipmentIdentity.catalog:
		var tiers: Array = spec.research_tiers
		check(tiers[0].model == tiers[1].model and tiers[2].model == tiers[3].model,"model upgrades between major variants: " + spec.id)
		schedules[str(spec.research_days)] = true
	check(schedules.size() > 6,"different branch research days")
	check(not game.research_panel._families(0).is_empty(),"economy research has usable projects")
	for city in game.cities.cities:
		for spec in game.buildings.catalog:
			var expected := 1 if spec.id == "train_station" and game.buildings.is_capital(city) else 0
			check(game.buildings.level(city.id,spec.id) == expected,"starting buildings: " + city.name + " / " + spec.id)
	game.production_panel.open("Moscow")
	check(game.production_panel.city_names.all(func(name):return game.production.cities.any(func(c):return c.name == name and game.production.controlled(c,"russia"))),"production lists controlled cities only")
	game.production_panel.hide()
	var enemy: Dictionary = game.cities.cities.filter(func(c):return c.country == "Ukraine")[0]
	game.city_panel.open(enemy)
	check(not game.city_panel.list.visible,"unscouted enemy construction inventory hidden")
	game.city_panel.hide()
	for resource in ProductionSystem.RESOURCES: game.production.stockpiles.russia[resource]=100000
	var province: Dictionary = game.buildings.provinces.places.values().filter(func(p):return game.production.controlled(p,"russia"))[0]
	check(game.buildings.reason(province.id,"train_station").is_empty(),"province train stations allowed")
	check(not game.buildings.reason(province.id,"factory").is_empty(),"province factories rejected")
	check(not game.production.schedule("tanks_russia",province.name).is_empty(),"no units produced in provinces")
	check(not game.buildings.reason("moscow","naval_base").is_empty(),"inland naval bases rejected")
	check(game.buildings.reason("rostov_on_don","naval_base").is_empty(),"coastal naval base allowed")
	check(game.buildings.reason("moscow","missile_factory").is_empty(),"missile factory available")
	check(game.buildings.validate(game.buildings.snapshot()),"new building save validates")
	var old: Dictionary = game.buildings.snapshot().duplicate(true)
	old.erase("capitals")
	for city_id in old.levels:
		for id in ["train_station","capitol","missile_factory"]: old.levels[city_id].erase(id)
	for id in old.provinces.levels:
		for kind in ["train_station","naval_base"]: old.provinces.levels[id].erase(kind)
	check(game.buildings.validate(old),"old building save remains compatible")
	check(game.research.validate(game.research.snapshot()),"economy and military research save validates")
	for ship in game.units.units.filter(func(u):return u.visual_kind == "naval"):
		check(not game.map.on_land(Vector2(ship.node.position.x,ship.node.position.z)),"ship starts on visible water: " + ship.id)
	check(game.units.sea_navigation.find_path(GeographicProjection.project(37.6,55.75),GeographicProjection.project(30.7,46.5)).is_empty(),"sea routes reject a start on visible land")
	game.mobile_start.hide()
	for i in 5: await process_frame
	check(game.badges.buttons.values().any(func(b):return b.visible and b.text.begins_with("L") and b.has_node("Health")),"unit level and health visible on map")
	print("RESULT checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)

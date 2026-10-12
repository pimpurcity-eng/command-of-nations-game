extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ",message)
	if not ok: failures += 1
func _initialize(): call_deferred("run")
func run():
	GameSession.player_country = "russia";GameSession.weapons_test = false
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 3: await process_frame
	game.mobile_start.hide();game.clock.paused = true
	var navy: Array = EquipmentIdentity.catalog.filter(func(s):return s.visual_kind=="naval")
	check(navy.size()==10,"five naval classes for each country")
	for spec in navy:
		var originals: Dictionary = {}
		for level in [1,3,5]:
			var tier: = EquipmentIdentity.research_tier(spec.id,level)
			originals[tier.model]=true
			var unit = game.units.units.filter(func(u):return u.equipment_id==spec.id and u.level==level)[0]
			check(game.units.sea_navigation.on_sea(Vector2(unit.node.position.x,unit.node.position.z)),spec.id+" tier starts at sea")
		check(originals.size()==3,spec.id+" has three distinct original model eras")
	var city: Dictionary = game.buildings.city("moscow")
	game.buildings.levels.moscow.airbase = 5
	game.buildings.levels.moscow.bunker = 5
	game.cities.sync_buildings()
	var district: Node3D = game.cities.districts.moscow
	for kind in ["airbase","bunker"]:
		var visual: Node3D = district.get_node("Infrastructure_"+kind)
		check(str(visual.get_meta("facility_model")).ends_with("_l5.glb"),kind+" level 5 uses supplied model")
		var bounds: = UnitVisual.model_bounds(visual,0.0)
		check(maxf(bounds.size.x,bounds.size.z)<2.0,kind+" fitted to city footprint including its map rotation")
		check(visual.get_meta("original_colors",false),kind+" keeps original colors")
	var rural: Dictionary = game.buildings.provinces.places.values().filter(func(p):return game.production.controlled(p,"russia"))[0]
	game.buildings.provinces.levels[rural.id].airbase = 5
	game.cities.sync_buildings()
	check(str(game.cities.rural_districts[rural.id].get_node("airbase").get_meta("facility_model")).ends_with("province_airport_l5.glb"),"province uses rural airport model")
	check(not game.production.schedule("destroyers_russia",rural.name).is_empty(),"rural airport cannot create naval units")
	game.buildings.levels.moscow.infrastructure = 1
	game.buildings.levels.kursk.infrastructure = 1
	game.buildings.changed.emit()
	var rail: RailwayMap = game.map.get_node("Railways")
	check(not rail.links.is_empty(),"completed nearby stations create a railway")
	for link in rail.links:
		check(link.route.all(func(point):return game.units.navigation.on_land(point) and game.units.navigation.controller_at(point)=="russia"),"rail route stays on friendly land")
	check(rail.get_child_count()>0,"supplied tracks are rendered in batches")
	var saved: Dictionary = game.buildings.snapshot()
	check(game.buildings.validate(saved),"new facility levels and stations save")
	game.buildings.levels.kursk.infrastructure = 0
	game.buildings.changed.emit()
	check(rail.links.is_empty(),"removing station state removes its tracks")
	game.buildings.restore(saved)
	check(not rail.links.is_empty(),"save restoration restores railway")
	print("RESULT checks=",checks," failures=",failures)
	game.queue_free();await process_frame;quit(1 if failures else 0)

extends SceneTree
## Actual-engine coastline comparison and a count sheet read from the new-match units.
## CITY_REVIEW_DIR is required; REVIEW_BASE=1 renders only the original coastline.
func _initialize() -> void: call_deferred("run")
func text_at(parent: Control, text: String, at: Vector2, size: Vector2, font_size: int, color: Color = Color("e9edf0")) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = size
	label.add_theme_font_override("font", StrategyTheme.font("Oswald", 500))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
func panel(parent: Node, rect: Rect2, color: Color) -> Panel:
	var box := Panel.new()
	box.position = rect.position
	box.size = rect.size
	var skin := StyleBoxFlat.new()
	skin.bg_color = color
	skin.set_corner_radius_all(10)
	box.add_theme_stylebox_override("panel", skin)
	parent.add_child(box)
	return box
func save(name: String) -> void:
	for i in 15: await process_frame
	var error := root.get_texture().get_image().save_png(OS.get_environment("CITY_REVIEW_DIR").path_join(name + ".png"))
	assert(error == OK)
func run() -> void:
	root.size = Vector2i(720, 1280)
	root.content_scale_size = Vector2i(720, 1280)
	GameSession.player_country = "ukraine"
	GameSession.weapons_test = false
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.mobile_start.hide()
	game.hud.hide()
	game.cities.label_layer.hide()
	game.units.hide()
	var city: Dictionary = game.buildings.city("odesa")
	game.rig.target = Vector3(city.point.x, 0, city.point.y)
	game.rig.distance = 6.0
	game.rig._snap(1.0)
	game.rig.set_process(false)
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var head := panel(overlay, Rect2(20, 20, 680, 96), Color(0.035, 0.055, 0.08, 0.94))
	var base := OS.get_environment("REVIEW_BASE") == "1"
	text_at(head, "ODESSA  |  " + ("BEFORE" if base else "CORRECTED SOURCE"), Vector2(20, 8), Vector2(640, 38), 28, Color("e6c684"))
	text_at(head, "City-edge review · Godot render", Vector2(20, 48), Vector2(640, 30), 19)
	await save("Odessa_Before" if base else "Odessa_After")
	if base: quit(); return
	head.queue_free()
	await process_frame
	var sheet := panel(overlay, Rect2(0, 0, 720, 1280), Color("0b1520"))
	var country := "russia"
	var forces: Array = game.units.units.filter(func(u): return u.country == country)
	text_at(sheet, "STARTING FORCES", Vector2(24, 20), Vector2(672, 54), 38, Color("e6c684"))
	text_at(sheet, "Per country · new match · %d units" % forces.size(), Vector2(24, 78), Vector2(672, 36), 24)
	var specs := [["TANKS", "light_tank_russia"], ["AIR DEFENSE", "skyguard_russia"], ["AIRCRAFT", game.STARTING_PLANE[country]], ["INFANTRY", "infantry_russia"]]
	for i in specs.size():
		var spec: Array = specs[i]
		var card := panel(sheet, Rect2(24 + (i % 2) * 348, 136 + (i / 2) * 218, 324, 200), Color("172635"))
		var count: int = forces.filter(func(u): return u.equipment_id == spec[1]).size()
		text_at(card, "%d  %s" % [count, spec[0]], Vector2(14, 6), Vector2(296, 40), 27, Color("e6c684"))
		var picture := TextureRect.new()
		picture.texture = CowUI.equipment_picture(spec[1])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(10, 48)
		picture.size = Vector2(304, 142)
		card.add_child(picture)
	text_at(sheet, "THREE UNITS IN EVERY CITY", Vector2(24, 590), Vector2(672, 42), 27, Color("e6c684"))
	var homes: Array = game.production.cities.filter(func(c): return c.country.to_lower() == country)
	for i in homes.size():
		var home: Dictionary = homes[i]
		var count: int = forces.filter(func(u): return not game.units.air.is_air(u) and CitySystem.near_city(Vector2(u.node.position.x, u.node.position.z), home.point)).size()
		assert(count == 3)
		var row := panel(sheet, Rect2(24, 644 + i * 43, 672, 37), Color("172635") if i % 2 == 0 else Color("11202e"))
		text_at(row, home.name, Vector2(12, 1), Vector2(520, 34), 22)
		text_at(row, str(count) + " units", Vector2(550, 1), Vector2(110, 34), 22)
	var rural: Array = forces.filter(func(u): return u.visual_kind == "infantry" and not homes.any(func(c): return CitySystem.near_city(Vector2(u.node.position.x, u.node.position.z), c.point)))
	assert(rural.size() == 8)
	var foot := panel(sheet, Rect2(24, 980, 672, 252), Color("172635"))
	text_at(foot, "%d INFANTRY · SEPARATE PROVINCES" % rural.size(), Vector2(16, 14), Vector2(640, 42), 26, Color("e6c684"))
	text_at(foot, "One infantry unit per province post", Vector2(16, 58), Vector2(640, 36), 22)
	text_at(foot, "1 aircraft · province airport", Vector2(16, 112), Vector2(640, 38), 25)
	text_at(foot, "23 infantry total: 15 in cities + 8 in provinces", Vector2(16, 174), Vector2(640, 38), 21, Color("b6c4cd"))
	await save("Starting_Forces")
	quit()

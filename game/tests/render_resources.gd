extends SceneTree
## Owner 2026-10-13: resources only in the seven cities (metal, rare earths, oil, food), Food in
## the top bar like Call of War, no resources or industry in provinces.
##   BUILDING_PREVIEW_DIR=/some/dir xvfb-run -a godot --path . --script tests/render_resources.gd
func _initialize() -> void: call_deferred("run")
var game
func shot(name: String) -> void:
	for i in 30: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = OS.get_environment("PLAY_AS") if not OS.get_environment("PLAY_AS").is_empty() else "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.clock.paused = true
	var at: Vector2 = game.buildings.capital(GameSession.player_country).point
	game.rig.target = Vector3(at.x, 0, at.y + 3.0)
	game.rig.distance = 45.0
	game.rig._snap(1.0)
	await shot("Resources_Map_" + GameSession.player_country)
	var province: Dictionary = game.buildings.provinces.places.values().filter(func(p): return game.production.controlled(p, GameSession.player_country))[0]
	if game.province_panel == null:
		game.province_panel = ProvincePanel.new()
		game.add_child(game.province_panel)
		game.province_panel.setup(game.buildings, game.hud.get_child(0).theme)
	game.province_panel.open(province)
	await shot("Resources_Province_" + GameSession.player_country)
	quit()

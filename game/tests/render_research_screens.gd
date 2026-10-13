extends SceneTree
## Owner review: research screens line up (cards, labels, last row) and the tutorial card steps aside.
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 30: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	root.get_texture().get_image().save_png(folder.path_join(name + ".png"))
func run() -> void:
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.tutorial = Tutorial.new()
	game.add_child(game.tutorial)
	game.tutorial.setup(game, game.hud.get_child(0).theme)
	game.research_panel.open()
	await shot("Research_Overview")
	game.research_panel.show_category(0)
	await shot("Research_Economy")
	game.research_panel.tree_scroll.scroll_vertical = 100000
	await shot("Research_Economy_Bottom")
	game.research_panel.show_category(2)
	await shot("Research_Ordnance")
	game.research_panel.show_category(5)
	await shot("Research_Barracks")
	quit()

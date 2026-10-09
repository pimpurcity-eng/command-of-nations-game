extends SceneTree
## Portrait screenshot of the live game at a map location (review aid).
##   godot --path . --script tests/render_view.gd -- <out.png> <longitude> <latitude> [distance] [country]
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("ARSENAL") == "archive": ArsenalFixture.use_archive()
	var args: = OS.get_cmdline_user_args()
	root.size = Vector2i(540, 1200)
	GameSession.player_country = args[4] if args.size() > 4 else "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	for i in 3: await process_frame
	game.mobile_start.hide()
	game.apply_player_country()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	game.units.fog_enabled = false
	var focus: Vector3 = game.map_position(float(args[1]), float(args[2]))
	game.rig.target = Vector3(focus.x, 0, focus.z)
	game.rig.distance = float(args[3]) if args.size() > 3 else 14.0
	game.rig._snap(1.0)
	for i in 20: await process_frame
	root.get_texture().get_image().save_png(args[0])
	quit()

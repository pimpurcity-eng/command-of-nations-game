extends SceneTree
## Portrait screenshots of the 20-player Europe map (review aid).
##   godot --path . --script tests/render_europe.gd -- <out_prefix> [lon lat distance]...
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var args: = OS.get_cmdline_user_args()
	root.size = Vector2i(540, 1200)
	var started: = Time.get_ticks_msec()
	var view = load("res://scenes/europe_map.tscn").instantiate()
	root.add_child(view)
	current_scene = view
	print("europe map built in %d ms" % (Time.get_ticks_msec() - started))
	var shot: = 0
	for i in range(1, args.size() - 2, 3):
		var focus: = GeographicProjection.project(float(args[i]), float(args[i + 1]))
		view.rig.target = Vector3(focus.x, 0, focus.y)
		view.rig.distance = float(args[i + 2])
		view.rig._snap(1.0)
		for f in 12: await process_frame
		root.get_texture().get_image().save_png("%s_%d.png" % [args[0], shot])
		shot += 1
	quit()

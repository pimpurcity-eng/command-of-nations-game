extends SceneTree
## Start-menu screenshot (online button, music credit). BUILDING_PREVIEW_DIR sets the folder.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(720, 1440)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 12: await process_frame
	var folder: = OS.get_environment("BUILDING_PREVIEW_DIR")
	if folder.is_empty(): folder = "user://building-preview"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join("Start_Menu.png"))
	quit()

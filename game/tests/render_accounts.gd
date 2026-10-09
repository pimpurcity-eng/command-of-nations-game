extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	root.size=Vector2i(720,1440)
	var panel:=AccountPanel.new();root.add_child(panel);panel.open();panel.build("signup")
	for i in 10:await process_frame
	var folder:=OS.get_environment("ACCOUNT_PREVIEW_DIR");DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder.path_join("Create_Commander_Account.png"))
	panel.email="commander@example.org";panel.build("verify")
	for i in 10:await process_frame
	root.get_texture().get_image().save_png(folder.path_join("Confirm_Commander_Email.png"))
	print("Rendered native account screens")
	quit()

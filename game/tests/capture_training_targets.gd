extends SceneTree
## Owner 2026-10-17: inspect the real animated city target, two sections and both films.
var out := ""
var game: Node
var animation_frame := 0

func frames(count: int) -> void:
	if OS.get_environment("CAPTURE_ANIMATION") != "1": return
	var folder := out.path_join("animation")
	DirAccess.make_dir_recursive_absolute(folder)
	for i in count:
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("%04d.png" % animation_frame))
		animation_frame += 1

func _initialize() -> void: call_deferred("run")

func shot(label: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(label + ".png"))
	print("SHOT ", label)

func run() -> void:
	Engine.max_fps = 30
	if OS.get_environment("WF_LIST_MODELS") == "1":
		TrainingScenario.ensure_supplied_equipment()
		var paths := []
		for country in TrainingScenario.STARTING_FORCES:
			for family in TrainingScenario.STARTING_FORCES[country]:
				paths.append(EquipmentIdentity.research_tier(family + "_" + country, 1).get("model", ""))
		for id in TrainingScenario.AID_LOADS:
			for family in TrainingScenario.AID_LOADS[id].equipment:
				paths.append(EquipmentIdentity.research_tier(TrainingScenario.aid_equipment(id, family), 1).get("model", ""))
		paths.append("res://assets/library/transport/civil_container_t1_feeder.glb")
		paths.append("res://assets/library/transport/train_diesel_locomotive.glb")
		print("TRAINING_ASSETS ", JSON.stringify(paths))
		quit()
		return
	out = OS.get_environment("CAPTURE_DIR")
	if out.is_empty(): out = ProjectSettings.globalize_path("user://training-captures")
	DirAccess.make_dir_recursive_absolute(out)
	var packs := OS.get_environment("WF_QA_PACKS")
	for pack in packs.split(";", false):
		print("QA pack ", pack.get_file(), " ", ProjectSettings.load_resource_pack(pack, false))
	GameSession.player_country = "ukraine"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.country_picker.select(0)
	game.start_training()
	await create_timer(1.0).timeout
	await shot("01_opening_film")
	game.training_match.cinema.fit_button.pressed.emit()
	await shot("02_opening_full_frame")
	game.training_match.cinema._finish()
	await shot("03_two_sections")
	game.training_match.choose_side("ukraine", true)
	await shot("04_tap_tanks")
	game.session.training.step = 2
	game.training_match.show_step()
	await shot("05_open_city_target")
	await frames(45)
	game.training_match.coach.target_button.pressed.emit()
	await shot("06_city_opened")
	await frames(45)
	game.city_panel.hide()
	game.training_match.start_supply_movie()
	await create_timer(1.0).timeout
	await shot("07_supply_film")
	game.training_match.cinema._finish()
	await create_timer(6.2).timeout
	await shot("08_ship_arrived")
	print("QA capture complete")
	game.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	quit()

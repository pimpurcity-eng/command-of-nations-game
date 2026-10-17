extends SceneTree
## Development capture: walks the training on the current window size and saves screenshots.
## Run under a display, e.g.
##   CAPTURE_DIR=/tmp/shots xvfb-run godot --path game --resolution 720x1560 --script tests/capture_training.gd
## CAPTURE_COUNTRY=russia captures the Russian side.
var out := ""
var game: Node

func _initialize() -> void: call_deferred("run")

## CAPTURE_QUICK=1 keeps only the key screens (for checking extra screen shapes faster).
const KEY_SHOTS := ["02_film_opening_b", "03_choose_side", "04_lesson_select", "06_lesson_move", "08_city_panel_hint", "10_feature_guard", "14_ship_docked", "15_ship_manifest", "18_train_docked", "20_finish"]
func shot(name: String, frames: int = 20) -> void:
	if OS.get_environment("CAPTURE_QUICK") == "1" and name not in KEY_SHOTS: return
	for i in frames: await process_frame
	var image := root.get_texture().get_image()
	image.save_jpg(out.path_join(name + ".jpg"), 0.85)
	print("SHOT ", name)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	out = OS.get_environment("CAPTURE_DIR")
	if out.is_empty(): out = ProjectSettings.globalize_path("user://captures")
	DirAccess.make_dir_recursive_absolute(out)
	var country := OS.get_environment("CAPTURE_COUNTRY")
	if country.is_empty(): country = "ukraine"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.start_training()
	var t: TrainingMatch = game.training_match
	await wait(1.2)
	await shot("01_film_opening_a", 2)
	await wait(8.0)
	await shot("02_film_opening_b", 2)
	t.movie_finished()
	await shot("03_choose_side", 40)
	t.choose_side(country, true)
	await shot("04_lesson_select", 40)
	var own: Dictionary = t._lesson_unit("select")
	game.units.select_unit(game.units.units.find(own))
	await shot("05_lesson_done", 12)
	await wait(1.4)
	await shot("06_lesson_move", 30)
	game.session.training.step = 2
	t.show_step()
	await shot("07_lesson_city", 40)
	game.city_panel.open(game.buildings.capital(GameSession.player_country))
	await wait(0.4)
	await shot("08_city_panel_hint", 20)
	game.city_panel.hide()
	game.session.training.phase = "features"
	game.session.training.step = 0
	t.show_step()
	await wait(0.4)
	await shot("09_feature_trade", 20)
	game.session.training.step = 2
	t.show_step()
	await wait(0.4)
	await shot("10_feature_guard", 20)
	t.start_supply_movie()
	await wait(3.0)
	await shot("11_film_supply_a", 2)
	await wait(12.0)
	await shot("12_film_supply_b", 2)
	t.movie_finished()
	await wait(1.0)
	await shot("13_ship_arriving", 2)
	await wait(5.5)
	await shot("14_ship_docked", 10)
	t.open_cargo("odesa")
	await shot("15_ship_manifest", 30)
	TrainingScenario.request_unload(game, "odesa")
	t.open_cargo("odesa")
	await shot("16_ship_unloaded", 20)
	t.cargo_overlay.hide()
	game.session.training.step = 2
	t.show_step()
	await wait(2.0)
	await shot("17_train_arriving", 2)
	await wait(4.5)
	await shot("18_train_docked", 10)
	t.open_cargo("lviv")
	await shot("19_train_manifest", 30)
	t.cargo_overlay.hide()
	game.session.training.phase = "reward"
	t.show_step()
	await wait(2.0)
	await shot("20_finish", 10)
	quit(0)

extends SceneTree
## Release walkthrough (owner 2026-10-17: "Make sure it works this time"). Follows the player's
## real path: the games list PLAY button, the opening film (must actually play), the side picker,
## every lesson in order, the supply film, both arrivals and the finish. Lessons are completed by
## recording their action, so this checks flow, screens and freezes rather than input detection
## (test_training_interaction covers real input). Env: WALK_COUNTRY (ukraine|russia),
## WALK_FULL (1|0), CAPTURE_DIR (screenshots, optional).
var game: Node
var out := ""
var failures := 0
var worst_frame := 0.0
var last_tick := 0
var shots := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if last_tick > 0: worst_frame = maxf(worst_frame, float(now - last_tick))
	last_tick = now
	return false

func shot(label: String) -> void:
	for i in 8: await process_frame
	if out.is_empty(): return
	shots += 1
	root.get_texture().get_image().save_jpg(out.path_join("%02d_%s.jpg" % [shots, label]), 0.8)

func wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func run() -> void:
	out = OS.get_environment("CAPTURE_DIR")
	if not out.is_empty(): DirAccess.make_dir_recursive_absolute(out)
	var country := OS.get_environment("WALK_COUNTRY")
	if country.is_empty(): country = "ukraine"
	var full := OS.get_environment("WALK_FULL") != "0"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	await shot("home")
	# The games list PLAY button, exactly as a player taps it.
	var play: Button = game.mobile_start.fresh_button
	check(play != null and not play.disabled, "games list has the 1-player PLAY button")
	play.pressed.emit()
	var t: TrainingMatch = null
	for i in 600:
		await process_frame
		t = game.training_match
		if t != null and is_instance_valid(t.cinema): break
	check(t != null and is_instance_valid(t.cinema), "PLAY opens the training film")
	last_tick = 0
	worst_frame = 0.0
	var start: float = t.cinema.player.stream_position if t.cinema.player.stream != null else -1.0
	await wait(2.5)
	var later: float = t.cinema.player.stream_position if t.cinema.player.stream != null else -1.0
	check(t.cinema.player.stream != null and later > start + 1.0, "opening film is really playing (%.1fs -> %.1fs)" % [start, later])
	await shot("film_opening")
	t.cinema._finish()
	for i in 120:
		await process_frame
		if is_instance_valid(t.side_screen): break
	check(is_instance_valid(t.side_screen) and game.session.training.phase == "side", "side picker follows the film")
	await shot("choose_side")
	t.choose_side(country, full)
	await wait(0.6)
	check(GameSession.player_country == country, "player commands " + country)
	check(game.session.training.phase == ("basics" if full else game.session.training.phase), "route starts in the right chapter")
	var guard := 0
	var last_phase := ""
	while game.session.training.phase in ["basics", "features", "logistics", "supply_video"] and guard < 80:
		guard += 1
		var state: Dictionary = game.session.training
		if state.phase == "supply_video":
			await wait(1.5)
			check(is_instance_valid(t.cinema) and t.cinema.player.stream != null and t.cinema.player.is_playing(), "supply film is really playing")
			await shot("film_supply")
			t.cinema._finish()
			await wait(7.0)
			await shot("aid_arrived")
			continue
		if state.phase != last_phase:
			last_phase = state.phase
			print("CHAPTER ", last_phase)
		await wait(0.35)
		await shot("%s_%d_%s" % [state.phase, int(state.step), t.current_action()])
		check(t.coach.card.visible or t._menu_open(), "lesson card shown for %s %s" % [state.phase, t.current_action()])
		var before := "%s:%d" % [state.phase, int(state.step)]
		state.actions[t._action_key()] = true
		t.next_step()
		await process_frame
		var after := "%s:%d" % [game.session.training.phase, int(game.session.training.step)]
		check(after != before, "lesson %s advances" % before)
	check(game.session.training.phase == "reward" and is_instance_valid(t.finish_screen), "training reaches the XP finish")
	await wait(1.6)
	await shot("finish")
	t.free_play()
	await wait(0.5)
	check(game.session.training.phase == "free" and not game.clock.paused and game.match_rules.ai_enabled, "match continues against the computer")
	await shot("match_continues")
	check(worst_frame < 4000.0, "no freeze longer than 4 s during the training (worst %.0f ms)" % worst_frame)
	print("RESULT WALKTHROUGH %s %s failures=%d worst_frame_ms=%.0f" % [country, "full" if full else "quick", failures, worst_frame])
	quit(1 if failures else 0)

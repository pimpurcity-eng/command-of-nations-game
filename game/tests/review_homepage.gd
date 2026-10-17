extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func frames() -> void:
	for i in 8: await process_frame
func run() -> void:
	var audio := GameAudio.new()
	root.add_child(audio)
	audio.play_music("menu_theme")
	var original_music := GameAudio.music_enabled
	var original_sound := GameAudio.sound_enabled
	root.size = Vector2i(720,1440)
	var lobby := MobileStartPanel.new()
	root.add_child(lobby)
	lobby.audio = audio
	lobby.setup(StrategyTheme.create(), false)
	await frames()
	check(not lobby.continue_button.visible and lobby.continue_button.disabled, "new player has no invented saved match")
	check(lobby.join_button.get_global_rect().end.y < lobby.navigation.position.y, "Join New is visible on the phone's first screen")
	check(lobby.active_games().is_empty() and lobby.empty_labels[0].visible, "new player sees an empty active-games list")
	lobby.join_button.pressed.emit()
	for i in 4: await process_frame
	check(lobby.current_page == "games" and lobby.fresh_button.is_visible_in_tree(), "Join New opens the Games list with the 1-player tutorial")
	check(lobby.online_button.is_visible_in_tree() and lobby.europe_button.disabled and lobby.europe_button.text == "COMING SOON", "2-player tutorial listed, Europe coming soon")
	var started := [""]
	lobby.training_requested.connect(func(resume: bool): started[0] = "resume" if resume else "new")
	lobby.fresh_button.pressed.emit()
	for i in 3: await process_frame
	check(started[0] == "new", "1-player tutorial button starts the tutorial")
	lobby.cancel_loading("Ready")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("HOME_REVIEW_DIR").path_join("Games_List.png"))
	lobby.nav_buttons.home.pressed.emit()
	await frames()
	check(lobby.scroll.get_combined_minimum_size().x <= 720, "phone page does not overflow horizontally")
	check(audio.music_playing() == "menu_theme", "menu music remains active")
	lobby.country_cards.ukraine.pressed.emit()
	check(lobby.selected_country() == "ukraine" and lobby.selected_doctrine() == "european", "nation card chooses the real doctrine")
	lobby.country_cards.russia.pressed.emit()
	check(lobby.selected_country() == "russia", "other nation remains selectable")
	lobby.music_button.pressed.emit()
	check(GameAudio.music_enabled != original_music, "Music button changes actual music preference")
	lobby.music_button.pressed.emit()
	lobby.sound_button.pressed.emit()
	check(GameAudio.sound_enabled != original_sound, "Sound button changes actual sound preference")
	lobby.sound_button.pressed.emit()
	var actions := [0]
	lobby.account_requested.connect(func(): actions[0] += 1)
	lobby.profile_button.pressed.emit()
	check(actions[0] == 1, "account action is wired")
	for id in ["games", "features", "updates", "settings", "home"]:
		lobby.nav_buttons[id].pressed.emit()
		await frames()
		check(lobby.current_page == id and lobby.pages[id].visible, "navigation opens " + id)
		check(lobby.pages.values().filter(func(p): return p.visible).size() == 1, "only the selected page is visible")
		if id == "features" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("HOME_REVIEW_DIR").path_join("Features_Home.png"))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("HOME_REVIEW_DIR").path_join("App_Game_Home.png"))
	lobby.begin_loading()
	lobby.nav_buttons.features.pressed.emit()
	check(lobby.current_page == "home" and lobby.fresh_button.disabled, "loading cannot start a second action or switch pages")
	lobby.cancel_loading("Ready")
	check(not lobby.fresh_button.disabled and not lobby.nav_buttons.features.disabled, "a cancelled connection returns to a usable lobby")
	lobby.queue_free()
	await frames()
	var saved := MobileStartPanel.new()
	root.add_child(saved)
	saved.audio = audio
	saved.setup(StrategyTheme.create(), true)
	await frames()
	check(saved.continue_button.is_visible_in_tree() and not saved.continue_button.disabled, "saved player can resume")
	saved.show_paused_match("training")
	await frames()
	var kinds: Array = saved.game_rows.filter(func(r): return r.card.is_visible_in_tree()).map(func(r): return r.kind)
	check("training" in kinds and "campaign" in kinds, "several games are listed at once: " + str(kinds))
	var resumed := [0]
	saved.resume_requested.connect(func(): resumed[0] += 1)
	for r in saved.game_rows:
		if r.kind == "training" and r.card.is_visible_in_tree(): r.button.pressed.emit()
	for i in 3: await process_frame
	check(resumed[0] == 1, "the paused tutorial resumes in place")
	saved.cancel_loading("Ready")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("HOME_REVIEW_DIR").path_join("Saved_Campaign_Home.png"))
	root.size = Vector2i(1440,900)
	await frames()
	check(saved.navigation.get_global_rect().end.x <= root.get_visible_rect().size.x, "desktop navigation stays in view")
	check(saved.scroll.get_combined_minimum_size().x <= 1100, "desktop page stays within its column")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("HOME_REVIEW_DIR").path_join("Desktop_Game_Home.png"))
	print("Homepage review: ", failures, " failures")
	saved.queue_free()
	audio.queue_free()
	await frames()
	quit(1 if failures else 0)

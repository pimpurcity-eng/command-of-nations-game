extends SceneTree
## Sounds and music (owner request 2026-10-12): every sound exists, weapons and events play,
## Sound/Music switches work and are remembered.
##   godot --headless --path . --script tests/test_game_audio.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	ArsenalFixture.use_archive()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameAudio.SETTINGS_PATH))
	GameAudio._loaded = false
	GameAudio.sound_enabled = true
	GameAudio.music_enabled = true
	var missing: = []
	for name in GameAudio.VOLUME:
		if not ResourceLoader.exists(GameAudio.SFX_DIR + name + ".ogg"): missing.append(name)
	for name in ["menu_theme", "battle_theme"]:
		if not ResourceLoader.exists(GameAudio.MUSIC_DIR + name + ".ogg"): missing.append(name)
	check(missing.is_empty(), "every sound and music track exists (%s)" % [missing])
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	current_scene = game
	for i in 4: await process_frame
	var audio: GameAudio = game.audio
	check(audio != null and audio.music_playing() == "menu_theme", "the menu theme plays on the start screen")
	check(game.mobile_start.music_button.text == "MUSIC: ON" and game.mobile_start.sound_button.text == "SOUND: ON", "the start screen shows Music and Sound switches")
	game.mobile_start.fresh_requested.emit()
	game.mobile_start.hide()
	for i in 90: await process_frame
	check(audio.music_playing() == "battle_theme", "the battle theme plays once the campaign starts")
	# Weapons: every combat effect maps to its own weapon sound and plays near the camera.
	var tank: Dictionary = {}
	for unit in game.units.units:
		if unit.country == "russia" and unit.visual_kind == "armor": tank = unit
	game.rig.target = tank.node.position
	game.rig.distance = 14.0
	game.rig._snap(1.0)
	var played: = []
	for shot in [["cannon", "tanks_russia"], ["tracer", "apcs_russia"], ["missile", "iskander_m"], ["artillery", "msta_s"], ["interceptor", "patriot_ukraine"], ["air_strike", "bombers_russia"], ["drone_strike", "shahed_136"]]:
		if audio.play_shot(shot[0], {"equipment_id": shot[1], "visual_kind": "air_defense" if shot[0] == "interceptor" else ""}, tank.node.position): played.append(shot[1])
	check(played.size() == 7, "tank, machine gun, missile, artillery, air defence, bomber and drone sounds play near the camera (%s)" % [played])
	# Every weapon type has its own sound (owner: "make sound for all weapons"), including the
	# 0.22 roster's infantry, rocket artillery, missiles, helicopters, drones and navy.
	var cases: = [
		[{"equipment_id": "infantry_russia"}, "tracer", "rifle_fire"], [{"equipment_id": "sniper_team"}, "tracer", "sniper_shot"],
		[{"equipment_id": "mortar_ukraine"}, "artillery", "mortar_fire"], [{"equipment_id": "javelin_team"}, "missile", "atgm_launch"],
		[{"equipment_id": "apcs_russia"}, "tracer", "heavy_machine_gun"], [{"equipment_id": "bmp3"}, "tracer", "autocannon"],
		[{"equipment_id": "tanks_ukraine"}, "cannon", "tank_cannon"], [{"equipment_id": "msta_s"}, "artillery", "artillery"],
		[{"equipment_id": "mlrs_russia"}, "missile", "mlrs_salvo"], [{"equipment_id": "iskander_m"}, "missile", "ballistic_missile"],
		[{"equipment_id": "kalibr_launcher"}, "missile", "cruise_missile"], [{"equipment_id": "shilka", "visual_kind": "air_defense"}, "interceptor", "aa_gun"],
		[{"equipment_id": "patriot_ukraine", "visual_kind": "air_defense"}, "interceptor", "interceptor"],
		[{"equipment_id": "fighters_russia"}, "air_strike", "jet_cannon"], [{"equipment_id": "fighters_russia"}, "interceptor", "interceptor"],
		[{"equipment_id": "bombers_russia"}, "air_strike", "bomber_strike"], [{"equipment_id": "ka52_attack_helicopter"}, "air_strike", "helicopter_rockets"],
		[{"equipment_id": "shahed_136"}, "drone_strike", "kamikaze_drone"], [{"equipment_id": "drones_ukraine"}, "drone_strike", "drone_strike"],
		[{"equipment_id": "frigate_europe"}, "artillery", "naval_gun"], [{"equipment_id": "destroyer_russia"}, "missile", "ship_missile"],
		[{"equipment_id": "corvette_russia"}, "interceptor", "ship_missile"], [{"equipment_id": "submarine_europe"}, "missile", "torpedo_launch"],
		[{"equipment_id": "carrier_russia"}, "air_strike", "carrier_launch"],
	]
	var wrong: = cases.filter(func(c: Array): return GameAudio.sound_for(c[0], c[1]) != c[2]).map(func(c: Array): return "%s→%s" % [c[0].equipment_id, GameAudio.sound_for(c[0], c[1])])
	check(wrong.is_empty(), "every weapon type gets its own sound (%s)" % [wrong])
	var unused: = GameAudio.VOLUME.keys().filter(func(n: String): return not ResourceLoader.exists(GameAudio.SFX_DIR + n + ".ogg"))
	check(unused.is_empty() and GameAudio.VOLUME.size() >= 37, "all %d sounds are in the game" % GameAudio.VOLUME.size())
	var naval: = {"visual_kind": "naval"}
	check(GameAudio.SHOT_SOUNDS.cannon == "tank_cannon" and audio.play_shot("artillery", naval, tank.node.position + Vector3(0.2, 0, 0)), "ships fire with the naval gun sound")
	check(not audio.play("explosion_small", tank.node.position + Vector3(400, 0, 0)), "battles far off-screen are silent")
	game.combat_effects.explode(tank.node.position, true)
	check(audio._pool.any(func(p: AudioStreamPlayer): return p.playing and p.stream == audio._stream("explosion_large")), "explosions are heard")
	# Events.
	game.match_rules.declare_war()
	check(audio._pool.any(func(p: AudioStreamPlayer): return p.playing and p.stream == audio._stream("war_declared")), "declaring war sounds the siren")
	# Switches.
	audio.set_sound(false)
	check(not audio.play("ui_click") and audio._pool.all(func(p: AudioStreamPlayer): return not p.playing), "Sound OFF silences everything at once")
	audio.set_music(false)
	check(audio.music_playing().is_empty(), "Music OFF stops the music")
	GameAudio._loaded = false
	GameAudio.sound_enabled = true
	GameAudio.music_enabled = true
	GameAudio.load_settings()
	check(not GameAudio.sound_enabled and not GameAudio.music_enabled, "the switches are remembered")
	game.hud._show_audio_items()
	check(game.hud.settings_menu.get_item_text(game.hud.settings_menu.get_item_index(31)) == "Sound: OFF" and game.hud.settings_menu.get_item_text(game.hud.settings_menu.get_item_index(32)) == "Music: OFF", "Settings shows Sound and Music switches")
	audio.set_sound(true)
	audio.set_music(true)
	print("RESULT failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

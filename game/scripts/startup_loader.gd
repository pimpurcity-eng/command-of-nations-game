extends Node
var panel: MobileStartPanel
var loaded: Array[Resource] = []
var audio: GameAudio
func _ready() -> void:
	audio = GameAudio.new()
	add_child(audio)
	audio.play_music("menu_theme")
	panel = MobileStartPanel.new()
	panel.audio = audio
	add_child(panel)
	panel.setup(StrategyTheme.create(),FileAccess.file_exists("user://regional_save.json"))
	panel.layer = 30
	panel.begin_loading()
	await get_tree().process_frame
	var catalog: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	var scenario: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/scenario_regional.json"))
	var paths: Array[String] = []
	for unit in scenario.units:
		for family in catalog:
			if family.id != unit.get("equipment_id",""): continue
			var tiers: Array = family.get("research_tiers",[])
			if tiers.is_empty(): continue
			var path: String = tiers[clampi(int(unit.get("level",1))-1,0,tiers.size()-1)].model
			if not paths.has(path): paths.append(path)
	paths.append("res://scenes/main.tscn")
	for i in paths.size():
		var path: String = paths[i]
		if ResourceLoader.load_threaded_request(path) != OK:
			panel.set_progress(panel.progress.value,"Unable to load campaign. Please restart.")
			push_error("Startup resource failed: "+path)
			return
		var fraction: Array = []
		while ResourceLoader.load_threaded_get_status(path,fraction) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			panel.set_progress(90.0*(i+float(fraction[0]))/paths.size(),"Loading campaign")
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
			panel.set_progress(panel.progress.value,"Unable to load campaign. Please restart.")
			return
		loaded.append(ResourceLoader.load_threaded_get(path))
		panel.set_progress(90.0*(i+1)/paths.size(),"Loading campaign")
		await get_tree().process_frame
	panel.set_progress(95,"Preparing map and forces")
	await get_tree().process_frame
	if get_tree().node_added.is_connected(audio._watch_button): get_tree().node_added.disconnect(audio._watch_button)
	var game: Node = (loaded[-1] as PackedScene).instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	panel.set_progress(100,"Ready")
	queue_free()

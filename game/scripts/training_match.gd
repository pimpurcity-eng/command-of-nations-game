class_name TrainingMatch
extends CanvasLayer
## Two cinematics with 5–10 real, foreground minutes of hands-on teaching between them.
const BASICS := [
	["select", "YOUR FIRST ORDER", "Tap one of your tanks. All starting troops are level 1. Russia begins with more troops and stronger income; Ukraine receives allied aid later. Show me focuses a suitable tank."],
	["move", "MOVE AN ARMY", "With your tank selected, tap Move, then nearby friendly ground. The lesson completes when your army starts moving. Drag and pinch the map to look around."],
	["city", "USE A CITY", "Tap one of your cities. Airports, drone factories, tank plants and barracks are already built. Show me focuses your capital."],
	["unit_card", "KNOW YOUR EQUIPMENT", "Open Research, then tap a unit picture to inspect its level-1 card, stats and costs. Close the card and Research when you are ready."],
	["research", "START RESEARCH", "In Research, start a level-1 research job for your country. Tanks are a useful first choice. Close the panel to continue; the research keeps running."],
	["produce", "QUEUE A UNIT", "Open your capital and queue basic infantry from the Infantry tab. This training preset already knows infantry level 1, so production can start while another family researches."],
	["patrol", "DRONES AND AIR DEFENCE", "Select a drone and set a patrol inside its airbase range. Keep air defence near valuable armies. Aircraft need a friendly airport to return and refuel."],
	["build", "BUILD YOUR ECONOMY", "Open a friendly city and queue a building, such as Industry. Construction and unit production use separate queues. Close the city to continue."],
]
const FEATURES := [
	["trade", "PHYSICAL TRADE", "Open Trade. Resources and equipment travel by train, ship or cargo aircraft. Inspect world prices and route capacity before committing to a shipment."],
	["world_prices", "THE TRANSPORT MARKET", "In Trade, open the Transport market tab. Compare prices, cargo capacity and equipment offers before committing funds."],
	["guard", "SLEEP DEFENCE", "Try Guard to let the defence AI protect your armies. In an online match the server must keep running while you are away; this offline training match pauses when the app is closed."],
	["victory", "AN ECONOMY CAN WIN", "Open Victory progress to inspect the economic objective. Build income, infrastructure and trade as well as armies. Imported aid does not count as newly earned victory income."],
	["diplomacy", "DIPLOMACY AND SUPPORT", "Open Diplomacy to inspect relations, alliances and resource transfers. Infantry and strategic weapons are not sold on the arms market."],
]
const LOGISTICS := [
	["inspect_ship", "THE LOADED SHIP · ODESA", "The American ship is at Odesa with five level-1 weapons, including a plane, plus resource cargo. Tap the ship, or Show me, to inspect its manifest. Aid belongs to Ukraine whichever side you command."],
	["unload_ship", "UNLOAD THE SHIP", "Open the ship and choose Unload cargo. Its weapons appear at Odesa and its resources enter Ukraine's stockpile. If you command Russia, choose Watch Ukraine unload."],
	["inspect_train", "EUROPEAN WEAPONS · LVIV", "The train from Europe is at Lviv with five more level-1 weapons. Tap the train, or Show me, to inspect it. The train carries weapons; resource crates came on the ship."],
	["unload_train", "UNLOAD THE TRAIN", "Open the train and unload its weapons at Lviv. European financial assistance is credited with the delivery. A lost terminal holds its requested cargo until Ukraine recovers it."],
	["reinforcements", "PUT YOUR TROOPS TO WORK", "Ukraine: select one of your unloaded ground units and order it toward friendly ground. Russia: move one of your tanks while observing Ukraine's reinforcements. Show me selects a suitable army."],
	["trade", "PROTECT THE SUPPLY NETWORK", "Odesa receives the ship; Lviv receives the train. In ordinary trade, trains and ships carry real cargo and can be attacked. Station levels and transport research raise capacity."],
	["next", "TAKE COMMAND", "Move reinforcements where they are needed, queue construction and choose your path to victory. The guided introduction is complete; this match continues with the opponent AI active."],
]
var game: Node
var root: Control
var card: PanelContainer
var heading: Label
var body: Label
var next_button: Button
var options: VBoxContainer
var movie_cover: ColorRect
var movie: VideoStreamPlayer
var movie_message: Label
var _movie_after := ""
var _poll := 0.0
var _previous_music := false
var _backgrounded := false
var supplies: TrainingSupplies
var cargo_overlay: ColorRect
var cargo_text: Label
var _cargo_id := ""
var show_button: Button
var _highlight: Panel
var _beacon: MeshInstance3D
var _menu_hint: Label
var _complete_delay := 0.0

func setup(main: Node, theme: Theme) -> void:
	game = main
	layer = 25
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.add_theme_stylebox_override("panel", CowUI.box(Color(0, 0, 0, 0), 6, CowUI.GOLD, 3, 0))
	_highlight.hide()
	root.add_child(_highlight)
	card = PanelContainer.new()
	card.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	card.offset_left = 12
	card.offset_right = -12
	card.offset_top = 132
	card.add_theme_stylebox_override("panel", CowUI.box(Color(0.05, 0.09, 0.12, 0.97), 10, CowUI.GOLD, 1, 16))
	root.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	heading = CowUI.label("", 22)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(heading)
	body = CowUI.label("", 18)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(body)
	options = VBoxContainer.new()
	column.add_child(options)
	for spec in [["Full training", "full"], ["New features only", "features"], ["Skip introduction · Play now", "skip"]]:
		var button := _button(spec[0])
		button.pressed.connect(begin.bind(spec[1]))
		options.add_child(button)
	var row := HBoxContainer.new()
	column.add_child(row)
	next_button = _button("Next")
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_button.pressed.connect(next_step)
	row.add_child(next_button)
	show_button = _button("Show me")
	show_button.pressed.connect(focus_objective)
	row.add_child(show_button)
	var skip := _button("Skip lessons")
	skip.pressed.connect(skip_lessons)
	row.add_child(skip)
	if not game.session.training.has("actions"): game.session.training.actions = {}
	if not game.session.training.aid_pending.is_empty() or not game.session.training.aid_received.is_empty(): _ensure_supplies()
	if game.session.training.phase in ["opening", "supply_video"]:
		play_movie(game.session.training.phase == "opening")
	else:
		show_step()

func _button(title: String) -> Button:
	var result := Button.new()
	result.text = title
	result.custom_minimum_size.y = 52
	return result

func begin(route: String) -> void:
	game.session.training.route = route
	game.session.training.step = 0
	if route == "full":
		game.session.training.phase = "opening"
		play_movie(true)
	elif route == "features":
		game.session.training.phase = "features"
		game.clock.paused = false
		show_step()
	else:
		# Explicitly skipping both films uses the same post-arrival state, once.
		TrainingScenario.release_aid(game, true)
		free_play()

func show_step() -> void:
	_clear_focus()
	_complete_delay = 0.0
	var phase: String = game.session.training.phase
	options.visible = phase == "choice"
	next_button.visible = phase not in ["choice", "practice", "free"]
	card.visible = phase != "free"
	show_button.visible = phase in ["basics", "features", "logistics"]
	next_button.disabled = current_action() != "next" and not action_completed()
	match phase:
		"choice":
			heading.text = "FIRST MATCH · RUSSIA–UKRAINE"
			body.text = "Level-1 armies, ready facilities and a smaller battlefield force. Watch the opening, learn by playing, then meet the supply ship and train. Choose how much guidance you want."
		"practice":
			heading.text = "TRY YOUR ORDERS"
			body.text = "Keep building, moving and inspecting the new features. The supply arrival follows your first few minutes of play."
		"basics", "features", "logistics":
			var steps: Array = BASICS if phase == "basics" else FEATURES if phase == "features" else LOGISTICS
			var index := clampi(int(game.session.training.step), 0, steps.size() - 1)
			heading.text = "%s · %d/%d" % [steps[index][1], index + 1, steps.size()]
			body.text = steps[index][2]
			next_button.text = "Take command" if phase == "logistics" and index == steps.size() - 1 else "Next"
	game.autosave()
	if phase == "basics" and int(game.session.training.step) == 0: focus_objective()

func next_step() -> void:
	var state: Dictionary = game.session.training
	if state.phase not in ["basics", "features", "logistics"]: return
	if current_action() != "next" and not action_completed(): return
	var steps: Array = BASICS if state.phase == "basics" else FEATURES if state.phase == "features" else LOGISTICS
	state.step += 1
	if state.step >= steps.size():
		state.step = 0
		if state.phase == "basics": state.phase = "features"
		elif state.phase == "features":
			state.phase = "practice"
			if float(state.active_seconds) >= TrainingScenario.MIN_PLAY_SECONDS:
				start_supply_movie()
				return
		else:
			free_play()
			return
	show_step()

func skip_lessons() -> void:
	if game.session.training.phase == "choice":
		begin("skip")
	elif game.session.training.phase == "logistics":
		free_play()
	else:
		# Lessons can be skipped while retaining the requested second cinematic.
		game.session.training.phase = "practice"
		game.session.training.step = 0
		game.clock.paused = false
		show_step()

func advance_training(real_seconds: float) -> void:
	var state: Dictionary = game.session.training
	if state.phase not in ["basics", "features", "practice"] or real_seconds <= 0: return
	state.active_seconds += real_seconds
	if (state.phase == "practice" and state.active_seconds >= TrainingScenario.MIN_PLAY_SECONDS) or state.active_seconds >= TrainingScenario.MAX_PLAY_SECONDS:
		start_supply_movie()

func start_supply_movie() -> void:
	game.session.training.phase = "supply_video"
	game.session.training.video_position = 0.0
	play_movie(false)

func play_movie(opening: bool) -> void:
	game.clock.paused = true
	card.hide()
	_movie_after = "basics" if opening else "logistics"
	movie_cover = ColorRect.new()
	movie_cover.color = Color.BLACK
	movie_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(movie_cover)
	var aspect := AspectRatioContainer.new()
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	movie_cover.add_child(aspect)
	movie = VideoStreamPlayer.new()
	movie.expand = true
	movie.volume_db = -6.0 if GameAudio.sound_enabled else -80.0
	aspect.add_child(movie)
	var path := TrainingScenario.OPENING_VIDEO if opening else TrainingScenario.SUPPLY_VIDEO
	var skip := _button("Skip video")
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -200
	skip.offset_top = -90
	skip.offset_right = -20
	skip.offset_bottom = -25
	skip.pressed.connect(movie_finished)
	movie_cover.add_child(skip)
	movie_message = CowUI.label("", 22)
	movie_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	movie_message.offset_left = -280
	movie_message.offset_right = 280
	movie_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	movie_cover.add_child(movie_message)
	_previous_music = GameAudio.music_enabled
	if game.audio != null: game.audio.pause_music_for_cinematic(true)
	if ResourceLoader.exists(path):
		movie.stream = load(path) as VideoStream
		if movie.stream != null:
			movie.finished.connect(movie_finished, CONNECT_ONE_SHOT)
			movie.play()
			movie.stream_position = float(game.session.training.get("video_position", 0.0))
		else:
			movie_message.text = "This video could not be played. You can continue the training."
	else:
		movie_message.text = "The opening video is not installed in this build." if opening else "The ship and train video is not installed in this build. Continue to unloading."
		skip.text = "Continue" if opening else "Continue to unloading"
	game.autosave()

func movie_finished() -> void:
	if _movie_after.is_empty(): return
	var after := _movie_after
	_movie_after = ""
	if is_instance_valid(movie): movie.stop()
	if is_instance_valid(movie_cover): movie_cover.queue_free()
	game.session.training.video_position = 0.0
	game.session.training.phase = after
	game.session.training.step = 0
	if after == "basics":
		game.units.selected = -1
		game.units.command_ids.clear()
		game.hud.clear_unit_selection()
	if after == "logistics":
		TrainingScenario.release_aid(game)
		_ensure_supplies()
		supplies.focus("odesa")
	if game.audio != null:
		game.audio.pause_music_for_cinematic(false)
		if _previous_music: game.audio.play_music("battle_theme")
	game.clock.paused = false
	show_step()

func free_play() -> void:
	TrainingScenario.request_unload(game)
	if not game.session.training.aid_received.is_empty(): _ensure_supplies()
	_clear_focus()
	game.session.training.phase = "free"
	Tutorial.mark_done()
	game.match_rules.ai_enabled = true
	game.clock.paused = false
	card.hide()
	game.autosave()
	game.hud.show_status("TRAINING COMPLETE · Take command. Your match continues.")

func _process(delta: float) -> void:
	if game == null: return
	var suspended: bool = _backgrounded or game.mobile_start.visible or game.browser_suspended
	root.visible = not suspended
	if is_instance_valid(movie): movie.paused = suspended
	if suspended: return
	if not game.match_rules.winner.is_empty():
		card.hide()
		return
	if is_instance_valid(movie) and movie.is_playing(): game.session.training.video_position = movie.stream_position
	if not game.clock.paused: advance_training(minf(delta, 0.25))
	_poll += delta
	if _poll < 0.3: return
	_poll = 0.0
	if not game.session.training.aid_pending.is_empty():
		TrainingScenario.try_unload(game)
		if is_instance_valid(supplies): supplies.refresh()
	if not _movie_after.is_empty(): return
	var menu_open := false
	for key in ["city_panel", "province_panel", "research_panel", "production_panel", "campaign_panel", "trade_panel", "exchange_panel", "weapon_showcase", "army_selection", "army_command", "stack_dialog", "fire_panel"]:
		var menu = game.get(key)
		if menu != null and is_instance_valid(menu) and menu.visible: menu_open = true
	if game.account_panel != null and game.account_panel.overlay.visible: menu_open = true
	if is_instance_valid(game.research_panel.unit_card) and game.research_panel.unit_card.visible: menu_open = true
	if is_instance_valid(cargo_overlay) and cargo_overlay.visible: menu_open = true
	card.visible = not menu_open and game.session.training.phase != "free"
	if game.session.training.phase in ["basics", "features", "logistics"]:
		if _action_done() and not game.session.training.actions.get(_action_key(), false):
			game.session.training.actions[_action_key()] = true
			game.autosave()
		var complete := action_completed()
		next_button.disabled = not complete
		next_button.text = "Take command" if current_action() == "next" else "Done · Next" if complete else "Complete the action"
		_update_guidance(menu_open)
		if complete and current_action() != "next" and not menu_open:
			_complete_delay += 0.3
			if _complete_delay >= 0.9: next_step()
		else: _complete_delay = 0.0
	if game.session.training.phase == "practice":
		var left := maxi(0, ceili(TrainingScenario.MIN_PLAY_SECONDS - float(game.session.training.active_seconds)))
		body.text = "Keep building, moving and trying the new features. Supply arrival in %d:%02d of active play." % [left / 60, left % 60]

func contains_screen(point: Vector2) -> bool:
	if not visible or not root.visible: return false
	if not _movie_after.is_empty(): return true
	if is_instance_valid(cargo_overlay) and cargo_overlay.visible: return true
	return card.visible and card.get_global_rect().has_point(get_final_transform().affine_inverse() * point)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]: _backgrounded = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]: _backgrounded = false

func _exit_tree() -> void:
	if is_instance_valid(movie): movie.stop()
	if is_instance_valid(supplies): supplies.queue_free()
	_clear_focus()
	if game != null and is_instance_valid(game.audio): game.audio.pause_music_for_cinematic(false)

func current_action() -> String:
	var phase: String = game.session.training.phase
	if phase not in ["basics", "features", "logistics"]: return ""
	var steps: Array = BASICS if phase == "basics" else FEATURES if phase == "features" else LOGISTICS
	return steps[clampi(int(game.session.training.step), 0, steps.size() - 1)][0]

func _action_key() -> String:
	return str(game.session.training.phase) + ":" + current_action()

func action_completed() -> bool:
	return bool(game.session.training.get("actions", {}).get(_action_key(), false)) or _action_done()

func _selected() -> Dictionary:
	var index: int = game.units.selected
	if index < 0 or index >= game.units.units.size(): return {}
	var unit: Dictionary = game.units.units[index]
	return unit if unit.country == GameSession.player_country else {}

func _action_done() -> bool:
	var selected := _selected()
	var country := GameSession.player_country
	match current_action():
		"select": return not selected.is_empty() and selected.visual_kind == "armor"
		"move": return not selected.is_empty() and selected.visual_kind == "armor" and selected.moving
		"city": return game.city_panel.visible and game.production.controlled(game.buildings.city(game.city_panel.city_id), country)
		"unit_card": return game.research_panel.unit_card.visible and EquipmentIdentity.spec(game.research_panel.unit_card.equipment_id).get("country", "") == country
		"research": return game.research.jobs.any(func(job: Dictionary): return game.production.equipment(job.equipment).country == country)
		"produce": return game.production.jobs.any(func(job: Dictionary): return game.production.equipment(job.equipment).country == country)
		"patrol": return game.units.units.any(func(unit: Dictionary): return unit.country == country and EquipmentIdentity.spec(unit.equipment_id).get("role", "") == "drone" and unit.get("flight_mode", "") == "patrol")
		"build": return game.buildings.jobs.any(func(job: Dictionary): return job.country == country)
		"trade": return game.trade_panel != null and game.trade_panel.visible
		"world_prices": return game.trade_panel != null and game.trade_panel.visible and game.trade_panel.market_view
		"guard": return game.match_rules.guarded(country)
		"victory", "diplomacy": return game.campaign_panel != null and game.campaign_panel.visible and game.campaign_panel.tab == current_action()
		"inspect_ship", "inspect_train": return is_instance_valid(cargo_overlay) and cargo_overlay.visible and _cargo_id == ("odesa" if current_action() == "inspect_ship" else "lviv")
		"unload_ship": return "odesa" in game.session.training.aid_received
		"unload_train": return "lviv" in game.session.training.aid_received
		"reinforcements": return not selected.is_empty() and selected.moving and (str(selected.id).begins_with("training_aid_") if country == "ukraine" else selected.visual_kind == "armor")
		"next": return true
	return false

func focus_objective() -> void:
	var action := current_action()
	if action in ["inspect_ship", "unload_ship", "inspect_train", "unload_train"]:
		open_cargo("odesa" if action.ends_with("ship") else "lviv")
		return
	if action in ["unit_card", "research"]:
		game.research_panel.open()
		return
	if action in ["trade", "world_prices"]:
		if game.trade_panel == null:
			game.trade_panel = TradePanel.new()
			game.add_child(game.trade_panel)
			game.trade_panel.setup(game.trade, root.theme)
		game.trade_panel.open()
		return
	if action in ["victory", "diplomacy"]:
		game.open_campaign(action)
		return
	var position := Vector3.ZERO
	if action in ["city", "build", "produce"]:
		var capital: Dictionary = game.buildings.capital(GameSession.player_country)
		position = game.map.position_at(capital.point)
		if action in ["build", "produce"]: game.city_panel.open(capital)
	else:
		var candidates: Array = game.units.units.filter(func(unit: Dictionary):
			if unit.country != GameSession.player_country: return false
			if action == "patrol": return EquipmentIdentity.spec(unit.equipment_id).get("role", "") == "drone"
			if action == "reinforcements" and GameSession.player_country == "ukraine": return str(unit.id).begins_with("training_aid_") and unit.visual_kind == "armor"
			return unit.visual_kind == "armor")
		if candidates.is_empty(): return
		var unit: Dictionary = candidates[0]
		position = unit.node.position
		if action in ["patrol", "reinforcements"]: game.units.select_unit(game.units.units.find(unit))
	game.rig.target = position
	game.rig.distance = 8.0
	game.rig._snap(1.0)
	if is_instance_valid(_beacon): _beacon.queue_free()
	_beacon = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.55
	ring.outer_radius = 0.68
	_beacon.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = CowUI.GOLD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beacon.material_override = material
	_beacon.position = position + Vector3.UP * 0.1
	game.add_child(_beacon)

func _update_guidance(menu_open: bool) -> void:
	_highlight.hide()
	if not menu_open:
		if is_instance_valid(_menu_hint): _menu_hint.hide()
		var target: Control
		match current_action():
			"move": target = game.hud.move_button
			"patrol": target = game.hud.patrol_button
			"guard": target = game.hud.guard_button
			_:
				var tab: String = {"unit_card":"research", "research":"research", "produce":"produce", "build":"produce", "trade":"market", "world_prices":"market", "victory":"more", "diplomacy":"diplomacy"}.get(current_action(), "")
				for button in game.hud.nav_row.get_children():
					if button.get_meta("tutorial_action", "") == tab: target = button
		if target != null and target.is_visible_in_tree():
			var transform: Transform2D = root.get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas()
			_highlight.position = transform.origin - Vector2(3, 3)
			_highlight.size = target.size * transform.get_scale() + Vector2(6, 6)
			_highlight.show()
		return
	var panel: Node
	for candidate in [game.city_panel, game.research_panel, game.trade_panel, game.campaign_panel, game.research_panel.unit_card]:
		if candidate != null and candidate.visible: panel = candidate
	if panel == null:
		if is_instance_valid(_menu_hint): _menu_hint.hide()
		return
	# Research owns a separate hidden unit-card layer before its main panel.
	# Search only the panel being displayed so guidance cannot land in that hidden card.
	var surface: Control = panel.get("panel")
	if surface == null: return
	var columns := surface.find_children("*", "VBoxContainer", true, false)
	if columns.is_empty(): return
	var column: VBoxContainer = columns[0]
	if not is_instance_valid(_menu_hint):
		_menu_hint = CowUI.label("", 17)
		_menu_hint.name = "TrainingObjective"
		_menu_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_hint.add_theme_color_override("font_color", CowUI.GOLD)
		column.add_child(_menu_hint)
	elif _menu_hint.get_parent() != column:
		_menu_hint.reparent(column)
	column.move_child(_menu_hint, mini(1, column.get_child_count() - 1))
	_menu_hint.text = "✓ Done. Close the panel to continue." if action_completed() else "TRAINING · " + body.text
	_menu_hint.show()

func _clear_focus() -> void:
	if is_instance_valid(_beacon): _beacon.queue_free()
	if is_instance_valid(_highlight): _highlight.hide()
	if is_instance_valid(_menu_hint):
		_menu_hint.queue_free()
		_menu_hint = null

func _ensure_supplies() -> void:
	if not is_instance_valid(supplies):
		supplies = TrainingSupplies.new()
		game.add_child(supplies)
		supplies.setup(game)
	else: supplies.refresh()

func pick_supply(screen: Vector2) -> bool:
	if not is_instance_valid(supplies) or not _movie_after.is_empty(): return false
	var id := supplies.pick(game.rig.camera, screen)
	if id.is_empty(): return false
	open_cargo(id)
	return true

func open_cargo(id: String) -> void:
	if not TrainingScenario.AID_LOADS.has(id): return
	if id not in game.session.training.aid_pending and id not in game.session.training.aid_received: return
	_ensure_supplies()
	supplies.focus(id)
	_cargo_id = id
	if is_instance_valid(cargo_overlay):
		cargo_overlay.hide()
		cargo_overlay.queue_free()
	cargo_overlay = ColorRect.new()
	cargo_overlay.color = Color(0.01, 0.025, 0.04, 0.95)
	cargo_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(cargo_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cargo_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = minf(600, get_viewport().get_visible_rect().size.x - 32)
	panel.add_theme_stylebox_override("panel", CowUI.box(Color("152532"), 12, CowUI.GOLD, 2, 20))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	var title := CowUI.label("SUPPLY SHIP · ODESA" if id == "odesa" else "EUROPEAN TRAIN · LVIV", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	cargo_text = CowUI.label("", 18)
	cargo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(cargo_text)
	_update_manifest()
	var unload := _button("Unload cargo" if GameSession.player_country == "ukraine" else "Watch Ukraine unload")
	unload.disabled = id in game.session.training.aid_received
	unload.pressed.connect(func():
		TrainingScenario.request_unload(game, id)
		supplies.refresh()
		_update_manifest()
		unload.disabled = id in game.session.training.aid_received
		game.autosave())
	column.add_child(unload)
	var back := _button("Back to map")
	back.pressed.connect(func(): cargo_overlay.hide())
	column.add_child(back)
	if current_action() in ["inspect_ship", "inspect_train"] and _action_done():
		game.session.training.actions[_action_key()] = true
	game.autosave()

func _update_manifest() -> void:
	var load_spec: Dictionary = TrainingScenario.AID_LOADS[_cargo_id]
	var lines: Array[String] = ["From %s · For Ukraine\n" % load_spec.donor]
	for family in load_spec.equipment:
		var equipment := TrainingScenario.aid_equipment(_cargo_id, family)
		lines.append("%d × %s · Level 1" % [load_spec.equipment[family], EquipmentIdentity.research_title(equipment, 1)])
	lines.append("")
	for resource in load_spec.resources:
		lines.append(("Financial assistance" if resource == "funds" else resource.capitalize()) + ": %s" % int(load_spec.resources[resource]))
	lines.append("\nUNLOADED · Weapons are at the terminal; funds and resources are credited." if _cargo_id in game.session.training.aid_received else "\nLOADED · Cargo remains aboard until unloaded. Ukraine must control the receiving terminal.")
	cargo_text.text = "\n".join(lines)

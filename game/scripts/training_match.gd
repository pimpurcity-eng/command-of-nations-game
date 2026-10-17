class_name TrainingMatch
extends CanvasLayer
## The training match (owner 2026-10-17: "take what we got there and make it 10 times better").
## Flow: opening film → choose a side and how much training → the basics (optional for
## experienced players) → the supply film → ship at Odesa and train at Lviv → the required
## Warfront systems (everyone), including unloading both → +10 XP (unlocks the Europe
## map) → the match carries on with 1 or 2 players, as chosen in the games menu.
## Every lesson completes from the real action in the real game, never from tapping Next.
signal training_finished(players: int)

const BASICS := [
	["select", "SELECT YOUR TANKS", {"russia": "Your six-tank column waits at the border. Tap it to take command.", "ukraine": "Your tanks hold Kharkiv. Tap them to take command."}],
	["move", "MOVE OUT", "Tap MOVE, then tap the map where your tanks should drive."],
	["city", "OPEN YOUR CAPITAL", "Tap your capital. Its factories, airbase and barracks are already built."],
	["unit_card", "KNOW YOUR WEAPONS", "Open RESEARCH, then tap any unit picture to see its stats and costs."],
	["research", "START RESEARCH", "Start a level-1 research project. It keeps running while you play."],
	["produce", "BUILD AN ARMY", "In your capital, open the Infantry tab and queue infantry."],
	["patrol", "DRONE PATROL", "Select a drone, tap PATROL, then tap a spot inside its range."],
	["build", "GROW YOUR ECONOMY", "Open a city and queue a building, such as Industry."],
]
const FEATURES := [
	["guard", "SLEEP DEFENCE", "Turn GUARD on. Its AI defends your country while you are away, without starting an offensive. Online AI takeover after 48 hours inactive is a separate system."],
	["economy", "BUILD YOUR ECONOMY", "Open your capital and queue Industry. It raises productive income. Check the resource income and upkeep before expanding your army."],
	["trade", "REAL CARGO, REAL ROUTES", "Open TRADE and choose a resource on an available neutral trade route. Opening the menu is not enough: create the route. Its trains or ships carry real, vulnerable cargo."],
	["transport", "BIGGER TERMINALS, MORE CARGO", "Open your capital and queue a Train Station upgrade. Higher terminal levels carry more cargo; friendly railway provinces let ground armies move twice as fast."],
	["world_prices", "WEAPONS AND WORLD PRICES", "Open Transport market. In WORLD PRICES, choose a weapon and inspect its minimum price. Demand changes prices; AI countries can also trade. Infantry and strategic weapons cannot be sold."],
	["victory", "WIN WITH YOUR ECONOMY", "Open Victory progress and read the Economic target: grow productive income, maintain the required treasury and keep your capital. Imported aid alone does not count as earned income."],
	["diplomacy", "TRADE ACCESS AND ALLIES", "Open Diplomacy. Trade deals, right of way and shared vision connect allies and their supply lines. Resources can support other countries."],
	["reports", "KNOW WHAT HAPPENED", "Open Battle reports. Check fights, losses and defences when you return, then use the newspaper to follow the wider war."],
	["guard_resume", "TAKE BACK COMMAND", "Turn GUARD off before continuing the match. You now know how to enable sleep defence and take control again."],
]
const LOGISTICS := [
	["inspect_ship", "THE SHIP HAS DOCKED", {"ukraine": "America sent four Abrams tanks and an F-16 to Odesa. Tap the ship to see the cargo.", "russia": "Western aid has reached Odesa. Tap the ship to see what Ukraine is getting."}],
	["unload_ship", "UNLOAD THE SHIP", {"ukraine": "Tap UNLOAD CARGO. The tanks roll off at Odesa and supplies go into your stockpile.", "russia": "Tap WATCH UKRAINE UNLOAD to see the new tanks land."}],
	["inspect_train", "THE TRAIN IS IN", {"ukraine": "Europe sent five more units to Lviv by rail. Tap the train.", "russia": "A European train has reached Lviv. Tap it to see what's aboard."}],
	["unload_train", "UNLOAD THE TRAIN", {"ukraine": "Unload the train. Its units stand ready at Lviv.", "russia": "Watch Ukraine unload the train at Lviv."}],
	["reinforcements", "SEND THEM TO THE FRONT", {"ukraine": "Select one of your new tank stacks and move it toward the front.", "russia": "Move your tank column before the aid reaches the front."}],
	["next", "PROTECT YOUR SUPPLY LINES", "Ports and stations bring in aid and trade. Hold them, and hit the enemy's. Next: the required Warfront feature training."],
]
const CHAPTERS := {"basics": "1 · OPTIONAL BASICS", "features": "2 · WARFRONT FEATURES", "logistics": "2 · AID ARRIVES"}
const CITY_ACTIONS := ["city", "build", "produce", "economy", "transport"]

var game: Node
var root: Control
var coach: TrainingCoach
var card: PanelContainer
var cinema: TrainingCinema
var side_screen: Control
var finish_screen: Control
var cargo_overlay: Control
var supplies: TrainingSupplies
var _movie_after := ""
var _poll := 0.0
var _previous_music := false
var _backgrounded := false
var _cargo_id := ""
var _beacon: MeshInstance3D
var _menu_hint: PanelContainer
var _complete_delay := 0.0
var _shown_key := ""
var _target_on_map := false
var _menu_glow: Panel

func setup(main: Node, theme: Theme) -> void:
	game = main
	layer = 25
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)
	coach = TrainingCoach.new()
	root.add_child(coach)
	coach.build(theme)
	card = coach.card
	coach.show_me.connect(focus_objective)
	coach.target_pressed.connect(_tap_lesson_target)
	coach.continue_pressed.connect(next_step)
	coach.skip_pressed.connect(skip_lessons)
	var state: Dictionary = game.session.training
	if not state.has("actions"): state.actions = {}
	if not state.has("players"): state.players = 1
	# Owner 2026-10-17: older saves credited opening a panel as doing a trade. Re-teach those
	# unfinished feature chapters with real actions while preserving delivered aid and armies.
	if int(state.get("lesson_revision", 1)) < 2:
		for action in FEATURES: state.actions.erase("features:" + str(action[0]))
		if state.phase == "features":
			state.phase = "supply_video" if state.aid_received.is_empty() and state.aid_pending.is_empty() else "features"
			state.step = 0
			state.video_position = 0.0
		state.lesson_revision = 2
	# Saves from the earlier training layout resume at the matching point of this one.
	if state.phase == "choice": state.phase = "opening"
	if state.phase == "practice": state.phase = "supply_video"
	if not state.aid_pending.is_empty() or not state.aid_received.is_empty(): _ensure_supplies()
	if state.phase in ["opening", "supply_video"]: play_movie(state.phase == "opening")
	else: show_step()

## Kept for scripted routes and tests: "full" starts at the film, "features" skips the basics,
## "skip" jumps to the finished state (not offered to players; XP needs the training).
func begin(route: String) -> void:
	game.session.training.route = route
	game.session.training.step = 0
	if route == "full":
		game.session.training.phase = "opening"
		play_movie(true)
	elif route == "features":
		start_supply_movie()
	else:
		TrainingScenario.release_aid(game, true)
		free_play()

func _steps(phase: String) -> Array:
	return BASICS if phase == "basics" else FEATURES if phase == "features" else LOGISTICS

func _text_for(entry: Array) -> String:
	var value = entry[2]
	return str(value.get(GameSession.player_country, value.values()[0])) if value is Dictionary else str(value)

func show_step() -> void:
	_clear_focus()
	_complete_delay = 0.0
	var state: Dictionary = game.session.training
	var phase: String = state.phase
	coach.set_card_visible(phase in ["basics", "features", "logistics"])
	if phase == "side": _show_side_picker()
	elif phase == "reward": _show_finish()
	elif phase in ["basics", "features", "logistics"]:
		var steps := _steps(phase)
		var index := clampi(int(state.step), 0, steps.size() - 1)
		var entry: Array = steps[index]
		var is_info: bool = entry[0] == "next"
		var main := "CONTINUE" if is_info else ""
		var skip := "Skip the basics  ›" if phase == "basics" else ""
		var progress_index := index + (LOGISTICS.size() if phase == "features" else 0)
		var progress_total := steps.size() if phase == "basics" else LOGISTICS.size() + FEATURES.size()
		coach.present(CHAPTERS[phase], progress_index, progress_total, entry[1], _text_for(entry), main, not is_info, skip)
		_shown_key = phase + ":" + str(index)
		if phase == "logistics" and entry[0] == "inspect_train" and not state.actions.get("train_arrived", false):
			state.actions["train_arrived"] = true
			_ensure_supplies()
			supplies.arrive("lviv")
			supplies.focus("lviv")
		if phase == "basics" and entry[0] in ["select", "city", "move", "patrol"]:
			focus_objective()
	game.autosave()

func next_step() -> void:
	var state: Dictionary = game.session.training
	if state.phase not in ["basics", "features", "logistics"]: return
	if current_action() != "next" and not action_completed(): return
	var steps := _steps(state.phase)
	state.step += 1
	if state.step >= steps.size():
		state.step = 0
		if state.phase == "basics":
			start_supply_movie()
			return
		elif state.phase == "logistics":
			state.phase = "features"
			# The feature lessons are about the player's own country: leave the aid terminals
			# (Odesa/Lviv) and return to the player's capital (Moscow for Russia, Kyiv for Ukraine).
			var capital: Dictionary = game.buildings.capital(GameSession.player_country)
			if not capital.is_empty():
				game.rig.target = game.map.position_at(capital.point)
				game.rig.distance = 12.0
				game.rig._snap(1.0)
		else:
			state.phase = "reward"
	show_step()

## Only the basics can be skipped (owner: experienced players opt out of the tutorial part;
## the new features and the aid arrival are for everyone).
func skip_lessons() -> void:
	var state: Dictionary = game.session.training
	if state.phase == "basics": start_supply_movie()

func advance_training(real_seconds: float) -> void:
	var state: Dictionary = game.session.training
	if state.phase in ["basics", "features", "logistics"] and real_seconds > 0: state.active_seconds += real_seconds

func start_supply_movie() -> void:
	game.session.training.phase = "supply_video"
	game.session.training.video_position = 0.0
	play_movie(false)

func play_movie(opening: bool) -> void:
	game.clock.paused = true
	coach.set_card_visible(false)
	_movie_after = "side" if opening else "logistics"
	if is_instance_valid(cinema): cinema.queue_free()
	cinema = TrainingCinema.new()
	root.add_child(cinema)
	cinema.finished.connect(movie_finished, CONNECT_ONE_SHOT)
	cinema.setup("opening" if opening else "supply", TrainingScenario.OPENING_VIDEO if opening else TrainingScenario.SUPPLY_VIDEO, float(game.session.training.get("video_position", 0.0)), GameAudio.sound_enabled)
	_previous_music = GameAudio.music_enabled
	if game.audio != null: game.audio.pause_music_for_cinematic(true)
	game.autosave()

func movie_finished() -> void:
	if _movie_after.is_empty(): return
	var after := _movie_after
	_movie_after = ""
	if is_instance_valid(cinema):
		var closing := cinema
		cinema = null
		closing.set_process(false)
		var fade := closing.create_tween()
		fade.tween_property(closing, "modulate:a", 0.0, 0.35)
		fade.tween_callback(closing.queue_free)
	var state: Dictionary = game.session.training
	state.video_position = 0.0
	state.phase = after
	state.step = 0
	game.units.selected = -1
	game.units.command_ids.clear()
	game.hud.clear_unit_selection()
	if after == "logistics":
		TrainingScenario.release_aid(game)
		_ensure_supplies()
		supplies.arrive("odesa")
		supplies.focus("odesa")
	if game.audio != null:
		game.audio.pause_music_for_cinematic(false)
		if _previous_music: game.audio.play_music("battle_theme")
	game.clock.paused = after == "side"
	show_step()

func _show_side_picker() -> void:
	if is_instance_valid(side_screen): return
	game.clock.paused = true
	side_screen = TrainingScreens.side_picker(root, GameSession.player_country, choose_side)

## The side and amount of training chosen after the opening film.
func choose_side(country: String, full_training: bool) -> void:
	if is_instance_valid(side_screen):
		side_screen.queue_free()
		side_screen = null
	if country != GameSession.player_country:
		GameSession.player_country = country
		game.apply_player_country()
	# Lesson one is selecting your tanks yourself, so nothing starts selected.
	game.units.selected = -1
	game.units.command_ids.clear()
	game.hud.clear_unit_selection()
	var state: Dictionary = game.session.training
	state.route = "full" if full_training else "features"
	state.phase = "basics" if full_training else "supply_video"
	state.step = 0
	game.clock.paused = false
	if game.audio != null: game.audio.play_music("battle_theme")
	game.refresh_hud()
	if full_training: show_step()
	else: start_supply_movie()

func _show_finish() -> void:
	if is_instance_valid(finish_screen): return
	game.clock.paused = true
	Tutorial.mark_done()
	PlayerAuth._set_training_flag("finished")
	var auth: PlayerAuth = game.account_panel.auth if game.account_panel != null else null
	var signed: bool = auth != null and auth.signed_in()
	if signed: auth.complete_training()
	if game.audio != null: game.audio.play("victory")
	finish_screen = TrainingScreens.finish(root, int(game.session.training.get("players", 1)), signed, free_play, func(): game.open_home_account())

func free_play() -> void:
	TrainingScenario.request_unload(game)
	if not game.session.training.aid_received.is_empty(): _ensure_supplies()
	_clear_focus()
	for screen in [finish_screen, side_screen, cargo_overlay]:
		if is_instance_valid(screen): screen.queue_free()
	game.session.training.phase = "free"
	Tutorial.mark_done()
	var players := int(game.session.training.get("players", 1))
	# One player: the computer takes the other side. Two players: it stays off for the
	# second commander (the games menu decides how that player joins).
	game.match_rules.ai_enabled = players == 1
	game.clock.paused = false
	coach.set_card_visible(false)
	game.autosave()
	game.hud.show_status("TRAINING COMPLETE · Take command. Your match continues.")
	training_finished.emit(players)

func _process(delta: float) -> void:
	if game == null: return
	var suspended: bool = _backgrounded or game.mobile_start.visible or game.browser_suspended
	root.visible = not suspended
	if is_instance_valid(cinema): cinema.set_paused(suspended)
	if suspended: return
	if not game.match_rules.winner.is_empty():
		coach.set_card_visible(false)
		return
	if is_instance_valid(cinema): game.session.training.video_position = cinema.position_seconds()
	if not game.clock.paused: advance_training(minf(delta, 0.25))
	_track_bottom()
	_poll += delta
	if _poll < 0.1: return
	_poll = 0.0
	if not game.session.training.aid_pending.is_empty():
		TrainingScenario.try_unload(game)
		if is_instance_valid(supplies): supplies.refresh()
	if not _movie_after.is_empty(): return
	var phase: String = game.session.training.phase
	if phase not in ["basics", "features", "logistics"]: return
	var menu_open := _menu_open()
	coach.set_card_visible(not menu_open)
	if _action_done() and not game.session.training.actions.get(_action_key(), false):
		game.session.training.actions[_action_key()] = true
		game.autosave()
	var complete := action_completed()
	if current_action() == "next":
		_update_guidance(menu_open)
		return
	if complete:
		coach.celebrate()
		if not menu_open:
			_complete_delay += 0.1
			if _complete_delay >= 1.0:
				if game.audio != null: game.audio.play("research_complete")
				next_step()
				return
		else: _complete_delay = 0.0
	_update_guidance(menu_open)

func _menu_open() -> bool:
	for key in ["city_panel", "province_panel", "research_panel", "production_panel", "campaign_panel", "trade_panel", "exchange_panel", "weapon_showcase", "army_selection", "army_command", "stack_dialog", "fire_panel"]:
		var menu = game.get(key)
		if menu != null and is_instance_valid(menu) and menu.visible: return true
	if game.account_panel != null and game.account_panel.overlay.visible: return true
	if game.guard_popup != null and game.guard_popup.visible: return true
	if is_instance_valid(game.research_panel.unit_card) and game.research_panel.unit_card.visible: return true
	return is_instance_valid(cargo_overlay) and cargo_overlay.visible

## Keeps the coach card just above the game's bottom bar, whatever the screen shape.
func _track_bottom() -> void:
	var limit := root.size.y - 16.0
	var sheet: Control = game.hud.command_panel
	if sheet != null and sheet.is_visible_in_tree():
		limit = minf(limit, _to_root(sheet).position.y)
	coach.set_bottom_limit(limit)

func contains_screen(point: Vector2) -> bool:
	if not visible or not root.visible: return false
	if not _movie_after.is_empty(): return true
	for screen in [side_screen, finish_screen, cargo_overlay]:
		if is_instance_valid(screen) and screen.visible: return true
	return coach.contains(get_final_transform().affine_inverse() * point)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]: _backgrounded = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]: _backgrounded = false

func _exit_tree() -> void:
	if is_instance_valid(cinema): cinema.set_paused(true)
	if is_instance_valid(supplies): supplies.queue_free()
	_clear_focus()
	if game != null and is_instance_valid(game.audio): game.audio.pause_music_for_cinematic(false)

func current_action() -> String:
	var phase: String = game.session.training.phase
	if phase not in ["basics", "features", "logistics"]: return ""
	var steps := _steps(phase)
	return steps[clampi(int(game.session.training.step), 0, steps.size() - 1)][0]

func _action_key() -> String:
	return str(game.session.training.phase) + ":" + current_action()

func action_completed() -> bool:
	return bool(game.session.training.get("actions", {}).get(_action_key(), false)) or _action_done()

## Owner 2026-10-17: normal Move closes its army controls; remember the accepted action now.
func order_accepted() -> void:
	if current_action() not in ["move", "patrol", "reinforcements"] or not _action_done(): return
	game.session.training.actions[_action_key()] = true
	game.autosave()

## A city lesson must not cycle through every troop stationed in that city.
func pick_lesson_target(screen: Vector2) -> bool:
	if not _movie_after.is_empty() or _menu_open(): return false
	if current_action() in CITY_ACTIONS:
		var hit: Dictionary = game.cities.pick_screen(screen)
		if hit.is_empty() or not game.production.controlled(hit.city, GameSession.player_country): return false
		game.clear_army_selection()
		game._set_order_mode(false)
		game.cities.select_city(hit.city)
		return true
	if current_action() == "select":
		for hit in game.units.pick_all_screen(game.rig.camera, screen):
			var unit: Dictionary = game.units.units[hit.index]
			if unit.country == GameSession.player_country and unit.visual_kind == "armor":
				game.units.select_unit(hit.index)
				return true
	return false

## Army badges sit above a garrison and receive the touch before the 3D map does.
func prefer_city_for_unit(unit: Dictionary) -> bool:
	if current_action() not in CITY_ACTIONS or not _movie_after.is_empty(): return false
	var point := Vector2(unit.node.position.x, unit.node.position.z)
	for city in game.production.cities:
		if game.production.controlled(city, GameSession.player_country) and point.distance_to(city.point) <= UnitSystem.CITY_RADIUS:
			game.clear_army_selection()
			game._set_order_mode(false)
			game.cities.select_city(city)
			return true
	return false

## The animated map callout activates the very same city, army or cargo as a map tap.
func _tap_lesson_target() -> void:
	var action := current_action()
	if action in CITY_ACTIONS:
		game.clear_army_selection()
		game._set_order_mode(false)
		game.cities.select_city(game.buildings.capital(GameSession.player_country))
	elif action in ["select", "move", "patrol", "reinforcements"]:
		var unit := _lesson_unit(action)
		if not unit.is_empty(): game.units.select_unit(game.units.units.find(unit))
	elif action in ["inspect_ship", "unload_ship", "inspect_train", "unload_train"]:
		open_cargo("odesa" if action.ends_with("ship") else "lviv")

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
		"economy": return game.buildings.jobs.any(func(job: Dictionary): return job.country == country and job.building == "industry") or game.production.cities.any(func(city: Dictionary): return game.production.controlled(city, country) and game.buildings.level(city.id, "industry") > 0)
		"trade": return not game.trade.routes_of(country).is_empty()
		"transport": return game.buildings.jobs.any(func(job: Dictionary): return job.country == country and job.building == "train_station" and job.level >= 2) or game.production.cities.any(func(city: Dictionary): return game.production.controlled(city, country) and game.buildings.level(city.id, "train_station") >= 2)
		"world_prices": return game.trade_panel != null and game.trade_panel.visible and game.trade_panel.market_view and game.trade_panel.inspected_world_item.has("equipment_id")
		"guard": return game.match_rules.guarded(country)
		"guard_resume": return not game.match_rules.guarded(country) and game.session.training.actions.get("features:guard", false)
		"reports": return game.campaign_panel != null and game.campaign_panel.visible and game.campaign_panel.tab == "battles"
		"victory", "diplomacy": return game.campaign_panel != null and game.campaign_panel.visible and game.campaign_panel.tab == current_action()
		"inspect_ship", "inspect_train": return is_instance_valid(cargo_overlay) and cargo_overlay.visible and _cargo_id == ("odesa" if current_action() == "inspect_ship" else "lviv")
		"unload_ship": return "odesa" in game.session.training.aid_received
		"unload_train": return "lviv" in game.session.training.aid_received
		"reinforcements": return not selected.is_empty() and selected.moving and (str(selected.id).begins_with("training_aid_") if country == "ukraine" else selected.visual_kind == "armor")
		"next": return true
	return false

## The army a lesson is about, for spotlighting and "Show me".
func _lesson_unit(action: String) -> Dictionary:
	var candidates: Array = game.units.units.filter(func(unit: Dictionary):
		if unit.country != GameSession.player_country: return false
		if action == "patrol": return EquipmentIdentity.spec(unit.equipment_id).get("role", "") == "drone"
		if action == "reinforcements" and GameSession.player_country == "ukraine": return str(unit.id).begins_with("training_aid_") and unit.visual_kind == "armor"
		return unit.visual_kind == "armor")
	return candidates[0] if not candidates.is_empty() else {}

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
	if action in ["victory", "diplomacy", "reports"]:
		game.open_campaign("battles" if action == "reports" else action)
		return
	var position := Vector3.ZERO
	if action in ["city", "build", "produce", "economy", "transport"]:
		var capital: Dictionary = game.buildings.capital(GameSession.player_country)
		position = game.map.position_at(capital.point)
		if action in ["build", "produce", "economy", "transport"]:
			game.city_panel.open(capital)
			if action in ["economy", "transport"]:
				var building := "industry" if action == "economy" else "train_station"
				game.city_panel.scroll.ensure_control_visible.call_deferred(game.city_panel.rows[building].card)
	else:
		var unit := _lesson_unit(action)
		if unit.is_empty(): return
		position = unit.node.position
		if action in ["patrol", "reinforcements"]: game.units.select_unit(game.units.units.find(unit))
	game.rig.target = position
	game.rig.distance = 8.0
	game.rig.reset_gestures()
	game.rig._snap(1.0)
	# Put the target in the open map above the coach, rather than underneath its card.
	_track_bottom()
	var viewport := game.get_viewport().get_visible_rect().size
	var top := 180.0
	var bottom := minf(coach.card.position.y, viewport.y - 200.0)
	var desired := Vector2(viewport.x * 0.5, (top + maxf(top + 140.0, bottom)) * 0.5)
	var ground = game.rig._ground_at(desired)
	if ground != null:
		var offset: Vector3 = position - ground
		offset.y = 0.0
		game.rig.target += offset
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

func _to_root(control: Control) -> Rect2:
	var transform: Transform2D = root.get_global_transform_with_canvas().affine_inverse() * control.get_global_transform_with_canvas()
	return Rect2(transform.origin, control.size * transform.get_scale())

func _world_rect(position: Vector3, half: float = 58.0) -> Rect2:
	var camera: Camera3D = game.rig.camera
	if camera == null or camera.is_position_behind(position): return Rect2()
	var point: Vector2 = get_final_transform().affine_inverse() * camera.unproject_position(position)
	if not root.get_rect().has_point(point): return Rect2()
	return Rect2(point - Vector2(half, half), Vector2(half, half) * 2.0)

## Where the player should tap now: a HUD button, a bottom tab, or something on the map.
func _target_rect() -> Rect2:
	var action := current_action()
	var control: Control
	match action:
		"move":
			if not _selected().is_empty(): control = game.hud.move_button
		"guard", "guard_resume": control = game.hud.guard_button
		"patrol":
			if game.hud.patrol_button.is_visible_in_tree(): control = game.hud.patrol_button
		"select", "reinforcements":
			if action == "reinforcements" and not _selected().is_empty(): control = game.hud.move_button
		_:
			var tab: String = {"unit_card": "research", "research": "research", "trade": "market", "world_prices": "market", "victory": "more", "diplomacy": "diplomacy", "reports": "more"}.get(action, "")
			for button in game.hud.nav_row.get_children():
				if button.get_meta("tutorial_action", "") == tab: control = button
	_target_on_map = false
	if control != null and control.is_visible_in_tree() and not (control is BaseButton and control.disabled): return _to_root(control)
	_target_on_map = true
	match action:
		"select", "move", "reinforcements", "patrol":
			var unit := _lesson_unit(action)
			if not unit.is_empty(): return _world_rect(unit.node.global_position)
		"city", "build", "produce", "economy", "transport":
			return _world_rect(game.map.position_at(game.buildings.capital(GameSession.player_country).point), 80.0)
		"inspect_ship", "unload_ship":
			if is_instance_valid(supplies) and supplies.vehicles.has("odesa"): return _world_rect(supplies.vehicles.odesa.global_position, 80.0)
		"inspect_train", "unload_train":
			if is_instance_valid(supplies) and supplies.vehicles.has("lviv"): return _world_rect(supplies.vehicles.lviv.global_position, 80.0)
	return Rect2()

func _update_guidance(menu_open: bool) -> void:
	if not menu_open:
		if is_instance_valid(_menu_hint): _menu_hint.hide()
		_clear_menu_glow()
		var rect := _target_rect() if not action_completed() or current_action() == "next" else Rect2()
		if rect.has_area() and current_action() != "next": coach.point_at(rect, _target_on_map)
		else: coach.clear_target()
		var captions := {"select": "TAP YOUR TANKS", "move": "SELECT YOUR TANKS", "patrol": "SELECT YOUR DRONE", "reinforcements": "SELECT YOUR TANKS", "inspect_ship": "INSPECT THE SHIP", "unload_ship": "UNLOAD THE SHIP", "inspect_train": "INSPECT THE TRAIN", "unload_train": "UNLOAD THE TRAIN"}
		if current_action() == "select":
			var own_tanks := _lesson_unit("select")
			if not own_tanks.is_empty(): captions.select = "TAP YOUR %d TANKS" % game.units.stacks.members(own_tanks).size()
		for action in CITY_ACTIONS: captions[action] = "OPEN " + game.buildings.capital(GameSession.player_country).name.to_upper() + "  ·  CITY"
		coach.set_target_caption(str(captions.get(current_action(), "")) if _target_on_map and not action_completed() else "")
		return
	coach.clear_target()
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
		# A gold banner inside the open menu: readable at a glance, never blocking it.
		_menu_hint = PanelContainer.new()
		_menu_hint.name = "TrainingObjective"
		_menu_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 700))
		label.add_theme_font_size_override("font_size", 24)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_hint.add_child(label)
		column.add_child(_menu_hint)
	elif _menu_hint.get_parent() != column:
		_menu_hint.reparent(column)
	column.move_child(_menu_hint, mini(1, column.get_child_count() - 1))
	var done := action_completed()
	var hint_label: Label = _menu_hint.get_child(0)
	_menu_hint.add_theme_stylebox_override("panel", CowUI.box(Color("5fae4b") if done else CowUI.GOLD, 10, Color(0, 0, 0, 0), 0, 14))
	hint_label.add_theme_color_override("font_color", Color.WHITE if done else Color("1c1a12"))
	var steps := _steps(game.session.training.phase)
	var entry: Array = steps[clampi(int(game.session.training.step), 0, steps.size() - 1)]
	hint_label.text = "✓  Done! Close this menu to continue." if done else "TRAINING  ·  " + _text_for(entry)
	_menu_hint.show()
	var target: Control
	var action := current_action()
	if not done and game.city_panel.visible and action in ["build", "economy", "transport"]:
		var building := "train_station" if action == "transport" else "industry"
		target = game.city_panel.rows[building].button
	elif not done and game.trade_panel != null and game.trade_panel.visible:
		var wanted := "world_price_item" if action == "world_prices" and game.trade_panel.market_view else "transport_market" if action == "world_prices" else "create_trade_route" if action == "trade" else ""
		for control in game.trade_panel.panel.find_children("*", "Control", true, false):
			if not wanted.is_empty() and control.get_meta("tutorial_action", "") == wanted:
				target = control
				break
	if target == null or not target.is_visible_in_tree():
		_clear_menu_glow()
	elif not is_instance_valid(_menu_glow) or _menu_glow.get_parent() != target:
		_clear_menu_glow()
		_menu_glow = Panel.new()
		_menu_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.border_color = CowUI.GOLD
		outline.set_border_width_all(4)
		outline.set_corner_radius_all(8)
		_menu_glow.add_theme_stylebox_override("panel", outline)
		target.add_child(_menu_glow)
		_menu_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glow := _menu_glow.create_tween().set_loops()
		glow.tween_property(_menu_glow, "modulate:a", 0.25, 0.55)
		glow.tween_property(_menu_glow, "modulate:a", 1.0, 0.55)

func _clear_menu_glow() -> void:
	if is_instance_valid(_menu_glow):
		_menu_glow.queue_free()
		_menu_glow = null

func _clear_focus() -> void:
	_clear_menu_glow()
	if is_instance_valid(_beacon): _beacon.queue_free()
	if coach != null: coach.clear_target()
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
	if is_instance_valid(cargo_overlay): cargo_overlay.queue_free()
	var loaded: bool = id in game.session.training.aid_pending
	cargo_overlay = TrainingScreens.manifest(root, id, loaded, GameSession.player_country == "ukraine", func():
		TrainingScenario.request_unload(game, id)
		supplies.refresh()
		game.autosave()
		if game.audio != null: game.audio.play("build_complete")
		# Show the cargo as unloaded for a moment, then return to the map to watch it land.
		open_cargo(id)
		var shown := cargo_overlay
		get_tree().create_timer(1.3).timeout.connect(func():
			if is_instance_valid(shown) and shown == cargo_overlay:
				shown.hide()
				supplies.focus(id)), func(): cargo_overlay.hide())
	if current_action() in ["inspect_ship", "inspect_train"] and _action_done():
		game.session.training.actions[_action_key()] = true
	game.autosave()

class_name TrainingScreens
extends RefCounted
## Full-screen training moments: choosing a side, the aid manifest, and the finish with its XP.
## Every screen is a solid dark overlay with a centred column capped at 760 units wide, so it
## reads the same on a small phone, a tall phone, a tablet and a landscape browser.

const BG := Color("0d1215")
const PANEL := Color("172026")
const EDGE := Color("33424a")
const TEXT := Color("f4efe2")
const SOFT := Color("c9c2b0")

static func text(value: String, size: int, color: Color = TEXT, weight: int = 600) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## A full-screen overlay with a scrollable, centred column. Returns [overlay, column].
static func overlay(parent: Control, background_alpha: float = 0.96) -> Array:
	var cover := ColorRect.new()
	cover.color = Color(BG, background_alpha)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(cover)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cover.add_child(scroll)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(centre)
	var margin := MarginContainer.new()
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 20)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	centre.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	var fit := func():
		var width := minf(cover.size.x - 40.0, 760.0)
		column.custom_minimum_size.x = width
		centre.custom_minimum_size = Vector2(cover.size.x, cover.size.y)
	cover.resized.connect(fit)
	fit.call_deferred()
	cover.modulate.a = 0.0
	cover.create_tween().tween_property(cover, "modulate:a", 1.0, 0.3)
	return [cover, column]

static func panel(color: Color = PANEL, edge: Color = EDGE, edge_width: int = 2) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", CowUI.box(color, 18, edge, edge_width, 22))
	return box

static func flag(colors: Array, height: float = 46.0) -> Control:
	var strip := VBoxContainer.new()
	strip.add_theme_constant_override("separation", 0)
	strip.custom_minimum_size = Vector2(height * 1.5, height)
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for color in colors:
		var band := ColorRect.new()
		band.color = color
		band.size_flags_vertical = Control.SIZE_EXPAND_FILL
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_child(band)
	return strip

const FLAGS := {"russia": [Color.WHITE, Color("1c3f94"), Color("d52b1e")], "ukraine": [Color("0057b7"), Color("ffd700")],
	"America": [Color("b22234"), Color.WHITE, Color("3c3b6e")], "Europe": [Color("003399"), Color("ffcc00"), Color("003399")]}

## Side and training choice, shown after the opening film. on_start(country, full_training).
static func side_picker(parent: Control, current: String, on_start: Callable) -> Control:
	var made := overlay(parent)
	var column: VBoxContainer = made[1]
	column.add_child(text("FIRST MATCH · RUSSIA–UKRAINE", 24, CowUI.GOLD, 700))
	column.add_child(text("Choose your side", 52, TEXT, 700))
	var state := {"country": current, "full": true}
	var cards := {}
	var refresh := func():
		for id in cards:
			var on: bool = id == state.country
			cards[id].add_theme_stylebox_override("panel", CowUI.box(Color("1d2a31") if on else PANEL, 18, CowUI.GOLD if on else EDGE, 4 if on else 2, 22))
	var sides := [
		["russia", "RUSSIA", "A bigger army and a stronger economy. Strike before Western aid reaches the front.", "21 units · 6-tank column · missiles"],
		["ukraine", "UKRAINE", "Fewer troops at the start, but American and European aid is on its way.", "12 units + 10 arriving by ship and train"]]
	for side in sides:
		var card := panel()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		cards[side[0]] = card
		var inside := VBoxContainer.new()
		inside.add_theme_constant_override("separation", 10)
		card.add_child(inside)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 18)
		inside.add_child(head)
		head.add_child(flag(FLAGS[side[0]]))
		var name_label := text(side[1], 40, TEXT, 700)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		inside.add_child(text(side[2], 27, TEXT, 500))
		inside.add_child(text(side[3], 24, CowUI.GOLD, 600))
		var id: String = side[0]
		card.gui_input.connect(func(event: InputEvent):
			if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
				state.country = id
				refresh.call())
		column.add_child(card)
	column.add_child(text("How much training?", 34, TEXT, 700))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 14)
	column.add_child(modes)
	var full := TrainingCoach.make_button("FULL TRAINING", Color("2c3a41"), 26)
	var quick := TrainingCoach.make_button("SKIP THE BASICS", Color("2c3a41"), 26)
	for button in [full, quick]:
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(button)
	var hint := text("", 24, SOFT, 500)
	column.add_child(hint)
	var pick_mode := func(value: bool):
		state.full = value
		full.button_pressed = value
		quick.button_pressed = not value
		for pair in [[full, value], [quick, not value]]:
			pair[0].add_theme_stylebox_override("normal", CowUI.box(Color("1d2a31") if pair[1] else Color("2c3a41"), 14, CowUI.GOLD if pair[1] else EDGE, 3 if pair[1] else 2, 16))
		hint.text = "New to strategy games: 8 quick hands-on lessons first." if value else "Played games like this before? Go straight to what's new in Warfront Mandate."
	full.pressed.connect(pick_mode.bind(true))
	quick.pressed.connect(pick_mode.bind(false))
	pick_mode.call(true)
	var go := TrainingCoach.make_button("TAKE COMMAND", CowUI.GREEN, 32)
	go.custom_minimum_size.y = 96
	go.pressed.connect(func(): on_start.call(state.country, state.full))
	column.add_child(go)
	refresh.call()
	return made[0]

## A live, slowly turning 3D picture of a unit's actual model (the aid hardware has no menu art).
static func model_preview(equipment: String, height: float = 170.0) -> Control:
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(0, height)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	frame.add_child(view)
	var stage := Node3D.new()
	view.add_child(stage)
	var spec := EquipmentIdentity.spec(equipment)
	var model := UnitVisual.create(spec.get("visual_kind", "armor"), Color("73bcff"), equipment, 1)
	stage.add_child(model)
	var box := AABB()
	var first := true
	for mesh in model.find_children("*", "VisualInstance3D", true, false):
		# Bounds in the model's own space (it is not in the scene tree yet).
		var relative := Transform3D.IDENTITY
		var node: Node = mesh
		while node != null and node != model:
			if node is Node3D: relative = (node as Node3D).transform * relative
			node = node.get_parent()
		var bounds: AABB = relative * (mesh as VisualInstance3D).get_aabb()
		box = bounds if first else box.merge(bounds)
		first = false
	var reach := maxf(box.size.length(), 0.01)
	model.position = -box.get_center()
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, reach * 0.42, reach * 1.55)
	view.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.3
	view.add_child(sun)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c9d4dc")
	environment.ambient_light_energy = 0.8
	world.environment = environment
	view.add_child(world)
	stage.rotation_degrees.y = -35.0
	var spin := stage.create_tween().set_loops()
	spin.tween_property(stage, "rotation_degrees:y", 325.0, 14.0).from(-35.0)
	return frame

## The manifest of a docked ship or train, grouped by unit type with pictures.
static func manifest(parent: Control, id: String, loaded: bool, player_is_ukraine: bool, on_unload: Callable, on_close: Callable) -> Control:
	var load_spec: Dictionary = TrainingScenario.AID_LOADS[id]
	var made := overlay(parent, 0.93)
	var column: VBoxContainer = made[1]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	column.add_child(head)
	head.add_child(flag(FLAGS.get(load_spec.donor, [Color.GRAY])))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(text(("SUPPLY SHIP · ODESA" if id == "odesa" else "AID TRAIN · LVIV"), 24, CowUI.GOLD, 700))
	titles.add_child(text("From %s · for Ukraine" % load_spec.donor, 40, TEXT, 700))
	var status := text("LOADED · %d units aboard" % TrainingScenario.equipment_count(id) if loaded else "UNLOADED · Units are at the terminal", 26, Color("9fdc8a") if not loaded else SOFT, 600)
	column.add_child(status)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	column.add_child(grid)
	for family in load_spec.equipment:
		var equipment := TrainingScenario.aid_equipment(id, family)
		var tile := panel(Color("1d272d"))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var inside := VBoxContainer.new()
		inside.add_theme_constant_override("separation", 6)
		tile.add_child(inside)
		inside.add_child(model_preview(equipment))
		inside.add_child(text("%d×  %s" % [int(load_spec.equipment[family]), EquipmentIdentity.research_title(equipment, 1)], 27, TEXT, 700))
		inside.add_child(text("Level 1 · " + str(EquipmentIdentity.spec(equipment).get("name", family.capitalize())), 22, SOFT, 500))
		grid.add_child(tile)
	if load_spec.resources.size() > 0:
		var cargo := panel(Color("1d272d"))
		var line := HFlowContainer.new()
		line.add_theme_constant_override("h_separation", 22)
		line.add_theme_constant_override("v_separation", 8)
		cargo.add_child(line)
		for resource in load_spec.resources:
			var amount := text("%s %s" % [("Funds" if resource == "funds" else resource.capitalize()), CowUI.short(load_spec.resources[resource])], 26, CowUI.GOLD, 600)
			amount.autowrap_mode = TextServer.AUTOWRAP_OFF
			line.add_child(amount)
		column.add_child(cargo)
	var unload := TrainingCoach.make_button("UNLOAD CARGO" if player_is_ukraine else "WATCH UKRAINE UNLOAD", CowUI.GREEN, 30)
	unload.custom_minimum_size.y = 96
	unload.disabled = not loaded
	unload.pressed.connect(on_unload)
	column.add_child(unload)
	var back := TrainingCoach.make_button("BACK TO MAP", Color("2c3a41"), 28)
	back.pressed.connect(on_close)
	column.add_child(back)
	return made[0]

## The finish: +XP counts up, the Europe map unlock, and the way into the match.
static func finish(parent: Control, players: int, signed_in: bool, on_continue: Callable, on_sign_in: Callable) -> Control:
	var made := overlay(parent)
	var column: VBoxContainer = made[1]
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var kicker := text("TRAINING COMPLETE", 28, CowUI.GOLD, 700)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(kicker)
	var xp := text("+0 XP", 120, TEXT, 700)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(xp)
	var count := {"value": 0.0}
	var tween := xp.create_tween()
	tween.tween_interval(0.35)
	tween.tween_method(func(v: float): xp.text = "+%d XP" % int(round(v)), 0.0, float(PlayerAuth.TRAINING_XP), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var unlocked := panel(Color("1d2a1f"), Color("5fae4b"), 3)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	unlocked.add_child(inside)
	var map_line := text("EUROPE MAP UNLOCKED", 34, Color("b9f0a6"), 700)
	map_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inside.add_child(map_line)
	var note := text("You now have the experience to join the Europe map." if signed_in else "Sign in to add these XP to your commander and unlock the Europe map.", 25, TEXT, 500)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inside.add_child(note)
	column.add_child(unlocked)
	var next := text("Your opponent is awake now. The match carries on from here." if players == 1 else "The match carries on with two commanders.", 26, SOFT, 500)
	next.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(next)
	var go := TrainingCoach.make_button("CONTINUE THE WAR", CowUI.GREEN, 32)
	go.custom_minimum_size.y = 96
	go.pressed.connect(on_continue)
	column.add_child(go)
	if not signed_in:
		var sign := TrainingCoach.make_button("SIGN IN TO COLLECT XP", Color("2c3a41"), 26)
		sign.pressed.connect(on_sign_in)
		column.add_child(sign)
	return made[0]

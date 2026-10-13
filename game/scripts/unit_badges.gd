class_name UnitBadges
extends CanvasLayer
signal badge_clicked(index: int)
var armies: UnitSystem
var city_labels: Array[Button] = []
var buttons: Dictionary = {}
func _ready() -> void :
	layer = 3
func contains(screen: Vector2) -> bool:
	var point: = get_final_transform().affine_inverse() * screen
	for button in buttons.values():
		if button.visible and button.get_global_rect().has_point(point): return true
	return false
## No labels or tags on units (owner request): units are recognised by their 3D models.
## The selected army's details are in the army panel.
const SHOW_TAGS: = true
func _process(_delta: float) -> void :
	if armies == null: return
	if not SHOW_TAGS:
		for button in buttons.values(): button.visible = false
		return
	var camera: = get_viewport().get_camera_3d()
	if camera == null: return
	var transform: = get_final_transform().affine_inverse()
	var size: = transform * get_viewport().get_visible_rect().size
	var bottom: = 248.0 if size.y > size.x else 164.0
	var top: = 132.0 if size.x > size.y and size.y < 600 else 168.0
	if top == 132:
		bottom = 124
		if size.x >= 800: top = 100
	var safe: = Rect2(Vector2(8, top), Vector2(size.x - 16, maxf(0, size.y - bottom - top)))
	var alive: Dictionary = {}
	var occupied: Array[Rect2] = []
	for label in city_labels:
		if label.visible: occupied.append(label.get_global_rect())
	var ordered: = armies.units.duplicate()
	ordered.sort_custom( func(a: Dictionary, b: Dictionary):
		var selected_stack: String = armies.units[armies.selected].country + ":" + armies.units[armies.selected].stack_id if armies.selected >= 0 else ""
		var a_selected: bool = a.country + ":" + a.stack_id == selected_stack
		var b_selected: bool = b.country + ":" + b.stack_id == selected_stack
		if a_selected != b_selected: return a_selected
		return a.node.global_position.distance_squared_to(camera.global_position) < b.node.global_position.distance_squared_to(camera.global_position))
	var far: bool = armies.view_distance > UnitSystem.FAR_ZOOM
	var close: bool = armies.view_distance <= UnitSystem.CLOSE_ZOOM
	for unit in ordered:
		alive[unit.id] = true
		var button: = _badge(unit)
		button.visible = false
		var group: = armies.stacks.members(unit)
		if armies.stacks.leader(group).id != unit.id or not armies.visible_to_player(unit): continue
		var icon_mode: bool = unit.get("icon_only", false) or (far and not unit.node.visible)
		# Middle zoom: the 3D model alone. Close zoom: model + health bar. Far / no model: symbol.
		if not icon_mode and not (close and unit.node.visible): continue
		var selected: bool = armies.selected >= 0 and armies.units[armies.selected].stack_id == unit.stack_id and armies.units[armies.selected].country == unit.country
		var hostile: bool = armies.at_war and unit.country != GameSession.player_country
		var hp: = 0.0
		for member in group: hp += member.health
		hp /= maxf(1.0, group.size())
		var icon: UnitTypeIcon = button.get_node("Icon")
		var health: ProgressBar = button.get_node("Health")
		var level: Label = button.get_node("Level")
		icon.visible = icon_mode
		# Owner 2026-10-13: no "L1/L2" text on the map, just a small health bar.
		level.visible = false
		icon.kind = unit.visual_kind
		icon.faction = unit.faction_color
		icon.selected = selected
		icon.hostile = hostile
		icon.queue_redraw()
		level.text = "L" + str(int(unit.get("level", 1))) + (" ×" + str(group.size()) if group.size() > 1 else "")
		health.value = hp
		var fill: StyleBoxFlat = health.get_theme_stylebox("fill")
		fill.bg_color = Color("d65448") if hp < 30 else Color("dfba58") if hp < 60 else Color("5fb04a")
		var tag: StyleBoxFlat = button.get_meta("style")
		tag.bg_color = Color(0, 0, 0, 0) if icon_mode else (Color(0.85, 0.66, 0.27, 0.95) if selected else (Color(0.55, 0.12, 0.08, 0.9) if hostile else Color(0, 0, 0, 0.55)))
		button.custom_minimum_size = Vector2(34, 38) if icon_mode else Vector2(40, 9)
		button.size = button.custom_minimum_size
		button.tooltip_text = unit.country.capitalize() + " · " + armies.stacks.summary(unit)
		var anchor: Vector3 = unit.node.global_position + Vector3.UP * 0.15
		if camera.is_position_behind(anchor): continue
		var point: = transform * camera.unproject_position(anchor)
		var footprint: = button.custom_minimum_size
		# Symbols sit on the unit; health tags sit just below its model.
		var offsets: Array = [Vector2(-footprint.x * 0.5, -footprint.y * 0.5)] if icon_mode else [Vector2(-footprint.x * 0.5, 10), Vector2(-footprint.x * 0.5, 22), Vector2(-footprint.x * 0.5, -18)]
		for extra in [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 22), Vector2(0, -22)]: if icon_mode: offsets.append(offsets[0] + extra)
		for offset in offsets:
			var bounds: = Rect2(point + offset, footprint)
			if not safe.encloses(bounds): continue
			var clear: = true
			for previous in occupied:
				if bounds.grow(1).intersects(previous): clear = false
			if not clear: continue
			button.position = bounds.position
			button.visible = true
			occupied.append(bounds)
			break
	for id in buttons.keys():
		if alive.has(id): continue
		buttons[id].queue_free()
		buttons.erase(id)

func _badge(unit: Dictionary) -> Button:
	if buttons.has(unit.id): return buttons[unit.id]
	var button: = Button.new()
	button.text = ""
	button.flat = false
	var style: = StyleBoxFlat.new()
	style.set_corner_radius_all(5)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	button.set_meta("style", style)
	for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		for index in armies.units.size():
			if armies.units[index].id == unit.id:
				if badge_clicked.has_connections(): badge_clicked.emit(index)
				else: armies.select_unit(index))
	var icon: = UnitTypeIcon.new()
	icon.name = "Icon"
	icon.position = Vector2(2, 0)
	icon.size = Vector2(30, 30)
	button.add_child(icon)
	var level: = Label.new()
	level.name = "Level"
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	level.offset_bottom = 18
	level.add_theme_font_size_override("font_size", 13)
	level.add_theme_color_override("font_color", Color("fff4d9"))
	button.add_child(level)
	var health: = ProgressBar.new()
	health.name = "Health"
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health.show_percentage = false
	health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	health.offset_left = 2
	health.offset_right = -2
	health.offset_top = -7
	health.offset_bottom = -2
	var back: = StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.6)
	back.set_corner_radius_all(2)
	health.add_theme_stylebox_override("background", back)
	var fill: = StyleBoxFlat.new()
	fill.bg_color = Color("5fb04a")
	fill.set_corner_radius_all(2)
	health.add_theme_stylebox_override("fill", fill)
	button.add_child(health)
	add_child(button)
	buttons[unit.id] = button
	return button

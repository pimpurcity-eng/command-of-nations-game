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
func _process(_delta: float) -> void :
	if armies == null: return
	var camera: = get_viewport().get_camera_3d()
	if camera == null: return
	var transform: = get_final_transform().affine_inverse()
	var size: = transform * get_viewport().get_visible_rect().size
	var bottom: = 182.0 if size.y > size.x else 164.0
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
	for unit in ordered:
		alive[unit.id] = true
		if not buttons.has(unit.id):
			# Call of War style tag: model thumbnail + unit count + health. No names on the map;
			# the selected army's names are shown in the army panel.
			var button: = Button.new()
			button.text = ""
			button.icon = UnitVisual.preview_texture(unit.equipment_id)
			button.expand_icon = true
			button.custom_minimum_size = Vector2(0, 26)
			button.add_theme_constant_override("icon_max_width", 22)
			button.add_theme_constant_override("h_separation", 3)
			button.add_theme_font_size_override("font_size", 13)
			var style: = StyleBoxFlat.new()
			style.bg_color = Color("eeece4")
			style.set_corner_radius_all(3)
			style.corner_radius_top_left = 11
			style.corner_radius_bottom_left = 11
			style.content_margin_left = 4
			style.content_margin_right = 6
			style.content_margin_top = 1
			style.content_margin_bottom = 4
			style.shadow_color = Color(0, 0, 0, 0.35)
			style.shadow_size = 2
			button.set_meta("style", style)
			for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, style)
			button.pressed.connect( func():
				for index in armies.units.size():
					if armies.units[index].id == unit.id:
						if badge_clicked.has_connections(): badge_clicked.emit(index)
						else: armies.select_unit(index))
			add_child(button)
			var health: = ProgressBar.new()
			health.name = "Health"
			health.mouse_filter = Control.MOUSE_FILTER_IGNORE
			health.show_percentage = false
			health.anchor_top = 1
			health.anchor_bottom = 1
			health.anchor_right = 1
			health.offset_left = 5
			health.offset_right = -5
			health.offset_top = -5
			health.offset_bottom = -2
			var fill: = StyleBoxFlat.new()
			fill.bg_color = Color("5fb04a")
			health.add_theme_stylebox_override("fill", fill)
			button.add_child(health)
			buttons[unit.id] = button
		var button: Button = buttons[unit.id]
		button.visible = false
		var group: = armies.stacks.members(unit)
		if armies.stacks.leader(group).id != unit.id or not armies.visible_to_player(unit): continue
		var selected: bool = armies.selected >= 0 and armies.units[armies.selected].stack_id == unit.stack_id and armies.units[armies.selected].country == unit.country
		button.text = str(group.size())
		var missing: bool = unit.node.get_child(0).get_meta("missing_original_model", false)
		button.tooltip_text = unit.country.capitalize() + " · " + armies.stacks.summary(unit)
		if missing: button.tooltip_text += " · Original model not recovered"
		var hostile: bool = armies.at_war and unit.country != GameSession.player_country
		var tag: StyleBoxFlat = button.get_meta("style")
		tag.bg_color = Color("f2c94c") if selected else (Color("c8453b") if hostile else (Color("eeece4") if unit.country == GameSession.player_country else Color("b9bdb3")))
		button.add_theme_color_override("font_color", Color.WHITE if hostile and not selected else Color("1d2224"))
		var hp: = 0.0
		for member in group: hp += member.health
		button.get_node("Health").value = hp / group.size()
		var anchor: Vector3 = unit.node.global_position + Vector3.UP * 0.15
		if camera.is_position_behind(anchor): continue
		var point: = transform * camera.unproject_position(anchor)
		var footprint: = button.get_combined_minimum_size()
		# Beside the unit (Call of War), not floating above it.
		for offset in [Vector2(18, - footprint.y * 0.5), Vector2( - footprint.x * 0.5, 10), Vector2( - footprint.x - 16, - footprint.y * 0.5), Vector2(16, - footprint.y - 20), Vector2( - footprint.x - 16, 20), Vector2( - footprint.x * 0.5, - footprint.y - 54), Vector2( - footprint.x * 0.5, 56)]:
			var bounds: = Rect2(point + offset, footprint)
			if not safe.encloses(bounds): continue
			var clear: = true
			for previous in occupied:
				if bounds.grow(2).intersects(previous): clear = false
			if not clear: continue
			button.position = bounds.position
			button.visible = true
			occupied.append(bounds)
			break
	for id in buttons.keys():
		if alive.has(id): continue
		buttons[id].queue_free()
		buttons.erase(id)

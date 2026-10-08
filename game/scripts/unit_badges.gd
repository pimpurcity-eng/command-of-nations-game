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
			var button: = Button.new()
			button.text = EquipmentIdentity.title(unit.equipment_id)
			button.icon = UnitVisual.preview_texture(unit.equipment_id)
			button.expand_icon = true
			button.custom_minimum_size.y = 30
			button.add_theme_constant_override("icon_max_width", 20)
			button.add_theme_font_size_override("font_size", 11)
			var style: = StyleBoxFlat.new()
			style.bg_color = Color("081b27")
			style.border_color = unit.faction_color
			style.border_width_left = 3
			style.set_corner_radius_all(4)
			style.content_margin_left = 5
			style.content_margin_right = 5
			style.content_margin_top = 3
			style.content_margin_bottom = 3
			for state in ["normal", "hover", "pressed"]: button.add_theme_stylebox_override(state, style)
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
			fill.bg_color = Color("70b49a")
			health.add_theme_stylebox_override("fill", fill)
			button.add_child(health)
			buttons[unit.id] = button
		var button: Button = buttons[unit.id]
		button.visible = false
		var group: = armies.stacks.members(unit)
		if armies.stacks.leader(group).id != unit.id or not armies.visible_to_player(unit): continue
		var selected: bool = armies.selected >= 0 and armies.units[armies.selected].stack_id == unit.stack_id and armies.units[armies.selected].country == unit.country
		var close: = camera.global_position.distance_to(unit.node.global_position) < 18
		var role_name: String = str(EquipmentIdentity.spec(unit.equipment_id).get("role", unit.visual_kind))
		var short_role: String = {"armor": "TANK", "ifv": "IFV", "artillery": "ART", "air_defense": "SAM", "missile_launcher": "MISSILE", "fighter": "AIR", "naval": "NAVY", "drone": "UAV"}.get(role_name, role_name.to_upper())
		button.text = str(group.size()) + " " + (EquipmentIdentity.title(unit.equipment_id) if selected else short_role)
		var composition: Dictionary = {}
		for member in group:
			var role: String = str(EquipmentIdentity.spec(member.equipment_id).get("role", member.visual_kind)).to_upper()
			composition[role] = composition.get(role, 0) + 1
		if composition.size() > 1:
			var rows: PackedStringArray = []
			for role in composition: rows.append(str(composition[role]) + " " + role)
			button.text = " · ".join(rows) if not selected and not close else button.text + "\n" + " · ".join(rows)
		var missing: bool = unit.node.get_child(0).get_meta("missing_original_model", false)
		if missing: button.text = "? " + button.text
		button.tooltip_text = unit.country.capitalize() + " · " + armies.stacks.summary(unit)
		if missing: button.tooltip_text += " · Original model not recovered"
		button.modulate = Color("ffe0a0") if selected else (Color("ed8880") if armies.at_war and unit.country != GameSession.player_country else Color.WHITE)
		var hp: = 0.0
		for member in group: hp += member.health
		button.get_node("Health").value = hp / group.size()
		var anchor: Vector3 = unit.node.global_position + Vector3.UP * 0.7
		if camera.is_position_behind(anchor): continue
		var point: = transform * camera.unproject_position(anchor)
		var footprint: = button.get_combined_minimum_size()
		for offset in [Vector2( - footprint.x * 0.5, - footprint.y - 5), Vector2( - footprint.x * 0.5, 10), Vector2(16, - footprint.y * 0.5), Vector2( - footprint.x - 16, - footprint.y * 0.5), Vector2(16, - footprint.y - 20), Vector2( - footprint.x - 16, 20), Vector2( - footprint.x * 0.5, - footprint.y - 54), Vector2( - footprint.x * 0.5, 56)]:
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

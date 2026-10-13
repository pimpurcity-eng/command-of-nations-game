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
## Army markers in the Call of War style: diamond tokens when zoomed out, a count and
## health tag beside each 3D model when zoomed in (see UnitToken).
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
	for unit in ordered:
		alive[unit.id] = true
		var button: = _badge(unit)
		button.visible = false
		var group: = armies.stacks.members(unit)
		if armies.stacks.leader(group).id != unit.id or not armies.visible_to_player(unit): continue
		var icon_mode: bool = unit.get("icon_only", false) or (far and not unit.node.visible)
		# Call of War style (owner 2026-10-13): far = diamond token; zoomed in = tag beside the model.
		var selected: bool = armies.selected >= 0 and armies.units[armies.selected].stack_id == unit.stack_id and armies.units[armies.selected].country == unit.country
		var hostile: bool = armies.at_war and unit.country != GameSession.player_country
		var hp: = 0.0
		for member in group: hp += member.health
		hp /= maxf(1.0, group.size())
		var token: UnitToken = button.get_node("Token")
		token.mode = "token" if icon_mode else "tag"
		token.kind = unit.visual_kind
		token.count = group.size()
		token.health = hp
		token.own = unit.country == GameSession.player_country
		token.hostile = hostile
		token.selected = selected
		token.refresh()
		button.custom_minimum_size = token.size
		button.size = token.size
		button.tooltip_text = unit.country.capitalize() + " · " + armies.stacks.summary(unit)
		var anchor: Vector3 = unit.node.global_position + Vector3.UP * 0.15
		if camera.is_position_behind(anchor): continue
		var point: = transform * camera.unproject_position(anchor)
		var footprint: = button.custom_minimum_size
		# Tokens sit on the army; tags sit to the right of the model, like Call of War.
		var offsets: Array = [Vector2(-footprint.x * 0.5, -footprint.y * 0.5)] if icon_mode else [Vector2(14, -footprint.y * 0.5), Vector2(14, -footprint.y * 0.5 - 30), Vector2(-footprint.x - 14, -footprint.y * 0.5), Vector2(14, -footprint.y * 0.5 + 30)]
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
	var style: = StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]: button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		for index in armies.units.size():
			if armies.units[index].id == unit.id:
				if badge_clicked.has_connections(): badge_clicked.emit(index)
				else: armies.select_unit(index))
	var token: = UnitToken.new()
	token.name = "Token"
	button.add_child(token)
	add_child(button)
	buttons[unit.id] = button
	return button

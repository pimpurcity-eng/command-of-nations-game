class_name ArmySelectionPanel
extends CanvasLayer
signal accepted(ids: Array[String])
var panel: PanelContainer
var list: VBoxContainer
var count_label: Label
var checks: Dictionary = {}
func setup(theme: Theme) -> void :
	layer = 15
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	count_label = Label.new()
	count_label.add_theme_font_size_override("font_size", 20)
	column.add_child(count_label)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var row: = HBoxContainer.new()
	column.add_child(row)
	for title in ["Cancel", "Accept"]:
		var button: = Button.new()
		button.text = title
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		button.pressed.connect( func():
			if title == "Accept":
				var ids: Array[String] = []
				for id in checks:
					if checks[id].button_pressed: ids.append(id)
				if ids.is_empty(): return
				accepted.emit(ids)
			hide())
	get_viewport().size_changed.connect(_layout)
	hide()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 600) * 0.5), 12)
	panel.size = Vector2(minf(600, size.x - 24), size.y - 24)
func _count() -> void :
	var selected: = 0
	for button in checks.values():
		if button.button_pressed: selected += 1
	count_label.text = "SELECT ARMIES · " + str(selected) + " selected"
func open(armies: UnitSystem, selected_ids: Array[String]) -> void :
	for child in list.get_children(): list.remove_child(child);child.queue_free()
	checks.clear()
	for group in armies.stacks.groups():
		var unit: = armies.stacks.leader(group)
		if unit.country != GameSession.player_country or unit.health <= 0: continue
		var button: = Button.new()
		button.toggle_mode = true
		button.custom_minimum_size.y = 64
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = EquipmentIdentity.title(unit.equipment_id) + " · " + str(group.size()) + " units\n" + ("Moving" if unit.moving else "Idle") + " · " + unit.visual_kind.capitalize()
		button.icon = UnitVisual.preview_texture(unit.equipment_id)
		button.add_theme_constant_override("icon_max_width", 60)
		button.button_pressed = unit.id in selected_ids
		button.toggled.connect( func(_on: bool): _count())
		checks[unit.id] = button
		list.add_child(button)
	_count()
	_layout()
	show()

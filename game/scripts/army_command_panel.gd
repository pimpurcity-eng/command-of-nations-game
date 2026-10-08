class_name ArmyCommandPanel
extends CanvasLayer
signal split_confirmed(ids: Array[String])
signal delay_confirmed(seconds: float, synchronize: bool)
signal upgrade_confirmed
signal rebase_confirmed(city_id: String)
var panel: PanelContainer
var heading: Label
var body: VBoxContainer
var confirm: Button
var action: = ""
var checks: Dictionary = {}
var delay_input: SpinBox
var sync: CheckBox
var bases: OptionButton
func setup(theme: Theme) -> void :
	layer = 16
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", Color("e9cf87"))
	column.add_child(heading)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var actions: = HBoxContainer.new()
	column.add_child(actions)
	for text in ["Cancel", "Confirm"]:
		var button: = Button.new()
		button.text = text
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
		if text == "Confirm": confirm = button
		button.pressed.connect( func():
			if text == "Confirm": _accept()
			else: hide())
	get_viewport().size_changed.connect(_layout)
	hide()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 550) * 0.5), 12)
	panel.size = Vector2(minf(550, size.x - 24), minf(620, size.y - 24))
func _begin(kind: String, title: String) -> void :
	action = kind
	heading.text = title
	for child in body.get_children(): body.remove_child(child);child.queue_free()
	checks.clear()
	confirm.disabled = false
	_layout()
	show()
func _label(text: String) -> void :
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)
func open_split(units: UnitSystem) -> void :
	_begin("split", "SPLIT ARMY")
	_label("Choose the units to detach. Leave at least one in the original army. The new army will be selected for its next order.")
	var group: = units.stacks.members(units.units[units.selected])
	for unit in group:
		var check: = CheckBox.new()
		check.text = EquipmentIdentity.title(unit.equipment_id) + " · L" + str(unit.level) + " · " + str(int(unit.health)) + " HP"
		check.custom_minimum_size.y = 48
		check.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		check.icon = UnitVisual.preview_texture(unit.equipment_id)
		check.add_theme_constant_override("icon_max_width", 48)
		checks[unit.id] = check
		body.add_child(check)
		check.toggled.connect( func(_enabled: bool):
			var count: = checks.values().filter( func(button: CheckBox): return button.button_pressed).size()
			confirm.disabled = count == 0 or count == checks.size())
	confirm.disabled = true
func open_delay(units: UnitSystem) -> void :
	_begin("delay", "DELAY / SYNC ARRIVAL")
	_label("Wait before continuing the current route. Times use the campaign clock. Combat and changing terrain can alter arrival times.")
	delay_input = SpinBox.new()
	delay_input.min_value = 0
	delay_input.max_value = 1440
	delay_input.step = 1
	delay_input.suffix = "game minutes"
	delay_input.custom_minimum_size.y = 48
	body.add_child(delay_input)
	sync = CheckBox.new()
	sync.text = "Match arrival times"
	sync.custom_minimum_size.y = 48
	sync.button_pressed = units.command_groups().size() > 1
	body.add_child(sync)
	var eligible: = units.command_groups().filter( func(unit: Dictionary): return unit.moving and not units.air.is_air(unit))
	_label(str(eligible.size()) + " ground / naval armies with active routes")
	confirm.disabled = eligible.is_empty()
func open_upgrade(units: UnitSystem, research: ResearchSystem) -> void :
	_begin("upgrade", "UPGRADE ARMY")
	_label("Upgrade eligible units to their highest researched level. Upgrading locks movement until complete; defensive combat remains available.")
	var group: = units.stacks.members(units.units[units.selected])
	var bill: Dictionary = {}
	var count: = 0
	var duration: = 0.0
	for resource in ProductionSystem.RESOURCES: bill[resource] = 0.0
	for unit in group:
		if unit.level >= research.level(unit.equipment_id): continue
		count += 1
		var spec: = research.economy.equipment(unit.equipment_id)
		for resource in ProductionSystem.RESOURCES: bill[resource] += ceil(spec.cost[resource] * 0.5)
		duration = maxf(duration, spec.seconds * 0.5)
	var text: = str(count) + " units · " + SimulationClock.duration(duration) + " at 1x"
	for resource in bill: text += "\n" + resource.capitalize() + ": " + str(int(bill[resource]))
	_label(text)
	confirm.disabled = count == 0 or group.any( func(unit: Dictionary): return unit.moving or unit.engaged or unit.get("upgrade_remaining", 0.0) > 0 or unit.get("refuel_remaining", 0.0) > 0)
	for resource in bill:
		if research.economy.stockpiles.russia[resource] < bill[resource]: confirm.disabled = true
	if confirm.disabled: _label("Stop the army, leave combat, finish refueling and make sure research and resources are available.")
func open_rebase(units: UnitSystem) -> void :
	_begin("rebase", "REBASE AIRCRAFT")
	_label("Transfer a landed squadron to a controlled airbase within operating range. The squadron flies there and refuels on landing.")
	bases = OptionButton.new()
	bases.custom_minimum_size.y = 48
	body.add_child(bases)
	var unit: Dictionary = units.units[units.selected]
	for city in units.air.economy.cities:
		if city.id == unit.base_city or not units.air.available(city, unit.country) or units.air.base(unit).point.distance_to(city.point) > units.air.radius(unit): continue
		bases.add_item(city.name)
		bases.set_item_metadata(bases.item_count - 1, city.id)
	confirm.disabled = bases.item_count == 0 or unit.flight_mode != "grounded" or unit.refuel_remaining > 0
	if confirm.disabled: _label("No available transfer. Land and refuel, then choose an airbase in range.")
func _accept() -> void :
	if action == "split":
		var ids: Array[String] = []
		for id in checks:
			if checks[id].button_pressed: ids.append(id)
		split_confirmed.emit(ids)
	elif action == "delay": delay_confirmed.emit(delay_input.value * 60.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND, sync.button_pressed)
	elif action == "upgrade": upgrade_confirmed.emit()
	elif action == "rebase" and bases.selected >= 0: rebase_confirmed.emit(bases.get_item_metadata(bases.selected))
	hide()

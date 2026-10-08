class_name StrategyHUD
extends CanvasLayer
signal cancel_order_requested
signal delay_requested
signal forced_march_requested
signal upgrade_requested
signal rebase_requested
signal select_armies_requested
signal fire_control_requested
signal attack_requested
signal campaign_requested(page: String)
signal merge_requested
signal split_requested
signal stack_info_requested
signal add_destination_requested
signal declare_war_requested
signal new_match_requested
var city_scores: = {"russia": 0, "ukraine": 0}
signal army_roster_requested
signal research_requested
signal weapon_showcase_requested
signal exchange_requested
signal capital_requested
signal production_requested
signal pause_requested
signal speed_requested(speed: float)
signal save_requested
signal load_requested
signal stop_requested
signal move_requested
signal patrol_requested
signal unit_requested(index: int)
signal home_requested
signal zoom_requested(amount: float)
signal rotate_requested(amount: float)
signal city_requested(index: int)
signal terrain_mode_requested(enabled: bool)
var detail: Label
var status: Label
var command_panel: PanelContainer
var action_row: HBoxContainer
var help_label: Label
var brand_label: Label
var region_label: Label
var toolbar: HBoxContainer
var mode_button: Button
var navigation_menu: MenuButton
var pause_button: Button
var time_label: Label
var resource_strip: Label
var resource_row: HBoxContainer
var resource_values: Dictionary = {}
var resource_captions: Dictionary = {}
var unit_portrait: TextureRect
var health_bar: ProgressBar
var inspecting_unit: = false
var selected_unit: = -1
var move_button: Button
var stop_button: Button
var patrol_button: Button
var armies_button: Button
var cancel_button: Button
var clock_paused: = true
var status_message: = "Select an army or city"
var choosing_destination: = false
var tech_button: Button
var builds_button: Button
var orders_menu: MenuButton
func _ready() -> void :
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme: = StrategyTheme.create()
	root.theme = theme
	var header: = _panel(root, Vector2(12, 10), 0, Vector2(-12, 58))
	var line: = HBoxContainer.new()
	header.add_child(line)
	brand_label = Label.new()
	brand_label.text = "COMMAND OF NATIONS"
	brand_label.add_theme_font_size_override("font_size", 19)
	brand_label.add_theme_color_override("font_color", Color("ebd5aa"))
	brand_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_label.clip_text = true
	line.add_child(brand_label)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 12)
	line.add_child(time_label)
	region_label = Label.new()
	region_label.text = "REGIONAL CAMPAIGN"
	region_label.add_theme_font_size_override("font_size", 14)
	line.add_child(region_label)
	resource_strip = Label.new()
	resource_strip.position = Vector2(12, 118)
	resource_strip.add_theme_font_size_override("font_size", 11)
	resource_strip.add_theme_color_override("font_color", Color("ebd5aa"))
	resource_strip.add_theme_color_override("font_outline_color", Color("07121b"))
	resource_strip.add_theme_constant_override("outline_size", 3)
	resource_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resource_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(resource_strip)
	resource_strip.visible = false
	resource_row = HBoxContainer.new()
	resource_row.position = Vector2(12, 64)
	resource_row.add_theme_constant_override("separation", 4)
	root.add_child(resource_row)
	for resource in ProductionSystem.RESOURCES:
		var card: = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style: = StrategyTheme.surface("panel", 7)
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		card.add_theme_stylebox_override("panel", style)
		resource_row.add_child(card)
		var column: = VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		card.add_child(column)
		var caption: = Label.new()
		caption.text = resource.capitalize()
		caption.add_theme_font_size_override("font_size", 10)
		caption.add_theme_color_override("font_color", Color("91aab7"))
		column.add_child(caption)
		resource_captions[resource] = caption
		var value: = Label.new()
		value.text = "0"
		value.add_theme_font_size_override("font_size", 15)
		value.add_theme_color_override("font_color", Color("e7d3a4"))
		column.add_child(value)
		resource_values[resource] = value
	toolbar = HBoxContainer.new()
	toolbar.position = Vector2(12, 112)
	root.add_child(toolbar)
	for entry in [["+", -0.15], ["−", 0.15]]:
		var button: = _button(entry[0])
		button.pressed.connect( func(): zoom_requested.emit(entry[1]))
		toolbar.add_child(button)
	var north: = _button("N")
	north.pressed.connect( func(): home_requested.emit())
	toolbar.add_child(north)
	for entry in [["L", -0.18], ["R", 0.18]]:
		var button: = _button(entry[0])
		button.pressed.connect( func(): rotate_requested.emit(entry[1]))
		toolbar.add_child(button)
	var city_menu: = MenuButton.new()
	city_menu.text = "Cities"
	city_menu.custom_minimum_size.y = 44
	for entry in [["Kyiv · Capital", 0], ["Lviv", 1], ["Odesa", 2], ["Kharkiv", 3], ["Dnipro", 4], ["Moscow · Capital", 5], ["Kursk", 6], ["Belgorod", 7], ["Voronezh", 8], ["Rostov-on-Don", 9]]:
		city_menu.get_popup().add_item(entry[0], entry[1])
	city_menu.get_popup().id_pressed.connect( func(index: int): city_requested.emit(index))
	toolbar.add_child(city_menu)
	mode_button = _button("Terrain")
	mode_button.toggle_mode = true
	mode_button.toggled.connect( func(enabled: bool):
		mode_button.text = "Borders" if enabled else "Terrain"
		terrain_mode_requested.emit(enabled))
	toolbar.add_child(mode_button)
	navigation_menu = MenuButton.new()
	navigation_menu.text = "View"
	navigation_menu.custom_minimum_size = Vector2(64, 48)
	for title in ["Reset north", "Rotate left", "Rotate right", "Terrain / borders", "Speed 1x", "Speed 2x", "Speed 4x", "Save game", "Load game", "Equipment & production", "Army roster", "New match", "Add destination to selected army", "Merge nearby friendly armies", "Split selected units", "Army composition / battle info", "Declare war on Ukraine", "Technology / day unlocks", "Capital / construction", "Supply exchange", "All weapon models", "Select several armies", "Fire control", "Attack enemy army", "Victory progress", "Diplomacy", "Delay / synchronize arrival", "Forced march", "Upgrade selected army", "Rebase aircraft"]:
		navigation_menu.get_popup().add_item(title)
	navigation_menu.get_popup().id_pressed.connect( func(index: int):
		match index:
			0: home_requested.emit()
			1: rotate_requested.emit(-0.18)
			2: rotate_requested.emit(0.18)
			3: mode_button.button_pressed = not mode_button.button_pressed
			4: speed_requested.emit(1.0)
			5: speed_requested.emit(2.0)
			6: speed_requested.emit(4.0)
			7: save_requested.emit()
			8: load_requested.emit()
			9: production_requested.emit()
			10: army_roster_requested.emit()
			11: new_match_requested.emit()
			12: add_destination_requested.emit()
			13: merge_requested.emit()
			14: split_requested.emit()
			15: stack_info_requested.emit()
			16: declare_war_requested.emit()
			17: research_requested.emit()
			18: capital_requested.emit()
			19: exchange_requested.emit()
			20: weapon_showcase_requested.emit()
			21: select_armies_requested.emit()
			22: fire_control_requested.emit()
			23: attack_requested.emit()
			24: campaign_requested.emit("victory")
			25: campaign_requested.emit("diplomacy")
			26: delay_requested.emit()
			27: forced_march_requested.emit()
			28: upgrade_requested.emit()
			29: rebase_requested.emit()
	)
	toolbar.add_child(navigation_menu)
	pause_button = _button("Pause")
	pause_button.pressed.connect( func(): pause_requested.emit())
	toolbar.add_child(pause_button)
	var tech: = _button("Tech")
	tech_button = tech
	tech.pressed.connect( func(): research_requested.emit())
	toolbar.add_child(tech)
	command_panel = _panel(root, Vector2(12, -152), 1, Vector2(-12, -12))
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	command_panel.add_child(column)
	detail = Label.new()
	detail.custom_minimum_size.y = 42
	detail.text = "REGIONAL COMMAND  ·  10 CITIES / 3 GROUPS"
	detail.add_theme_font_size_override("font_size", 15)
	detail.add_theme_color_override("font_color", Color("ebd5aa"))
	var selection_row: = HBoxContainer.new()
	selection_row.add_theme_constant_override("separation", 12)
	column.add_child(selection_row)
	unit_portrait = TextureRect.new()
	unit_portrait.custom_minimum_size = Vector2(76, 43)
	unit_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	unit_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	selection_row.add_child(unit_portrait)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_row.add_child(detail)
	action_row = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 5)
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size.y = 4
	health_bar.show_percentage = false
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var health_fill: = StyleBoxFlat.new()
	health_fill.bg_color = Color("76bca0")
	health_bar.add_theme_stylebox_override("fill", health_fill)
	var health_background: = StyleBoxFlat.new()
	health_background.bg_color = Color("243748")
	health_bar.add_theme_stylebox_override("background", health_background)
	column.add_child(health_bar)
	health_bar.visible = false
	column.add_child(action_row)
	armies_button = _button("Armies")
	armies_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	armies_button.pressed.connect( func(): select_armies_requested.emit())
	action_row.add_child(armies_button)
	cancel_button = _button("Cancel")
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.visible = false
	cancel_button.pressed.connect( func(): cancel_order_requested.emit())
	action_row.add_child(cancel_button)
	patrol_button = _button("Patrol")
	patrol_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	patrol_button.pressed.connect( func(): patrol_requested.emit())
	patrol_button.visible = false
	action_row.add_child(patrol_button)
	var production: = _button("Builds")
	builds_button = production
	production.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	production.pressed.connect( func(): capital_requested.emit())
	action_row.add_child(production)
	orders_menu = MenuButton.new()
	orders_menu.text = "Orders"
	orders_menu.custom_minimum_size = Vector2(44, 48)
	orders_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for title in ["Army details", "Attack enemy", "Fire control", "Add destination", "Merge nearby", "Split units", "Select armies", "Delay / sync arrival", "Forced march", "Upgrade army", "Rebase aircraft"]: orders_menu.get_popup().add_item(title)
	orders_menu.get_popup().id_pressed.connect( func(index: int):
		match index:
			0: stack_info_requested.emit()
			1: attack_requested.emit()
			2: fire_control_requested.emit()
			3: add_destination_requested.emit()
			4: merge_requested.emit()
			5: split_requested.emit()
			6: select_armies_requested.emit()
			7: delay_requested.emit()
			8: forced_march_requested.emit()
			9: upgrade_requested.emit()
			10: rebase_requested.emit()
	)
	orders_menu.hide()
	action_row.add_child(orders_menu)
	move_button = _button("Move")
	move_button.disabled = true
	var order_style: = StyleBoxFlat.new()
	order_style.bg_color = Color("2b3027")
	order_style.border_color = Color("d0b777")
	order_style.set_border_width_all(1)
	order_style.set_corner_radius_all(6)
	order_style.content_margin_left = 17
	order_style.content_margin_right = 17
	move_button.add_theme_stylebox_override("normal", order_style)
	move_button.add_theme_color_override("font_color", Color("ebd5aa"))
	move_button.pressed.connect( func(): move_requested.emit())
	action_row.add_child(move_button)
	stop_button = _button("Stop")
	stop_button.disabled = true
	stop_button.pressed.connect( func(): stop_requested.emit())
	action_row.add_child(stop_button)
	status = Label.new()
	status.text = "Choose a city or select a group to issue orders."
	status.add_theme_font_size_override("font_size", 12)
	status.max_lines_visible = 2
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	help_label = Label.new()
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color("abbac1"))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.text = "Drag to pan · Pinch to zoom · L/R to rotate\nSelect a group, tap Move, then choose a destination."
	column.add_child(help_label)
	get_viewport().size_changed.connect(_responsive_layout)
	_responsive_layout()
func _button(title: String) -> Button:
	var button: = Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(40, 48)
	return button
func _panel(root: Control, start: Vector2, anchor: float, end: Vector2) -> PanelContainer:
	var panel: = PanelContainer.new()
	root.add_child(panel)
	panel.anchor_right = 1
	panel.anchor_top = anchor
	panel.anchor_bottom = anchor
	panel.offset_left = start.x
	panel.offset_top = start.y
	panel.offset_right = end.x
	panel.offset_bottom = end.y
	panel.add_theme_stylebox_override("panel", StrategyTheme.surface("panel"))
	return panel
func show_territory(t: Dictionary) -> void :
	inspecting_unit = false
	builds_button.show()
	orders_menu.hide()
	health_bar.visible = false
	detail.text = t.title.to_upper() + "  /  " + ("YOURS · YOUR COUNTRY" if t.controller == GameSession.player_country else t.controller.to_upper()) + " · " + str(t.get("terrain", "plains")).to_upper()
func show_status(message: String) -> void :
	status_message = message
	status.text = ("PAUSED · Tap Play to run orders · " if clock_paused else "") + message
	status.add_theme_color_override("font_color", Color("ebd5aa") if clock_paused else Color("b9cdd8"))
func _responsive_layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	resource_strip.size.x = size.x - 24
	resource_row.size = Vector2(size.x - 24, 42)
	unit_portrait.visible = size.x > 480
	var compact: = size.x < 900 or size.y < 600
	var landscape: = size.x > size.y
	var short_landscape: = landscape and size.y < 600
	brand_label.add_theme_font_size_override("font_size", 16 if compact else 19)
	region_label.visible = not compact
	command_panel.offset_top = -120 if short_landscape else (-152 if landscape else -170)
	unit_portrait.visible = not short_landscape
	unit_portrait.custom_minimum_size = Vector2(60, 42) if size.x < 480 else Vector2(76, 43)
	detail.add_theme_font_size_override("font_size", 13 if size.x < 480 else 15)
	detail.custom_minimum_size.y = 42 if size.x < 480 else 52
	resource_row.position.x = 12
	resource_row.position.y = 48 if short_landscape else 64
	resource_row.size.y = 30 if short_landscape else 42
	toolbar.position.y = 84 if short_landscape else 112
	var header: PanelContainer = brand_label.get_parent().get_parent()
	header.offset_bottom = 44 if short_landscape else 58
	for value in resource_values.values(): value.add_theme_font_size_override("font_size", 12 if short_landscape else 15)
	if short_landscape and size.x >= 800:

		brand_label.add_theme_font_size_override("font_size", 13)
		resource_row.position = Vector2(222, 10)
		resource_row.size = Vector2(size.x - 402, 30)
		toolbar.position.y = 52
	for key in resource_captions:
		resource_captions[key].text = {"funds": "Funds", "materials": "Mat.", "electronics": "Elec.", "fuel": "Fuel", "manpower": "Crew"}[key] if short_landscape else key.capitalize()
	status.max_lines_visible = 1 if short_landscape else 2
	detail.max_lines_visible = 1 if short_landscape else (2 if size.x < 480 else -1)
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	help_label.visible = not landscape and not compact
	navigation_menu.visible = true
	tech_button.visible = size.x >= 480
	for index in [2, 3, 4]: toolbar.get_child(index).visible = not compact
	mode_button.visible = not compact
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for child in action_row.get_children():
		child.add_theme_font_size_override("font_size", 15 if compact else 16)
		child.custom_minimum_size.y = 44 if short_landscape else 48
	mode_button.add_theme_font_size_override("font_size", 14)

func show_clock(elapsed: float, speed: float, paused: bool) -> void :
	var seconds: = int(elapsed * SimulationClock.REAL_SECONDS_PER_SIM_SECOND)
	time_label.text = "D%d %02d:%02d · %s" % [1 + seconds / 86400, (seconds % 86400) / 3600, (seconds % 3600) / 60, "PAUSED" if paused else str(int(speed)) + "x"]
	region_label.text = "CITY CAPTURES  RUSSIA %d/3   UKRAINE %d/3" % [city_scores.russia, city_scores.ukraine]
	if not region_label.visible: time_label.text += " · %d/3" % city_scores.russia
	clock_paused = paused
	pause_button.text = "Play" if paused else "Pause"
	pause_button.modulate = Color("ffe0a0") if paused else Color.WHITE
	show_status(status_message)

func show_army_roster(units: Array) -> void :
	var popup: = PopupMenu.new()
	add_child(popup)
	for i in units.size():
		if units[i].country != GameSession.player_country: continue
		popup.add_item(("Z · " if units[i].country == GameSession.player_country else "") + units[i].country.capitalize() + " · " + EquipmentIdentity.title(units[i].equipment_id) + " · " + units[i].name, i)
	popup.id_pressed.connect( func(index: int): unit_requested.emit(index))
	popup.popup_hide.connect( func(): popup.queue_free())
	var size: = get_viewport().get_visible_rect().size
	popup.popup_centered_clamped(Vector2i(mini(460, int(size.x) - 24), mini(400, int(size.y) - 24)))

func show_unit(unit: Dictionary) -> void :
	inspecting_unit = true
	builds_button.hide()
	orders_menu.show()
	show_health(unit.health)
	detail.text = EquipmentIdentity.title(unit.equipment_id).to_upper() + " / " + unit.country.to_upper() + " · " + str(int(unit.health)) + "%"
	unit_portrait.texture = UnitVisual.preview_texture(unit.equipment_id)
	move_button.disabled = unit.country != GameSession.player_country
	stop_button.disabled = unit.country != GameSession.player_country
	show_air_commands(unit.visual_kind == "fighter")
func show_air_commands(aircraft: bool) -> void :
	patrol_button.visible = aircraft and not choosing_destination
	armies_button.visible = not aircraft and not choosing_destination
	cancel_button.visible = choosing_destination
	move_button.text = "Fly" if aircraft else "Move"
	stop_button.text = "Return" if aircraft else "Stop"
func set_order_mode(enabled: bool) -> void :
	choosing_destination = enabled
	cancel_button.visible = enabled
	show_air_commands(move_button.text == "Fly")
	move_button.modulate = Color("ffe0a0") if enabled else Color.WHITE
func show_health(value: float) -> void :
	health_bar.visible = inspecting_unit
	health_bar.value = value
	health_bar.tooltip_text = "Army health: %d%%" % roundi(value)
func clear_unit_selection() -> void :
	builds_button.show()
	orders_menu.hide()
	health_bar.visible = false
	inspecting_unit = false
	move_button.disabled = true
	stop_button.disabled = true
	detail.text = "REGIONAL COMMAND"

func show_resources(country: String, stockpile: Dictionary) -> void :
	resource_strip.text = country.capitalize() + "  ·  "
	for resource in ProductionSystem.RESOURCES:
		resource_strip.text += resource.capitalize() + " " + str(int(stockpile[resource])) + "   "
		resource_values[resource].text = str(int(stockpile[resource]))

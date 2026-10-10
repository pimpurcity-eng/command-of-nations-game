class_name CampaignPanel
extends CanvasLayer
var panel: PanelContainer
var content: VBoxContainer
var rules: MatchSystem
var buildings: BuildingSystem
var tab: = "victory"
func setup(match_rules: MatchSystem, infrastructure: BuildingSystem, theme: Theme) -> void :
	rules = match_rules
	buildings = infrastructure
	layer = 14
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
	var tabs: = HBoxContainer.new()
	column.add_child(tabs)
	for entry in [["Victory", "victory"], ["Diplomacy", "diplomacy"], ["Close", "close"]]:
		var button: = Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
		button.pressed.connect( func():
			if entry[1] == "close": hide();return
			tab = entry[1]
			_refresh())
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)
	get_viewport().size_changed.connect(_layout)
	rules.report.connect( func(_message: String):
		if visible: _refresh())
	hide()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 650) * 0.5), 12)
	panel.size = Vector2(minf(650, size.x - 24), size.y - 24)
func _label(text: String, heading: bool = false) -> void :
	var label: = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if heading:
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color("e9cf87"))
	content.add_child(label)
func _refresh() -> void :
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	var scores: = rules.city_score()
	if tab == "victory":
		_label("VICTORY PROGRESS", true)
		_label("Capture three opposing city provinces to win this campaign. Hold each city center uncontested to take control.")
		if not rules.winner.is_empty(): _label(rules.winner.capitalize() + " has won this campaign.", true)
		for country in ["russia", "ukraine"]:
			_label(country.capitalize() + " · " + str(scores[country]) + " / 3 opposing cities", true)
			var bar: = ProgressBar.new()
			bar.max_value = 3
			bar.value = scores[country]
			bar.custom_minimum_size.y = 16
			bar.show_percentage = false
			content.add_child(bar)
		for city in buildings.economy.cities:
			var controller: = buildings.economy.controller(city)
			_label(city.name + " · " + ("YOURS" if controller == GameSession.player_country else controller.capitalize()) + (" · captured" if controller != city.country.to_lower() else " · core city"))
	else:
		_label("DIPLOMACY", true)
		_label(GameSession.player_country.capitalize() + " · You\n" + GameSession.opponent_country().capitalize() + " · AI opponent")
		_label("AT WAR" if rules.at_war else "AT PEACE", true)
		_label("Red territory belongs to the opposing country during war. Friendly control follows captured province ownership.")
		for country in ["russia", "ukraine"]:
			var provinces: = 0
			var cities: = 0
			for territory in rules.terrain.territories:
				if territory.playable and territory.controller == country: provinces += 1
			for city in buildings.economy.cities:
				if buildings.economy.controlled(city, country): cities += 1
			_label(country.capitalize() + " · " + str(provinces) + " provinces · " + str(cities) + " cities")
		var action: = Button.new()
		action.text = "End war · single-player ceasefire" if rules.at_war else "Declare war on " + GameSession.opponent_country().capitalize()
		action.custom_minimum_size.y = 48
		action.disabled = not rules.winner.is_empty()
		action.pressed.connect( func():
			if rules.at_war: rules.ceasefire()
			else: rules.declare_war()
			rules.terrain.update_relations(rules.at_war)
			_refresh())
		content.add_child(action)
func open(page: String = "victory") -> void :
	tab = page
	_refresh()
	_layout()
	show()

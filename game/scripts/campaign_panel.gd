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
	for entry in [["Victory", "victory"], ["News", "news"], ["Battles", "battles"], ["Diplomacy", "diplomacy"], ["Close", "close"]]:
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
	if tab == "news":
		_label("WAR NEWSPAPER", true)
		if rules.chronicle.issues.is_empty(): _label("The first issue is printed at the end of day 1.")
		for i in range(rules.chronicle.issues.size() - 1, -1, -1):
			var issue: Dictionary = rules.chronicle.issues[i]
			_label(str(issue.headline).to_upper(), true)
			for line in issue.lines: _label(str(line))
		return
	if tab == "battles":
		_label("BATTLE REPORTS", true)
		if rules.chronicle.battles.is_empty(): _label("No battles yet.")
		for i in range(rules.chronicle.battles.size() - 1, -1, -1):
			_label(WarChronicle.summary(rules.chronicle.battles[i]))
		return
	if tab == "victory":
		_label("VICTORY PROGRESS", true)
		if not rules.winner.is_empty(): _label(MatchSystem.VICTORY_NAMES.get(rules.victory_type, "VICTORY") + " · " + rules.winner.capitalize() + " has won this campaign.", true)
		_label("Four ways to win:\n• DOMINATION: capture %d%% of all victory points outside your homeland and hold them for a game hour (province 1, city %d, capital %d points).\n• ECONOMIC (very hard): earn %d%% of all income on the map, keep %s funds and hold your capital, without a break for %d days.\n• ELIMINATION: destroy every enemy army and production.\n• POINTS: after day %d the most victory points wins." % [roundi(VictoryRules.DOMINATION_SHARE * 100), VictoryRules.CITY_POINTS, VictoryRules.CAPITAL_POINTS, roundi(VictoryRules.ECONOMIC_SHARE * 100), _short(VictoryRules.ECONOMIC_FUNDS), int(VictoryRules.ECONOMIC_DAYS), int(VictoryRules.TIME_LIMIT_DAYS)])
		var countries: Array = buildings.economy.stockpiles.keys()
		var table: = VictoryRules.standings(rules.terrain.territories, rules.cities, countries)
		for country in countries:
			var row: Dictionary = table[country]
			_label("%s%s · %d victory points" % [country.capitalize(), " (you)" if country == GameSession.player_country else "", row.points], true)
			_bar("Domination %d / %d foreign points" % [row.foreign_held, ceili(row.foreign_total * VictoryRules.DOMINATION_SHARE)], row.domination / VictoryRules.DOMINATION_SHARE)
			var economic: = rules.victory.economic_conditions(rules, country)
			var held: float = rules.victory.economic_held.get(country, 0.0) / VictoryRules.DAY
			_bar("Economy · income share %d%% (need %d%%) · funds %s / %s · capital %s · %.1f / %d days" % [roundi(100 * rules.victory.income_share(country)), roundi(VictoryRules.ECONOMIC_SHARE * 100), _short(buildings.economy.stockpiles[country].get("funds", 0.0)), _short(VictoryRules.ECONOMIC_FUNDS), "held" if economic[2] else "LOST", held, int(VictoryRules.ECONOMIC_DAYS)], held / VictoryRules.ECONOMIC_DAYS)
		var days_left: = VictoryRules.TIME_LIMIT_DAYS - rules.clock.elapsed / VictoryRules.DAY if rules.clock != null else VictoryRules.TIME_LIMIT_DAYS
		_label("Points decision in %.1f days." % maxf(days_left, 0.0))
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
func _bar(caption: String, fraction: float) -> void:
	_label(caption)
	var bar: = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(fraction, 0.0, 1.0)
	bar.custom_minimum_size.y = 16
	bar.show_percentage = false
	content.add_child(bar)
static func _short(amount: float) -> String:
	return ("%.0fk" % (amount / 1000.0)) if amount >= 10000 else str(roundi(amount))
func open(page: String = "victory") -> void :
	tab = page
	_refresh()
	_layout()
	show()

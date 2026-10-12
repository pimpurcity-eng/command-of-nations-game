class_name CampaignPanel
extends CanvasLayer
var panel: PanelContainer
var content: VBoxContainer
var rules: MatchSystem
var buildings: BuildingSystem
var tab: = "victory"
signal strategic_launch_requested(kind: String)
signal status_message(text: String)
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
	for entry in [["Victory", "victory"], ["News", "news"], ["Battles", "battles"], ["Diplomacy", "diplomacy"], ["Arsenal", "strategic"], ["Close", "close"]]:
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
	if tab == "strategic":
		_strategic()
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
			if not buildings.economy.controlled(city,GameSession.player_country): continue
			var controller: = buildings.economy.controller(city)
			_label(city.name + " · " + ("YOURS" if controller == GameSession.player_country else controller.capitalize()) + (" · captured" if controller != city.country.to_lower() else " · core city"))
	else:
		_diplomacy()
## Relations, coalitions and chat (Diplomacy). The AI answers proposals by how the war goes.
func _diplomacy() -> void:
	var me: = GameSession.player_country
	var talks: Diplomacy = rules.diplomacy
	var countries: Array = buildings.economy.stockpiles.keys()
	var table: = VictoryRules.standings(rules.terrain.territories, rules.cities, countries)
	_label("DIPLOMACY", true)
	for other in countries:
		if other == me: continue
		var r: = talks.relation(me, other)
		var flags: = []
		if r.right_of_way: flags.append("right of way")
		if r.shared_vision: flags.append("shared vision")
		if talks.embargoed(me, other): flags.append("you embargo them")
		if talks.embargoed(other, me): flags.append("they embargo you")
		_label("%s · %s · %s%s" % [other.capitalize(), "AI" if other in talks.ai_countries else "player", "AT WAR" if r.war else "AT PEACE", (" · " + ", ".join(flags)) if not flags.is_empty() else ""], true)
		var row: = HBoxContainer.new()
		_action(row, "Propose peace" if r.war else "Declare war", func():
			if r.war: hud_status(talks.propose(me, other, "peace", table).message)
			else: rules.declare_war())
		_action(row, "Right of way", func(): hud_status(talks.propose(me, other, "right_of_way", table).message), r.war or r.right_of_way)
		_action(row, "Shared vision", func(): hud_status(talks.propose(me, other, "shared_vision", table).message), r.war or r.shared_vision)
		_action(row, "Lift embargo" if talks.embargoed(me, other) else "Embargo", func(): talks.set_embargo(me, other, not talks.embargoed(me, other)))
		content.add_child(row)
	_label("COALITION", true)
	var mine: = talks.coalition_of(me)
	if mine.is_empty():
		_label("Coalition members are at peace and share vision. Leaving blocks rejoining for %d days." % int(Diplomacy.REJOIN_DAYS))
		var row: = HBoxContainer.new()
		var name_box: = LineEdit.new()
		name_box.placeholder_text = "Coalition name"
		name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_box)
		_action(row, "Create", func(): hud_status(talks.create_coalition(name_box.text, me)))
		content.add_child(row)
		for name in talks.coalitions:
			var join_row: = HBoxContainer.new()
			_action(join_row, "Join %s (%d)" % [name, talks.coalitions[name].members.size()], func(): hud_status(talks.join(name, me)))
			content.add_child(join_row)
	else:
		_label("%s · members: %s" % [mine, ", ".join(talks.coalitions[mine].members.map(func(c): return str(c).capitalize()))])
		var row: = HBoxContainer.new()
		_action(row, "Leave coalition", func(): talks.leave(me))
		content.add_child(row)
	_label("MESSAGES", true)
	var inbox: = talks.inbox(me)
	if inbox.is_empty(): _label("No messages yet.")
	for i in range(maxi(0, inbox.size() - 20), inbox.size()):
		var m: Dictionary = inbox[i]
		_label("Day %d · %s → %s: %s" % [1 + int(m.time / VictoryRules.DAY), str(m.from).capitalize(), "everyone" if m.to == "all" else str(m.to).replace("coalition:", "coalition ").capitalize(), m.text])
	var send: = HBoxContainer.new()
	var to: = OptionButton.new()
	var targets: = ["all"]
	for other in countries:
		if other != me: targets.append(other)
	if not mine.is_empty(): targets.append("coalition:" + mine)
	for target in targets: to.add_item("Everyone" if target == "all" else target.replace("coalition:", "Coalition ").capitalize())
	send.add_child(to)
	var text: = LineEdit.new()
	text.placeholder_text = "Message"
	text.max_length = 300
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	send.add_child(text)
	_action(send, "Send", func():
		var target: String = targets[to.selected]
		talks.post(me, target, text.text)
		if target in talks.ai_countries:
			talks.post(target, me, "We will answer on the battlefield." if talks.at_war(me, target) else "Your message has been noted, " + me.capitalize() + "."))
	content.add_child(send)
func _action(row: HBoxContainer, caption: String, action: Callable, disabled: bool = false) -> void:
	var button: = Button.new()
	button.text = caption
	button.disabled = disabled or not rules.winner.is_empty()
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.pressed.connect(func():
		action.call()
		rules.terrain.update_relations(rules.at_war)
		_refresh())
	row.add_child(button)
func hud_status(message: String) -> void:
	if not message.is_empty(): status_message.emit(message)
func _strategic() -> void:
	var me: = GameSession.player_country
	_label("DOCTRINES", true)
	for country in buildings.economy.stockpiles.keys():
		var id: = Doctrine.of(country)
		_label("%s%s · %s: %s" % [country.capitalize(), " (you)" if country == me else "", Doctrine.DOCTRINES[id].name, Doctrine.DOCTRINES[id].summary])
	_label("STRATEGIC WEAPONS", true)
	_label("Tap a target province or enemy army on the map, then launch. Upgraded air defence (level %d+) within range can shoot missiles down. Strikes hit every army in the blast, including yours. Nuclear fallout cuts nearby output to %d%% for 3 days." % [StrategicWeapons.ABM_LEVEL, roundi(StrategicWeapons.FALLOUT_OUTPUT * 100)])
	var day: = 1 + int(rules.clock.elapsed / VictoryRules.DAY) if rules.clock != null else 1
	for kind in StrategicWeapons.WEAPONS:
		var weapon: Dictionary = StrategicWeapons.WEAPONS[kind]
		var cost: = []
		for resource in weapon.cost:
			if weapon.cost[resource] > 0: cost.append("%s %s" % [_short(weapon.cost[resource]), resource])
		_label("%s · ready: %d · cost %s · builds in %.1f days" % [weapon.name, rules.strategic.count(me, kind), ", ".join(cost), weapon.build / VictoryRules.DAY])
		var row: = HBoxContainer.new()
		var build: = Button.new()
		var why: = rules.strategic.reason(me, kind, day, buildings.economy.stockpiles[me])
		build.text = "Build" if why.is_empty() else why
		build.disabled = not why.is_empty() or not rules.winner.is_empty()
		build.custom_minimum_size.y = 48
		build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		build.pressed.connect(func():
			rules.strategic.build(me, kind, day, buildings.economy.stockpiles[me])
			_refresh())
		var fire: = Button.new()
		fire.text = "Launch at target"
		fire.disabled = rules.strategic.count(me, kind) <= 0 or not rules.at_war or not rules.winner.is_empty()
		fire.custom_minimum_size.y = 48
		fire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fire.pressed.connect(func():
			hide()
			strategic_launch_requested.emit(kind))
		row.add_child(build)
		row.add_child(fire)
		content.add_child(row)
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

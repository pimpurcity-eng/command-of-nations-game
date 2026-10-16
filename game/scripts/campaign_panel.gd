class_name CampaignPanel
extends CanvasLayer
## Victory, newspaper, battle reports, diplomacy and arsenal pages.
## Owner 2026-10-16: "Build the reports bigger, like the battle reports. I can barely see them" -
## full-screen phone layout, 28-34 px type, cards with flags and generous spacing.
## Owner 2026-10-16: "Make the newspaper better. Anyone can post, make it more accessible" - a
## masthead, one section per day, the AI's official statements and articles any country writes.
## Owner 2026-10-16: "Diplomacy, that's where your messages should be, and your game alliance, not
## your total game alliance, just for the map, and you show the leaders what country's leading" -
## the Diplomacy page opens with this match's leaderboard, then the match coalition, messages and
## relations. Account-wide alliances stay in the commander profile.
var panel: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var title: Label
var tab_row: HBoxContainer
var rules: MatchSystem
var buildings: BuildingSystem
var tab: = "victory"
var writing: = false
var draft: = ""
var chat_draft: = ""
var chat_target: = 0
signal strategic_launch_requested(kind: String)
signal status_message(text: String)

const BODY: = 28
const SMALL: = 24
const HEAD: = 34
const PAPER: = Color("f1ece0")
const PAPER_INK: = Color("26231d")
const PAPER_MUTED: = Color("6b6455")
const TABS: = [["Victory", "victory"], ["News", "news"], ["Battles", "battles"], ["Diplomacy", "diplomacy"], ["Arsenal", "strategic"]]
const TITLES: = {"victory": "Victory progress", "news": "War newspaper", "battles": "Battle reports", "diplomacy": "Diplomacy", "strategic": "Arsenal"}

func setup(match_rules: MatchSystem, infrastructure: BuildingSystem, theme: Theme) -> void :
	rules = match_rules
	buildings = infrastructure
	layer = 14
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", CowUI.skin("panel_dark", 8))
	root.add_child(panel)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	panel.add_child(column)
	var head: = CowUI.header("", false)
	title = head.title
	title.add_theme_font_size_override("font_size", 34)
	head.close.custom_minimum_size = Vector2(64, 64)
	head.close.pressed.connect(hide)
	column.add_child(head.bar)
	tab_row = HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 0)
	column.add_child(tab_row)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var margin: = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 14)
	scroll.add_child(margin)
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)
	get_viewport().size_changed.connect(_layout)
	rules.report.connect( func(_message: String):
		if visible and not writing: _refresh())
	rules.diplomacy.changed.connect(func():
		if visible and not writing and tab in ["news", "diplomacy"]: _refresh())
	hide()

func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	var width: = minf(760.0, size.x)
	panel.position = Vector2((size.x - width) * 0.5, 0)
	panel.size = Vector2(width, size.y)

func _build_tabs() -> void:
	for child in tab_row.get_children(): tab_row.remove_child(child); child.queue_free()
	for entry in TABS:
		var selected: bool = entry[1] == tab
		var button: = Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(0, 76)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 24)
		button.add_theme_font_override("font", CowUI.title_font())
		button.add_theme_color_override("font_color", CowUI.GOLD if selected else Color("d9d3c0"))
		button.add_theme_color_override("font_hover_color", CowUI.GOLD)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, CowUI.skin("tab_on" if selected else "tab_off", 6, 0))
		button.pressed.connect(func():
			tab = entry[1]
			writing = false
			_refresh()
			scroll.scroll_vertical = 0)
		tab_row.add_child(button)

# --- Building blocks -------------------------------------------------------------------------

func _text(text: String, size: int = BODY, color: Color = Color("ece6d6"), parent: Control = null) -> Label:
	var label: = CowUI.label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 40
	if size < 18: label.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 400))
	(parent if parent != null else content).add_child(label)
	return label

## Kept for callers and tests: a body line, or a gold heading.
func _label(text: String, heading: bool = false) -> void :
	if heading: _heading(text)
	else: _text(text)

func _heading(text: String, parent: Control = null) -> void:
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	(parent if parent != null else content).add_child(box)
	var label: = _text(text.to_upper(), HEAD, CowUI.GOLD, box)
	label.add_theme_font_override("font", StrategyTheme.font("Oswald", 500))
	var rule: = ColorRect.new()
	rule.color = Color(CowUI.GOLD, 0.45)
	rule.custom_minimum_size.y = 2
	box.add_child(rule)

## A card: light paper (`paper`) or dark inset. Returns the column to fill.
func _card(paper: bool = true, border: Color = Color(0, 0, 0, 0), parent: Control = null) -> VBoxContainer:
	var card: = PanelContainer.new()
	var style: = CowUI.box(PAPER if paper else Color("263239"), 12, border if border.a > 0 else (Color("c4bda8") if paper else Color("3a464a")), 3 if border.a > 0 else 1, 18)
	card.add_theme_stylebox_override("panel", style)
	(parent if parent != null else content).add_child(card)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	card.add_child(column)
	return column

func _button(caption: String, action: Callable, disabled: bool = false, color: Color = CowUI.GREEN) -> Button:
	var button: = Button.new()
	button.text = caption
	button.disabled = disabled or not rules.winner.is_empty()
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", CowUI.title_font())
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("d8d4c8"))
	var face: = "btn_red" if color == CowUI.RED else ("btn_dark" if color == CowUI.DARK else "btn_green")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, CowUI.skin("btn_grey" if state == "disabled" else face, 12, 8, Color(1.12, 1.12, 1.12) if state == "hover" else Color.WHITE))
	button.pressed.connect(action)
	return button

## Older pages add buttons through this: the action runs, relations update, the page redraws.
func _action(row: Container, caption: String, action: Callable, disabled: bool = false) -> void:
	row.add_child(_button(caption, func():
		action.call()
		rules.terrain.update_relations(rules.at_war)
		_refresh(), disabled))

func _line_edit(placeholder: String, text: String, length: int) -> LineEdit:
	var edit: = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = text
	edit.max_length = length
	edit.custom_minimum_size.y = 72
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", BODY)
	return edit

func _flag(country: String, minimum: Vector2 = Vector2(54, 38)) -> Control:
	var flag: = Flag.new()
	flag.country = country
	flag.custom_minimum_size = minimum
	flag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return flag

## Flag, country name and an optional "(you)".
func _country_row(country: String, size: int, color: Color, parent: Control) -> HBoxContainer:
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	row.add_child(_flag(country))
	var name: = _text(country.capitalize() + ("  (you)" if country == GameSession.player_country else ""), size, color, row)
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return row

func _day_of(time: float) -> int:
	return 1 + int(time / VictoryRules.DAY)

func _clock_of(time: float) -> String:
	var hours: = fposmod(time, VictoryRules.DAY) / VictoryRules.DAY * 24.0
	return "%02d:%02d" % [int(hours), int(fmod(hours, 1.0) * 60.0)]

func _today() -> int:
	return _day_of(rules.clock.elapsed) if rules.clock != null else 1

# --- Pages -----------------------------------------------------------------------------------

func _refresh() -> void :
	_build_tabs()
	title.text = TITLES.get(tab, "Campaign")
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	match tab:
		"news": _newspaper()
		"battles": _battles()
		"strategic": _strategic()
		"victory": _victory()
		_: _diplomacy()

## The newspaper: masthead, write button, then one section per day (newest first) with the
## day's issue, the official statement and readers' articles.
func _newspaper() -> void:
	var masthead: = _card(true, Color("8a7a52"))
	var name: = _text("THE FRONTLINE GAZETTE", 44, PAPER_INK, masthead)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.add_theme_font_override("font", StrategyTheme.font("Oswald", 600))
	var date: = _text("DAY %d  ·  DAILY WAR EDITION  ·  OPEN TO EVERY NATION" % _today(), 20, PAPER_MUTED, masthead)
	date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule: = ColorRect.new()
	rule.color = PAPER_INK
	rule.custom_minimum_size.y = 3
	masthead.add_child(rule)
	var talks: Diplomacy = rules.diplomacy
	if writing:
		var editor: = _card(false, CowUI.GOLD)
		_text("Write an article", HEAD, CowUI.GOLD, editor)
		_text("Signed by %s · Day %d. Every country in this match can read it." % [GameSession.player_country.capitalize(), _today()], SMALL, Color("c9c3ae"), editor)
		var box: = TextEdit.new()
		box.text = draft
		box.placeholder_text = "Headline and story…"
		box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		box.custom_minimum_size.y = 240
		box.add_theme_font_size_override("font_size", BODY)
		box.text_changed.connect(func(): draft = box.text.left(Diplomacy.ARTICLE_LENGTH))
		editor.add_child(box)
		var buttons: = HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 12)
		editor.add_child(buttons)
		buttons.add_child(_button("Cancel", func():
			writing = false
			_refresh(), false, CowUI.DARK))
		buttons.add_child(_button("Publish", func():
			if draft.strip_edges().length() < 3:
				hud_status("Write a few words first")
				return
			talks.post_article(GameSession.player_country, draft)
			draft = ""
			writing = false
			hud_status("Article published in the newspaper")
			_refresh()))
		box.grab_focus.call_deferred()
	else:
		content.add_child(_button("WRITE ARTICLE", func():
			writing = true
			_refresh()))
	var articles: = talks.articles()
	var issues: Dictionary = {}
	for issue in rules.chronicle.issues: issues[int(issue.day)] = issue
	var printed: = false
	for day in range(_today(), 0, -1):
		var todays: = articles.filter(func(m: Dictionary): return _day_of(m.time) == day)
		if not issues.has(day) and todays.is_empty(): continue
		printed = true
		_heading("Day %d" % day + ("  ·  today" if day == _today() else ""))
		if issues.has(day): _issue(issues[day])
		if not todays.is_empty():
			_text("READERS' COLUMNS", SMALL, Color("c9c3ae"))
			for i in range(todays.size() - 1, -1, -1): _article(todays[i])
	if not printed:
		var empty: = _card()
		_text("The first issue is printed at the end of day 1. Write the first article yourself!", BODY, PAPER_INK, empty)

func _issue(issue: Dictionary) -> void:
	var page: = _card()
	var head: = _text(str(issue.headline).replace("Day %d: " % int(issue.day), ""), 36, PAPER_INK, page)
	head.add_theme_font_override("font", StrategyTheme.font("Oswald", 600))
	for line in issue.lines:
		var text: = str(line)
		if text.begins_with("• "): text = text.substr(2)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		page.add_child(row)
		var bullet: = ColorRect.new()
		bullet.color = Color("8a7a52")
		bullet.custom_minimum_size = Vector2(8, 8)
		bullet.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var holder: = MarginContainer.new()
		holder.add_theme_constant_override("margin_top", 14)
		holder.add_child(bullet)
		row.add_child(holder)
		_text(text, 26, PAPER_INK, row)
	if issue.has("statement"):
		var quote: = _card(true, Color("b5413a"), page)
		_country_row(str(issue.statement.country), SMALL, Color("8b2f28"), quote)
		_text("OFFICIAL STATEMENT", 18, Color("8b2f28"), quote)
		_text("“" + str(issue.statement.text) + "”", BODY, PAPER_INK, quote)

func _article(m: Dictionary) -> void:
	var card: = _card(true, CowUI.GOLD if m.from == GameSession.player_country else Color(0, 0, 0, 0))
	var by: = _country_row(str(m.from), SMALL, PAPER_MUTED, card)
	var when: = _text("Day %d · %s" % [_day_of(m.time), _clock_of(m.time)], 20, PAPER_MUTED, by)
	when.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	when.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text(str(m.text), BODY, PAPER_INK, card)

## Battle reports: one card per battle, newest first, with each side's shots and losses.
func _battles() -> void:
	var battles: Array = rules.chronicle.battles
	_text("%d battles recorded · newest first" % battles.size(), SMALL, Color("c9c3ae"))
	if battles.is_empty():
		var empty: = _card()
		_text("No battles yet. Every fight in one place within a game hour becomes a report here.", BODY, PAPER_INK, empty)
	for i in range(battles.size() - 1, -1, -1):
		var b: Dictionary = battles[i]
		var card: = _card()
		var head: = _text("Battle of " + str(b.province), HEAD, PAPER_INK, card)
		head.add_theme_font_override("font", StrategyTheme.font("Oswald", 600))
		var minutes: = int((float(b.end) - float(b.start)) / VictoryRules.DAY * 24.0 * 60.0)
		_text("Day %d · %s · %s of fighting" % [int(b.day), _clock_of(float(b.start)), ("%dh %02dm" % [minutes / 60, minutes % 60]) if minutes >= 60 else "%d min" % maxi(minutes, 1)], SMALL, PAPER_MUTED, card)
		var sides: = {}
		for c in b.shots: sides[c] = true
		for c in b.lost: sides[c] = true
		var least: = 1 << 30
		for c in sides: least = mini(least, b.lost.get(c, []).size())
		var best: Array = sides.keys().filter(func(c): return b.lost.get(c, []).size() == least)
		var fewest: String = str(best[0]) if not best.is_empty() else ""
		var tied: = best.size() > 1
		for c in sides:
			var lost: Array = b.lost.get(c, [])
			var side: = _card(false, Color(0, 0, 0, 0), card)
			var row: = _country_row(str(c), BODY, Color("f3e6c4"), side)
			var tally: = _text("%d shots · %d lost" % [int(b.shots.get(c, 0)), lost.size()], SMALL, Color("ff8a78") if not lost.is_empty() else Color("9fd18f"), row)
			tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tally.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			if not lost.is_empty():
				var names: = {}
				for unit in lost: names[unit] = int(names.get(unit, 0)) + 1
				var parts: = []
				for unit in names: parts.append(("%d× %s" % [names[unit], unit]) if names[unit] > 1 else str(unit))
				_text("Lost: " + ", ".join(parts), SMALL, Color("e6c3b8"), side)
		if sides.size() > 1:
			_text(("Outcome: undecided, equal losses" if tied else "Outcome: %s lost the fewest units" % fewest.capitalize()), SMALL, Color("4b6a4e") if not tied else PAPER_MUTED, card)

func _victory() -> void:
	if not rules.winner.is_empty(): _heading(MatchSystem.VICTORY_NAMES.get(rules.victory_type, "VICTORY") + " · " + rules.winner.capitalize() + " has won this campaign.")
	var ways: = _card()
	_text("Four ways to win", HEAD, PAPER_INK, ways)
	_text("• DOMINATION: capture %d%% of all victory points outside your homeland and hold them for %s (province 1, city %d, capital %d points).\n• ECONOMIC: grow productive income to %d%% of your starting economy, keep %s funds and hold your capital, without a break for %d days.\n• ELIMINATION: destroy every enemy army and production and take its capital.\n• POINTS: after day %d the most victory points wins." % [roundi(VictoryRules.DOMINATION_SHARE * 100), SimulationClock.duration(VictoryRules.DOMINATION_HOLD), VictoryRules.CITY_POINTS, VictoryRules.CAPITAL_POINTS, roundi(VictoryRules.ECONOMIC_GROWTH * 100), _short(VictoryRules.ECONOMIC_FUNDS), int(VictoryRules.ECONOMIC_DAYS), int(VictoryRules.TIME_LIMIT_DAYS)], SMALL, PAPER_INK, ways)
	var countries: Array = buildings.economy.stockpiles.keys()
	var table: = VictoryRules.standings(rules.terrain.territories, rules.cities, countries)
	for country in countries:
		var row: Dictionary = table[country]
		var card: = _card(false)
		var name: = _country_row(country, HEAD, Color("f3e6c4"), card)
		var points: = _text("%d pts" % row.points, HEAD, CowUI.GOLD, name)
		points.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_bar("Domination %d / %d foreign points" % [row.foreign_held, ceili(row.foreign_total * VictoryRules.DOMINATION_SHARE)], row.domination / VictoryRules.DOMINATION_SHARE, card)
		# Owner 2026-10-16: a domination win is announced while it counts down.
		var countdown: float = rules.victory.domination_countdown(country)
		if countdown >= 0.0: _text("Wins by domination in %s unless the share drops below %d%%." % [SimulationClock.duration(countdown), roundi(VictoryRules.DOMINATION_SHARE * 100)], SMALL, CowUI.GOLD, card)
		var economic: = rules.victory.economic_conditions(rules, country)
		var held: float = rules.victory.economic_held.get(country, 0.0) / VictoryRules.DAY
		_bar("Economy · income %.1f / %.1f · funds %s / %s · capital %s · %.1f / %d days" % [rules.victory.income_rate.get(country, 0.0), rules.victory.economic_target(country), _short(buildings.economy.stockpiles[country].get("funds", 0.0)), _short(VictoryRules.ECONOMIC_FUNDS), "held" if economic[2] else "LOST", held, int(VictoryRules.ECONOMIC_DAYS)], held / VictoryRules.ECONOMIC_DAYS, card)
	var days_left: = VictoryRules.TIME_LIMIT_DAYS - rules.clock.elapsed / VictoryRules.DAY if rules.clock != null else VictoryRules.TIME_LIMIT_DAYS
	_text("Points decision in %.1f days (%s at this speed)." % [maxf(days_left, 0.0), SimulationClock.duration(maxf(days_left, 0.0) * VictoryRules.DAY)], BODY, CowUI.GOLD)
	var cities: = _card()
	_text("Your cities", HEAD, PAPER_INK, cities)
	for city in buildings.economy.cities:
		if not buildings.economy.controlled(city,GameSession.player_country): continue
		var controller: = buildings.economy.controller(city)
		_text(city.name + " · " + ("YOURS" if controller == GameSession.player_country else controller.capitalize()) + (" · captured" if controller != city.country.to_lower() else " · core city"), SMALL, PAPER_INK, cities)

## Diplomacy: leaderboard, match coalition, messages, then relations with each country.
func _diplomacy() -> void:
	var me: = GameSession.player_country
	var talks: Diplomacy = rules.diplomacy
	var countries: Array = buildings.economy.stockpiles.keys()
	var table: = VictoryRules.standings(rules.terrain.territories, rules.cities, countries)
	# Leaderboard for this match.
	_heading("Leaderboard · this match")
	var ranked: = countries.duplicate()
	ranked.sort_custom(func(a, b): return table[a].points > table[b].points or (table[a].points == table[b].points and a < b))
	for i in ranked.size():
		var country: String = ranked[i]
		var leading: = i == 0
		var row_card: = _card(not leading, CowUI.GOLD if leading else Color(0, 0, 0, 0))
		if leading: (row_card.get_parent() as PanelContainer).add_theme_stylebox_override("panel", CowUI.box(Color("3d3420"), 12, CowUI.GOLD, 3, 18))
		var ink: = Color("f3e6c4") if leading else PAPER_INK
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_card.add_child(row)
		var rank: = _text("#%d" % (i + 1), HEAD, CowUI.GOLD if leading else PAPER_MUTED, row)
		rank.size_flags_horizontal = Control.SIZE_FILL
		rank.autowrap_mode = TextServer.AUTOWRAP_OFF
		rank.custom_minimum_size.x = 56
		row.add_child(_flag(country))
		var coalition: = talks.coalition_of(country)
		var name: = _text(country.capitalize() + (" (you)" if country == me else "") + (("\n" + coalition) if not coalition.is_empty() else ""), BODY, ink, row)
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var points: = _text("%d pts" % table[country].points, HEAD, CowUI.GOLD if leading else PAPER_INK, row)
		points.size_flags_horizontal = Control.SIZE_FILL
		points.autowrap_mode = TextServer.AUTOWRAP_OFF
		points.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if leading: _text("★ LEADING THE WAR · %d%% of the way to domination" % roundi(100.0 * table[country].domination / VictoryRules.DOMINATION_SHARE), SMALL, CowUI.GOLD, row_card)
	# This match's coalition (not the account alliance).
	_heading("Your coalition · this map only")
	var mine: = talks.coalition_of(me)
	var coalition_card: = _card(false)
	if mine.is_empty():
		_text("You are in no coalition in this match. Members are at peace, share vision and may cross each other's land. Leaving blocks rejoining for %d days." % int(Diplomacy.REJOIN_DAYS), SMALL, Color("d9d3c0"), coalition_card)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		coalition_card.add_child(row)
		var name_box: = _line_edit("Coalition name", "", 24)
		row.add_child(name_box)
		var create: = _button("Create", func():
			hud_status(talks.create_coalition(name_box.text, me))
			_refresh())
		create.size_flags_horizontal = Control.SIZE_FILL
		create.custom_minimum_size.x = 150
		row.add_child(create)
		for name in talks.coalitions:
			var join_row: = HBoxContainer.new()
			coalition_card.add_child(join_row)
			_action(join_row, "Join %s (%d members)" % [name, talks.coalitions[name].members.size()], func(): hud_status(talks.join(name, me)))
	else:
		_text(mine, HEAD, CowUI.GOLD, coalition_card)
		for member in talks.coalitions[mine].members:
			var member_row: = _country_row(str(member), BODY, Color("f3e6c4"), coalition_card)
			if member == talks.coalitions[mine].get("leader", ""):
				var tag: = _text("LEADER", SMALL, CowUI.GOLD, member_row)
				tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var row: = HBoxContainer.new()
		coalition_card.add_child(row)
		_action(row, "Leave coalition", func(): talks.leave(me))
	_text("Alliances outside matches are in your commander profile.", 20, Color("a9a392"), coalition_card)
	# Messages.
	_heading("Messages")
	var compose: = _card(false)
	var targets: = ["all"]
	for other in countries:
		if other != me: targets.append(other)
	if not mine.is_empty(): targets.append("coalition:" + mine)
	var to: = OptionButton.new()
	to.custom_minimum_size.y = 64
	to.add_theme_font_size_override("font_size", 26)
	for target in targets: to.add_item("To: " + ("Everyone" if target == "all" else target.replace("coalition:", "Coalition ").capitalize()))
	to.selected = clampi(chat_target, 0, targets.size() - 1)
	to.item_selected.connect(func(index: int): chat_target = index)
	to.get_popup().add_theme_font_size_override("font_size", 30)
	compose.add_child(to)
	var send: = HBoxContainer.new()
	send.add_theme_constant_override("separation", 10)
	compose.add_child(send)
	var text: = _line_edit("Write a message…", chat_draft, Diplomacy.CHAT_LENGTH)
	text.text_changed.connect(func(value: String): chat_draft = value)
	send.add_child(text)
	var send_message: = func():
		var target: String = targets[to.selected]
		if text.text.strip_edges().is_empty(): return
		talks.post(me, target, text.text)
		chat_draft = ""
		if target in talks.ai_countries and MatchClient.active == null:
			talks.post(target, me, "We will answer on the battlefield." if talks.at_war(me, target) else "Your message has been noted, " + me.capitalize() + ".")
		_refresh()
	text.text_submitted.connect(func(_value: String): send_message.call())
	var send_button: = _button("Send", send_message)
	send_button.size_flags_horizontal = Control.SIZE_FILL
	send_button.custom_minimum_size.x = 130
	send.add_child(send_button)
	var inbox: = talks.inbox(me)
	if inbox.is_empty(): _text("No messages yet.", BODY, Color("c9c3ae"))
	for i in range(inbox.size() - 1, maxi(-1, inbox.size() - 21), -1):
		var m: Dictionary = inbox[i]
		var card: = _card(true, CowUI.GOLD if m.from == me else Color(0, 0, 0, 0))
		var head: = _country_row(str(m.from), SMALL, PAPER_MUTED, card)
		var meta: = _text("→ %s · Day %d %s" % ["everyone" if m.to == "all" else str(m.to).replace("coalition:", "coalition ").capitalize(), _day_of(m.time), _clock_of(m.time)], 20, PAPER_MUTED, head)
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		meta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text(str(m.text), BODY, PAPER_INK, card)
	# Relations.
	_heading("Relations")
	for other in countries:
		if other == me: continue
		var r: = talks.relation(me, other)
		var flags: = []
		if r.right_of_way: flags.append("right of way")
		if r.shared_vision: flags.append("shared vision")
		if r.get("trade", false): flags.append("trade")
		if talks.embargoed(me, other): flags.append("you embargo them")
		if talks.embargoed(other, me): flags.append("they embargo you")
		var card: = _card(false, Color("b5413a") if r.war else Color(0, 0, 0, 0))
		var row: = _country_row(other, HEAD, Color("f3e6c4"), card)
		var state: = _text("AT WAR" if r.war else "AT PEACE", BODY, Color("ff8a78") if r.war else Color("9fd18f"), row)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text(("AI country" if other in talks.ai_countries else "Player") + ((" · " + ", ".join(flags)) if not flags.is_empty() else ""), SMALL, Color("c9c3ae"), card)
		var grid: = GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		card.add_child(grid)
		_action(grid, "Propose peace" if r.war else "Declare war", func():
			if r.war: hud_status(talks.propose(me, other, "peace", table).message)
			else: rules.declare_war())
		_action(grid, "Right of way", func(): hud_status(talks.propose(me, other, "right_of_way", table).message), r.war or r.right_of_way)
		_action(grid, "Shared vision", func(): hud_status(talks.propose(me, other, "shared_vision", table).message), r.war or r.shared_vision)
		_action(grid, "Trade deal", func(): hud_status(talks.propose(me, other, "trade", table).message), r.war or r.get("trade", false))
		_action(grid, "Lift embargo" if talks.embargoed(me, other) else "Embargo", func(): talks.set_embargo(me, other, not talks.embargoed(me, other)))

func hud_status(message: String) -> void:
	if not message.is_empty(): status_message.emit(message)

func _strategic() -> void:
	var me: = GameSession.player_country
	_heading("Doctrines")
	for country in buildings.economy.stockpiles.keys():
		var card: = _card(false)
		_country_row(country, BODY, Color("f3e6c4"), card)
		_text(Doctrine.summary(country), SMALL, Color("d9d3c0"), card)
	_heading("Strategic weapons")
	_text("Tap a target province or enemy army on the map, then launch. Upgraded air defence (level %d+) within range can shoot missiles down. Strikes hit every army in the blast, including yours. Nuclear fallout cuts nearby output to %d%% for 3 days." % [StrategicWeapons.ABM_LEVEL, roundi(StrategicWeapons.FALLOUT_OUTPUT * 100)], SMALL, Color("d9d3c0"))
	var day: = _today()
	for kind in StrategicWeapons.WEAPONS:
		var weapon: Dictionary = StrategicWeapons.WEAPONS[kind]
		var cost: = []
		for resource in weapon.cost:
			if float(weapon.cost.get(resource, 0.0)) > 0: cost.append("%s %s" % [_short(float(weapon.cost.get(resource, 0.0))), resource])
		var card: = _card()
		_text("%s · ready: %d" % [weapon.name, rules.strategic.count(me, kind)], HEAD, PAPER_INK, card)
		_text("Cost %s · builds in %s" % [", ".join(cost), SimulationClock.duration(weapon.build)], SMALL, PAPER_MUTED, card)
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		card.add_child(row)
		var why: = rules.strategic.reason(me, kind, day, buildings.economy.stockpiles[me])
		row.add_child(_button("Build" if why.is_empty() else why, func():
			rules.strategic.build(me, kind, day, buildings.economy.stockpiles[me])
			_refresh(), not why.is_empty()))
		row.add_child(_button("Launch at target", func():
			hide()
			strategic_launch_requested.emit(kind), rules.strategic.count(me, kind) <= 0 or not rules.at_war, CowUI.RED))

func _bar(caption: String, fraction: float, parent: Control = null) -> void:
	_text(caption, SMALL, Color("d9d3c0"), parent)
	var bar: = ProgressBar.new()
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(fraction, 0.0, 1.0)
	bar.custom_minimum_size.y = 18
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", CowUI.box(Color("3a3f42"), 4))
	bar.add_theme_stylebox_override("fill", CowUI.box(Color("b8863b"), 4))
	(parent if parent != null else content).add_child(bar)

static func _short(amount: float) -> String:
	return ("%.0fk" % (amount / 1000.0)) if amount >= 10000 else str(roundi(amount))

func open(page: String = "victory") -> void :
	tab = page
	writing = false
	_layout()
	_refresh()
	show()
	scroll.scroll_vertical = 0

## Small national flag: known flags drawn in their colours, others in stripes from the name.
class Flag extends Control:
	const COLOURS: = {"russia": ["ffffff", "1f4fb3", "d0312d"], "ukraine": ["1f5fbf", "f6c700"], "belarus": ["c8313e", "c8313e", "4aa657"], "poland": ["ffffff", "dc143c"], "germany": ["000000", "dd0000", "ffce00"], "france": ["0055a4", "ffffff", "ef4135"], "usa": ["b22234", "ffffff", "3c3b6e"], "china": ["de2910", "de2910"], "uk": ["012169", "ffffff", "c8102e"]}
	var country: = ""
	func _init() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var rect: = Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var colours: Array = COLOURS.get(country, [])
		if colours.is_empty():
			var hue: = float(hash(country) % 360) / 360.0
			colours = [Color.from_hsv(hue, 0.6, 0.75).to_html(), "ffffff", Color.from_hsv(fmod(hue + 0.5, 1.0), 0.6, 0.6).to_html()]
		var vertical: = country in ["france"]
		for i in colours.size():
			var band: = Rect2(rect.position + Vector2(rect.size.x * i / colours.size(), 0), Vector2(rect.size.x / colours.size(), rect.size.y)) if vertical else Rect2(rect.position + Vector2(0, rect.size.y * i / colours.size()), Vector2(rect.size.x, rect.size.y / colours.size()))
			draw_rect(band, Color(colours[i]))
		draw_rect(rect, Color(0, 0, 0, 0.65), false, 2.0)

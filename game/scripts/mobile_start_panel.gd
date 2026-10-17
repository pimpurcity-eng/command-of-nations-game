class_name MobileStartPanel
extends CanvasLayer
## Shared command centre for the native app and browser game.
signal continue_requested
signal fresh_requested
signal test_requested(scenario: String)
signal online_requested
signal account_requested
signal training_requested(resume: bool)
## Carry on with the match that was paused when the player went back to the home screen.
signal resume_requested
const GOLD := Color("e2b866")
const INK := Color("f4f1e8")
const MUTED := Color("a9b8c2")
const NAVY := Color("0c1720")
var online_button: Button
var language_picker: OptionButton
var country_picker: OptionButton
var panel: PanelContainer
var continue_button: Button
var content: VBoxContainer
var artwork: TextureRect
var fresh_button: Button
var test_button: Button
var range_picker: GridContainer
var progress: ProgressBar
var loading_label: Label
var branding: VBoxContainer
var heading: Label
var footer: Label
var audio: GameAudio
var music_button: Button
var sound_button: Button
var loading := false
var has_save := false
var country_cards: Dictionary = {}
var credit_label: Label
var screen: Control
var scroll: ScrollContainer
var hero: Control
var masthead: PanelContainer
var navigation: PanelContainer
var pages: Dictionary = {}
var nav_buttons: Dictionary = {}
var current_page := "home"
var commander_label: Label
var profile_button: Button
var catalogue: Dictionary = {}
var training_buttons: Array[Button] = []
var nation_summary: Label
var status_bar: PanelContainer
var active_heading: Label
var my_games_heading: Label
var new_games_heading: Label
var join_button: Button
var resume_button: Button
var show_all_button: Button
## The game RESUME GAME carries on with: the paused one, otherwise the most recently saved.
var featured_kind := ""
var side_overlay: Control
var side_panel: PanelContainer
var side_title: Label
## The game waiting for a side: "training" (1 player) or "online" (2 players).
var pending_side := ""
var _last_facts: Label
## Owner 2026-10-17: "they have to play that game first" — the other games open once the
## 1-player Russia vs Ukraine guided opening is finished (Tutorial.done()).
var unlock_note: Label
var locked_games: Array = []
var coming_soon_buttons: Array = []
var europe_button: Button
var game_rows: Array = []
var empty_labels: Array[Label] = []
## Which game is loaded and paused behind the home screen: "", "training", "campaign" or "online".
var paused_kind := ""

static func _font(weight: int, spacing: int = 0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Oswald.ttf")
	f.variation_embolden = clampf((weight - 400) / 300.0, 0, 1) * 0.9
	f.spacing_glyph = spacing
	return f
func selected_country() -> String:
	if country_picker.selected < 0: return GameSession.player_country
	return str(country_picker.get_item_metadata(country_picker.selected))
func selected_doctrine() -> String:
	return Doctrine.of(selected_country())
func _label(text: String, pixels: int, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
func _surface(color: Color, border: Color = Color("2b3b45"), margin: int = 24) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(margin)
	return s
func _button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_font_override("font", _font(600, 1))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var color := GOLD if primary else Color("1c2c37")
		if state == "hover": color = color.lightened(0.1)
		if state == "pressed": color = color.darkened(0.15)
		if state == "disabled": color = Color("18232b")
		button.add_theme_stylebox_override(state, _surface(color, GOLD if primary else Color("344754"), 12))
	button.add_theme_stylebox_override("focus", _surface(Color.TRANSPARENT, INK, 12))
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("171b1b") if primary else INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	return button
func _chip(text: String) -> Button:
	var button := _button(text)
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 17)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button
func _box(parent: Node, spacing: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box
func _card(parent: Node) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _surface(Color("14232d")))
	parent.add_child(card)
	return card
func _section(parent: Node, text: String) -> void:
	var title := _label(text, 24, INK)
	title.add_theme_font_override("font", _font(600, 2))
	parent.add_child(title)

func setup(theme: Theme, saved: bool) -> void:
	has_save = saved if MapDefinition.is_regional() else FileAccess.file_exists(MapDefinition.save_path())
	layer = 15
	catalogue = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_features.json"))
	screen = Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = theme
	add_child(screen)
	var background := ColorRect.new()
	background.color = NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(background)
	masthead = PanelContainer.new()
	masthead.add_theme_stylebox_override("panel", _surface(NAVY, Color("2b3b45"), 20))
	screen.add_child(masthead)
	var mast := HBoxContainer.new()
	mast.add_theme_constant_override("separation", 16)
	masthead.add_child(mast)
	# Owner 2026-10-17: new "Shield & Globe" logo replaces the W / M text mark.
	var mark := TextureRect.new()
	mark.texture = load("res://assets/interface/logo_shield_globe.svg")
	mark.custom_minimum_size = Vector2(68, 68)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mast.add_child(mark)
	var name_label := _label("WARFRONT MANDATE", 23)
	name_label.add_theme_font_override("font", _font(600, 2))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mast.add_child(name_label)
	profile_button = _chip("ACCOUNT")
	profile_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	profile_button.pressed.connect(func():
		if not loading: account_requested.emit())
	mast.add_child(profile_button)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	screen.add_child(scroll)
	content = _box(scroll, 0)
	_build_home()
	_build_games()
	_build_features()
	_build_updates()
	_build_settings()
	_build_side_choice()
	refresh_active_games()
	# Loading and connection messages stay in view whichever tab started them.
	status_bar = PanelContainer.new()
	status_bar.add_theme_stylebox_override("panel", _surface(Color("101e27"), Color("2b3b45"), 10))
	status_bar.visible = false
	screen.add_child(status_bar)
	var status_box := _box(status_bar, 6)
	loading_label = _label("Ready to command", 18, MUTED)
	status_box.add_child(loading_label)
	progress = ProgressBar.new()
	progress.value = 100
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	progress.add_theme_stylebox_override("background", _surface(Color("243743"), Color.TRANSPARENT, 0))
	progress.add_theme_stylebox_override("fill", _surface(GOLD, Color.TRANSPARENT, 0))
	status_box.add_child(progress)
	navigation = PanelContainer.new()
	navigation.add_theme_stylebox_override("panel", _surface(NAVY, Color("2b3b45"), 12))
	screen.add_child(navigation)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	navigation.add_child(nav)
	for item in [["home", "HOME", "city"], ["games", "GAMES", "attack"], ["updates", "NEWS", "more"], ["features", "FEATURES", "research"], ["settings", "SETTINGS", "chevrons"]]:
		var button := _chip(item[1])
		button.icon = load("res://assets/interface/icons/" + item[2] + ".svg")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_select_page.bind(item[0]))
		nav.add_child(button)
		nav_buttons[item[0]] = button
	_select_page("home")
	get_viewport().size_changed.connect(_layout)
	_layout()
	_layout.call_deferred()
	visibility_changed.connect(func():
		if visible:
			refresh_active_games()
			_layout.call_deferred()
		else: paused_kind = "")
func _page(id: String, padded: bool = true) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32 if padded else 0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(margin)
	pages[id] = margin
	return _box(margin, 22)
## Owner 2026-10-17: Call of War-style home — several games at once ("like as a person"), each
## resumed from YOUR ACTIVE GAMES; the Games list holds the 1-player and 2-player Russia–Ukraine
## tutorials (which replace the old Russia–Ukraine start) and "Europe map coming soon"; news on home.
func _build_home() -> void:
	var home := _page("home", false)
	home.add_theme_constant_override("separation", 0)
	hero = Control.new()
	hero.custom_minimum_size.y = 300
	home.add_child(hero)
	artwork = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.texture = load("res://assets/interface/campaign_hero_landscape.webp")
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero.add_child(artwork)
	var shade := TextureRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.65, 1])
	gradient.colors = PackedColorArray([Color(0.03, 0.08, 0.12, 0.36), Color(0.03, 0.08, 0.12, 0.4), NAVY])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	shade.texture = texture
	hero.add_child(shade)
	branding = _box(hero, 12)
	branding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kicker := _label("MODERN STRATEGY  /  WW3", 16, GOLD)
	kicker.add_theme_font_override("font", _font(500, 3))
	branding.add_child(kicker)
	heading = _label("WARFRONT\nMANDATE", 72)
	heading.add_theme_font_override("font", _font(700, 2))
	heading.add_theme_constant_override("line_spacing", -14)
	heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	heading.add_theme_constant_override("shadow_offset_y", 3)
	branding.add_child(heading)
	branding.add_child(_label(str(catalogue.tagline), 23))
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 32)
	home.add_child(margin)
	var body := _box(margin, 22)
	var greeting := HBoxContainer.new()
	body.add_child(greeting)
	commander_label = _label("WELCOME, COMMANDER", 24)
	commander_label.add_theme_font_override("font", _font(600, 1))
	commander_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	greeting.add_child(commander_label)
	var status := _label("EARLY ACCESS", 15, GOLD)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	greeting.add_child(status)
	# Owner 2026-10-17: "a join new game button or a resume game" — the two big actions come first.
	var quick := HBoxContainer.new()
	quick.add_theme_constant_override("separation", 14)
	body.add_child(quick)
	resume_button = _big_action("▶  RESUME GAME", "", true)
	resume_button.pressed.connect(func(): _resume_game(featured_kind))
	join_button = _big_action("+  JOIN NEW GAME", "Russia vs Ukraine · Europe soon", false)
	join_button.pressed.connect(_open_games.bind(true))
	quick.add_child(resume_button)
	quick.add_child(join_button)
	# YOUR ACTIVE GAMES: one row per game in progress, each with its own Resume.
	active_heading = _label("YOUR ACTIVE GAMES", 24)
	active_heading.add_theme_font_override("font", _font(600, 2))
	body.add_child(active_heading)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	body.add_child(panel)
	var rows := _box(panel, 12)
	for kind in GAME_KINDS:
		var button := _game_row(rows, kind)
		if kind == "campaign": continue_button = button
	_empty_games(rows, "No games in progress yet. Tap JOIN NEW GAME to start Russia vs Ukraine.")
	show_all_button = _button("SHOW ALL GAMES  →")
	show_all_button.pressed.connect(_open_games.bind(false))
	body.add_child(show_all_button)
	# News sits on home; the full list is on the News tab.
	_section(body, "NEWS")
	for i in mini(2, catalogue.updates.size()): _update_card(body, catalogue.updates[i])
	var all_news := _button("ALL NEWS  →")
	all_news.pressed.connect(_select_page.bind("updates"))
	body.add_child(all_news)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 12)
	body.add_child(toggles)
	if audio != null:
		music_button = _chip("MUSIC: ON")
		sound_button = _chip("SOUND: ON")
		toggles.add_child(music_button)
		toggles.add_child(sound_button)
		music_button.pressed.connect(func(): audio.set_music(not GameAudio.music_enabled))
		sound_button.pressed.connect(func(): audio.set_sound(not GameAudio.sound_enabled))
		audio.settings_changed.connect(_show_audio)
		_show_audio()
	_section(body, "MORE THAN CONQUEST")
	for id in ["guard", "economy", "trade"]:
		_feature_card(body, catalogue.features.filter(func(f: Dictionary): return f.id == id)[0])
	var all_features := _button("EXPLORE ALL FEATURES  →")
	all_features.pressed.connect(_select_page.bind("features"))
	body.add_child(all_features)
	# Owner 2026-10-16: the Premium membership screen is reachable from home.
	var premium := _button("★ PREMIUM MEMBERSHIP  →")
	premium.pressed.connect(func():
		if loading: return
		var account: Variant = get_parent().get("account_panel") if get_parent() != null else null
		PremiumPanel.show_over(self, account.auth if account is AccountPanel else null))
	body.add_child(premium)
	if GameAudio.custom_menu_theme():
		credit_label = _label(GameAudio.MENU_THEME_CREDIT, 16, MUTED)
		credit_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		body.add_child(credit_label)
	# CC BY 3.0 requires the battle music credit to be shown.
	var battle_credit: = _label(GameAudio.MUSIC_CREDITS, 14, MUTED)
	battle_credit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	battle_credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(battle_credit)
	footer = _label("WARFRONTMANDATE.COM", 16, MUTED)
	footer.add_theme_font_override("font", _font(500, 3))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(footer)

## The Games tab: MY GAMES (same rows as home) and NEW GAMES.
func _build_games() -> void:
	var page := _page("games")
	page.add_child(_label("GAMES", 44))
	my_games_heading = _label("MY GAMES", 24)
	my_games_heading.add_theme_font_override("font", _font(600, 2))
	page.add_child(my_games_heading)
	var rows := _box(page, 12)
	for kind in GAME_KINDS: _game_row(rows, kind)
	_empty_games(rows, "No games in progress yet. Start one below.")
	new_games_heading = _label("NEW GAMES", 24)
	new_games_heading.add_theme_font_override("font", _font(600, 2))
	page.add_child(new_games_heading)
	unlock_note = _label("LOCKED · Play Russia vs Ukraine (1 player) first. Finish its guided opening to unlock the other games.", 19, GOLD)
	page.add_child(unlock_note)
	# Call of War-style rows: picture, name, facts and one JOIN button; details underneath.
	# 1 player: the offline training match against the AI.
	fresh_button = _row_button("PLAY  ▶", true)
	fresh_button.pressed.connect(func(): _choose_side("training", "RUSSIA VS UKRAINE · 1 PLAYER"))
	training_buttons.append(fresh_button)
	_new_game_card(page, "map:russia_ukraine", "1", "RUSSIA VS UKRAINE", "1 player · vs AI · offline",
		"Opening film, guided first orders, allied supplies by ship and train — then full command against the AI.", fresh_button)
	# 2 players: the persistent online Russia–Ukraine match, one commander per side.
	online_button = _row_button("JOIN  ▶", true)
	online_button.pressed.connect(func(): _choose_side("online", "RUSSIA VS UKRAINE · 2 PLAYERS"))
	_new_game_card(page, "map:russia_ukraine", "2", "RUSSIA VS UKRAINE", "2 players · online · being built",
		"One commander per side. Needs an account; the AI covers your side while you are away.", online_button)
	# Owner 2026-10-17: "unlock the two-player Russia, being built right now" — open while it is tested.
	# Owner 2026-10-17: two more small-map games are being built.
	var middle_east := _row_button("COMING SOON", false)
	middle_east.disabled = true
	_new_game_card(page, "map:middle_east", "6", "IRAN · U.S. · ISRAEL", "6 players · smaller map · coming soon",
		"A six-nation war in the Middle East on a compact map.", middle_east)
	var china := _row_button("COMING SOON", false)
	china.disabled = true
	_new_game_card(page, "map:china", "$", "CHINA · ECONOMY", "Economy game · coming soon",
		"Build China into the world's leading economy through industry and trade.", china)
	coming_soon_buttons = [middle_east, china]
	# Europe: the 20-nation map is not open yet.
	europe_button = _row_button("COMING SOON", false)
	europe_button.disabled = true
	_new_game_card(page, "map:europe", "20", "EUROPE · 20 NATIONS", "20 players · online · coming soon",
		"Pick one of 20 European countries and fight for the continent. Watch News for the launch.", europe_button)
	# Owner 2026-10-17: the 100-player world map is coming too.
	var world := _row_button("COMING SOON", false)
	world.disabled = true
	_new_game_card(page, "map:world", "100", "WORLD · 100 NATIONS", "100 players · online · coming soon",
		"The whole world: 100 nations on one map, with every continent in play.", world)
	coming_soon_buttons.append(world)
	# Practice maps for each kind of weapon.
	test_button = _row_button("PLAY  ▾", false)
	test_button.pressed.connect(func():
		range_picker.visible = not range_picker.visible
		if range_picker.visible: scroll.ensure_control_visible.call_deferred(range_picker))
	var practice := _new_game_card(page, "attack", "★", "WEAPONS RANGE", "Practice · every unit",
		"Separate test maps per kind of unit.", test_button)
	# Owner 2026-10-14: separate test maps per kind of unit ("too much if they're all in one").
	range_picker = GridContainer.new()
	range_picker.columns = 2
	range_picker.add_theme_constant_override("h_separation", 10)
	range_picker.add_theme_constant_override("v_separation", 10)
	range_picker.visible = false
	practice.add_child(range_picker)
	for scenario in WeaponScenarios.LIST:
		var choice: = _button(str(scenario.title).to_upper())
		choice.add_theme_font_size_override("font_size", 18)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.pressed.connect(func(): range_picker.hide(); request_start("test:" + str(scenario.id)))
		range_picker.add_child(choice)

## Owner 2026-10-17: no side picker on the Games list — tapping Play or Join asks for the side.
func _build_side_choice() -> void:
	side_overlay = Control.new()
	side_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	side_overlay.visible = false
	screen.add_child(side_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed: _cancel_side())
	side_overlay.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_overlay.add_child(centre)
	side_panel = PanelContainer.new()
	side_panel.add_theme_stylebox_override("panel", _surface(Color("14232d"), GOLD, 24))
	centre.add_child(side_panel)
	var sides := _box(side_panel, 16)
	side_title = _label("RUSSIA VS UKRAINE", 30)
	side_title.add_theme_font_override("font", _font(600, 1))
	sides.add_child(side_title)
	sides.add_child(_label("CHOOSE YOUR SIDE", 17, GOLD))
	country_picker = OptionButton.new()
	for country in MapDefinition.players():
		var nation_label: String = country.name+" · "+Doctrine.info(country.id).name+" weapons"
		var flag_path: String = "res://assets/interface/flags/"+country.id+".svg"
		if ResourceLoader.exists(flag_path): country_picker.add_icon_item(load(flag_path),nation_label)
		else: country_picker.add_item(nation_label)
		country_picker.set_item_metadata(country_picker.item_count-1,country.id)
		if country.id == GameSession.player_country: country_picker.select(country_picker.item_count-1)
	country_picker.visible = not MapDefinition.is_regional()
	country_picker.custom_minimum_size.y = 60
	country_picker.add_theme_font_size_override("font_size",20)
	country_picker.add_theme_constant_override("icon_max_width",30)
	country_picker.item_selected.connect(func(_index):_show_nation())
	sides.add_child(country_picker)
	if MapDefinition.is_regional():
		var nations := HBoxContainer.new()
		nations.add_theme_constant_override("separation", 14)
		sides.add_child(nations)
		for spec in [["russia", "RUSSIA", [Color.WHITE, Color("1c3f94"), Color("d52b1e")], "Russian"], ["ukraine", "UKRAINE", [Color("0057b7"), Color("ffd700")], "European"]]:
			nations.add_child(_nation_card(spec[0], spec[1], spec[2], spec[3]))
	else:
		nation_summary = _label("",18,MUTED)
		sides.add_child(nation_summary)
	var cancel := _button("CANCEL")
	cancel.pressed.connect(_cancel_side)
	sides.add_child(cancel)
	_show_nation()

func _choose_side(mode: String, title: String) -> void:
	if loading: return
	# The 1-player training picks its side after the opening film (owner 2026-10-17: "they can
	# choose either Russia or Ukraine after the first video"), so it starts straight away.
	if not MapDefinition.is_regional() or mode == "training":
		request_start(mode)
		return
	pending_side = mode
	side_title.text = title
	side_overlay.show()

func _cancel_side() -> void:
	pending_side = ""
	side_overlay.hide()

func _big_action(title: String, subtitle: String, primary: bool) -> Button:
	var button := _button(title + ("\n" + subtitle if not subtitle.is_empty() else ""), primary)
	button.custom_minimum_size.y = 104
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_constant_override("line_spacing", -2)
	return button

## Owner 2026-10-17: "have a little icon there too" — a map picture with the player count on a
## ribbon, like Call of War. Pictures come from extras/maps/tools/render_game_thumbs.py.
func _map_badge(map_name: String, players: String) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(112, 112)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_bottom = -10
	var style := _surface(Color("0f1b23"), Color("5a6b73"), 0)
	style.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", style)
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(frame)
	var picture := TextureRect.new()
	picture.texture = load("res://assets/interface/game_thumbs/" + map_name + ".png")
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(picture)
	var ribbon := PanelContainer.new()
	var ribbon_style := _surface(Color("17222a"), GOLD, 0)
	ribbon_style.content_margin_left = 8
	ribbon_style.content_margin_right = 8
	ribbon_style.set_corner_radius_all(12)
	ribbon_style.set_border_width_all(2)
	ribbon.add_theme_stylebox_override("panel", ribbon_style)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ribbon.anchor_left = 0.5
	ribbon.anchor_right = 0.5
	ribbon.anchor_top = 1
	ribbon.anchor_bottom = 1
	ribbon.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ribbon.grow_vertical = Control.GROW_DIRECTION_BEGIN
	badge.add_child(ribbon)
	var count := _label("★ " + players + " ★", 18, INK)
	count.add_theme_font_override("font", _font(600, 1))
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(count)
	return badge

func _badge(icon_name: String, tag: String) -> Control:
	if icon_name.begins_with("map:"): return _map_badge(icon_name.substr(4), tag)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(76, 76)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_theme_stylebox_override("panel", _surface(Color("0f1b23"), Color("344754"), 6))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := _box(badge, 2)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	var icon := TextureRect.new()
	icon.texture = load("res://assets/interface/icons/" + icon_name + ".svg")
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stack.add_child(icon)
	var label := _label(tag, 18, GOLD)
	label.add_theme_font_override("font", _font(600, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack.add_child(label)
	return badge

func _row_button(text: String, primary: bool) -> Button:
	var button := _button(text, primary)
	button.custom_minimum_size = Vector2(150, 64)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	return button

func _new_game_card(parent: Node, icon_name: String, tag: String, title: String, facts: String, text: String, button: Button) -> VBoxContainer:
	var card := _card(parent)
	# Playable games carry a gold edge; coming-soon games stay quiet.
	var open := not button.disabled
	var style := _surface(Color("16262f") if open else Color("111c23"), Color(GOLD, 0.5) if open else Color("24323b"))
	if open: style.border_width_left = 6
	card.add_theme_stylebox_override("panel", style)
	var body := _box(card, 12)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	body.add_child(top)
	top.add_child(_badge(icon_name, tag))
	var words := _box(top, 4)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var name_label := _label(title, 24)
	name_label.add_theme_font_override("font", _font(600, 1))
	words.add_child(name_label)
	_last_facts = _label(facts, 17, MUTED if "coming soon" in facts else GOLD)
	words.add_child(_last_facts)
	top.add_child(button)
	body.add_child(_label(text, 18, MUTED))
	return body

const GAME_KINDS := ["training", "online", "campaign"]
const GAME_INFO := {
	"training": ["map:russia_ukraine", "1", "RUSSIA VS UKRAINE"],
	"online": ["map:russia_ukraine", "2", "RUSSIA VS UKRAINE"],
	"campaign": ["map:russia_ukraine", "1", "RUSSIA VS UKRAINE · CLASSIC"],
}
func _game_row(parent: Node, kind: String) -> Button:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _surface(Color("14232d"), Color("2b3b45"), 16))
	parent.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(_badge(GAME_INFO[kind][0], GAME_INFO[kind][1]))
	var words := _box(row, 4)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var title := _label(GAME_INFO[kind][2], 22)
	title.add_theme_font_override("font", _font(600, 1))
	words.add_child(title)
	var meta := _label("", 17, MUTED)
	words.add_child(meta)
	var button := _button("RESUME  ▶", true)
	button.custom_minimum_size.x = 168
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_resume_game.bind(kind))
	row.add_child(button)
	game_rows.append({"kind": kind, "card": card, "meta": meta, "button": button})
	return button

func _empty_games(parent: Node, text: String) -> void:
	var empty := _label(text, 19, MUTED)
	parent.add_child(empty)
	empty_labels.append(empty)

## Which games this player has going: the paused match plus anything saved on the device or joined online.
func active_games() -> Array[String]:
	var list: Array[String] = []
	for kind in GAME_KINDS:
		var live: bool = paused_kind == kind
		match kind:
			"training": live = live or FileAccess.file_exists(TrainingScenario.SAVE_PATH)
			"online": live = live or not online_country().is_empty()
			"campaign": live = live or (MapDefinition.is_regional() and has_save)
		if live: list.append(kind)
	return list

func refresh_active_games() -> void:
	var games := active_games()
	active_heading.text = "YOUR ACTIVE GAMES" + ("  ·  %d" % games.size() if games.size() > 1 else "")
	if my_games_heading != null: my_games_heading.text = "MY GAMES" + ("  ·  %d" % games.size() if not games.is_empty() else "")
	for item in game_rows:
		var kind: String = item.kind
		item.card.visible = kind in games
		var paused := paused_kind == kind
		var meta := ""
		match kind:
			"training": meta = "1 player · against the AI · " + _saved_text(TrainingScenario.SAVE_PATH)
			"online":
				var country := online_country() if not online_country().is_empty() else selected_country()
				meta = "2 players · online · you command " + MapDefinition.country_name(country)
			"campaign": meta = "Offline · against the AI · " + _saved_text("user://regional_save.json")
		item.meta.text = ("PAUSED · " if paused else "") + meta
		item.button.visible = kind in games
		item.button.disabled = loading or not item.button.visible
	for label in empty_labels: label.visible = games.is_empty()
	# RESUME GAME: the paused game first, otherwise the one saved most recently.
	featured_kind = ""
	var newest := -1
	for kind in games:
		var stamp := 1 << 40 if kind == paused_kind else FileAccess.get_modified_time({"training": TrainingScenario.SAVE_PATH, "campaign": "user://regional_save.json"}.get(kind, GameAudio.SETTINGS_PATH))
		if stamp > newest: newest = stamp; featured_kind = kind
	resume_button.visible = not featured_kind.is_empty()
	resume_button.disabled = loading
	if not featured_kind.is_empty(): resume_button.text = "▶  RESUME GAME\n" + {"training": "Russia vs Ukraine · 1P", "online": "Russia vs Ukraine · 2P", "campaign": "Russia vs Ukraine · classic"}[featured_kind]
	join_button.text = "+  JOIN NEW GAME\n" + "Russia vs Ukraine · Europe soon"
	show_all_button.visible = not games.is_empty()
	var unlocked := Tutorial.done()
	if unlock_note != null: unlock_note.visible = not unlocked and not locked_games.is_empty()
	for item in locked_games:
		item.button.text = item.open if unlocked else "LOCKED"
		item.button.disabled = loading or not unlocked
		item.facts.text = item.text
	if fresh_button != null: fresh_button.text = "RESTART" if "training" in games else "PLAY  ▶"

static func _saved_text(path: String) -> String:
	var stamp := FileAccess.get_modified_time(path)
	if stamp == 0: return "saved on this device"
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(stamp + bias * 60)
	var months := ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
	return "saved %d %s · %02d:%02d" % [d.day, months[d.month - 1], d.hour, d.minute]

## Owner 2026-10-17: remember the online match the player joined so it is listed with their other games.
static func remember_online(country: String) -> void:
	if not MapDefinition.is_regional() or country.is_empty(): return
	var file := ConfigFile.new()
	file.load(GameAudio.SETTINGS_PATH)
	file.set_value("online", "joined_regional", country)
	file.save(GameAudio.SETTINGS_PATH)
static func online_country() -> String:
	var file := ConfigFile.new()
	if file.load(GameAudio.SETTINGS_PATH) != OK: return ""
	return str(file.get_value("online", "joined_regional", ""))

func _resume_game(kind: String) -> void:
	if loading: return
	# The Russia–Ukraine games run on the regional map; from another map, go back there first.
	if not MapDefinition.is_regional():
		MapDefinition.launch(get_tree(), MapDefinition.REGIONAL)
		return
	if paused_kind == kind:
		request_start("resume")
		return
	match kind:
		"training": request_start("training_resume")
		"campaign": request_start("continue")
		"online":
			_choose_country(online_country())
			request_start("online")

func _choose_country(id: String) -> void:
	for i in country_picker.item_count:
		if country_picker.get_item_metadata(i) == id: country_picker.select(i)
	_show_nation()

func _open_games(focus_new: bool) -> void:
	_select_page("games")
	if not focus_new or current_page != "games": return
	await get_tree().process_frame
	await get_tree().process_frame
	scroll.ensure_control_visible(new_games_heading)
func _nation_card(id: String, title: String, stripes: Array, doctrine: String) -> Button:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 194
	card.toggle_mode = true
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)
	# Owner 2026-10-15 ("Ukraine words spilling over"): the card grows with its text.
	margin.minimum_size_changed.connect(func(): card.custom_minimum_size.y = maxf(194.0, margin.get_combined_minimum_size().y))
	var body := _box(margin, 7)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flag := VBoxContainer.new()
	flag.custom_minimum_size = Vector2(44, 28)
	flag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	flag.add_theme_constant_override("separation", 0)
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for color in stripes:
		var band := ColorRect.new()
		band.color = color
		band.size_flags_vertical = Control.SIZE_EXPAND_FILL
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag.add_child(band)
	body.add_child(flag)
	var title_label := _label(title, 24)
	title_label.add_theme_font_override("font", _font(600, 1))
	body.add_child(title_label)
	body.add_child(_label(doctrine + " doctrine", 17, MUTED))
	var traits: Dictionary = CountryTraits.of(id)
	body.add_child(_label("+ " + str(traits.plus) + "\n− " + str(traits.minus), 16, MUTED))
	card.pressed.connect(func():
		if loading: return
		for i in country_picker.item_count:
			if country_picker.get_item_metadata(i) == id: country_picker.select(i)
		_show_nation()
		if not pending_side.is_empty():
			var mode := pending_side
			_cancel_side()
			request_start(mode))
	country_cards[id] = card
	return card
func _show_nation() -> void:
	if nation_summary != null: nation_summary.text = Doctrine.summary(selected_country())+"\n20 selectable nations · 7 cities each · other nations controlled by AI"
	for id in country_cards:
		var chosen: bool = selected_country() == id
		var card: Button = country_cards[id]
		card.button_pressed = chosen
		for state in ["normal", "hover", "pressed", "disabled"]:
			card.add_theme_stylebox_override(state, _surface(Color("2a322c") if chosen else Color("182832"), GOLD if chosen else Color("344754"), 0))
		card.add_theme_stylebox_override("focus", _surface(Color.TRANSPARENT, INK, 0))
func _feature_card(parent: Node, spec: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_card(parent).add_child(row)
	var icon := TextureRect.new()
	icon.texture = load("res://assets/interface/icons/" + str(spec.icon) + ".svg")
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var body := _box(row, 8)
	body.add_child(_label(spec.title, 26))
	body.add_child(_label(spec.text, 21, MUTED))
func _build_features() -> void:
	var page := _page("features")
	page.add_child(_label("THE GAME", 18, GOLD))
	page.add_child(_label("A nation is more\nthan its army.", 48))
	page.add_child(_label("Military power, industry, trade and diplomacy shape the same campaign.", 24, MUTED))
	var priorities := ["guard", "economy", "trade"]
	for id in priorities:
		_feature_card(page, catalogue.features.filter(func(f: Dictionary): return f.id == id)[0])
	for feature in catalogue.features:
		if feature.id not in priorities: _feature_card(page, feature)
	page.add_child(_label(catalogue.roadmap, 21, MUTED))
	var play := _button("BACK TO HOME  →", true)
	play.pressed.connect(_select_page.bind("home"))
	page.add_child(play)
func _update_card(parent: Node, update: Dictionary) -> void:
	var body := _box(_card(parent), 10)
	body.add_child(_label(update.date, 16, GOLD))
	body.add_child(_label(update.title, 28))
	body.add_child(_label(update.text, 21, MUTED))
func _build_updates() -> void:
	var page := _page("updates")
	page.add_child(_label("LATEST FROM THE FRONT", 36))
	for update in catalogue.updates: _update_card(page, update)
	page.add_child(_label(catalogue.roadmap, 21, MUTED))
	var website := _button("VISIT WARFRONTMANDATE.COM  ↗")
	website.pressed.connect(func(): OS.shell_open("https://warfrontmandate.com/"))
	page.add_child(website)
func _build_settings() -> void:
	var page := _page("settings")
	page.add_child(_label("COMMAND CENTRE SETTINGS", 36))
	page.add_child(_label("Language", 24, GOLD))
	language_picker = OptionButton.new()
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var languages := ["English", "Русский", "Українська", "Deutsch", "Français", "Español"]
	var codes := ["en", "ru", "uk", "de", "fr", "es"]
	var preferences := ConfigFile.new()
	preferences.load("user://settings.cfg")
	var locale: String = preferences.get_value("general", "locale", "en")
	TranslationServer.set_locale(locale)
	for i in codes.size():
		language_picker.add_item(languages[i])
		if codes[i] == locale: language_picker.select(i)
	language_picker.custom_minimum_size.y = 64
	page.add_child(language_picker)
	language_picker.item_selected.connect(func(i: int):
		TranslationServer.set_locale(codes[i])
		var file := ConfigFile.new()
		file.load("user://settings.cfg")
		file.set_value("general", "locale", codes[i])
		file.save("user://settings.cfg"))
	page.add_child(_label("Music and sound", 24, GOLD))
	page.add_child(_label("Use the Music and Sound switches on Home. Your choices are remembered for your next visit.", 24, MUTED))
	var account := _button("COMMANDER ACCOUNT  →")
	account.pressed.connect(func():
		if not loading: account_requested.emit())
	page.add_child(account)
	for link in [["PRIVACY POLICY", "privacy"], ["ACCOUNT DELETION", "delete-account"]]:
		var button := _button(link[0] + "  ↗")
		button.pressed.connect(func(): OS.shell_open("https://warfrontmandate.com/" + link[1]))
		page.add_child(button)
func set_commander(name_text: String, signed_in: bool) -> void:
	commander_label.text = "WELCOME, " + name_text.to_upper() if signed_in else "WELCOME, COMMANDER"
	profile_button.text = "PROFILE" if signed_in else "ACCOUNT"
func _select_page(id: String) -> void:
	if loading: return
	current_page = id
	for key in pages: pages[key].visible = key == id
	for key in nav_buttons: nav_buttons[key].modulate = GOLD if key == id else INK
	scroll.scroll_vertical = 0
	_layout.call_deferred()
func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	# The game's portrait canvas expands on desktop. Keep the lobby at readable
	# physical pixel sizes rather than shrinking it to a phone-sized centre column.
	var landscape := size.x > size.y
	var pixel_scale := size.y / maxf(1, get_tree().root.size.y) if landscape else 1.0
	screen.scale = Vector2.ONE * pixel_scale
	size /= pixel_scale
	var width := minf(1100, size.x)
	var left := (size.x - width) / 2
	masthead.position = Vector2(left, 0)
	masthead.size = Vector2(width, 88)
	navigation.position = Vector2(left, size.y - 86)
	navigation.size = Vector2(width, 86)
	screen.move_child(side_overlay, -1)
	side_panel.custom_minimum_size.x = minf(660, width - 32)
	var status_height := 64.0 if status_bar.visible else 0.0
	status_bar.position = Vector2(left, size.y - 86 - status_height)
	status_bar.size = Vector2(width, status_height)
	scroll.position = Vector2(left, 88)
	scroll.size = Vector2(width, maxf(100, size.y - 174 - status_height))
	content.custom_minimum_size.x = maxf(0, width - 16)
	var portrait := size.y > size.x
	hero.custom_minimum_size.y = 300 if portrait else 320
	artwork.texture = load("res://assets/interface/campaign_hero_landscape.webp")
	branding.position = Vector2(32, 24)
	branding.size = Vector2(width - 64, 260)
	heading.add_theme_font_size_override("font_size", 70 if width >= 680 else 58)
	for card in country_cards.values():
		card.custom_minimum_size.y = maxf(194.0 if width >= 680 else 244.0, card.get_child(0).get_combined_minimum_size().y)
func begin_loading() -> void:
	loading = true
	for button in [online_button, continue_button, fresh_button, test_button, profile_button, join_button, resume_button]: button.disabled = true
	for button in training_buttons: button.disabled = true
	for item in game_rows: item.button.disabled = true
	language_picker.disabled = true
	country_picker.disabled = true
	for card in country_cards.values(): card.disabled = true
	for button in nav_buttons.values(): button.disabled = true
	set_progress(0, "Loading game")
func set_progress(value: float, message: String) -> void:
	if not status_bar.visible:
		status_bar.visible = true
		_layout()
	progress.value = value
	loading_label.text = ("Starting · " + message) if booting and not pending_start.is_empty() else message
## Owner 2026-10-15: "go straight into the home screen, then choose, then wait". While the map
## is still being prepared the home screen stays usable; a choice made then is remembered
## (pending_start) and carried out as soon as the map is ready.
var booting: = false
var pending_start: = ""
func begin_background_loading() -> void:
	booting = true
	profile_button.disabled = true
	for button in nav_buttons.values(): button.disabled = true
	set_progress(0, "Preparing map")
func request_start(mode: String) -> void:
	if booting:
		if pending_start.is_empty():
			pending_start = mode
			loading = true
			for button in [online_button, continue_button, fresh_button, test_button, join_button, resume_button]: button.disabled = true
			for button in training_buttons: button.disabled = true
			for item in game_rows: item.button.disabled = true
			for card in country_cards.values(): card.disabled = true
			country_picker.disabled = true
		return
	if loading: return
	begin_loading()
	await get_tree().process_frame
	if mode.begins_with("test:"):
		test_requested.emit(mode.get_slice(":", 1))
		return
	match mode:
		"resume": resume_requested.emit()
		"continue": continue_requested.emit()
		"fresh": fresh_requested.emit()
		"test": test_requested.emit("all")
		"online": online_requested.emit()
		"training": training_requested.emit(false)
		"training_resume": training_requested.emit(true)
## Owner 2026-10-15 ("a button to go back to the home screen"): the match is saved and paused;
## Resume Campaign carries straight on.
func show_paused_match(kind: String = "campaign") -> void:
	paused_kind = kind
	if kind == "campaign": has_save = true
	cancel_loading("")
	show()
	_select_page("home")
	scroll.scroll_vertical = 0
func cancel_loading(message: String) -> void:
	loading = false
	for button in [online_button, fresh_button, test_button, profile_button, join_button, resume_button]: button.disabled = false
	for button in training_buttons: button.disabled = false
	refresh_active_games()
	language_picker.disabled = false
	country_picker.disabled = false
	for card in country_cards.values(): card.disabled = false
	for button in nav_buttons.values(): button.disabled = false
	set_progress(100, message)
	# Nothing to report: give the space back to the page.
	if message.is_empty() or message == "Ready":
		status_bar.visible = false
		_layout()
func _show_audio() -> void:
	music_button.text = "MUSIC: " + ("ON" if GameAudio.music_enabled else "OFF")
	sound_button.text = "SOUND: " + ("ON" if GameAudio.sound_enabled else "OFF")

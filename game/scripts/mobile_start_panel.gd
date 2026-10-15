class_name MobileStartPanel
extends CanvasLayer
## Shared command centre for the native app and browser game.
signal continue_requested
signal fresh_requested
signal test_requested(scenario: String)
signal online_requested
signal account_requested
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

static func _font(weight: int, spacing: int = 0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Oswald.ttf")
	f.variation_embolden = clampf((weight - 400) / 300.0, 0, 1) * 0.9
	f.spacing_glyph = spacing
	return f
func selected_country() -> String:
	return "ukraine" if country_picker.selected == 0 else "russia"
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
	has_save = saved
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
	var mark := _label("W / M", 26, GOLD)
	mark.add_theme_font_override("font", _font(600, 1))
	mark.custom_minimum_size.x = 92
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
	_build_features()
	_build_updates()
	_build_settings()
	navigation = PanelContainer.new()
	navigation.add_theme_stylebox_override("panel", _surface(NAVY, Color("2b3b45"), 12))
	screen.add_child(navigation)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	navigation.add_child(nav)
	for item in [["home", "HOME", "city"], ["features", "FEATURES", "research"], ["updates", "NEWS", "more"], ["settings", "SETTINGS", "chevrons"]]:
		var button := _chip(item[1])
		button.icon = load("res://assets/interface/icons/" + item[2] + ".svg")
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 22)
		button.pressed.connect(_select_page.bind(item[0]))
		nav.add_child(button)
		nav_buttons[item[0]] = button
	_select_page("home")
	get_viewport().size_changed.connect(_layout)
	_layout()
	_layout.call_deferred()
	visibility_changed.connect(func():
		if visible: _layout.call_deferred())
func _page(id: String, padded: bool = true) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32 if padded else 0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(margin)
	pages[id] = margin
	return _box(margin, 22)
func _build_home() -> void:
	var home := _page("home", false)
	home.add_theme_constant_override("separation", 0)
	hero = Control.new()
	hero.custom_minimum_size.y = 360
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
	var pillars := _label("AI DEFENCE  ·  ECONOMIC VICTORY  ·  REAL TRADE", 16, GOLD)
	pillars.add_theme_font_override("font", _font(500, 1))
	branding.add_child(pillars)
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
	if has_save: _section(body, "YOUR CAMPAIGN")
	panel = _card(body)
	panel.visible = has_save
	var campaign := _box(panel, 12)
	campaign.add_child(_label("RUSSIA–UKRAINE", 28))
	campaign.add_child(_label("Offline campaign · Saved on this device", 19, MUTED))
	continue_button = _button("RESUME CAMPAIGN  →", true)
	continue_button.visible = has_save
	continue_button.disabled = not has_save
	continue_button.pressed.connect(func(): request_start("continue"))
	campaign.add_child(continue_button)
	_section(body, "PLAY YOUR WAY")
	var play := _box(_card(body), 16)
	play.add_child(_label("CHOOSE YOUR NATION", 17, GOLD))
	country_picker = OptionButton.new()
	country_picker.add_item("Ukraine")
	country_picker.add_item("Russia")
	country_picker.select(0 if GameSession.player_country == "ukraine" else 1)
	country_picker.visible = false
	play.add_child(country_picker)
	var nations := HBoxContainer.new()
	nations.add_theme_constant_override("separation", 14)
	play.add_child(nations)
	for spec in [["russia", "RUSSIA", [Color.WHITE, Color("1c3f94"), Color("d52b1e")], "Russian"], ["ukraine", "UKRAINE", [Color("0057b7"), Color("ffd700")], "European"]]:
		nations.add_child(_nation_card(spec[0], spec[1], spec[2], spec[3]))
	_show_nation()
	fresh_button = _button("NEW CAMPAIGN  →" if has_save else "START CAMPAIGN  →", not has_save)
	fresh_button.pressed.connect(func(): request_start("fresh"))
	play.add_child(fresh_button)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 14)
	play.add_child(secondary)
	online_button = _button("ONLINE MATCH")
	online_button.pressed.connect(func(): request_start("online"))
	test_button = _button("WEAPONS RANGE")
	test_button.pressed.connect(func():
		range_picker.visible = not range_picker.visible
		if range_picker.visible: scroll.ensure_control_visible.call_deferred(range_picker))
	for button in [online_button, test_button]:
		button.add_theme_font_size_override("font_size", 20)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		secondary.add_child(button)
	# Owner 2026-10-14: separate test maps per kind of unit ("too much if they're all in one").
	range_picker = GridContainer.new()
	range_picker.columns = 2
	range_picker.add_theme_constant_override("h_separation", 10)
	range_picker.add_theme_constant_override("v_separation", 10)
	range_picker.visible = false
	play.add_child(range_picker)
	for scenario in WeaponScenarios.LIST:
		var choice: = _button(str(scenario.title).to_upper())
		choice.add_theme_font_size_override("font_size", 18)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.pressed.connect(func(): range_picker.hide(); request_start("test:" + str(scenario.id)))
		range_picker.add_child(choice)
	play.add_child(_label("Offline against AI · Online with an account", 17, MUTED))
	loading_label = _label("Ready to command", 18, MUTED)
	play.add_child(loading_label)
	progress = ProgressBar.new()
	progress.value = 100
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	progress.add_theme_stylebox_override("background", _surface(Color("243743"), Color.TRANSPARENT, 0))
	progress.add_theme_stylebox_override("fill", _surface(GOLD, Color.TRANSPARENT, 0))
	play.add_child(progress)
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
	if GameAudio.custom_menu_theme():
		credit_label = _label(GameAudio.MENU_THEME_CREDIT, 16, MUTED)
		credit_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		body.add_child(credit_label)
	_section(body, "MORE THAN CONQUEST")
	for id in ["guard", "economy", "trade"]:
		_feature_card(body, catalogue.features.filter(func(f: Dictionary): return f.id == id)[0])
	var all_features := _button("EXPLORE ALL FEATURES  →")
	all_features.pressed.connect(_select_page.bind("features"))
	body.add_child(all_features)
	_section(body, "LATEST FROM THE FRONT")
	_update_card(body, catalogue.updates[0])
	footer = _label("WARFRONTMANDATE.COM", 16, MUTED)
	footer.add_theme_font_override("font", _font(500, 3))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(footer)
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
		country_picker.select(0 if id == "ukraine" else 1)
		_show_nation())
	country_cards[id] = card
	return card
func _show_nation() -> void:
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
	var play := _button("BACK TO YOUR CAMPAIGN  →", true)
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
	scroll.position = Vector2(left, 88)
	scroll.size = Vector2(width, maxf(100, size.y - 174))
	content.custom_minimum_size.x = maxf(0, width - 16)
	var portrait := size.y > size.x
	hero.custom_minimum_size.y = 360 if portrait else 380
	artwork.texture = load("res://assets/interface/campaign_hero_landscape.webp")
	branding.position = Vector2(32, 24)
	branding.size = Vector2(width - 64, 310)
	heading.add_theme_font_size_override("font_size", 70 if width >= 680 else 58)
	for card in country_cards.values(): card.custom_minimum_size.y = 194 if width >= 680 else 244
func begin_loading() -> void:
	loading = true
	for button in [online_button, continue_button, fresh_button, test_button, profile_button]: button.disabled = true
	language_picker.disabled = true
	country_picker.disabled = true
	for card in country_cards.values(): card.disabled = true
	for button in nav_buttons.values(): button.disabled = true
	set_progress(0, "Loading campaign")
	scroll.ensure_control_visible(loading_label)
func set_progress(value: float, message: String) -> void:
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
			for button in [online_button, continue_button, fresh_button, test_button]: button.disabled = true
			for card in country_cards.values(): card.disabled = true
			country_picker.disabled = true
			scroll.ensure_control_visible(loading_label)
		return
	if loading: return
	begin_loading()
	await get_tree().process_frame
	if mode.begins_with("test:"):
		test_requested.emit(mode.get_slice(":", 1))
		return
	match mode:
		"continue": continue_requested.emit()
		"fresh": fresh_requested.emit()
		"test": test_requested.emit("all")
		"online": online_requested.emit()
## Owner 2026-10-15 ("a button to go back to the home screen"): the match is saved and paused;
## Resume Campaign carries straight on.
func show_paused_match() -> void:
	has_save = true
	panel.visible = true
	continue_button.visible = true
	fresh_button.text = "NEW CAMPAIGN  →"
	cancel_loading("Match paused · tap Resume Campaign to carry on")
	show()
	scroll.scroll_vertical = 0
func cancel_loading(message: String) -> void:
	loading = false
	for button in [online_button, fresh_button, test_button, profile_button]: button.disabled = false
	continue_button.disabled = not has_save
	language_picker.disabled = false
	country_picker.disabled = false
	for card in country_cards.values(): card.disabled = false
	for button in nav_buttons.values(): button.disabled = false
	set_progress(100, message)
func _show_audio() -> void:
	music_button.text = "MUSIC: " + ("ON" if GameAudio.music_enabled else "OFF")
	sound_button.text = "SOUND: " + ("ON" if GameAudio.sound_enabled else "OFF")

class_name MobileStartPanel
extends CanvasLayer
signal continue_requested
signal fresh_requested
signal test_requested
signal online_requested
var online_button: Button
var language_picker: OptionButton
var country_picker: OptionButton
var panel: PanelContainer
var continue_button: Button
var content: VBoxContainer
var artwork: TextureRect
var fresh_button: Button
var test_button: Button
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
func selected_country() -> String:
	return "ukraine" if country_picker.selected == 0 else "russia"
func _label(text: String, pixels: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	return label
func _button(text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_font_override("font", _font(600, 3))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("e2b866") if primary else Color(1, 1, 1, 0.07)
		if state == "hover": style.bg_color = style.bg_color.lightened(0.1)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.15)
		if state == "disabled": style.bg_color = Color(1, 1, 1, 0.04)
		style.border_color = Color("f3d08c") if primary else Color(1, 1, 1, 0.16)
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		if primary:
			style.shadow_color = Color(0.89, 0.72, 0.4, 0.35)
			style.shadow_size = 10
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("15110a") if primary else Color("eef1f2"))
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	return button
const GOLD := Color("e2b866")
const INK := Color("f4f1e8")
const MUTED := Color("a9b8c2")
var country_cards: Dictionary = {}
var credit_label: Label

static func _font(weight: int, spacing: int = 0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load("res://assets/fonts/Oswald.ttf")
	f.variation_opentype = {"wght": weight}
	# Oswald.ttf is the regular cut: embolden for the heavier weights.
	f.variation_embolden = clampf((weight - 400) / 300.0, 0.0, 1.0) * 0.9
	f.spacing_glyph = spacing
	return f

## Owner 2026-10-13: "the start screen looks like a cheap Atari game, make it amazing".
## Cinematic art, a proper display title, flag cards to choose a side, one clear gold action.
func setup(theme: Theme, saved: bool) -> void:
	has_save = saved
	layer = 15
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.theme = theme
	add_child(screen)
	artwork = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.texture = load("res://assets/interface/warfront_start_hero.webp")
	screen.add_child(artwork)
	var dim := TextureRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.28, 0.52, 0.72, 1])
	gradient.colors = PackedColorArray([Color(0.01, 0.02, 0.03, 0.78), Color(0.01, 0.02, 0.03, 0.15), Color(0.01, 0.02, 0.03, 0.0), Color(0.01, 0.02, 0.03, 0.75), Color(0.01, 0.02, 0.03, 0.97)])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2(0, 0)
	shade.fill_to = Vector2(0, 1)
	dim.texture = shade
	screen.add_child(dim)
	# Title block.
	branding = VBoxContainer.new()
	branding.add_theme_constant_override("separation", 0)
	branding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(branding)
	var kicker := _label("GLOBAL STRATEGY  ·  MODERN WARFARE", 15, GOLD)
	kicker.add_theme_font_override("font", _font(500, 3))
	branding.add_child(kicker)
	heading = _label("WARFRONT\nMANDATE", 84, INK)
	heading.add_theme_font_override("font", _font(700, 2))
	heading.add_theme_constant_override("line_spacing", -22)
	heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	heading.add_theme_constant_override("shadow_offset_x", 0)
	heading.add_theme_constant_override("shadow_offset_y", 5)
	heading.add_theme_constant_override("shadow_outline_size", 8)
	branding.add_child(heading)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 14)
	branding.add_child(badge_row)
	var rule := ColorRect.new()
	rule.color = GOLD
	rule.custom_minimum_size = Vector2(54, 3)
	rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_row.add_child(rule)
	var ww3 := _label("WW3", 26, GOLD)
	ww3.add_theme_font_override("font", _font(600, 4))
	var ww3_box := PanelContainer.new()
	var ww3_style := StyleBoxFlat.new()
	ww3_style.bg_color = Color(0, 0, 0, 0.35)
	ww3_style.border_color = GOLD
	ww3_style.set_border_width_all(2)
	ww3_style.set_corner_radius_all(4)
	ww3_style.content_margin_left = 12
	ww3_style.content_margin_right = 10
	ww3_style.content_margin_top = 0
	ww3_style.content_margin_bottom = 2
	ww3_box.add_theme_stylebox_override("panel", ww3_style)
	ww3_box.add_child(ww3)
	badge_row.add_child(ww3_box)
	var tagline := _label("YOUR ORDERS. THE WORLD'S FUTURE.", 16, Color("d6dde1"))
	tagline.add_theme_font_override("font", _font(400, 2))
	tagline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge_row.add_child(tagline)
	# Command card.
	panel = PanelContainer.new()
	screen.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.065, 0.88)
	style.border_color = Color(0.89, 0.72, 0.4, 0.55)
	style.border_width_top = 2
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 18
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var choose := _label("CHOOSE YOUR NATION", 15, GOLD)
	choose.add_theme_font_override("font", _font(500, 3))
	content.add_child(choose)
	# Kept for selected_country() and saves; the flag cards drive it.
	country_picker = OptionButton.new()
	country_picker.add_item("Ukraine")
	country_picker.add_item("Russia")
	country_picker.select(0 if GameSession.player_country == "ukraine" else 1)
	country_picker.visible = false
	content.add_child(country_picker)
	var nations := HBoxContainer.new()
	nations.add_theme_constant_override("separation", 12)
	content.add_child(nations)
	for spec in [["russia", "RUSSIA", [Color.WHITE, Color("1c3f94"), Color("d52b1e")], "Eastern doctrine"], ["ukraine", "UKRAINE", [Color("0057b7"), Color("ffd700")], "European doctrine"]]:
		nations.add_child(_nation_card(spec[0], spec[1], spec[2], spec[3]))
	_show_nation()
	continue_button = _button("CONTINUE CAMPAIGN", saved)
	continue_button.visible = saved
	continue_button.disabled = not saved
	continue_button.pressed.connect(func(): request_start("continue"))
	content.add_child(continue_button)
	fresh_button = _button("NEW CAMPAIGN" if saved else "START CAMPAIGN", not saved)
	fresh_button.pressed.connect(func(): request_start("fresh"))
	content.add_child(fresh_button)
	var secondary := HBoxContainer.new()
	secondary.add_theme_constant_override("separation", 12)
	content.add_child(secondary)
	online_button = _button("ONLINE MATCH")
	online_button.pressed.connect(func(): request_start("online"))
	test_button = _button("WEAPONS RANGE")
	test_button.pressed.connect(func(): request_start("test"))
	for button in [online_button, test_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 54
		button.add_theme_font_size_override("font_size", 18)
		secondary.add_child(button)
	loading_label = _label("Ready to command", 15, MUTED)
	content.add_child(loading_label)
	progress = ProgressBar.new()
	progress.value = 100
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.08)
	track.set_corner_radius_all(2)
	progress.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(2)
	progress.add_theme_stylebox_override("fill", fill)
	content.add_child(progress)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 8)
	content.add_child(toggles)
	if audio != null:
		music_button = _chip("MUSIC: ON")
		sound_button = _chip("SOUND: ON")
		toggles.add_child(music_button)
		toggles.add_child(sound_button)
		music_button.pressed.connect(func(): audio.set_music(not GameAudio.music_enabled))
		sound_button.pressed.connect(func(): audio.set_sound(not GameAudio.sound_enabled))
		audio.settings_changed.connect(_show_audio)
		_show_audio()
	var settings_toggle := _chip("SETTINGS")
	toggles.add_child(settings_toggle)
	var advanced := VBoxContainer.new()
	advanced.visible = false
	advanced.add_theme_constant_override("separation", 8)
	content.add_child(advanced)
	settings_toggle.pressed.connect(func(): advanced.visible = not advanced.visible)
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
	language_picker.custom_minimum_size.y = 48
	advanced.add_child(language_picker)
	language_picker.item_selected.connect(func(i: int):
		TranslationServer.set_locale(codes[i])
		var file := ConfigFile.new()
		file.load("user://settings.cfg")
		file.set_value("general", "locale", codes[i])
		file.save("user://settings.cfg"))
	if GameAudio.custom_menu_theme():
		credit_label = _label(GameAudio.MENU_THEME_CREDIT, 12, Color(0.85, 0.8, 0.65, 0.8))
		credit_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		credit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(credit_label)
	footer = _label("WARFRONTMANDATE.COM", 13, Color(0.66, 0.73, 0.78, 0.8))
	footer.add_theme_font_override("font", _font(500, 4))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(footer)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# Fit the card to its contents once the controls have their real sizes.
	_layout.call_deferred()
	get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)

func _chip(text: String) -> Button:
	var chip := Button.new()
	chip.text = text
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.custom_minimum_size.y = 40
	chip.add_theme_font_size_override("font_size", 14)
	chip.add_theme_font_override("font", _font(500, 2))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(1, 1, 1, 0.06 if state != "pressed" else 0.14)
		box.border_color = Color(1, 1, 1, 0.14)
		box.set_border_width_all(1)
		box.set_corner_radius_all(20)
		chip.add_theme_stylebox_override(state, box)
	chip.add_theme_color_override("font_color", Color("d6dde1"))
	return chip

func _nation_card(id: String, title: String, stripes: Array, subtitle: String) -> Button:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size.y = 108
	card.toggle_mode = true
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_left = 14
	body.offset_top = 12
	body.offset_right = -14
	body.offset_bottom = -10
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	var flag := VBoxContainer.new()
	flag.custom_minimum_size = Vector2(42, 28)
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
	var name_label := _label(title, 22, INK)
	name_label.add_theme_font_override("font", _font(600, 2))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(name_label)
	var note := _label(subtitle, 12, MUTED)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(note)
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
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var box := StyleBoxFlat.new()
			box.bg_color = Color(0.89, 0.72, 0.4, 0.16) if chosen else Color(1, 1, 1, 0.05)
			box.border_color = GOLD if chosen else Color(1, 1, 1, 0.12)
			box.set_border_width_all(2 if chosen else 1)
			box.set_corner_radius_all(12)
			card.add_theme_stylebox_override(state, box)

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var portrait := size.y > size.x
	var margin := clampf(size.x * 0.065, 18, 48)
	var width := minf(600, size.x - margin * 2)
	var small := size.x < 500
	heading.add_theme_font_size_override("font_size", int(clampf(size.x * 0.15, 46, 108)))
	branding.position = Vector2(margin, maxf(36, size.y * 0.07))
	branding.size = Vector2(size.x - margin * 2, 0)
	var height := minf(content.get_combined_minimum_size().y + 42, size.y * 0.62)
	if portrait:
		panel.position = Vector2((size.x - width) * 0.5, size.y - height - 56)
	else:
		width = minf(500, size.x * 0.46)
		height = size.y - 90
		panel.position = Vector2(size.x - width - margin, 30)
		branding.size.x = size.x * 0.45 - margin
	content.custom_minimum_size.x = maxf(0, width - 44)
	panel.size = Vector2(width, height)
	footer.position = Vector2(margin, size.y - 38)
	footer.size = Vector2(size.x - margin * 2, 22)
	for button in [continue_button, fresh_button]: button.add_theme_font_size_override("font_size", 20 if small else 24)

func begin_loading() -> void:
	loading = true
	online_button.disabled = true
	if language_picker != null: language_picker.disabled = true
	country_picker.disabled = true
	for card in country_cards.values(): card.disabled = true
	continue_button.disabled = true
	fresh_button.disabled = true
	test_button.disabled = true
	set_progress(0, "Loading campaign")
func set_progress(value: float, message: String) -> void:
	progress.value = value
	loading_label.text = message
func request_start(mode: String) -> void:
	if loading: return
	begin_loading()
	await get_tree().process_frame
	match mode:
		"continue": continue_requested.emit()
		"fresh": fresh_requested.emit()
		"test": test_requested.emit()
		"online": online_requested.emit()
## Back to the menu after a start that did not happen (e.g. the match server could not be reached).
func cancel_loading(message: String) -> void:
	loading = false
	if language_picker != null: language_picker.disabled = false
	country_picker.disabled = false
	for card in country_cards.values(): card.disabled = false
	continue_button.disabled = not has_save
	fresh_button.disabled = false
	test_button.disabled = false
	online_button.disabled = false
	set_progress(100, message)

func _show_audio() -> void:
	music_button.text = "MUSIC: " + ("ON" if GameAudio.music_enabled else "OFF")
	sound_button.text = "SOUND: " + ("ON" if GameAudio.sound_enabled else "OFF")

## Doctrines come with the country (owner request 2026-10-12); there is no separate choice.
func selected_doctrine() -> String:
	return Doctrine.of(selected_country())

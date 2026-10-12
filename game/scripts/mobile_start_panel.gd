class_name MobileStartPanel
extends CanvasLayer
signal continue_requested
signal fresh_requested
signal test_requested
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
	button.custom_minimum_size.y = 68
	button.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StrategyTheme.surface("button", 20)
		style.bg_color = Color("d4a85c") if primary else Color("17242d")
		if state == "hover": style.bg_color = style.bg_color.lightened(0.12)
		if state == "pressed": style.bg_color = style.bg_color.darkened(0.15)
		if state == "disabled": style.bg_color = Color("283137")
		style.border_color = Color("e8bd72") if primary else Color("40515b")
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Color("111c23") if primary else Color("e9edf0"))
	return button
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
	gradient.offsets = PackedFloat32Array([0, 0.45, 1])
	gradient.colors = PackedColorArray([Color(0.025, 0.045, 0.065, 0.25), Color(0.025, 0.045, 0.065, 0.0), Color(0.025, 0.045, 0.065, 0.98)])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2(0, 0)
	shade.fill_to = Vector2(0, 1)
	dim.texture = shade
	screen.add_child(dim)
	branding = VBoxContainer.new()
	branding.add_theme_constant_override("separation", 4)
	screen.add_child(branding)
	branding.add_child(_label("GLOBAL STRATEGY  /  MODERN WARFARE", 18, Color("d9b477")))
	heading = _label("WARFRONT\nMANDATE", 84, Color("f3f1e9"))
	heading.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 800))
	heading.add_theme_constant_override("line_spacing", -10)
	heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	heading.add_theme_constant_override("shadow_offset_y", 4)
	branding.add_child(heading)
	branding.add_child(_label("W W 3", 30, Color("e6b66a")))
	branding.add_child(_label("YOUR ORDERS. THE WORLD'S FUTURE.", 18, Color("b9c6cd")))
	panel = PanelContainer.new()
	screen.add_child(panel)
	var style := StrategyTheme.surface("panel", 24)
	style.bg_color = Color(0.035, 0.065, 0.085, 0.92)
	style.border_color = Color("42515b")
	style.set_corner_radius_all(16)
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	content.add_child(_label("CHOOSE YOUR COMMAND", 20, Color("d9b477")))
	var note := _label("Russia vs Ukraine · Single-player campaign", 20, Color("b9c6cd"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	country_picker = OptionButton.new()
	country_picker.add_item("Ukraine")
	country_picker.add_item("Russia")
	country_picker.select(0 if GameSession.player_country == "ukraine" else 1)
	country_picker.custom_minimum_size.y = 62
	country_picker.add_theme_font_size_override("font_size", 24)
	content.add_child(country_picker)
	continue_button = _button("CONTINUE CAMPAIGN", saved)
	continue_button.visible = saved
	continue_button.disabled = not saved
	continue_button.pressed.connect(func(): request_start("continue"))
	content.add_child(continue_button)
	fresh_button = _button("NEW CAMPAIGN" if saved else "START CAMPAIGN", not saved)
	fresh_button.pressed.connect(func(): request_start("fresh"))
	content.add_child(fresh_button)
	test_button = _button("ALL WEAPONS  /  TEST RANGE")
	test_button.pressed.connect(func(): request_start("test"))
	content.add_child(test_button)
	loading_label = _label("Ready to command", 18, Color("a4b7c3"))
	content.add_child(loading_label)
	progress = ProgressBar.new()
	progress.value = 100
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	var track := StyleBoxFlat.new()
	track.bg_color = Color("25323b")
	progress.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("d9b477")
	progress.add_theme_stylebox_override("fill", fill)
	content.add_child(progress)
	if audio != null:
		var switches := HBoxContainer.new()
		switches.add_theme_constant_override("separation", 12)
		music_button = _button("MUSIC: ON")
		sound_button = _button("SOUND: ON")
		for button in [music_button, sound_button]:
			button.custom_minimum_size.y = 48
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 18)
			switches.add_child(button)
		music_button.pressed.connect(func(): audio.set_music(not GameAudio.music_enabled))
		sound_button.pressed.connect(func(): audio.set_sound(not GameAudio.sound_enabled))
		audio.settings_changed.connect(_show_audio)
		content.add_child(switches)
		_show_audio()
	footer = _label("WARFRONTMANDATE.COM", 16, Color("91a6b3"))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(footer)
	get_viewport().size_changed.connect(_layout)
	_layout()
func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var portrait := size.y > size.x
	var margin := clampf(size.x * 0.065, 20, 48)
	var width := minf(624, size.x - margin * 2)
	var height := minf((550 if has_save else 470) if audio != null else (490 if has_save else 410), size.y * 0.55)
	var small := size.x < 500
	for child in content.get_children():
		if child is Button:
			child.add_theme_font_size_override("font_size", 16 if small else 24)
		elif child is Label:
			child.add_theme_font_size_override("font_size", 14 if small else 20)
	for child in branding.get_children():
		if child is Label and child != heading:
			child.add_theme_font_size_override("font_size", 12 if small else (30 if child.text == "W W 3" else 18))
	heading.add_theme_font_size_override("font_size", int(clampf(size.x * 0.117, 40, 84)))
	branding.position = Vector2(margin, maxf(28, size.y * 0.075))
	branding.size = Vector2(width, 300)
	if portrait:
		panel.position = Vector2((size.x - width) * 0.5, size.y - height - 70)
	else:
		width = minf(520, size.x * 0.46)
		height = size.y - 100
		panel.position = Vector2(size.x - width - margin, 30)
		branding.size.x = size.x * 0.45 - margin
	content.custom_minimum_size.x = maxf(0, width - 48)
	panel.size = Vector2(width, height)
	footer.position = Vector2(margin, size.y - 42)
	footer.size = Vector2(size.x - margin * 2, 24)
func begin_loading() -> void:
	loading = true
	country_picker.disabled = true
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

func _show_audio() -> void:
	music_button.text = "MUSIC: " + ("ON" if GameAudio.music_enabled else "OFF")
	sound_button.text = "SOUND: " + ("ON" if GameAudio.sound_enabled else "OFF")

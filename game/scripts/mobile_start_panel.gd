class_name MobileStartPanel
extends CanvasLayer
signal continue_requested
signal fresh_requested
signal test_requested
signal europe_requested
signal world_requested
signal online_requested
var country_picker: OptionButton
var language_picker: OptionButton
## Languages with translations (translations/ui.csv, tools/make_translations.py).
const LANGUAGES: = [["en", "English"], ["ru", "Русский"], ["uk", "Українська"], ["de", "Deutsch"], ["fr", "Français"], ["es", "Español"]]
const SETTINGS_PATH: = "user://settings.cfg"
static func apply_saved_language() -> void:
	var settings: = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	var saved: String = settings.get_value("general", "locale", "")
	if not saved.is_empty(): TranslationServer.set_locale(saved)
func _choose_language(index: int) -> void:
	var code: String = LANGUAGES[index][0]
	TranslationServer.set_locale(code)
	var settings: = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("general", "locale", code)
	settings.save(SETTINGS_PATH)
func selected_country() -> String:
	return "ukraine" if country_picker.selected == 0 else "russia"
var panel: PanelContainer
var continue_button: Button
var content: VBoxContainer
var artwork: TextureRect
var fresh_button: Button
var has_save: = false
## Music and sound switches (owner request 2026-10-12); main sets `audio` before setup().
var audio: GameAudio
var music_button: Button
var sound_button: Button
func setup(theme: Theme, saved: bool) -> void :
	apply_saved_language()
	has_save = saved
	layer = 15
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	artwork = TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(artwork)
	var dim: = TextureRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var gradient: = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.055, 0.075, 0.65), Color(0.02, 0.055, 0.075, 0.08)])
	var shade: = GradientTexture2D.new()
	shade.gradient = gradient
	shade.fill_from = Vector2(0, 0)
	shade.fill_to = Vector2(0, 1)
	dim.texture = shade
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	var style: = StrategyTheme.surface("panel", 22)
	style.bg_color = Color("20282d")
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	var kicker: = Label.new()
	kicker.text = "REGIONAL CAMPAIGN"
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", Color("dcc38b"))
	content.add_child(kicker)
	var heading: = Label.new()
	heading.text = "COMMAND\nOF NATIONS"
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("f0e5c9"))
	content.add_child(heading)
	var note: = Label.new()
	note.text = "Choose Russia or Ukraine · Single player against the other country’s AI\nDrag to explore. Pinch to zoom. Tap armies for orders."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 13)
	content.add_child(note)
	country_picker = OptionButton.new()
	country_picker.add_item("Play as Ukraine")
	country_picker.add_item("Play as Russia")
	country_picker.select(0 if GameSession.player_country == "ukraine" else 1)
	country_picker.custom_minimum_size.y = 48
	content.add_child(country_picker)
	language_picker = OptionButton.new()
	language_picker.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for language in LANGUAGES: language_picker.add_item("🌐 " + language[1])
	var current: = TranslationServer.get_locale().substr(0, 2)
	for i in LANGUAGES.size():
		if LANGUAGES[i][0] == current: language_picker.select(i)
	language_picker.custom_minimum_size.y = 48
	language_picker.item_selected.connect(_choose_language)
	content.add_child(language_picker)
	continue_button = Button.new()
	continue_button.text = "CONTINUE CAMPAIGN"
	continue_button.custom_minimum_size.y = 52
	continue_button.disabled = not saved
	continue_button.visible = saved
	continue_button.pressed.connect( func(): continue_requested.emit();hide())
	content.add_child(continue_button)
	fresh_button = Button.new()
	fresh_button.text = "START NEW CAMPAIGN" if saved else "START CAMPAIGN"
	fresh_button.custom_minimum_size.y = 52
	fresh_button.pressed.connect( func(): fresh_requested.emit();hide())
	content.add_child(fresh_button)
	var online_button: = Button.new()
	online_button.text = "ONLINE MATCH · PLAY OTHER COMMANDERS"
	online_button.custom_minimum_size.y = 52
	online_button.pressed.connect(func(): online_requested.emit())
	content.add_child(online_button)
	var test_button: = Button.new()
	test_button.text = "ALL WEAPONS TEST MAP"
	test_button.custom_minimum_size.y = 48
	test_button.pressed.connect(func(): test_requested.emit(); hide())
	content.add_child(test_button)
	var europe_button: = Button.new()
	europe_button.text = "EUROPE MAP · 20 PLAYERS (PREVIEW)"
	europe_button.custom_minimum_size.y = 48
	europe_button.pressed.connect(func():
		europe_button.text = "LOADING EUROPE…"
		europe_button.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
		europe_requested.emit())
	content.add_child(europe_button)
	var world_button: = Button.new()
	world_button.text = "WORLD MAP · 100 PLAYERS (PREVIEW)"
	world_button.custom_minimum_size.y = 48
	world_button.pressed.connect(func():
		world_button.text = "LOADING WORLD…"
		world_button.disabled = true
		await get_tree().process_frame
		await get_tree().process_frame
		world_requested.emit())
	content.add_child(world_button)
	_start_music(content)
	get_viewport().size_changed.connect(_layout)
	_layout()
func _start_music(content: VBoxContainer) -> void:
	if audio == null: return
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	music_button = Button.new()
	sound_button = Button.new()
	for button in [music_button, sound_button]:
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	music_button.pressed.connect(func(): audio.set_music(not GameAudio.music_enabled))
	sound_button.pressed.connect(func(): audio.set_sound(not GameAudio.sound_enabled))
	audio.settings_changed.connect(_show_audio)
	content.add_child(row)
	if GameAudio.custom_menu_theme():
		var credit: = Label.new()
		credit.text = GameAudio.MENU_THEME_CREDIT
		credit.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		credit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		credit.add_theme_font_size_override("font_size", 12)
		credit.add_theme_color_override("font_color", Color("c9bc98"))
		content.add_child(credit)
	_show_audio()
func _show_audio() -> void:
	music_button.text = "MUSIC: " + ("ON" if GameAudio.music_enabled else "OFF")
	sound_button.text = "SOUND: " + ("ON" if GameAudio.sound_enabled else "OFF")
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	var portrait: = size.y > size.x
	var art: = "res://assets/interface/campaign_hero_portrait.webp" if portrait else "res://assets/interface/campaign_hero_landscape.webp"
	if ResourceLoader.exists(art): artwork.texture = load(art)
	# Everything scrolls inside the panel; it is tall enough to show the main buttons at once.
	var height: = minf(820.0 if portrait else 660.0, size.y - 24)
	panel.position = Vector2(maxf(12, (size.x - 520) * 0.14), maxf(12, (size.y - height) * (0.25 if portrait else 0.5)))
	var width: = minf(520, size.x - 24)
	content.custom_minimum_size.x = maxf(0, width - 60)
	panel.size = Vector2(width, height)

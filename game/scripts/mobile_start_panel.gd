class_name MobileStartPanel
extends CanvasLayer
signal continue_requested
signal fresh_requested
signal test_requested
var country_picker: OptionButton
func selected_country() -> String:
	return "ukraine" if country_picker.selected == 0 else "russia"
var panel: PanelContainer
var continue_button: Button
var content: VBoxContainer
var artwork: TextureRect
var fresh_button: Button
var test_button: Button
var progress: ProgressBar
var loading_label: Label
var loading: = false
var has_save: = false
func setup(theme: Theme, saved: bool) -> void :
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
	loading_label = Label.new()
	loading_label.text = "Ready"
	content.add_child(loading_label)
	progress = ProgressBar.new()
	progress.value = 100
	progress.custom_minimum_size.y = 24
	content.add_child(progress)
	continue_button = Button.new()
	continue_button.text = "CONTINUE CAMPAIGN"
	continue_button.custom_minimum_size.y = 52
	continue_button.disabled = not saved
	continue_button.visible = saved
	continue_button.pressed.connect( func(): request_start("continue"))
	column.add_child(continue_button)
	fresh_button = Button.new()
	fresh_button.text = "START NEW CAMPAIGN" if saved else "START CAMPAIGN"
	fresh_button.custom_minimum_size.y = 52
	fresh_button.pressed.connect( func(): request_start("fresh"))
	column.add_child(fresh_button)
	test_button = Button.new()
	test_button.text = "ALL WEAPONS · REAL MAP"
	test_button.custom_minimum_size.y = 48
	test_button.pressed.connect(func(): request_start("test"))
	column.add_child(test_button)
	get_viewport().size_changed.connect(_layout)
	_layout()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	var portrait: = size.y > size.x
	var art: = "res://assets/interface/campaign_hero_portrait.webp" if portrait else "res://assets/interface/campaign_hero_landscape.webp"
	if ResourceLoader.exists(art): artwork.texture = load(art)
	var height: = minf(600 if has_save else 540, size.y - 24)
	panel.position = Vector2(maxf(12, (size.x - 520) * 0.14), maxf(12, (size.y - height) * (0.25 if portrait else 0.5)))
	var width: = minf(520, size.x - 24)
	content.custom_minimum_size.x = maxf(0, width - 60)
	panel.size = Vector2(width, height)

func begin_loading() -> void:
	loading = true
	country_picker.disabled = true
	continue_button.disabled = true
	fresh_button.disabled = true
	test_button.disabled = true
	set_progress(0,"Loading campaign")
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

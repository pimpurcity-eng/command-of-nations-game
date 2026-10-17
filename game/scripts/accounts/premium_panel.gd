class_name PremiumPanel
extends CanvasLayer
## Owner 2026-10-16: the Premium membership screen, opened from the home screen and the
## commander profile. Shows what Premium gives, what stays free, and the membership status.
## Billing is not built yet: the buy button says "Coming soon" (Google Play subscription).
signal closed
var overlay: Control
var fields: VBoxContainer
var status: Label
var auth: PlayerAuth

## Opens the shared Premium screen on top of whatever is showing.
static func show_over(parent: Node, account: PlayerAuth = null) -> PremiumPanel:
	var panel: PremiumPanel = null
	for child in parent.get_children():
		if child is PremiumPanel: panel = child
	if panel == null:
		panel = PremiumPanel.new()
		parent.add_child(panel)
	panel.auth = account
	panel.open()
	return panel

func _ready() -> void:
	layer = 31
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.07, 0.97)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.offset_left = 32
	scroll.offset_right = -32
	scroll.offset_top = 60
	scroll.offset_bottom = -40
	overlay.add_child(scroll)
	fields = VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 16)
	scroll.add_child(fields)
	var theme := Theme.new()
	theme.default_font = (func(): StrategyTheme.ensure_symbols(); return load("res://assets/fonts/RobotoCondensed.ttf")).call()
	theme.default_font_size = 28
	var style := StyleBoxFlat.new()
	style.bg_color = Color("172a35")
	style.set_corner_radius_all(18)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	for state in ["normal", "hover", "pressed", "disabled"]: theme.set_stylebox(state, "Button", style)
	theme.set_color("font_color", "Button", Color("f0dec1"))
	fields.theme = theme
	overlay.hide()

func open() -> void:
	build()
	overlay.show()
	if auth != null and auth.signed_in():
		await PlayerPremium.refresh(auth)
		if overlay.visible: build()

func close() -> void:
	overlay.hide()
	closed.emit()

func _label(text: String, size: int = 26, color: Color = Color("f0dec1")) -> Label:
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", size)
	item.add_theme_color_override("font_color", color)
	fields.add_child(item)
	return item

func _button(text: String, action: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size.y = 64
	item.pressed.connect(action)
	fields.add_child(item)
	return item

func build() -> void:
	for child in fields.get_children():
		fields.remove_child(child)
		child.queue_free()
	_label("WARFRONT MANDATE: WW3", 24, Color("c9ad73"))
	_label("★ PREMIUM COMMANDER", 42, Color("e9c46a"))
	if PlayerPremium.is_premium():
		var until := PlayerPremium.until_text()
		_label("Your Premium membership is active" + (" until " + until if not until.is_empty() else "") + ".", 28, Color("e9c46a"))
	else:
		_label("Conveniences for dedicated commanders. Premium never makes your armies stronger: every unit, building and research stays open to everyone.", 26)
	if not PlayerPremium.is_premium():
		_label("Planned price: " + PlayerPremium.PRICE_IDEA + " (Google Play subscription).", 24, Color("a9b4bb"))
		var buy := _button("Coming soon — Google Play subscription", func():
			status.text = "Coming soon: Premium will be a Google Play subscription. Nothing is charged yet.")
		buy.add_theme_color_override("font_color", Color("e9c46a"))
	status = _label("", 24, Color("e9c46a"))
	_label("WHAT PREMIUM GIVES", 30, Color("c9ad73"))
	for benefit in PlayerPremium.BENEFITS:
		_label(("✔ " if benefit.live else "· ") + str(benefit.title) + (" (coming soon)" if not benefit.live else ""), 26, Color("f0dec1") if benefit.live else Color("a9b4bb"))
		_label("    " + str(benefit.text), 22, Color("a9b4bb"))
	_label("FREE FOR EVERY COMMANDER", 30, Color("c9ad73"))
	for item in PlayerPremium.ALWAYS_FREE: _label("✔ " + str(item), 24)
	if auth == null or not auth.signed_in():
		_label("Premium belongs to your commander account. Sign in so it follows you on every device.", 22, Color("a9b4bb"))
	# Test toggle for the owner and testers; never shown in the store builds.
	if OS.is_debug_build():
		_button("Test build: Premium %s (tap to switch)" % ("ON" if PlayerPremium.is_premium() else "OFF"), func():
			PlayerPremium.test_override = 0 if PlayerPremium.is_premium() else 1
			build())
	_button("Back", close)

class_name CowUI
extends RefCounted
## Shared look for the full-screen menus (city, research), modelled on the Call of War
## screens the owner sent: dark header with a centred title and square close button, dark
## status boxes, a tab row, and a light list of picture rows with green action buttons.
const DARK: = Color("23272b")
const DARKER: = Color("1a1d20")
const LINE: = Color("4a4f52")
const GOLD: = Color("e9c46a")
const LIST: = Color("cdc8b6")
const ROW: = Color("dcd7c6")
const INK: = Color("2a2a26")
const GREEN: = Color("4f8a3a")
const RED: = Color("b5413a")

## Textured 9-patch from assets/interface/skin (tools/make_ui_skin.py).
static func skin(name: String, _corner: int = 8, margin: int = 0, tint: Color = Color.WHITE) -> StyleBox:
	var palette: = {"panel_dark": "20282d", "header": "182126", "inset": "263239", "frame": "2d3a41", "list": "e2e2d9", "row": "f1f0e9", "tab_on": "34423d", "tab_off": "232e34", "btn_green": "4b6a4e", "btn_green_pressed": "3b5340", "btn_grey": "92978e", "btn_dark": "2c373d", "btn_red": "944d46", "banner_russia": "f1f0e9", "banner_ukraine": "f1f0e9"}
	if not palette.has(name):
		var art: = StyleBoxTexture.new()
		art.texture = load("res://assets/interface/skin/" + name + ".png")
		art.set_texture_margin_all(_corner)
		art.set_content_margin_all(margin)
		art.modulate_color = tint
		return art
	var style: = box(Color(palette[name]) * tint, 16, Color("c4c8be") if name == "row" else Color("3a464a"), 1, margin)
	if name == "tab_on":
		style.border_color = GOLD
		style.border_width_bottom = 3
		style.border_width_top = 0
		style.border_width_left = 0
		style.border_width_right = 0
	if name == "row": style.shadow_color = Color(0, 0, 0, 0.08);style.shadow_size = 2
	return style

static var _icons: Dictionary = {}
static func icon_texture(kind: String) -> Texture2D:
	var path: = "res://assets/interface/icons/" + kind + ".svg"
	if not ResourceLoader.exists(path): return null
	if not _icons.has(kind): _icons[kind] = load(path)
	return _icons[kind]

static func equipment_picture(id: String) -> Texture2D:
	var air_drawing: String = {"skyguard_russia": "strela10", "patriot_russia": "bukm3"}.get(id, "")
	var air_path: String = "res://assets/interface/illustrations/" + air_drawing + ".png"
	if not air_drawing.is_empty() and ResourceLoader.exists(air_path): return load(air_path)
	var portrait: = "res://assets/interface/portraits/" + id + ".png"
	if ResourceLoader.exists(portrait): return load(portrait)
	var direct: = UnitVisual.preview_path(id)
	if not direct.is_empty() and ResourceLoader.exists(direct): return load(direct)
	var spec: = EquipmentIdentity.spec(id)
	var path: = UnitVisual.stand_in_path(id, spec.get("visual_kind", "armor"))
	for suffix in [".png", "_preview.png"]:
		var candidate: String = path.trim_suffix(".glb") + suffix
		if ResourceLoader.exists(candidate): return load(candidate)
	return UnitVisual.preview_texture(id)

static func research_picture(id: String, level: int) -> Texture2D:
	var tier_name: String = EquipmentIdentity.research_title(id, level)
	var drawing: String = ""
	if id.ends_with("_russia"):
		for pair in [["Strela-10", "strela10"], ["Tor-M2", "torm2"], ["Buk-M3", "bukm3"], ["S-400", "s400"], ["S-500", "s500"]]:
			if tier_name.begins_with(pair[0]): drawing = pair[1]
	var path: String = "res://assets/interface/illustrations/" + drawing + ".png"
	return load(path) if not drawing.is_empty() and ResourceLoader.exists(path) else equipment_picture(id)

static func title_font() -> Font:
	return StrategyTheme.font("RobotoCondensed", 600)

static func box(color: Color, radius: int = 0, border: Color = Color(0, 0, 0, 0), width: int = 0, margin: int = 0) -> StyleBoxFlat:
	var style: = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style

static func label(text: String, size: int, color: Color = Color("efe6cf")) -> Label:
	var result: = Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	if size >= 18: result.add_theme_font_override("font", title_font())
	return result

## Square framed button holding an icon (close, back).
static func square(kind: String) -> Button:
	var button: = Button.new()
	button.custom_minimum_size = Vector2(52, 52)
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, skin("frame", 10, 0, Color.WHITE if state == "normal" else Color(1.15, 1.1, 1.0)))
	var icon: = Icon.new(kind, GOLD, Vector2.ZERO)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 14
	icon.offset_right = -14
	icon.offset_top = 14
	icon.offset_bottom = -14
	button.add_child(icon)
	return button

## Dark header: optional back button, centred title, close button.
static func header(title_text: String, with_back: bool) -> Dictionary:
	var bar: = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", skin("header", 4, 8))
	var row: = HBoxContainer.new()
	bar.add_child(row)
	var back: = square("back")
	back.modulate.a = 1.0 if with_back else 0.0
	back.disabled = not with_back
	row.add_child(back)
	var title: = label(title_text, 28, Color("f3e6c4"))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	title.add_theme_constant_override("shadow_offset_y", 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	row.add_child(title)
	var close: = square("close")
	row.add_child(close)
	return {"bar": bar, "title": title, "back": back, "close": close}

## Dark status box ("No construction", "No research"): icon + text + progress bar.
static func status_box(kind: String) -> Dictionary:
	var panel: = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 84
	panel.add_theme_stylebox_override("panel", skin("inset", 10, 10))
	var row: = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var picture: = TextureRect.new()
	picture.custom_minimum_size = Vector2(56, 56)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.visible = false
	row.add_child(picture)
	var icon: Control = StrategyHUD.Glyph.new(kind, Color("ece6d6"), Vector2(44, 56), 0.9) if kind in ["produce", "research"] else Icon.new(kind, Color("ece6d6"), Vector2(44, 56))
	row.add_child(icon)
	var column: = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(column)
	var text: = label("", 17, Color("ece6d6"))
	text.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 500))
	text.clip_text = true
	column.add_child(text)
	var bar: = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	bar.add_theme_stylebox_override("background", box(Color("3a3f42"), 2))
	bar.add_theme_stylebox_override("fill", box(Color("b8863b"), 2))
	bar.visible = false
	column.add_child(bar)
	return {"panel": panel, "picture": picture, "icon": icon, "text": text, "bar": bar}

## Tab row button (icon above caption); `selected` gets the gold underline.
static func tab(caption: String, kind: String, selected: bool) -> Button:
	var button: = Button.new()
	button.custom_minimum_size = Vector2(84, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, skin("tab_on" if selected else "tab_off", 6, 0, Color.WHITE if state == "normal" or selected else Color(1.2, 1.2, 1.2)))
	var column: = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if not kind.is_empty():
		var icon: Control = StrategyHUD.Glyph.new(kind, GOLD, Vector2(28, 26)) if kind in ["produce", "research", "city", "flag"] else Icon.new(kind, GOLD, Vector2(28, 26))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
	var text: = label(caption, 14, GOLD if selected else Color("e3d9bd"))
	text.add_theme_font_override("font", title_font())
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	return button

## Green (or red) action button with an icon above its caption, like CONSTRUCT.
static func action(caption: String, kind: String, color: Color = GREEN) -> Button:
	var button: = Button.new()
	button.custom_minimum_size = Vector2(118, 56)
	var face: = "btn_red" if color == RED else ("btn_dark" if color == DARK else "btn_green")
	for state in ["normal", "hover", "pressed", "disabled"]:
		var texture: = "btn_grey" if state == "disabled" else (face + "_pressed" if state == "pressed" and face == "btn_green" else face)
		button.add_theme_stylebox_override(state, skin(texture, 12, 0, Color(1.12, 1.12, 1.12) if state == "hover" else Color.WHITE))
	var column: = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(column)
	if not kind.is_empty():
		var icon: = Icon.new(kind, Color.WHITE, Vector2(24, 24))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(icon)
	var text: = label(caption, 13, Color.WHITE)
	text.add_theme_font_override("font", title_font())
	text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	text.add_theme_constant_override("shadow_offset_y", 1)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(text)
	button.set_meta("caption", text)
	return button

## Resource cost: icon with the amount underneath (red when unaffordable).
static func cost(resource: String, amount: float, enough: bool) -> VBoxContainer:
	var column: = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: = TextureRect.new()
	icon.texture = ResourceSites.icon(resource)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(icon)
	var value: = label(short(amount), 13, INK if enough else Color("b0302a"))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(value)
	return column

static func short(amount: float) -> String:
	if amount >= 1000000: return "%.1fm" % (amount / 1000000.0)
	if amount >= 1000: return "%.1fk" % (amount / 1000.0)
	return str(int(amount))

## Section caption in the light list ("Unit production").
static func section(text: String) -> Label:
	var caption: = label(text, 20, INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.custom_minimum_size.y = 48
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return caption

## Small vector icons not in the HUD set: hammer, clock, back, close.
class Icon extends Control:
	var kind: String
	var tint: Color
	func _init(icon_kind: String, color: Color, minimum: Vector2) -> void:
		kind = icon_kind
		tint = color
		custom_minimum_size = minimum
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var texture: = CowUI.icon_texture(kind)
		if texture != null:
			draw_texture_rect(texture, Rect2(Vector2.ZERO, size), false, tint)
			return
		var c: = size * 0.5
		var u: = minf(size.x, size.y) / 24.0
		if tint.get_luminance() > 0.5:
			# Soft drop shadow under light icons so they read as embossed, not flat.
			var keep: = tint
			tint = Color(0, 0, 0, 0.45)
			draw_set_transform(Vector2(1.2, 1.6) * u)
			_shape(c, u)
			draw_set_transform(Vector2.ZERO)
			tint = keep
		_shape(c, u)
	func _shape(c: Vector2, u: float) -> void:
		match kind:
			"hammer":
				draw_line(c + Vector2(-4, -2) * u, c + Vector2(5, 9) * u, tint, 2.6 * u)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -5) * u, c + Vector2(-2, -10) * u, c + Vector2(2, -6) * u, c + Vector2(-5, -1) * u]), tint)
			"clock":
				draw_arc(c, 8 * u, 0, TAU, 24, tint, 1.8 * u)
				draw_line(c, c + Vector2(0, -5) * u, tint, 1.8 * u)
				draw_line(c, c + Vector2(4, 1) * u, tint, 1.8 * u)
			"back":
				draw_polyline(PackedVector2Array([c + Vector2(4, -9) * u, c + Vector2(-5, 0) * u, c + Vector2(4, 9) * u]), tint, 3.2 * u)
			"close":
				draw_line(c + Vector2(-8, -8) * u, c + Vector2(8, 8) * u, tint, 3.2 * u)
				draw_line(c + Vector2(8, -8) * u, c + Vector2(-8, 8) * u, tint, 3.2 * u)
			"flask":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-3, -9) * u, c + Vector2(3, -9) * u, c + Vector2(3, -2) * u, c + Vector2(9, 9) * u, c + Vector2(-9, 9) * u, c + Vector2(-3, -2) * u]), tint)
			"chevrons":
				for dx in [-4, 4]: draw_polyline(PackedVector2Array([c + Vector2(dx - 4, -7) * u, c + Vector2(dx + 3, 0) * u, c + Vector2(dx - 4, 7) * u]), tint, 3.0 * u)

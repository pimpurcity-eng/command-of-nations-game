class_name TrainingCoach
extends Control
## The training's on-screen coach (owner 2026-10-17: "I can barely see the tutorial, like the
## words" / "make it 10 times better"). Call of War look: one solid card above the bottom bar
## with large type, a chapter progress line, the rest of the screen dimmed with a spotlight on
## what to tap, a pulsing tap ring, and a green "done" moment when the player completes a step.
## Sizes are in the game's 720-wide portrait units and the card is capped in width, so phones,
## tablets and landscape browser windows all read the same.
signal show_me
signal continue_pressed
signal skip_pressed

const CARD := Color("141b20")
const CARD_EDGE := Color("e9c46a")
const DONE := Color("5fae4b")
const TEXT := Color("f4efe2")
const SOFT := Color("c9c2b0")
const TRACK := Color("39444b")
const MAX_WIDTH := 740.0

const SPOTLIGHT_SHADER := """
shader_type canvas_item;
uniform vec4 hole = vec4(0.0);
uniform vec2 area = vec2(720.0, 1440.0);
uniform float strength = 0.0;
uniform float round_ = 24.0;
float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
void fragment() {
	vec2 p = UV * area;
	float d = rounded_box(p - (hole.xy + hole.zw * 0.5), hole.zw * 0.5, min(round_, min(hole.z, hole.w) * 0.5));
	float a = strength * smoothstep(0.0, 10.0, d);
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""

var dim: ColorRect
var pulse: Control
var card: PanelContainer
var chapter: Label
var counter: Label
var track: HBoxContainer
var title: Label
var body: Label
var show_button: Button
var main_button: Button
var skip_button: Button
var _style: StyleBoxFlat
var _hole := Rect2()
var _round := false
var _strength := 0.0
var _pulse_time := 0.0
var _bottom := 0.0
var _done := false

func build(theme_source: Theme) -> void:
	theme = theme_source
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SPOTLIGHT_SHADER
	material.shader = shader
	dim.material = material
	add_child(dim)
	pulse = Control.new()
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pulse.draw.connect(_draw_pulse)
	add_child(pulse)
	card = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	_style = CowUI.box(CARD, 22, CARD_EDGE, 0, 26)
	_style.border_width_top = 4
	_style.shadow_color = Color(0, 0, 0, 0.55)
	_style.shadow_size = 18
	_style.content_margin_top = 22
	_style.content_margin_bottom = 24
	card.add_theme_stylebox_override("panel", _style)
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	chapter = _label(22, CowUI.GOLD, 700)
	chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter.clip_text = true
	top.add_child(chapter)
	counter = _label(22, SOFT, 600)
	top.add_child(counter)
	track = HBoxContainer.new()
	track.add_theme_constant_override("separation", 6)
	column.add_child(track)
	title = _label(40, TEXT, 700)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	body = _label(29, TEXT, 500)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_constant_override("line_spacing", 4)
	column.add_child(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	show_button = _button("SHOW ME", Color("2c3a41"))
	show_button.pressed.connect(func(): show_me.emit())
	buttons.add_child(show_button)
	main_button = _button("CONTINUE", CowUI.GREEN)
	main_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_button.pressed.connect(func(): continue_pressed.emit())
	buttons.add_child(main_button)
	skip_button = Button.new()
	skip_button.flat = true
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 600))
	skip_button.add_theme_font_size_override("font_size", 24)
	skip_button.add_theme_color_override("font_color", SOFT)
	skip_button.add_theme_color_override("font_hover_color", TEXT)
	skip_button.custom_minimum_size.y = 56
	skip_button.pressed.connect(func(): skip_pressed.emit())
	column.add_child(skip_button)
	resized.connect(_layout)

func _label(size: int, color: Color, weight: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func make_button(caption: String, color: Color, font_size: int = 28) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150, 84)
	button.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 700))
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var tint: Color = color.lightened(0.1) if state == "hover" else color.darkened(0.18) if state == "pressed" else Color("4a5358") if state == "disabled" else color
		var face := CowUI.box(tint, 14, tint.lightened(0.25) if state != "disabled" else Color("5c666b"), 2, 16)
		face.border_width_top = 2
		face.border_width_bottom = 5
		face.border_color = tint.darkened(0.35)
		button.add_theme_stylebox_override(state, face)
	return button

func _button(caption: String, color: Color) -> Button:
	return make_button(caption, color)

## Fills the card. steps/done drive the segmented progress line.
func present(chapter_text: String, step: int, steps: int, heading: String, text: String, main_text: String, show_me_visible: bool, skip_text: String) -> void:
	_done = false
	_style.border_color = CARD_EDGE
	chapter.text = chapter_text
	counter.text = "%d / %d" % [step + 1, steps] if steps > 1 else ""
	for child in track.get_children(): child.queue_free()
	track.visible = steps > 1
	for i in steps:
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(0, 7)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.color = CowUI.GOLD if i < step else (TEXT if i == step else TRACK)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(bar)
	title.text = heading
	body.text = text
	set_main(main_text, not main_text.is_empty())
	show_button.visible = show_me_visible
	skip_button.text = skip_text
	skip_button.visible = not skip_text.is_empty()
	card.modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	var tween := create_tween().set_parallel()
	tween.tween_property(card, "modulate:a", 1.0, 0.25)
	_layout()

func set_main(text: String, enabled: bool) -> void:
	main_button.visible = not text.is_empty()
	main_button.text = text
	main_button.disabled = not enabled

## The player did it: the card edge turns green and the title gets a tick.
func celebrate() -> void:
	if _done: return
	_done = true
	_style.border_color = DONE
	title.text = "✓  " + title.text
	title.add_theme_color_override("font_color", Color("b9f0a6"))
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.03, 1.03), 0.12)
	tween.tween_property(card, "scale", Vector2.ONE, 0.18)
	tween.tween_callback(func(): title.add_theme_color_override("font_color", TEXT))
	clear_target()

## Spotlight a screen rectangle (root-local units): a rounded outline for buttons, a ring for
## things on the map (round = true).
func point_at(rect: Rect2, round: bool = false) -> void:
	_hole = rect.grow(8 if not round else 0)
	_round = round
	_strength = 0.58

func clear_target() -> void:
	_hole = Rect2()
	_strength = 0.0

func set_card_visible(value: bool) -> void:
	card.visible = value
	if not value: clear_target()

func set_bottom_limit(y: float) -> void:
	if not is_equal_approx(y, _bottom):
		_bottom = y
		_layout()

func contains(point: Vector2) -> bool:
	return card.visible and card.get_global_rect().has_point(point)

func _layout() -> void:
	var area := size
	if area.x <= 0 or not card.visible: return
	var width := minf(area.x - 24.0, MAX_WIDTH)
	# Wrapped text needs the final width before its height is known, so the card is sized from
	# its minimum at that width every frame (cheap; keeps phones, tablets and browsers right).
	card.custom_minimum_size = Vector2(width, 0)
	card.size = Vector2(width, card.get_combined_minimum_size().y)
	var floor_y := _bottom if _bottom > 0.0 else area.y - 24.0
	card.position = Vector2((area.x - width) * 0.5, floor_y - card.size.y - 14.0)
	card.pivot_offset = card.size * 0.5

func _process(delta: float) -> void:
	_pulse_time += delta
	_layout()
	var material := dim.material as ShaderMaterial
	material.set_shader_parameter("area", size)
	material.set_shader_parameter("hole", Vector4(_hole.position.x, _hole.position.y, _hole.size.x, _hole.size.y))
	material.set_shader_parameter("round_", minf(_hole.size.x, _hole.size.y) * 0.5 if _round else 16.0)
	var current: float = material.get_shader_parameter("strength") if material.get_shader_parameter("strength") != null else 0.0
	material.set_shader_parameter("strength", move_toward(current, _strength if _hole.has_area() and card.visible else 0.0, delta * 2.5))
	pulse.queue_redraw()

func _draw_pulse() -> void:
	if not _hole.has_area() or not card.visible: return
	var centre := _hole.get_center()
	var reach := maxf(_hole.size.x, _hole.size.y) * 0.5
	if _round:
		pulse.draw_arc(centre, reach, 0.0, TAU, 64, Color(CowUI.GOLD, 0.95), 4.0, true)
		for i in 2:
			var t := fmod(_pulse_time * 0.9 + float(i) * 0.5, 1.0)
			pulse.draw_arc(centre, reach + 6.0 + t * 40.0, 0.0, TAU, 64, Color(CowUI.GOLD, (1.0 - t) * 0.75), 3.0, true)
	else:
		var outline := StyleBoxFlat.new()
		outline.draw_center = false
		outline.set_border_width_all(4)
		outline.set_corner_radius_all(16)
		outline.border_color = CowUI.GOLD
		outline.anti_aliasing = true
		var t := fmod(_pulse_time * 0.9, 1.0)
		pulse.draw_style_box(outline, _hole)
		outline.border_color = Color(CowUI.GOLD, (1.0 - t) * 0.7)
		outline.set_border_width_all(3)
		pulse.draw_style_box(outline, _hole.grow(4.0 + t * 18.0))
	# A bobbing pointer just above the target.
	var bob := sin(_pulse_time * 5.0) * 8.0
	var tip := Vector2(centre.x, _hole.position.y - 14.0 + bob)
	if tip.y < 90.0: tip = Vector2(centre.x, _hole.end.y + 14.0 - bob)
	var up := tip.y > centre.y
	var direction := -1.0 if up else 1.0
	var arrow := PackedVector2Array([tip, tip + Vector2(-22, -30 * direction), tip + Vector2(-8, -30 * direction), tip + Vector2(-8, -58 * direction), tip + Vector2(8, -58 * direction), tip + Vector2(8, -30 * direction), tip + Vector2(22, -30 * direction)])
	pulse.draw_colored_polygon(arrow, CowUI.GOLD)
	pulse.draw_polyline(arrow + PackedVector2Array([tip]), Color("2a2108"), 2.0)

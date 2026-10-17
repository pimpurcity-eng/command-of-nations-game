class_name TrainingCinema
extends Control
## Full-screen film player for the training (owner 2026-10-17: "I want the video to fit on a phone
## straight up"). A landscape film fills an upright phone edge to edge: the frame is scaled to
## cover the screen and the visible window pans to follow the action (PANS, per film second).
## Portrait or landscape screens both work; captions, a progress line and hold-to-skip sit on top.
signal finished

## Horizontal centre of the action (0 = left edge, 1 = right edge of the film) at a film time.
const PANS := {
	"opening": [[0.0, 0.47], [2.0, 0.52], [3.2, 0.62], [4.2, 0.74], [5.0, 0.55], [6.2, 0.66], [7.4, 0.76],
		[8.2, 0.52], [11.0, 0.55], [12.0, 0.36], [13.0, 0.42], [18.0, 0.5], [21.6, 0.5], [22.2, 0.42],
		[25.0, 0.5], [26.4, 0.66], [27.0, 0.5], [30.0, 0.5]],
	"supply": [[0.0, 0.47], [2.4, 0.5], [3.4, 0.58], [5.0, 0.52], [6.0, 0.32], [7.6, 0.4], [8.6, 0.56],
		[12.4, 0.56], [13.2, 0.42], [14.2, 0.48], [17.5, 0.56], [18.5, 0.46], [20.0, 0.42], [24.0, 0.34],
		[24.8, 0.8], [30.0, 0.8]],
}
## [start, end, kicker, line] in film seconds.
const CAPTIONS := {
	"opening": [[0.6, 6.6, "EASTERN EUROPE · DAWN", "The border is quiet. Not for long."],
		[7.6, 12.4, "", "Armoured columns roll across the frontier."],
		[13.2, 21.2, "", "Airborne troops drop behind the lines."],
		[22.0, 26.8, "", "Every army needs a commander."],
		[27.2, 30.2, "WARFRONT MANDATE", "Your war begins now."]],
	"supply": [[0.6, 5.6, "LVIV · WESTERN UKRAINE", "A European train brings weapons by rail."],
		[6.2, 12.6, "", "Tanks, artillery and air defence ride its flatcars."],
		[13.6, 23.6, "ODESA · BLACK SEA", "An American ship brings tanks and a fighter jet."],
		[24.6, 30.2, "", "The aid has landed. Now put it to work."]],
}
const HOLD_TO_SKIP := 0.7

var film := "opening"
var player: VideoStreamPlayer
var frame: Control
var kicker: Label
var line: Label
var caption_box: VBoxContainer
var progress: ColorRect
var skip_button: Button
var skip_fill: ColorRect
var message: Label
var _holding := false
var _hold := 0.0
var _caption := -1
var _done := false
var _length := 30.0

func setup(which: String, path: String, start_at: float, sound_on: bool) -> void:
	film = which
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.volume_db = -4.0 if sound_on else -80.0
	frame.add_child(player)
	# Cinematic grade: soft vignette top and bottom keeps captions readable on any shot.
	for top in [true, false]:
		var shade := TextureRect.new()
		var gradient := Gradient.new()
		gradient.set_color(0, Color(0, 0, 0, 0.78 if top else 0.0))
		gradient.set_color(1, Color(0, 0, 0, 0.0 if top else 0.88))
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill_from = Vector2(0, 0)
		texture.fill_to = Vector2(0, 1)
		texture.width = 4
		texture.height = 64
		shade.texture = texture
		shade.stretch_mode = TextureRect.STRETCH_SCALE
		shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top: shade.offset_bottom = 260
		else: shade.offset_top = -520
		add_child(shade)
	caption_box = VBoxContainer.new()
	caption_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	caption_box.add_theme_constant_override("separation", 6)
	caption_box.modulate.a = 0.0
	add_child(caption_box)
	kicker = _text(24, CowUI.GOLD, 700)
	caption_box.add_child(kicker)
	line = _text(40, Color.WHITE, 700)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_box.add_child(line)
	progress = ColorRect.new()
	progress.color = CowUI.GOLD
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(progress)
	skip_button = Button.new()
	skip_button.text = "HOLD TO SKIP  ›"
	skip_button.focus_mode = Control.FOCUS_NONE
	skip_button.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", 700))
	skip_button.add_theme_font_size_override("font_size", 24)
	skip_button.add_theme_color_override("font_color", Color.WHITE)
	for state in ["normal", "hover", "pressed", "focus"]:
		skip_button.add_theme_stylebox_override(state, CowUI.box(Color(0, 0, 0, 0.5), 30, Color(1, 1, 1, 0.45), 2, 14))
	skip_button.clip_contents = true
	skip_button.button_down.connect(func(): _holding = true)
	skip_button.button_up.connect(func(): _holding = false)
	add_child(skip_button)
	skip_fill = ColorRect.new()
	skip_fill.color = Color(CowUI.GOLD, 0.55)
	skip_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_button.add_child(skip_fill)
	skip_button.move_child(skip_fill, 0)
	message = _text(30, Color.WHITE, 600)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(message)
	resized.connect(_layout)
	if ResourceLoader.exists(path) and load(path) is VideoStream:
		player.stream = load(path)
		player.finished.connect(_finish)
		player.play()
		player.stream_position = start_at
		_length = maxf(player.get_stream_length(), 1.0)
	else:
		message.text = "This film is not included in this build.\nTap Continue."
		skip_button.text = "CONTINUE  ›"
		skip_button.pressed.connect(_finish)
	_layout()

func _text(size: int, color: Color, weight: int) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", StrategyTheme.font("RobotoCondensed", weight))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Horizontal action centre for a film time, eased between the PANS keyframes.
static func pan_at(which: String, time: float) -> float:
	var keys: Array = PANS.get(which, [[0.0, 0.5]])
	if time <= keys[0][0]: return keys[0][1]
	for i in range(1, keys.size()):
		if time <= keys[i][0]:
			var span: float = maxf(keys[i][0] - keys[i - 1][0], 0.001)
			var t := clampf((time - keys[i - 1][0]) / span, 0.0, 1.0)
			return lerpf(keys[i - 1][1], keys[i][1], t * t * (3.0 - 2.0 * t))
	return keys[-1][1]

func _layout() -> void:
	var screen := size
	if screen.x <= 0 or screen.y <= 0: return
	var source := Vector2(16, 9)
	var texture := player.get_video_texture() if player.stream != null else null
	if texture != null and texture.get_width() > 0: source = Vector2(texture.get_width(), texture.get_height())
	# Cover: the film fills the screen; on an upright phone the sides are cropped and panned.
	var scale := maxf(screen.x / source.x, screen.y / source.y)
	frame.size = source * scale
	var centre := pan_at(film, player.stream_position if player.stream != null else 0.0)
	frame.position = Vector2(clampf(screen.x * 0.5 - frame.size.x * centre, screen.x - frame.size.x, 0.0), (screen.y - frame.size.y) * 0.5)
	var side := maxf(28.0, (screen.x - 760.0) * 0.5)
	caption_box.offset_left = side
	caption_box.offset_right = -side
	caption_box.offset_bottom = -110
	caption_box.offset_top = -330
	caption_box.alignment = BoxContainer.ALIGNMENT_END
	progress.position = Vector2(0, screen.y - 6)
	progress.size = Vector2(screen.x * clampf(player.stream_position / _length if player.stream != null else 0.0, 0.0, 1.0), 6)
	skip_button.size = Vector2(0, 0)
	var button_size := skip_button.get_combined_minimum_size()
	skip_button.size = button_size
	skip_button.position = Vector2(screen.x - button_size.x - 24, 40)
	skip_fill.position = Vector2.ZERO
	skip_fill.size = Vector2(button_size.x * clampf(_hold / HOLD_TO_SKIP, 0.0, 1.0), button_size.y)
	message.offset_left = -minf(320, screen.x * 0.5 - 24)
	message.offset_right = minf(320, screen.x * 0.5 - 24)

func _process(delta: float) -> void:
	if _done: return
	if _holding: _hold += delta
	else: _hold = maxf(0.0, _hold - delta * 3.0)
	if _hold >= HOLD_TO_SKIP:
		_finish()
		return
	var time := player.stream_position if player.stream != null else 0.0
	var index := -1
	var list: Array = CAPTIONS.get(film, [])
	for i in list.size():
		if time >= list[i][0] and time < list[i][1]: index = i
	if index != _caption:
		_caption = index
		if index >= 0:
			kicker.text = list[index][2]
			kicker.visible = not str(list[index][2]).is_empty()
			line.text = list[index][3]
			caption_box.modulate.a = 0.0
			create_tween().tween_property(caption_box, "modulate:a", 1.0, 0.45)
		else:
			create_tween().tween_property(caption_box, "modulate:a", 0.0, 0.35)
	_layout()

func set_paused(value: bool) -> void:
	if player.stream != null: player.paused = value

func position_seconds() -> float:
	return player.stream_position if player.stream != null and player.is_playing() else 0.0

func _finish() -> void:
	if _done: return
	_done = true
	if player.stream != null: player.stop()
	finished.emit()

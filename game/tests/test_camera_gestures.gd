extends SceneTree
## Camera-only gesture regressions; no private models or running match are needed.
## Finger events from the same frame must be considered together.
const CameraRig = preload("res://scripts/strategy_camera.gd")
var rig: Node3D
var failures: Array[String] = []
var checks: = 0
var taps: = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS ", message)
	else:
		failures.append(message)
		print("FAIL ", message)

func touch(index: int, position: Vector2, pressed: bool) -> void:
	var event: = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	rig._unhandled_input(event)

func drag(index: int, position: Vector2) -> void:
	var event: = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	rig._unhandled_input(event)

func reset_camera() -> void:
	rig.reset_gestures()
	rig.input_blocked = Callable()
	rig.bounds = Rect2(-100, -100, 200, 200)
	rig.target = Vector3.ZERO
	rig.distance = 30.0
	rig.yaw = 0.0
	rig._snap(1.0)
	taps = 0

func begin_pinch() -> void:
	touch(0, Vector2(180, 400), true)
	touch(1, Vector2(360, 400), true)

func run() -> void:
	root.size = Vector2i(540, 960)
	rig = CameraRig.new()
	root.add_child(rig)
	await process_frame
	rig.set_process(false)
	rig.map_clicked.connect(func(_position: Vector2, _order: bool): taps += 1)

	# Both fingers move together, but Android delivers their events one at a time.
	# Test either delivery order: the span is unchanged once the frame is complete.
	for reverse_order in [false, true]:
		reset_camera()
		begin_pinch()
		var start_target: Vector3 = rig.target
		var worst_zoom: = 0.0
		for frame in range(1, 7):
			var offset: = Vector2(frame * 24, frame * 8)
			if reverse_order:
				drag(1, Vector2(360, 400) + offset)
				drag(0, Vector2(180, 400) + offset)
			else:
				drag(0, Vector2(180, 400) + offset)
				drag(1, Vector2(360, 400) + offset)
			rig._process(1.0 / 60.0)
			worst_zoom = maxf(worst_zoom, absf(rig.distance - 30.0))
		check(worst_zoom < 0.0001, "two-finger pan preserves zoom, reverse order=" + str(reverse_order))
		check(rig.target.distance_to(start_target) > 0.5, "two-finger pan still moves the map")
		touch(0, Vector2(324, 448), false)
		touch(1, Vector2(504, 448), false)
		check(taps == 0 and rig.fling == Vector3.ZERO, "pinch release causes no tap or fling")

	reset_camera()
	begin_pinch()
	for frame in range(1, 6):
		drag(0, Vector2(180 - frame * 12, 400))
		drag(1, Vector2(360 + frame * 12, 400))
		rig._process(1.0 / 60.0)
	check(rig.distance < 24.0, "a deliberate pinch still zooms in")

	reset_camera()
	begin_pinch()
	for frame in range(1, 6):
		drag(0, Vector2(180 - frame, 400))
		drag(1, Vector2(360 + frame, 400))
		rig._process(1.0 / 60.0)
	check(is_equal_approx(rig.distance, 30.0), "small span noise stays below the pinch threshold")

	# A release may arrive before the next process frame. Keep the last movement.
	reset_camera()
	begin_pinch()
	drag(0, Vector2(204, 408))
	drag(1, Vector2(384, 408))
	touch(0, Vector2(204, 408), false)
	touch(1, Vector2(384, 408), false)
	check(rig.target.length() > 0.1, "pending pinch movement is applied before release")
	check(is_equal_approx(rig.distance, 30.0), "release before a frame does not invent a zoom")
	check(rig.touches.is_empty() and not rig.pinch_active, "release clears pinch state")

	# UI-consumed releases must also finish the queued gesture before removing a finger.
	reset_camera()
	begin_pinch()
	drag(0, Vector2(204, 408))
	drag(1, Vector2(384, 408))
	rig.input_blocked = func(position: Vector2) -> bool: return position.y > 700.0
	var release: = InputEventScreenTouch.new()
	release.index = 0
	release.position = Vector2(204, 800)
	release.pressed = false
	rig._input(release)
	check(rig.target.length() > 0.1 and is_equal_approx(rig.distance, 30.0), "UI-consumed release flushes movement without zoom")
	check(not rig.touches.has(0), "UI-consumed release removes its finger")

	reset_camera()
	begin_pinch()
	drag(0, Vector2(210, 400))
	drag(1, Vector2(390, 400))
	rig.reset_gestures()
	var reset_target: Vector3 = rig.target
	var reset_distance: float = rig.distance
	rig._process(1.0 / 60.0)
	check(rig.target == reset_target and rig.distance == reset_distance, "gesture reset discards pending movement")
	check(rig.touches.is_empty(), "gesture reset clears all fingers")

	reset_camera()
	touch(0, Vector2(270, 400), true)
	touch(0, Vector2(270, 400), false)
	check(taps == 1, "a normal tap still emits one map click")
	print("RESULT CAMERA_GESTURES checks=", checks, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

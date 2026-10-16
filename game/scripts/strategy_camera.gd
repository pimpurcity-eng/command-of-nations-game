class_name StrategyCamera
extends Node3D
signal map_clicked(screen: Vector2, order: bool)
var camera: = Camera3D.new()
var target: = Vector3(3, 0, -5)
var yaw: = 0.0
var pitch: = 1.02
var distance: = 57.0
var press: = Vector2.ZERO
var last: = Vector2.ZERO
var dragging: = false
var mouse_moved: = false
var button: = 0
var touches: Dictionary = {}
var touch_moved: = false
var pinch_active: = false
var input_blocked: Callable
var rendered_target: = Vector3(3, 0, -5)
var rendered_distance: = 57.0
var rendered_yaw: = 0.0
var rendered_pitch: = 1.02
## Finger taps may wobble a little on high-density phone screens.
const TAP_SLOP: = 14.0
var fling: = Vector3.ZERO
## Where the camera may look (map x/z). Owner 2026-10-15 ("moving side to side ... not doing it
## right"): the old fixed limits stopped panning short of eastern Russia; main sets these from
## the playable map.
var bounds: = Rect2(-20, -28, 48, 48)
## Height of the map surface, so a dragged point stays under the finger.
var ground_height: = 0.2
var _last_drag_usec: = 0
var _drag_velocity: = Vector3.ZERO
## Owner 2026-10-16 ("the camera ... is still a little jiggly"): finger input only moves the goal
## (target / distance); the shown camera follows it with frame-rate independent smoothing, so
## uneven touch timing and uneven phone frames no longer show as jumps. Input is never applied
## twice (the old code snapped the shown camera on every touch event and lerped it again later).
const SMOOTHING: = 20.0
## Two-finger noise: the span must change this much (px) before a pinch starts zooming, so a
## two-finger pan or a resting pinch does not wobble the zoom.
const PINCH_DEAD_ZONE: = 12.0
var _pinch_span: = 0.0
var _pinch_start_span: = 0.0
var _pinch_mid: = Vector2.ZERO
var _pinch_zooming: = false
func _ready() -> void :
	# Move the camera before the armies, labels and cities lay themselves out this frame, so
	# screen-space tags never trail the 3D map by a frame.
	process_priority = -100
	add_child(camera)
	camera.current = true
	camera.fov = 48
	camera.far = 250
	_snap(1.0)
func _process(delta: float) -> void :
	var direction: = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x += 1
	_pan(direction * delta * 450.0)
	# Momentum after a flick, like Call of War's map.
	if fling.length() > 0.01 and touches.is_empty() and not dragging:
		target += fling * delta
		fling *= exp(-delta * 7.0)
	else:
		fling = Vector3.ZERO if not touches.is_empty() or dragging else fling
	_snap(1.0 - exp( - delta * SMOOTHING))
func _clamp_target() -> void:
	target.x = clampf(target.x, bounds.position.x, bounds.end.x)
	target.z = clampf(target.z, bounds.position.y, bounds.end.y)
## Tilt the camera when zoomed in so units and cities read as 3D (Call of War style);
## look more straight down when zoomed out over the whole theater.
## Owner 2026-10-14 ("the camera's not right"): zoomed in it lay almost flat; keep it looking down.
## Owner 2026-10-14 ("it's the camera, the zoom"): the tilt follows the zoom at once instead of
## catching up afterwards, so the map no longer swims after a pinch.
func _tilt(at_distance: float) -> float:
	return minf(pitch, lerpf(0.88, 1.1, smoothstep(5.0, 32.0, at_distance)))
func _pose(at: Vector3, at_distance: float, at_yaw: float) -> Transform3D:
	var tilt: = _tilt(at_distance)
	var offset: = Vector3(sin(at_yaw) * cos(tilt), sin(tilt), cos(at_yaw) * cos(tilt)) * at_distance
	return Transform3D(Basis.IDENTITY, at + offset).looking_at(at, Vector3.UP)
func _snap(weight: float) -> void :
	_clamp_target()
	rendered_target = rendered_target.lerp(target, weight)
	rendered_distance = lerpf(rendered_distance, distance, weight)
	rendered_yaw = lerpf(rendered_yaw, yaw, weight)
	# Settle exactly once it is too close to see, so the labels stop re-laying out.
	if rendered_target.distance_squared_to(target) < 1e-8 and absf(rendered_distance - distance) < 1e-4 and absf(rendered_yaw - yaw) < 1e-5:
		rendered_target = target
		rendered_distance = distance
		rendered_yaw = yaw
	rendered_pitch = _tilt(rendered_distance)
	camera.transform = _pose(rendered_target, rendered_distance, rendered_yaw)
## The map point under a screen position for the camera's goal (where input is aiming), not
## the smoothed camera still on its way there.
func _goal_ground(screen: Vector2) -> Variant:
	var shown: = camera.transform
	camera.transform = _pose(target, distance, yaw)
	var origin: = camera.project_ray_origin(screen)
	var normal: = camera.project_ray_normal(screen)
	camera.transform = shown
	var hit = Plane(Vector3.UP, ground_height).intersects_ray(origin, normal)
	return hit if hit != null and (hit as Vector3).is_finite() else null
func _pan(motion: Vector2) -> void :
	var right: = Vector3(cos(yaw), 0, - sin(yaw))
	var forward: = Vector3(sin(yaw), 0, cos(yaw))
	target += (right * motion.x + forward * motion.y) * distance * 0.0015
func zoom(amount: float) -> void :
	distance = clampf(distance * exp(amount), 4.5, 60.0)
func zoom_at(amount: float, screen: Vector2) -> void:
	# The ground point under the fingers stays under the fingers while zooming. Worked out on
	# the camera's goal, so a pinch never snaps the shown camera (it glides there).
	_clamp_target()
	var before = _goal_ground(screen)
	var old_distance: = distance
	zoom(amount)
	if is_equal_approx(old_distance, distance): return
	var after = _goal_ground(screen)
	if before != null and after != null:
		var shift: Vector3 = (before as Vector3) - (after as Vector3)
		shift.y = 0.0
		target += shift
		_clamp_target()
func _ground_at(screen: Vector2) -> Variant:
	var hit = Plane(Vector3.UP, ground_height).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	return hit if hit != null and (hit as Vector3).is_finite() else null
func reset() -> void :
	target = Vector3(3, 0, -5)
	yaw = 0
	pitch = 1.02
	distance = 57
func _unhandled_input(event: InputEvent) -> void :

	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1: return
	if event is InputEventMouseButton:
		if input_blocked.is_valid() and input_blocked.call(event.position): return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom_at(-0.12, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom_at(0.12, event.position)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				press = event.position
				last = press
				button = event.button_index
				dragging = true
				mouse_moved = false
			else:
				if dragging and event.button_index == button and not mouse_moved and press.distance_to(event.position) < TAP_SLOP and not event.canceled:
					map_clicked.emit(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		mouse_moved = mouse_moved or press.distance_to(event.position) >= TAP_SLOP
		if not mouse_moved: return
		if button == MOUSE_BUTTON_MIDDLE or Input.is_physical_key_pressed(KEY_SHIFT):
			rotate_view( - event.relative.x * 0.004)
			pitch = clampf(pitch + event.relative.y * 0.004, 0.35, 1.35)
		else: _drag_map(last, event.position)
		last = event.position
	elif event is InputEventScreenTouch:
		if event.pressed:
			if input_blocked.is_valid() and input_blocked.call(event.position): return
			touches[event.index] = event.position
			fling = Vector3.ZERO
			_drag_velocity = Vector3.ZERO
			_last_drag_usec = Time.get_ticks_usec()
			if touches.size() > 1:
				touch_moved = true
				pinch_active = true
				_begin_pinch()
			if touches.size() == 1:
				press = event.position
				touch_moved = false
		else:
			if event.canceled: touch_moved = true
			if touches.has(event.index) and touches.size() == 1 and not touch_moved and press.distance_to(event.position) < TAP_SLOP: map_clicked.emit(event.position, false)
			# A finger that stopped before lifting leaves the map where it is.
			var held: = Time.get_ticks_usec() - _last_drag_usec > 80000
			if touches.size() == 1 and touch_moved and not pinch_active: fling = _drag_velocity.limit_length(distance * 2.0) if _drag_velocity.length() > distance * 0.15 and not held else Vector3.ZERO
			touches.erase(event.index)
			if touches.is_empty(): pinch_active = false
			elif touches.size() >= 2: _begin_pinch()
	elif event is InputEventScreenDrag:
		if not touches.has(event.index): return
		var was_moved: = touch_moved
		touch_moved = touch_moved or press.distance_to(event.position) > TAP_SLOP or touches.size() > 1
		if touches.size() >= 2:
			touches[event.index] = event.position
			_update_pinch()
		elif not pinch_active and touch_moved:
			# The first move past the tap slop drags from where the finger went down, so the
			# map point under the finger stays under it (no catch-up jump later).
			_drag_map(press if not was_moved else touches[event.index], event.position, true)
		touches[event.index] = event.position
## Owner 2026-10-16 ("still a little jiggly"): a pinch is read from both fingers' current
## positions together (not one finger against the other's stale one), zooms only after the span
## has clearly changed, and pans by the midpoint.
func _pinch_pair() -> Array:
	var keys: = touches.keys()
	keys.sort()
	return [touches[keys[0]], touches[keys[1]]]
func _begin_pinch() -> void:
	var pair: = _pinch_pair()
	_pinch_mid = (pair[0] + pair[1]) * 0.5
	_pinch_span = (pair[0] as Vector2).distance_to(pair[1])
	_pinch_start_span = _pinch_span
	_pinch_zooming = false
	_drag_velocity = Vector3.ZERO
	fling = Vector3.ZERO
func _update_pinch() -> void:
	var pair: = _pinch_pair()
	var mid: Vector2 = (pair[0] + pair[1]) * 0.5
	var span: float = (pair[0] as Vector2).distance_to(pair[1])
	_drag_map(_pinch_mid, mid, false)
	_pinch_mid = mid
	if not _pinch_zooming and absf(span - _pinch_start_span) >= PINCH_DEAD_ZONE:
		_pinch_zooming = true
		_pinch_span = span
	if _pinch_zooming and _pinch_span >= 16.0 and span >= 16.0:
		zoom_at(log(_pinch_span / span), mid)
	_pinch_span = span
func reset_gestures() -> void :
	fling = Vector3.ZERO
	_drag_velocity = Vector3.ZERO
	touches.clear()
	dragging = false
	mouse_moved = false
	touch_moved = false
	pinch_active = false
	_pinch_zooming = false
func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: reset_gestures()

func rotate_view(amount: float) -> void :
	yaw = clampf(yaw + amount, -1.1, 1.1)
func _drag_map(previous: Vector2, current: Vector2, track_velocity: bool = true) -> void:
	# Both points on the camera's goal, so drags compose exactly while the shown camera glides.
	var a = _goal_ground(previous)
	var b = _goal_ground(current)
	if a != null and b != null:
		var shift: Vector3 = a - b
		shift.y = 0.0
		if shift.is_finite():
			target += shift
			_clamp_target()
			if not track_velocity: return
			# Flick speed from the time between finger events, not the frame time.
			var now: = Time.get_ticks_usec()
			var dt: = clampf(float(now - _last_drag_usec) / 1000000.0, 1.0 / 240.0, 0.1)
			_last_drag_usec = now
			_drag_velocity = _drag_velocity.lerp(shift / dt, 0.35)

func _input(event: InputEvent) -> void :


	if not input_blocked.is_valid(): return
	if event is InputEventScreenTouch and not event.pressed and touches.has(event.index) and input_blocked.call(event.position):
		touch_moved = true
		touches.erase(event.index)
		if touches.is_empty(): pinch_active = false
		elif touches.size() >= 2: _begin_pinch()
	if event is InputEventMouseButton and not event.pressed and dragging and input_blocked.call(event.position): dragging = false

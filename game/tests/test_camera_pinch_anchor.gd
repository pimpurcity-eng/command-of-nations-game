extends SceneTree
## Owner 2026-10-16: keep the map point under the fingers fixed throughout zoom smoothing.
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var rig := StrategyCamera.new()
	root.add_child(rig)
	await process_frame
	rig.set_process(false)
	rig.bounds = Rect2(-100, -100, 200, 200)
	for size in [Vector2i(540, 960), Vector2i(720, 1440), Vector2i(1440, 2880)]:
		root.size = size
		await process_frame
		rig.reset_gestures()
		rig.target = Vector3(2, 0, -3)
		rig.distance = 30.0
		rig._snap(1.0)
		var screen := Vector2(400, 300)
		var start: Vector3 = rig._ground_at(screen)
		for step in 20: rig.zoom_at(-0.08, screen)
		var worst := 0.0
		for frame in 30:
			rig._process(1.0 / 60.0)
			worst = maxf(worst, (rig._ground_at(screen) as Vector3).distance_to(start))
		check(worst < 0.05, "pinch anchor stays fixed throughout smoothing at %s (drift %.6f)" % [size, worst])
		var before := rig.rendered_target
		rig._drag_map(screen, screen + Vector2(80, 0), false)
		for frame in 10: rig._process(1.0 / 60.0)
		check(rig.rendered_target.distance_to(before) > 0.1, "panning after zoom is not trapped by the old anchor")
		rig.target += Vector3(4, 0, 2)
		rig._snap(1.0)
		check(rig.rendered_target.is_equal_approx(rig.target), "a programmatic camera move supersedes the zoom anchor")
	print("RESULT PINCH_ANCHOR checks=", checks, " failures=", failures)
	rig.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

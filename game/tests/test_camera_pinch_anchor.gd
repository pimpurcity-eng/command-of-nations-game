extends SceneTree
## Owner 2026-10-14: pinch zoom must keep the map point under the fingers in place.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(540, 960)
	var rig: = StrategyCamera.new()
	root.add_child(rig)
	await process_frame
	rig.target = Vector3(2, 0, -3)
	rig.distance = 30.0
	rig._snap(1.0)
	var screen: = Vector2(400, 300)
	var start = rig._ground_at(screen)
	var worst: = 0.0
	for step in 20:
		rig.zoom_at(-0.08, screen)
		worst = maxf(worst, (rig._ground_at(screen) as Vector3).distance_to(start))
	for step in 10:
		await process_frame
	var settled: float = (rig._ground_at(screen) as Vector3).distance_to(start)
	print("zoomed to ", rig.distance, " drift ", worst, " after settling ", settled)
	if worst > 0.05 or settled > 0.05:
		print("FAIL pinch anchor drifted")
	else:
		print("PASS pinch anchor")
	quit()

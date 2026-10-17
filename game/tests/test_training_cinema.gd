extends SceneTree
## Owner 2026-10-17: real playback, every phone shape, and recoverable missing/stalled films.
var checks := 0
var failures := 0

class DelayedExtras extends WebExtras:
	var requests := []
	func _want(pack: int, urgent: bool = false) -> void:
		requests.append([pack, urgent])

func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var cinema := TrainingCinema.new()
	root.add_child(cinema)
	cinema.setup("opening", TrainingScenario.OPENING_VIDEO, 0.0, true)
	await create_timer(0.5).timeout
	check(cinema.player.is_playing() and cinema.position_seconds() > 0.1, "real opening frames decode and advance")
	for area in [Vector2(320, 640), Vector2(720, 1440), Vector2(720, 1560), Vector2(1080, 2340), Vector2(1440, 720)]:
		cinema.size = area
		cinema.fill_screen = true
		cinema._layout()
		check(cinema.frame.size.x >= area.x - 1 and cinema.frame.size.y >= area.y - 1, "upright film covers %s" % area)
		check(not cinema.fit_button.get_rect().intersects(cinema.skip_button.get_rect()), "film controls stay separate on %s" % area)
		cinema.fill_screen = false
		cinema._layout()
		check(Rect2(Vector2.ZERO, area).grow(1).encloses(cinema.frame.get_rect()), "full-frame option preserves the whole film on %s" % area)
	cinema.set_paused(true)
	cinema._process(TrainingCinema.STALL_TIMEOUT + 1.0)
	check(not cinema.retry_button.visible, "background pausing is not mistaken for failed playback")
	cinema.set_paused(false)
	cinema._last_position = cinema.player.stream_position
	cinema.player.paused = true
	cinema._process(TrainingCinema.STALL_TIMEOUT + 1.0)
	check(cinema.retry_button.visible and cinema.message.text.contains("Playback stopped"), "a stuck decoder offers Retry and Continue")
	cinema.retry_button.pressed.emit()
	check(cinema.player.is_playing() and not cinema.retry_button.visible, "Retry starts the installed film again")
	var ends := []
	cinema.finished.connect(func(): ends.append(true))
	cinema._finish()
	cinema._finish()
	check(ends.size() == 1, "film completion is delivered exactly once")
	cinema.queue_free()
	var available := WebExtras.available
	var needs := WebExtras._needs.duplicate(true)
	var loaded := WebExtras._loaded.duplicate(true)
	var instance := WebExtras._instance
	var delayed := DelayedExtras.new()
	root.add_child(delayed)
	WebExtras.available = false
	WebExtras._needs = {TrainingScenario.SUPPLY_VIDEO: [999]}
	WebExtras._loaded = {}
	var waiting := TrainingCinema.new()
	root.add_child(waiting)
	waiting.setup("supply", TrainingScenario.SUPPLY_VIDEO, 0.0, true)
	check(waiting._waiting and delayed.requests.has([999, true]), "a requested film takes priority over background weapon downloads")
	waiting._process(TrainingCinema.LOAD_TIMEOUT + 0.1)
	check(not waiting._waiting and waiting.retry_button.visible, "a failed web download cannot hold the tutorial forever")
	waiting.retry_button.pressed.emit()
	WebExtras._loaded[999] = true
	waiting._process(0.1)
	check(waiting.player.is_playing() and not waiting._waiting, "a retried download starts once its pack is ready")
	waiting._finish()
	waiting.queue_free()
	delayed.queue_free()
	WebExtras.available = available
	WebExtras._needs = needs
	WebExtras._loaded = loaded
	WebExtras._instance = instance
	print("RESULT TRAINING_CINEMA checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

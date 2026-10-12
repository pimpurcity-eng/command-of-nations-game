extends SceneTree
## Online matches, phone side: a real game connects to a dedicated server process and shows
## the server's state (owner request 2026-10-12).
##   xvfb-run -a godot --path . --script tests/test_multiplayer_phone.gd
var failures: Array[String] = []
const PORT: = 18930
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")

func wait_for(condition: Callable, frames: int = 600) -> bool:
	for i in frames:
		if condition.call(): return true
		await process_frame
	return condition.call()

func run() -> void:
	var save: = "user://matches/phone-test.json"
	for path in [save, save.get_basename() + "_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.set_environment("WM_ALLOW_DEV_TOKENS", "1")
	var server_pid: = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://scripts/net/server_main.gd", "--", "--port", str(PORT), "--match", "phone-test"])
	check(server_pid > 0, "the dedicated server starts")
	ArsenalFixture.use_archive()
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.boot_finished: await process_frame
	var phone: = MatchClient.new()
	game.add_child(phone)
	phone.welcomed.connect(func(_state: Dictionary): phone.attach(game))
	for attempt in 60:
		phone.connect_to("ws://127.0.0.1:%d" % PORT, "dev:matthew", "phone-test", "ukraine")
		if await wait_for(func(): return phone.ws.get_ready_state() in [WebSocketPeer.STATE_OPEN, WebSocketPeer.STATE_CLOSED] , 120) and phone.ws.get_ready_state() == WebSocketPeer.STATE_OPEN: break
		phone.ws = WebSocketPeer.new()
		phone._hello_sent = false
		await create_timer(0.5).timeout
	check(await wait_for(func(): return phone.country == "ukraine", 1200), "the phone joins the online match as Ukraine")
	check(MatchClient.active == phone and GameSession.player_country == "ukraine", "the phone now plays Ukraine through the server")
	var ids: = {}
	for unit in game.units.units: ids[unit.id] = true
	var sent: = {}
	for entry in phone.state.units: sent[entry.id] = true
	check(ids == sent, "the phone shows exactly the armies the server sent")
	check(game.clock.paused, "the phone's own simulation is stopped: the server decides")
	var stock: Dictionary = game.production.stockpiles.ukraine
	check(is_equal_approx(float(stock.funds), float(phone.state.stockpile.funds)), "the phone shows the server's stockpile")
	# A move order from the phone's own controls goes to the server and comes back in a tick.
	var army: Dictionary = {}
	for unit in game.units.units:
		if unit.country == "ukraine" and unit.visual_kind in ["armor", "ifv", "infantry"] and army.is_empty(): army = unit
	var goal: Vector2 = Vector2(army.node.position.x, army.node.position.z)
	for t in game.map.territories:
		if t.playable and t.controller == "ukraine" and t.center.distance_to(goal) > 1.0 and t.center.distance_to(goal) < 4.0: goal = t.center
	game.units.select_unit(game.units.units.find(army))
	var sent_for: int = game.units.order_many(Vector3(goal.x, 0, goal.y))
	check(sent_for == 1 and not army.moving, "the Move button sends the order instead of moving locally")
	check(await wait_for(func(): var a: Dictionary = game.units.find_id(army.id); return not a.is_empty() and a.moving, 600), "the server's tick shows the army on the move")
	var start: Vector3 = game.units.find_id(army.id).node.position
	await create_timer(3.0).timeout
	check(game.units.find_id(army.id).node.position.distance_to(start) > 0.001, "the army glides along as the server moves it")
	phone.leave()
	OS.kill(server_pid)
	for path in [save, save.get_basename() + "_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("ALL PHONE TESTS PASSED")
	else: print("FAILED: ", failures)
	quit(1 if not failures.is_empty() else 0)

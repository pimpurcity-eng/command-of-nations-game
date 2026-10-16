extends SceneTree
## Online matches (owner request 2026-10-12): one server and several phones in one process,
## talking over a real WebSocket on localhost.
##   xvfb-run -a godot --path . --script tests/test_multiplayer.gd
var failures: Array[String] = []
const PORT: = 18910
const URL: = "ws://127.0.0.1:18910"
const SAVE: = "user://test_online_match.json"
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

func client(token: String, country: String = "") -> MatchClient:
	var c: = MatchClient.new()
	root.add_child(c)
	c.connect_to(URL, token, "test", country)
	return c

func last_result(c: MatchClient, op: String) -> Array:
	for i in range(c.results.size() - 1, -1, -1):
		if c.results[i][0] == op: return c.results[i]
	return []

func run() -> void:
	ArsenalFixture.use_archive()
	GameSession.player_country = "russia"
	for path in [SAVE, SAVE.get_basename() + "_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	while not game.boot_finished: await process_frame
	var server: = MatchServer.new()
	server.allow_dev_tokens = true
	server.inactive_seconds = MatchServer.INACTIVE_REAL_SECONDS
	root.add_child(server)
	check(server.start(game, PORT, "test", SAVE) == OK, "the match server listens")
	check(server.ai_seats.size() == 2 and "russia" in server.ai_seats and "ukraine" in server.ai_seats and game.match_rules.ai_enabled, "the AI plays every seat until players join")
	check(not game.clock.paused, "the server's clock runs in real time")

	# Sign-in rules.
	server.allow_dev_tokens = false
	var stranger: = client("dev:mallory")
	check(await wait_for(func(): return stranger.error == "Sign in to play online"), "development sign-ins are refused unless the server allows them")
	server.allow_dev_tokens = true
	var lost: = MatchClient.new()
	root.add_child(lost)
	lost.connect_to(URL, "dev:lost", "another-match", "")
	check(await wait_for(func(): return lost.error == "No such match"), "a phone asking for another match is turned away")

	# Two players join.
	var alice: = client("dev:alice", "russia")
	check(await wait_for(func(): return alice.country == "russia"), "the first player gets the country they asked for")
	var bob: = client("dev:bob", "russia")
	check(await wait_for(func(): return bob.country == "ukraine"), "a taken seat sends the next player to a free one (join in progress)")
	var carol: = client("dev:carol")
	check(await wait_for(func(): return carol.error == "This match is full"), "a full match turns new players away")
	await wait_for(func(): return server.ai_seats.is_empty(), 60)
	check(server.ai_seats.is_empty() and not game.match_rules.ai_enabled, "the AI hands both countries to their players")

	# Fog of war: each phone only gets what its country can see; enemy orders stay secret.
	await wait_for(func(): return alice.state.get("t", "") == "tick", 120)
	var units: UnitSystem = game.units
	var fair: = true
	var secret: = true
	var own: = 0
	for entry in alice.state.units:
		var unit: = units.find_id(entry.id)
		if entry.country == "russia": own += 1
		elif unit.is_empty() or not units.unit_visible(unit, "russia"): fair = false
		if entry.country != "russia" and (entry.has("route") or entry.has("attack_target")): secret = false
	var russian_total: = units.units.filter(func(u: Dictionary): return u.country == "russia" and u.health > 0).size()
	var hidden: = units.units.filter(func(u: Dictionary): return u.country == "ukraine" and not units.unit_visible(u, "russia")).size()
	check(fair and own == russian_total, "Russia's phone gets all its own armies and only the enemies in sight")
	check(hidden == 0 or alice.state.units.size() < units.units.size(), "armies out of sight are not sent at all")
	check(secret, "enemy routes and targets are never sent")
	var mine: Array = alice.state.stockpile.keys()
	mine.sort()
	var theirs: Array = game.production.stockpiles.russia.keys()
	theirs.sort()
	check(mine == theirs and not alice.state.has("stockpiles") and not JSON.stringify(alice.state).contains("\"ukraine\":{\"funds\""), "each phone gets only its own stockpile")

	# Combat removes casualties after their last frame; snapshots already omit them.
	# The server must not index the shorter snapshot with live-array positions.
	var casualty: Dictionary = units.units.filter(func(u: Dictionary): return u.health > 1.0)[0]
	var previous_health: float = casualty.health
	casualty.health = 0.0
	var expected_ids: Dictionary = {}
	for unit in units.units:
		if unit.health > 0.001 and units.unit_visible(unit, "russia"): expected_ids[unit.id] = true
	var casualty_tick: Dictionary = server._state("russia", "tick", false)
	var received_ids: Dictionary = {}
	for entry in casualty_tick.get("units", []): received_ids[entry.id] = true
	check(received_ids == expected_ids and not received_ids.has(casualty.id), "a casualty still in the live array cannot break or misalign the next server tick")
	casualty.health = previous_health

	# Orders are checked against the sender's country.
	var russian: Dictionary = {}
	var ukrainian: Dictionary = {}
	for unit in units.units:
		if unit.country == "russia" and unit.visual_kind in ["armor", "ifv", "infantry"] and russian.is_empty(): russian = unit
		if unit.country == "ukraine" and unit.visual_kind in ["armor", "ifv", "infantry"] and ukrainian.is_empty(): ukrainian = unit
	var goal: Vector2 = Vector2(russian.node.position.x, russian.node.position.z)
	for t in game.map.territories:
		if t.playable and t.controller == "russia" and t.center.distance_to(goal) > 1.0 and t.center.distance_to(goal) < 4.0: goal = t.center
	bob.send_units("move", [russian.id], {"x": goal.x, "z": goal.y})
	check(await wait_for(func(): return not last_result(bob, "move").is_empty()) and not last_result(bob, "move")[1] and not russian.moving, "a player cannot move another country's army")
	alice.send_units("move", [russian.id], {"x": goal.x, "z": goal.y})
	check(await wait_for(func(): return not last_result(alice, "move").is_empty()) and last_result(alice, "move")[1] and russian.moving, "a player's own move order is carried out by the server")
	var ukrainian_kit: = ""
	for equipment in game.production.catalog:
		if equipment.country == "ukraine": ukrainian_kit = equipment.id
	alice.send("produce", {"equipment": ukrainian_kit, "city": "Moscow"})
	check(await wait_for(func(): return not last_result(alice, "produce").is_empty()) and not last_result(alice, "produce")[1], "a player cannot produce the other country's equipment")
	alice.send("research", {"id": ukrainian_kit, "target": 2})
	check(await wait_for(func(): return not last_result(alice, "research").is_empty()) and not last_result(alice, "research")[1], "a player cannot research for the other country")
	alice.send("teleport", {})
	check(await wait_for(func(): return not last_result(alice, "teleport").is_empty()) and last_result(alice, "teleport")[2] == "Unknown order", "unknown orders are refused")

	# The phone's own buttons go to the server while online.
	MatchClient.active = alice
	var russian_kit: = ""
	for equipment in game.production.catalog:
		if equipment.country == "russia" and russian_kit.is_empty(): russian_kit = equipment.id
	var jobs_before: int = game.production.jobs.size()
	var reply: String = game.production.enqueue(russian_kit, "Moscow")
	var local_jobs: int = game.production.jobs.size()
	MatchClient.active = null
	check(reply.is_empty() and local_jobs == jobs_before, "online, the production button sends an order instead of building locally")
	check(await wait_for(func(): return not last_result(alice, "produce").is_empty() and last_result(alice, "produce") != ["produce", false, ""] and alice.results.filter(func(r: Array): return r[0] == "produce").size() >= 2), "the server answers the production order")

	# War and peace between two players.
	alice.send("declare_war")
	check(await wait_for(func(): return game.match_rules.at_war and bob.state.get("at_war", false)), "a declaration of war reaches both phones")
	alice.send("propose", {"to": "ukraine", "kind": "peace"})
	check(await wait_for(func(): return game.match_rules.diplomacy.pending.has("russia>ukraine:peace")), "a peace offer to a player waits for their answer")
	bob.answer("russia", "peace", true)
	check(await wait_for(func(): return not game.match_rules.at_war), "the other player accepts and the war ends")
	alice.send("chat", {"to": "ukraine", "text": "Good game"})
	check(await wait_for(func(): return bob.state.get("diplomacy", {}).get("messages", []).any(func(m: Dictionary): return m.text == "Good game"), 300), "chat reaches the other player")
	alice.send("chat", {"to": "coalition:nobody", "text": "spy"})
	check(await wait_for(func(): return alice.results.any(func(r: Array): return r[0] == "chat" and not r[1])), "players cannot write to a coalition they are not in")

	# AI takeover after two real days, simulated with the persisted wall-clock activity time.
	bob.leave()
	server.seats.ukraine.last_seen = Time.get_unix_time_from_system() - MatchServer.INACTIVE_REAL_SECONDS - 1.0
	check(await wait_for(func(): return "ukraine" in server.ai_seats, 900), "the AI takes over a player who has been away")
	check(game.match_rules.seat_ai.has("ukraine") and game.match_rules.seat_ai.ukraine.country == "ukraine" and not game.match_rules.seat_ai.has("russia"), "only the absent player's country is played by the AI")
	var bob_again: = client("dev:bob")
	check(await wait_for(func(): return bob_again.country == "ukraine"), "a returning player gets their country back")
	check(await wait_for(func(): return not "ukraine" in server.ai_seats, 60), "the AI hands back command when they return")
	var alice_phone2: = client("dev:alice")
	check(await wait_for(func(): return alice_phone2.country == "russia" and not alice.error.is_empty()), "signing in on a second phone moves the seat there")

	# Persistence.
	server.save()
	check(FileAccess.file_exists(SAVE), "the match is saved")
	var seats: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE.get_basename() + "_seats.json"))
	check(seats is Dictionary and seats.seats.russia.user == "dev:alice" and seats.seats.ukraine.user == "dev:bob", "seats are saved with the match")
	var moved_to: = Vector2(russian.node.position.x, russian.node.position.z)
	server.stop()
	var restart: = MatchServer.new()
	restart.allow_dev_tokens = true
	root.add_child(restart)
	check(restart.start(game, PORT + 1, "test", SAVE) == OK and restart.seats.russia.user == "dev:alice", "a restarted server resumes the match and its seats")
	var resumed: = units.find_id(russian.id)
	check(not resumed.is_empty() and Vector2(resumed.node.position.x, resumed.node.position.z).distance_to(moved_to) < 0.5, "armies resume where they were")
	restart.stop()

	for path in [SAVE, SAVE.get_basename() + "_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures.is_empty(): print("ALL MULTIPLAYER TESTS PASSED")
	else: print("FAILED: ", failures)
	quit(1 if not failures.is_empty() else 0)

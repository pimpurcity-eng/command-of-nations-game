extends SceneTree
## Real localhost WebSockets: lobby, country claims, orders and persisted Europe seats.
const PORT: = 18961
const URL: = "ws://127.0.0.1:18961"
const SAVE: = "user://test_europe_online.json"
var checks: = 0
var failures: = 0
var game: Node
var server: MatchServer
var clients: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label)
func wait_for(condition: Callable, seconds: float = 10.0) -> bool:
	var until: = Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < until:
		if condition.call(): return true
		await process_frame
	return condition.call()
func phone(token: String, country: String = "", preview: bool = false) -> MatchClient:
	var c: = MatchClient.new()
	root.add_child(c)
	clients.append(c)
	if preview: c.preview(URL, token, "europe-test")
	else: c.connect_to(URL, token, "europe-test", country)
	return c
func run() -> void:
	MapDefinition.use(MapDefinition.EUROPE)
	GameSession.player_country = "poland"
	UnitSystem.force_mobile = true
	for path in [SAVE, SAVE.get_basename() + "_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game = load(MapDefinition.scene_path()).instantiate()
	root.add_child(game); current_scene = game
	while not game.boot_finished: await process_frame
	server = MatchServer.new()
	server.allow_dev_tokens = true
	root.add_child(server)
	check(server.start(game, PORT, "europe-test", SAVE) == OK, "Europe server listens")
	check(server.countries.size() == 20 and server.ai_seats.size() == 44, "20 claimable countries and 24 permanent AI countries")
	var public: = server.lobby_state()
	check(public.capacity == 20 and public.players == 0 and public.seats.size() == 20, "public lobby shows actual capacity and available countries")
	check(not JSON.stringify(public).contains("user") and not public.has("units") and not public.has("stockpile"), "public lobby reveals no account IDs, armies or resources")
	var lobby: = phone("dev:alice", "", true)
	var info: Dictionary = {}
	lobby.lobby_received.connect(func(data): info.merge(data, true))
	check(await wait_for(func(): return info.get("capacity", 0) == 20), "phone loads match information before choosing a country")
	check(lobby.country.is_empty() and server.seats.poland.user.is_empty(), "browsing does not reserve a country")
	var panel: = MatchLobbyPanel.new()
	root.add_child(panel); panel.open(game.hud.get_child(0).theme, lobby); panel.show_match(info)
	check(panel.countries.item_count == 20 and not panel.join_button.disabled, "home match picker lists all 20 countries")
	lobby.join_country("poland")
	check(await wait_for(func(): return lobby.country == "poland"), "choosing Poland reserves that country")
	var taken: = phone("dev:bob", "poland")
	check(await wait_for(func(): return taken.error.contains("already taken")), "a taken country is refused without silently assigning another")
	check(server.seats.romania.user.is_empty(), "refused country claims do not consume another seat")
	var bob: = phone("dev:bob", "romania")
	check(await wait_for(func(): return bob.country == "romania"), "second player chooses Romania")
	check(server.seats.poland.user == "dev:alice" and server.seats.romania.user == "dev:bob", "each country belongs to one account")
	check(not "poland" in server.ai_seats and not "romania" in server.ai_seats and "serbia" in server.ai_seats and "albania" in server.ai_seats, "players control their countries while unclaimed and small nations keep AI")
	var returning: = phone("dev:alice", "", true)
	var mine: Dictionary = {}
	returning.lobby_received.connect(func(data): mine.merge(data, true))
	check(await wait_for(func(): return mine.get("own_country", "") == "poland"), "signed-in account sees its existing country on another device")
	panel.show_match(mine)
	check(panel.countries.disabled and panel.join_button.text.begins_with("RESUME"), "returning players resume their reserved country")
	check(lobby.state.map == MapDefinition.EUROPE and lobby.state.match == "europe-test" and lobby.state.speed == 1, "welcome identifies the map, match and authoritative 1× speed")
	check(lobby.state.units.all(func(u): return u.country == "poland" or (not u.has("route") and not u.has("attack_target"))), "enemy routes and attack targets remain private")
	check(lobby.state.units.all(func(u): var actual: Dictionary = game.units.find_id(u.id); return not actual.is_empty() and game.units.unit_visible(actual, "poland")), "phone receives only armies in its country's sight")
	var casualty: Dictionary = game.units.units.filter(func(u): return u.health > 1.0)[0]
	var previous_health: float = casualty.health
	casualty.health = 0.0
	var expected_ids: Dictionary = {}
	for unit in game.units.units:
		if unit.health > 0.001 and game.units.unit_visible(unit, "poland"): expected_ids[unit.id] = true
	var casualty_tick: Dictionary = server._state("poland", "tick", false)
	var received_ids: Dictionary = {}
	for entry in casualty_tick.get("units", []): received_ids[entry.id] = true
	check(received_ids == expected_ids and not received_ids.has(casualty.id), "a destroyed army cannot corrupt the Europe server tick or fog of war")
	casualty.health = previous_health
	var foreign: Dictionary = game.units.units.filter(func(u): return u.country == "romania")[0]
	var before: Variant = foreign.get("route", []).duplicate()
	check(not server.command("poland", {"op":"move", "ids":[foreign.id], "x":0, "z":0}).is_empty() and foreign.get("route", []) == before, "players cannot command another country's army")
	check(server.command("poland", {"op":"produce", "equipment":"infantry_romania", "city":"Warsaw"}).contains("country"), "players cannot produce another country's equipment")
	check(server.command("romania", {"op":"declare_war", "to":"serbia"}).is_empty(), "Romania can declare its own war")
	check(game.match_rules.diplomacy.at_war("romania", "serbia") and not game.match_rules.diplomacy.at_war("poland", "serbia"), "declaration uses the sender's country and selected enemy")
	check(server.command("poland", {"op":"declare_war", "to":"belarus"}).is_empty(), "another country can declare a separate war while a war already exists")
	var incompatible: = MatchClient.new()
	root.add_child(incompatible); clients.append(incompatible)
	incompatible._handle({"t":"welcome", "map":MapDefinition.REGIONAL, "country":"russia"})
	check(incompatible.error.contains("different map") and incompatible.country.is_empty(), "phone rejects a different map before applying its state")
	# Claims for the remaining countries persist with the real match, without requiring
	# 18 more rendering clients. Admit is the same post-auth path used above.
	for country in server.countries:
		if country in ["poland", "romania"]: continue
		var peer: = {"ws":WebSocketPeer.new(), "state":"auth", "user":"", "name":"", "country":"", "since":0.0}
		server.admit(peer, "dev:" + country, country, country)
	check(server.lobby_state().players == 20 and server.public_seats().values().all(func(s): return s.claimed), "all 20 country reservations are represented in the match")
	server.save()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE.get_basename() + "_seats.json"))
	check(saved is Dictionary and saved.seats.size() == 20 and saved.seats.poland.user == "dev:alice", "all country reservations are saved")
	lobby.leave(); bob.leave(); returning.leave()
	server.stop()
	var restart: = MatchServer.new()
	restart.allow_dev_tokens = true
	root.add_child(restart)
	check(restart.start(game, PORT, "europe-test", SAVE) == OK and restart.seats.poland.user == "dev:alice" and restart.seats.romania.user == "dev:bob", "server restart restores the Europe match and its country owners")
	server = restart
	var resumed: = phone("dev:alice", "romania")
	check(await wait_for(func(): return resumed.country == "poland"), "returning account resumes Poland even when another country was requested")
	resumed.attach(game)
	check(MatchClient.active == resumed and GameSession.player_country == "poland" and game.clock.paused and not game.match_rules.ai_enabled, "attached phone applies welcome immediately and stops its own simulation")
	var speed: float = game.clock.speed
	game.clock.set_speed(10); game.clock.toggle_pause()
	check(game.clock.speed == speed and game.clock.paused, "phone cannot change the online match speed or pause the server")
	resumed.leave(); MatchClient.active = null
	for c in clients: c.leave()
	restart.stop(); panel.queue_free()
	for path in [SAVE, SAVE.get_basename() + "_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("RESULT EUROPE_ONLINE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)

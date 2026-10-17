extends SceneTree
## Real HTTP eligibility checks plus persistent individual match identities.
var checks := 0
var failures := 0
var listener := TCPServer.new()
var requests: Array = []
var sockets: Array = []
var clients: Array[MatchClient] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS " if ok else "FAIL ") + text)
func wait_for(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await process_frame
	return condition.call()
func _process(_delta: float) -> bool:
	while listener.is_connection_available(): sockets.append({"peer":listener.take_connection(), "bytes":""})
	for socket in sockets.duplicate():
		var peer: StreamPeerTCP = socket.peer
		peer.poll()
		if peer.get_available_bytes() > 0: socket.bytes += peer.get_utf8_string(peer.get_available_bytes())
		if not str(socket.bytes).contains("\r\n\r\n"): continue
		var token := "eligible" if str(socket.bytes).contains("Bearer eligible") else "untrained" if str(socket.bytes).contains("Bearer untrained") else "low"
		requests.append(socket.bytes)
		var data: Variant = {"id":token,"email_confirmed_at":"2026-10-17T00:00:00Z","user_metadata":{"commander_name":token,"level":99,"xp":999999}}
		if str(socket.bytes).begins_with("POST /rest/v1/rpc/multiplayer_access"):
			data = [{"xp":8100 if token != "low" else 8099,"level":10 if token != "low" else 9,"training_complete":token != "untrained"}]
		var body := JSON.stringify(data)
		peer.put_data(("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % body.to_utf8_buffer().size() + body).to_utf8_buffer())
		sockets.erase(socket)
	return false
func phone(token: String) -> MatchClient:
	var client := MatchClient.new()
	root.add_child(client); clients.append(client)
	client.connect_to("ws://127.0.0.1:18972",token,"access-test","russia")
	return client
func run() -> void:
	check(not PlayerAuth.multiplayer_reason({"xp":8099,"training_complete":true}).is_empty(),"level 9 cannot enter regular multiplayer")
	check(PlayerAuth.multiplayer_reason({"xp":8100,"training_complete":true}).is_empty(),"level 10 with training can enter")
	check(not PlayerAuth.multiplayer_reason({"xp":999999,"training_complete":false}).is_empty(),"high XP cannot replace completed training")
	check(not PlayerAuth.multiplayer_reason({}).is_empty(),"missing eligibility fails closed")
	var auth := PlayerAuth.shared(self)
	auth.base_url = "https://test.supabase.co"; auth.public_key = "sb_publishable_test"
	auth.accept_session({"access_token":"fixture","expires_in":3600,"user":{"id":"registry-a","email_confirmed_at":"2026-10-17T00:00:00Z"}},false)
	auth.transport = func(path: String,_payload: Dictionary,_method: int,bearer: String) -> Dictionary:
		check(path == "/rest/v1/rpc/multiplayer_access" and bearer == "fixture","client eligibility uses authenticated database RPC")
		return {"ok":true,"data":{"rows":[{"xp":8100,"training_complete":true}]}}
	check((await auth.multiplayer_access()).ok,"client accepts verified eligibility")
	auth.transport = func(_p,_v,_m,_b): return PlayerAuth.failure("offline")
	check(not (await auth.multiplayer_access()).ok,"client refuses unverifiable access")
	var first := {"url":"wss://play.warfrontmandate.com","map":MapDefinition.REGIONAL,"match":"round-1","country":"russia","token":"must-not-save","access_token":"must-not-save"}
	var second := first.duplicate(); second.match = "round-2"; second.country = "ukraine"
	check(OnlineGames.remember(first)==OK and OnlineGames.remember(second)==OK,"two rounds on one map are stored independently")
	check(OnlineGames.games().size()==2 and OnlineGames.games()[0].match=="round-2","Resume keeps the individual match ID")
	OnlineGames.remember(first)
	check(OnlineGames.games().size()==2 and OnlineGames.games()[0].match=="round-1","rejoining updates the same round without duplicates")
	check(not FileAccess.get_file_as_string(OnlineGames.SAVE_PATH).contains("must-not-save"),"match records never persist credentials")
	check(OnlineGames.games("registry-b").is_empty(),"another account cannot inherit saved games")
	OnlineGames.queue_pending(second); OnlineGames.pending.clear()
	check(OnlineGames.pending_entry().match=="round-2","match choice survives the OAuth page reload")
	OnlineGames.clear_pending()
	check(OnlineGames.pending_entry().is_empty(),"completed or cancelled launch clears its saved intent")
	check(not OnlineGames.valid({"url":"wss://example.invalid","map":MapDefinition.REGIONAL,"match":"x"}),"match records cannot send an account token to an untrusted server")
	auth.clear_session()
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); current_scene = game
	while not game.boot_finished: await process_frame
	check(listener.listen(18973,"127.0.0.1")==OK,"local account HTTP fixture listens")
	var server := MatchServer.new(); root.add_child(server)
	server.supabase_url = "http://127.0.0.1:18973"; server.supabase_key = "fixture-public"
	var save := "user://test_eligibility.json"
	for path in [save,save.get_basename()+"_seats.json"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(server.start(game,18972,"access-test",save)==OK,"real match WebSocket listens with development tokens disabled")
	var low := phone("low")
	check(await wait_for(func(): return low.error.contains("level 10")),"server refuses level 9 despite forged level 99 user metadata")
	check(server.seats.russia.user.is_empty(),"ineligible connection cannot claim a country")
	var untrained := phone("untrained")
	check(await wait_for(func(): return untrained.error.contains("training")),"server refuses high XP without completed training")
	var eligible := phone("eligible")
	check(await wait_for(func(): return eligible.country == "russia"),"server admits a verified trained level 10 account")
	check(server.seats.russia.user=="eligible","eligible account owns only the requested country")
	check(requests.filter(func(request): return str(request).begins_with("POST /rest/v1/rpc/multiplayer_access")).size()==3,"every real join checks eligibility against the account service")
	# My Games rediscovers this account's seat through the real lobby, even without a local record.
	auth.accept_session({"access_token":"eligible","expires_in":3600,"user":{"id":"eligible","email_confirmed_at":"2026-10-17T00:00:00Z"}},false)
	var settings := ConfigFile.new()
	settings.set_value("online","server_url","ws://127.0.0.1:18972")
	settings.set_value("online","match","access-test")
	settings.save(GameAudio.SETTINGS_PATH)
	var browser := MatchBrowserPanel.new(); root.add_child(browser)
	browser.open(game.hud.get_child(0).theme,true)
	check(await wait_for(func(): return not browser.entries.is_empty() and browser.entries[0].ready),"My Games discovers the real round on a fresh device")
	check(browser.entries[0].button.text=="RESUME" and not browser.entries[0].button.disabled,"an existing seat gets its own enabled Resume")
	check(browser.entries[0].info.text.contains("1/2 players"),"browser displays actual server capacity")
	var chosen: Dictionary = {}
	browser.selected.connect(func(entry: Dictionary): chosen.merge(entry,true))
	browser.entries[0].button.pressed.emit()
	check(chosen.get("match","")=="access-test" and chosen.get("country","")=="russia" and chosen.get("resume",false),"Resume targets the exact match and existing country")
	check(OnlineGames.games().size()==1 and OnlineGames.games()[0].match=="access-test","discovered account seat becomes a persistent match record")
	for client in clients: client.leave(); client.queue_free()
	server.stop(); listener.stop(); server.queue_free(); game.queue_free()
	await process_frame
	print("RESULT ONLINE FLOW checks=",checks," failures=",failures)
	quit(1 if failures else 0)

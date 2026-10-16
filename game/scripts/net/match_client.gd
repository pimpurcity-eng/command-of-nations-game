class_name MatchClient
extends Node
## Online matches, phone side (owner request 2026-10-12). Connects to a MatchServer, signs in
## with the player's account token and shows what the server says. While a client is active
## (MatchClient.active), the phone's own orders — moving, attacking, producing, research,
## building, diplomacy, strategic weapons — are sent to the server instead of being carried out
## locally, and the local simulation is paused: the server is the only authority.
## Without a game attached (game == null) it only keeps the received state (tests, bots).
signal welcomed(state: Dictionary)
signal ticked(state: Dictionary)
signal event_received(text: String)
signal result_received(op: String, ok: bool, message: String)
signal closed(reason: String)

## The client whose orders go to the server (null in single-player).
static var active: MatchClient

var ws: = WebSocketPeer.new()
var game: Node
var token: = ""
var match_id: = ""
var wanted_country: = ""
var country: = ""
var state: Dictionary = {}
var results: Array = []        # [op, ok, message], newest last (kept short)
var events: Array = []         # texts, newest last (kept short)
var error: = ""
var _hello_sent: = false
var _closed: = false
var _shown_winner: = false

func connect_to(url: String, account_token: String, match: String, country_wanted: String = "") -> Error:
	token = account_token
	match_id = match
	wanted_country = country_wanted
	ws.inbound_buffer_size = 1 << 22  # a full state can be a few hundred kB
	return ws.connect_to_url(url)

## Lets this client drive `main` (a running main.tscn): orders go to the server from now on.
func attach(main: Node) -> void:
	var needs_state: bool = game != main or active != self
	game = main
	active = self
	game.match_rules.ai_enabled = false
	game.clock.paused = true
	# The welcome may arrive before its handler attaches the running scene. Apply
	# that snapshot now, so country, armies and resources are correct from the first frame.
	if needs_state and not country.is_empty() and not state.is_empty(): _apply(state, true)

func leave() -> void:
	ws.close(1000, "Left the match")
	if active == self: active = null

func is_open() -> bool:
	return ws.get_ready_state() == WebSocketPeer.STATE_OPEN and not country.is_empty()

func _process(delta: float) -> void:
	ws.poll()
	var ready: = ws.get_ready_state()
	if ready == WebSocketPeer.STATE_OPEN and not _hello_sent:
		_hello_sent = true
		_send({"t": "hello", "token": token, "match": match_id, "country": wanted_country})
	# Read even while closing: a refusal arrives just before the server closes the connection.
	while ws.get_available_packet_count() > 0:
		var message: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
		if message is Dictionary: _handle(message)
	match ready:
		WebSocketPeer.STATE_CLOSED:
			if not _closed:
				_closed = true
				if error.is_empty() and ws.get_close_code() == 4000: error = ws.get_close_reason()
				if active == self: active = null
				closed.emit(error if not error.is_empty() else ws.get_close_reason())
	if game != null and active == self:
		game.clock.paused = true
		game.units.glide(delta)

func _handle(message: Dictionary) -> void:
	match str(message.get("t", "")):
		"welcome":
			country = str(message.get("country", ""))
			state = message
			_apply(message, true)
			welcomed.emit(message)
		"tick":
			state.merge(message, true)
			_apply(message, message.has("research"))
			ticked.emit(message)
		"event":
			events.append(str(message.get("text", "")))
			if events.size() > 50: events.pop_front()
			if game != null: game.hud.show_status(events[-1])
			event_received.emit(events[-1])
		"result":
			results.append([str(message.get("op", "")), bool(message.get("ok", false)), str(message.get("message", ""))])
			if results.size() > 50: results.pop_front()
			if game != null and not results[-1][1]: game.hud.show_status(results[-1][2])
			result_received.emit(results[-1][0], results[-1][1], results[-1][2])
		"guard_report":
			if game != null: game.show_guard_report(str(message.get("text", "")))
		"error":
			error = str(message.get("message", ""))
			if game != null: game.hud.show_status(error)

## Sends an order. Returns "" when sent (the server answers with a "result" message).
func send(op: String, data: Dictionary = {}) -> String:
	if not is_open(): return "Not connected to the match server"
	var message: = {"t": "cmd", "op": op}
	message.merge(data)
	_send(message)
	return ""

## Sends an army order for the given army ids; returns how many armies it was sent for.
func send_units(op: String, ids: Array, data: Dictionary = {}) -> int:
	if ids.is_empty(): return 0
	var message: = {"ids": ids.duplicate()}
	message.merge(data)
	return ids.size() if send(op, message).is_empty() else 0

func answer(proposer: String, kind: String, accept: bool) -> String:
	return send("answer", {"from": proposer, "kind": kind, "accept": accept})

func _send(message: Dictionary) -> void:
	ws.send_text(JSON.stringify(message))

## Shows the server's state on the phone.
func _apply(message: Dictionary, full: bool) -> void:
	if game == null: return
	if GameSession.player_country != country:
		GameSession.player_country = country
		game.apply_player_country(false)
	game.clock.elapsed = float(message.get("time", game.clock.elapsed))
	game.units.apply_remote(message.get("units", []))
	var controllers: = {}
	for pair in message.get("territories", []): controllers[pair[0]] = pair[1]
	for t in game.map.territories:
		if controllers.has(t.id): t.controller = controllers[t.id]
	var rules: MatchSystem = game.match_rules
	rules.at_war = bool(message.get("at_war", false))
	game.units.at_war = rules.at_war
	game.map.update_relations(rules.at_war)
	rules.winner = str(message.get("winner", ""))
	rules.victory_type = str(message.get("victory_type", ""))
	if message.has("stockpile"): game.production.stockpiles[country] = message.stockpile
	var gold_changed: bool = message.has("gold") and int(game.production.gold.get(country,0)) != int(message.gold)
	if message.has("gold"): game.production.gold[country] = int(message.gold)
	if message.has("jobs"): game.production.jobs = message.jobs
	if message.has("market"): game.trade.market.apply_remote(message.market)
	if full:
		if message.has("trade_routes"): game.trade.restore({"routes": message.trade_routes, "convoys": message.get("trade_convoys", [])}, false)
		if message.has("research"): game.research.restore(message.research)
		if message.has("buildings"): game.buildings.restore(message.buildings)
		if message.has("victory"): rules.victory.restore(message.victory)
		if message.has("annexation"): rules.annexation.restore(message.annexation)
		if message.has("strategic"): rules.strategic.restore(message.strategic)
		if message.has("chronicle"): rules.chronicle.restore(message.chronicle)
		if message.has("diplomacy"): rules.diplomacy.restore(message.diplomacy)
		rules.diplomacy.ai_countries = message.get("ai_countries", [])
		var guarded: Array = message.get("guards", [])
		for guard_country in game.production.stockpiles: rules.set_guard(guard_country, guard_country in guarded)
	if gold_changed: game.production.changed.emit()
	game.refresh_hud()
	if not rules.winner.is_empty() and not _shown_winner:
		_shown_winner = true
		game.show_result(rules.winner)

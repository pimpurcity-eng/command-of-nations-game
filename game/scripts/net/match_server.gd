class_name MatchServer
extends Node
## Online matches, server side (owner request 2026-10-12, Call of War style).
## One headless Godot process runs one persistent match: the full game (main.tscn) simulates in
## real time and this node is its only authority. Phones connect over WebSocket (wss:// behind
## Caddy in production, see docs/MULTIPLAYER_SERVER.md) and exchange small JSON messages:
##   phone  → {"t": "hello", "token", "match", "country"}   sign in (Supabase access token)
##   phone  → {"t": "cmd", "op", ...}                       an order, checked against the sender's country
##   server → {"t": "welcome", "country", "seats", ...}     the whole state this player may see
##   server → {"t": "tick", ...}                            twice a second: armies in sight, borders, economy
##   server → {"t": "result", "op", "ok", "message"}        the answer to an order
##   server → {"t": "event", "text"}                        news for everyone (captures, launches, joins)
## - Fog of war is enforced here: a phone is only sent the armies its country can see.
## - Seats: each country is held by one account for the whole match; a player who comes back
##   gets the same country (join in progress takes any free seat).
## - The AI plays every empty seat and takes over a player who has been away INACTIVE_SECONDS;
##   it hands back the moment they reconnect.
## - The match is saved every SAVE_EVERY seconds and when the server stops, and resumed on start.
const TICK: = 0.5
const SLOW_EVERY: = 4
const SAVE_EVERY: = 60.0
const HELLO_TIMEOUT: = 15.0
const MAX_COMMANDS_PER_SECOND: = 20
const MAX_MESSAGE_BYTES: = 8192
var countries: Array = ["russia", "ukraine"]
const UNIT_OPS: = ["move", "stop", "attack", "retreat"]
## Private fields of enemy armies that are never sent (their orders are secret).
const HIDDEN_FIELDS: = ["route", "attack_target", "fire_mode", "forced_march", "delay_remaining", "upgrade_remaining", "upgrade_target", "patrol_center", "patrol_phase", "flight_used", "refuel_remaining"]

var guard_reports: Dictionary = {}  # country -> pending "while you were away" report
var game: Node
var tcp: = TCPServer.new()
var peers: Array = []          # {ws, state: new|auth|play, user, name, country, since, budget}
var seats: Dictionary = {}     # country -> {"user", "name", "last_seen"}
var ai_seats: Array = []
var match_id: = "default"
var save_path: = ""
var inactive_seconds: = 600.0
var allow_dev_tokens: = false
var supabase_url: = ""
var supabase_key: = ""
var now: = 0.0
var _tick: = 0.0
var _ticks: = 0
var _save: = 0.0

## Starts serving `main` (a running main.tscn) on `port`. Resumes `path` when it exists.
func start(main: Node, port: int, id: String, path: String, bind: String = "*") -> Error:
	game = main
	countries = game.production.stockpiles.keys()
	match_id = id
	save_path = path
	for country in countries: seats[country] = {"user": "", "name": "", "last_seen": -INF}
	_load()
	game.set_process(false)  # the phone autosave is replaced by the match save
	game.mobile_start.hide()
	game.clock.paused = false
	game.match_rules.online = true
	game.match_rules.report.connect(func(text: String): _broadcast({"t": "event", "text": text}))
	_update_seats()
	return tcp.listen(port, bind)

func stop() -> void:
	save()
	for peer in peers: peer.ws.close(1001, "Server stopping")
	peers.clear()
	tcp.stop()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if game != null and is_instance_valid(game): save()

func _process(delta: float) -> void:
	if game == null: return
	now += delta
	game.clock.paused = false
	while tcp.is_connection_available():
		var ws: = WebSocketPeer.new()
		ws.inbound_buffer_size = MAX_MESSAGE_BYTES * 4
		if ws.accept_stream(tcp.take_connection()) == OK:
			peers.append({"ws": ws, "state": "new", "user": "", "name": "", "country": "", "since": now, "budget": MAX_COMMANDS_PER_SECOND, "refill": now})
	for peer in peers.duplicate():
		peer.ws.poll()
		match peer.ws.get_ready_state():
			WebSocketPeer.STATE_OPEN:
				while peer.ws.get_available_packet_count() > 0:
					_receive(peer, peer.ws.get_packet().get_string_from_utf8())
				if peer.state != "play" and now - peer.since > HELLO_TIMEOUT: _reject(peer, "Sign-in timed out")
				if peer.state == "play": seats[peer.country].last_seen = now
			WebSocketPeer.STATE_CLOSED:
				peers.erase(peer)
	_tick += delta
	if _tick >= TICK:
		_tick = 0.0
		_ticks += 1
		_update_seats()
		for peer in peers:
			if peer.state == "play": _send(peer, _state(peer.country, "tick", _ticks % SLOW_EVERY == 0))
	_save += delta
	if _save >= SAVE_EVERY:
		_save = 0.0
		save()

func _receive(peer: Dictionary, text: String) -> void:
	if text.length() > MAX_MESSAGE_BYTES: return
	var message: Variant = JSON.parse_string(text)
	if not message is Dictionary: return
	match [peer.state, message.get("t", "")]:
		["new", "hello"]: _hello(peer, message)
		["play", "cmd"]:
			peer.budget = minf(MAX_COMMANDS_PER_SECOND, peer.budget + (now - peer.refill) * MAX_COMMANDS_PER_SECOND)
			peer.refill = now
			if peer.budget < 1.0:
				_send(peer, {"t": "result", "op": str(message.get("op", "")), "ok": false, "message": "Too many orders, slow down"})
				return
			peer.budget -= 1.0
			var answer: = command(peer.country, message)
			_send(peer, {"t": "result", "op": str(message.get("op", "")), "ok": answer.is_empty(), "message": answer})
			# The "while you were away" report goes only to the player who switched guard off.
			if guard_reports.has(peer.country): _send(peer, {"t": "guard_report", "text": guard_reports[peer.country]}); guard_reports.erase(peer.country)
		["play", "ping"]: _send(peer, {"t": "pong"})

## Sign-in: development tokens ("dev:<name>") only when allowed; otherwise the Supabase access
## token is checked with Supabase itself.
func _hello(peer: Dictionary, message: Dictionary) -> void:
	if str(message.get("match", "")) != match_id:
		_reject(peer, "No such match")
		return
	var token: = str(message.get("token", ""))
	var wanted: = str(message.get("country", ""))
	peer.state = "auth"
	if token.begins_with("dev:"):
		if not allow_dev_tokens:
			_reject(peer, "Sign in to play online")
			return
		var name: = token.substr(4).strip_edges().left(24)
		if name.is_empty():
			_reject(peer, "Sign in to play online")
			return
		admit(peer, "dev:" + name, name, wanted)
		return
	if supabase_url.is_empty() or token.is_empty():
		_reject(peer, "Sign in to play online")
		return
	var http: = HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if not peers.has(peer): return
		var user: Variant = JSON.parse_string(body.get_string_from_utf8()) if result == HTTPRequest.RESULT_SUCCESS and code == 200 else null
		if not user is Dictionary or str(user.get("id", "")).is_empty():
			_reject(peer, "Your sign-in has expired; sign in again")
			return
		var metadata: Dictionary = user.get("user_metadata", {}) if user.get("user_metadata") is Dictionary else {}
		admit(peer, str(user.id), str(metadata.get("commander_name", "Commander")).left(24), wanted))
	if http.request(supabase_url.trim_suffix("/") + "/auth/v1/user", ["apikey: " + supabase_key, "Authorization: Bearer " + token]) != OK:
		http.queue_free()
		_reject(peer, "Sign-in service unavailable")

## Seats a signed-in player: their old country if they have one, else the one they asked for,
## else any free seat (join in progress).
func admit(peer: Dictionary, user: String, name: String, wanted: String) -> void:
	var country: = ""
	for c in countries:
		if seats[c].user == user: country = c
	if country.is_empty():
		if wanted in countries and seats[wanted].user.is_empty(): country = wanted
		else:
			for c in countries:
				if seats[c].user.is_empty() and country.is_empty(): country = c
	if country.is_empty():
		_reject(peer, "This match is full")
		return
	for other in peers:
		if other != peer and other.user == user and other.state == "play": _reject(other, "Signed in on another device")
	var returning: bool = seats[country].user == user
	seats[country] = {"user": user, "name": name, "last_seen": now}
	peer.merge({"state": "play", "user": user, "name": name, "country": country}, true)
	_update_seats()
	var welcome: = _state(country, "welcome", true)
	welcome.country = country
	_send(peer, welcome)
	_broadcast({"t": "event", "text": "%s %s command of %s" % [name, "resumed" if returning else "took", country.capitalize()]})
	save()

func _reject(peer: Dictionary, reason: String) -> void:
	_send(peer, {"t": "error", "message": reason})
	peer.ws.close(4000, reason)
	peer.state = "closed"

func connected(country: String) -> bool:
	for peer in peers:
		if peer.state == "play" and peer.country == country: return true
	return false

## The AI plays empty seats and players away longer than inactive_seconds.
func _update_seats() -> void:
	var ai: Array = []
	for country in countries:
		var seat: Dictionary = seats[country]
		if seat.user.is_empty() or (not connected(country) and now - float(seat.last_seen) > inactive_seconds): ai.append(country)
	if ai == ai_seats: return
	for country in countries:
		if country in ai and not country in ai_seats and not seats[country].user.is_empty():
			_broadcast({"t": "event", "text": "%s is away · the AI commands %s until they return" % [seats[country].name, country.capitalize()]})
	ai_seats = ai
	game.match_rules.set_ai_countries(ai)

func public_seats() -> Dictionary:
	var result: = {}
	for country in countries:
		result[country] = {"name": seats[country].name, "online": connected(country), "ai": country in ai_seats}
	return result

## What `country` may know: armies in its sight (enemy orders hidden), borders, its economy.
func _state(country: String, kind: String, full: bool) -> Dictionary:
	var units: UnitSystem = game.units
	var rules: MatchSystem = game.match_rules
	var all: = units.snapshot()
	var visible: Array = []
	for i in units.units.size():
		var unit: Dictionary = units.units[i]
		if unit.health <= 0 or not units.unit_visible(unit, country): continue
		var entry: Dictionary = all[i]
		if unit.country != country:
			for field in HIDDEN_FIELDS: entry.erase(field)
		visible.append(entry)
	var borders: Array = []
	for t in game.map.territories:
		if t.playable: borders.append([t.id, t.controller])
	var own_jobs: Array = game.production.jobs.filter(func(job: Dictionary): return game.production.equipment(job.equipment).country == country)
	var state: = {"t": kind, "time": game.clock.elapsed, "units": visible, "territories": borders, "at_war": rules.at_war, "winner": rules.winner, "victory_type": rules.victory_type,
		"market": game.trade.market.snapshot(country), "stockpile": game.production.stockpiles.get(country, {}), "jobs": own_jobs, "seats": public_seats()}
	if full:
		var talks: = rules.diplomacy.snapshot()
		talks.messages = rules.diplomacy.inbox(country)
		var mine: = {}
		for key in rules.diplomacy.pending:
			if key.contains(">" + country + ":") or key.begins_with(country + ">"): mine[key] = rules.diplomacy.pending[key]
		talks.pending = mine
		var strategic: = {"stock": {country: rules.strategic.stock.get(country, {})}, "jobs": rules.strategic.jobs.filter(func(job: Dictionary): return job.country == country), "fallout": rules.strategic.fallout}
		state.merge({"diplomacy": talks, "ai_countries": ai_seats, "guards": rules.guards.keys(), "research": game.research.snapshot(), "buildings": game.buildings.snapshot(), "victory": rules.victory.snapshot(), "annexation": rules.annexation.snapshot(), "strategic": strategic, "chronicle": rules.chronicle.snapshot(), "trade_convoys": game.trade.snapshot().convoys.filter(func(c): return c.country == country), "trade_routes": game.trade.routes_of(country).map(func(r): return {"id": r.id, "country": r.country, "partner": r.partner, "city": r.city, "mode": r.mode, "cargo": r.cargo, "timer": r.timer})})
	return state

## Carries out one order for `country`. Returns "" or the reason it was refused.
func command(country: String, message: Dictionary) -> String:
	var rules: MatchSystem = game.match_rules
	var units: UnitSystem = game.units
	var talks: Diplomacy = rules.diplomacy
	var op: = str(message.get("op", ""))
	if not rules.winner.is_empty(): return "The match is over"
	var ids: Array = message.get("ids", []) if message.get("ids") is Array else []
	var point: = Vector2(float(message.get("x", 0.0)), float(message.get("z", 0.0)))
	if op in UNIT_OPS and ids.is_empty(): return "Select one of your armies"
	if not is_finite(point.x) or not is_finite(point.y): return "Invalid position"
	match op:
		"move":
			return "" if units.command(country, ids, "move", point, "", bool(message.get("append", false))) > 0 else "No army could take that route"
		"stop":
			units.command(country, ids, "stop")
			return ""
		"attack":
			var enemy: = units.find_id(str(message.get("target", "")))
			if enemy.is_empty() or enemy.country == country or not units.unit_visible(enemy, country): return "That target is not in sight"
			if not rules.at_war: rules.declare_war()
			return "" if units.command(country, ids, "attack", Vector2.ZERO, enemy.id) > 0 else "No army could attack"
		"retreat":
			var moved: = 0
			for id in ids.slice(0, 64):
				var unit: = units.find_id(str(id))
				if unit.is_empty() or unit.country != country: continue
				var destination: = rules.retreat(units.stacks.members(unit), Vector2(unit.node.position.x, unit.node.position.z))
				if destination != Vector2.INF: moved += units.command(country, [unit.id], "move", destination)
			return "" if moved > 0 else "No friendly province to retreat to"
		"market_resource":
			return game.trade.market.list_resource(country, str(message.get("city", "")), str(message.get("cargo", "")), int(message.get("amount", 0)), int(message.get("price", 0)))
		"market_unit":
			return game.trade.market.list_unit(country, str(message.get("city", "")), str(message.get("unit", "")), int(message.get("price", 0)))
		"market_interdict":
			return game.trade.market.interdict(country,int(message.get("id",-1)),ids)
		"market_buy":
			return game.trade.market.buy(country, int(message.get("id", -1)), str(message.get("city", "")), str(message.get("mode", "")))
		"market_cancel":
			return game.trade.market.cancel(country, int(message.get("id", -1)))
		"trade_open":
			return game.trade.open_route(country, str(message.get("partner", "")), str(message.get("cargo", "")), str(message.get("city", "")))
		"trade_close":
			for route in game.trade.routes:
				if int(route.id) == int(message.get("id", -1)) and route.country == country:
					game.trade.close_route(route.id)
					return ""
			return "Choose your own trade route"
		"guard":
			# Sleep defence: the server's DefenceAI holds this player's land while they are away.
			var on: = bool(message.get("on", false))
			var away_report: = rules.set_guard(country, on)
			if not away_report.is_empty(): guard_reports[country] = away_report
			_broadcast({"t": "event", "text": "%s %s guard mode" % [country.capitalize(), "switched on" if on else "switched off"]})
			return ""
		"declare_war":
			if rules.at_war: return "Already at war"
			rules.declare_war()
			return ""
		"propose":
			var to: = str(message.get("to", ""))
			if not to in countries or to == country: return "Choose another country"
			if not str(message.get("kind", "")) in ["peace", "right_of_way", "shared_vision", "trade", "coalition"]: return "Unknown proposal"
			return talks.propose(country, to, message.kind, VictoryRules.standings(game.map.territories, rules.cities, countries)).message.replace("Proposal sent", "")
		"answer":
			return talks.answer(country, str(message.get("from", "")), str(message.get("kind", "")), bool(message.get("accept", false)))
		"embargo":
			var to: = str(message.get("to", ""))
			if not to in countries or to == country: return "Choose another country"
			talks.set_embargo(country, to, bool(message.get("on", true)))
			return ""
		"chat":
			var to: = str(message.get("to", "all"))
			var coalition: = talks.coalition_of(country)
			if not (to == "all" or (to in countries and to != country) or (not coalition.is_empty() and to == "coalition:" + coalition)): return "Choose who to write to"
			talks.post(country, to, str(message.get("text", "")))
			return ""
		"coalition_create": return talks.create_coalition(str(message.get("name", "")), country)
		"coalition_join": return talks.join(str(message.get("name", "")), country)
		"coalition_leave":
			talks.leave(country)
			return ""
		"produce":
			var equipment_id: = str(message.get("equipment", ""))
			if game.production.equipment(equipment_id).get("country", "") != country: return "Choose your country's equipment"
			return game.production.enqueue(equipment_id, str(message.get("city", "")))
		"research":
			return game.research.start(str(message.get("id", "")), int(message.get("target", 0)), country)
		"build":
			return game.buildings.enqueue(str(message.get("city", "")), str(message.get("building", "")), country)
		"annex":
			for t in game.map.territories:
				if t.id == str(message.get("territory", "")):
					return rules.annexation.start(t, country, game.production.stockpiles[country], VictoryRules.province_points(game.map.territories, rules.cities))
			return "Tap a captured province first"
		"strategic_build":
			var kind: = str(message.get("kind", ""))
			if not StrategicWeapons.WEAPONS.has(kind): return "Unknown weapon"
			return rules.strategic.build(country, kind, 1 + int(game.clock.elapsed / VictoryRules.DAY), game.production.stockpiles[country])
		"strategic_launch":
			var kind: = str(message.get("kind", ""))
			if not StrategicWeapons.WEAPONS.has(kind): return "Unknown weapon"
			if not rules.at_war: return "Strategic weapons can only be used at war"
			var result: = rules.strategic.launch(country, kind, point, units, game.map.territories)
			if result.ok: rules.report.emit("%s launched a %s · %s" % [country.capitalize(), StrategicWeapons.WEAPONS[kind].name.to_lower(), result.message])
			if result.ok and kind == "nuclear" and not result.get("intercepted", false): rules.nuclear_aftermath(point, StrategicWeapons.WEAPONS[kind].radius)
			return "" if result.ok else result.message
	return "Unknown order"

func save() -> void:
	if game == null or save_path.is_empty(): return
	game.autosave(save_path)
	var file: = FileAccess.open(save_path.get_basename() + "_seats.json", FileAccess.WRITE)
	if file == null: return
	var stored: = {}
	for country in seats: stored[country] = {"user": seats[country].user, "name": seats[country].name}
	file.store_string(JSON.stringify({"match": match_id, "seats": stored}))

func _load() -> void:
	if save_path.is_empty() or not FileAccess.file_exists(save_path): return
	var result: Dictionary = game.session.read_save(save_path, game.map, game.units)
	if result.has("error"):
		push_warning("Match save not resumed: " + str(result.error))
		return
	game.session.restore(result.state, game.clock, game.map, game.units, game.rig)
	var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path.get_basename() + "_seats.json"))
	if stored is Dictionary and stored.get("match", "") == match_id:
		for country in countries:
			var seat: Dictionary = stored.seats.get(country, {})
			seats[country] = {"user": str(seat.get("user", "")), "name": str(seat.get("name", "")), "last_seen": -INF}

func _send(peer: Dictionary, message: Dictionary) -> void:
	if peer.ws.get_ready_state() == WebSocketPeer.STATE_OPEN: peer.ws.send_text(JSON.stringify(message))

func _broadcast(message: Dictionary) -> void:
	for peer in peers:
		if peer.state == "play": _send(peer, message)

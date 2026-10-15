class_name ExternalCountryAI
extends Node
## Optional Groq free-plan strategic advisor. Never runs on a phone/browser.
## The model chooses indices from locally generated actions; it cannot invent server commands.
const URL: = "https://api.groq.com/openai/v1/chat/completions"
const DEFAULT_MODEL: = "openai/gpt-oss-20b"
const MAX_COMPLETION: = 512
var server: MatchServer
var api_key: = ""
var model: = DEFAULT_MODEL
var enabled: = false
var interval: = 900.0
var daily_requests: = 96
var daily_tokens: = 100000
var used_requests: = 0
var used_tokens: = 0
var budget_day: = -1
var budget_path: = ""
var next_country: Dictionary = {}
var global_wait: = 0.0
var country_cursor: = 0
var pending: = false
var status: = "Built-in country AI active; external API disabled"

func configure(owner_server: MatchServer) -> void:
	server = owner_server
	api_key = OS.get_environment("GROQ_API_KEY")
	enabled = OS.get_environment("WM_EXTERNAL_AI") == "1" and not api_key.is_empty()
	if OS.has_environment("WM_AI_MODEL"): model = OS.get_environment("WM_AI_MODEL")
	budget_path = "user://ai_budget_" + server.match_id.validate_filename() + ".json"
	if FileAccess.file_exists(budget_path):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(budget_path))
		if saved is Dictionary:
			budget_day = int(saved.get("day",-1))
			used_requests = int(saved.get("requests",0))
			used_tokens = int(saved.get("tokens",0))
			country_cursor = int(saved.get("cursor",0))
	_roll_day()
	status = "Groq strategic AI ready; built-in tactical AI remains active" if enabled else "Set server-only GROQ_API_KEY and WM_EXTERNAL_AI=1 to enable free-plan AI"

func _roll_day() -> void:
	var today: = int(Time.get_unix_time_from_system() / 86400.0)
	if today == budget_day: return
	budget_day = today; used_requests = 0; used_tokens = 0

func _save_budget() -> void:
	if budget_path.is_empty(): return
	var file: = FileAccess.open(budget_path,FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"day":budget_day,"requests":used_requests,"tokens":used_tokens,"cursor":country_cursor}))

func eligible(country: String) -> bool:
	return server != null and server.game != null and country in server.ai_seats and not server.game.match_rules.guarded(country) and server.game.match_rules.winner.is_empty()

func _process(delta: float) -> void:
	if not enabled or server == null or pending: return
	global_wait = maxf(0.0,global_wait-delta)
	if global_wait > 0: return
	_roll_day()
	if used_requests >= daily_requests or used_tokens >= daily_tokens:
		status = "External AI daily budget reached; built-in AI continues"
		return
	var country: = next_due_country()
	if not country.is_empty(): request_plan(country,candidates(country))

func next_due_country() -> String:
	if server == null or server.ai_seats.is_empty(): return ""
	for offset in server.ai_seats.size():
		var index: int = (country_cursor + offset) % server.ai_seats.size()
		var country: String = server.ai_seats[index]
		if not eligible(country) or server.now < float(next_country.get(country,0.0)): continue
		country_cursor = (index + 1) % server.ai_seats.size()
		return country
	return ""

func candidates(country: String) -> Array:
	var game: Node = server.game
	var result: Array = []
	for strategy in ["economy","balanced","defensive"]:
		result.append({"label":"National strategy: " + strategy,"cmd":{"op":"ai_strategy","strategy":strategy}})
	var cities: Array = game.production.cities.filter(func(c): return game.production.controlled(c,country))
	var added: = 0
	for city in cities:
		if added >= 2: break
		if game.buildings.reason(city.id,"industry",country).is_empty():
			result.append({"label":"Upgrade industry in " + city.name,"cmd":{"op":"build","city":city.id,"building":"industry"}})
			added += 1
	added = 0
	for spec in game.production.catalog:
		if spec.country != country or spec.get("retired",false): continue
		var target: int = game.research.level(spec.id) + 1
		if target <= 5 and game.research.reason(spec.id,target,country).is_empty():
			result.append({"label":"Research %s level %d" % [spec.name,target],"cmd":{"op":"research","id":spec.id,"target":target}})
			added += 1
		if added >= 2: break
	added = 0
	for spec in game.production.catalog:
		if spec.country != country or not game.production.research_lock(spec).is_empty(): continue
		for city in cities:
			if spec.get("requires_port",false) and not city.has("naval_spawn"): continue
			var ready: bool = not game.production.jobs.any(func(j): return j.city == city.name)
			for building in spec.get("building_requirements",{}):
				if game.buildings.level(city.id,building) < int(spec.building_requirements[building]): ready = false
			for cargo in spec.cost:
				if float(game.production.stockpiles[country].get(cargo,0)) < float(spec.cost[cargo]): ready = false
			if ready:
				result.append({"label":"Produce %s at %s" % [spec.name,city.name],"cmd":{"op":"produce","equipment":spec.id,"city":city.name}})
				added += 1
				break
		if added >= 2: break
	for other in server.countries:
		if other == country or result.size() >= 11: continue
		var talks: Diplomacy = game.match_rules.diplomacy
		if not talks.at_war(country,other) and not bool(talks.relation(country,other).get("trade",false)):
			result.append({"label":"Propose peaceful trade with " + other,"cmd":{"op":"propose","to":other,"kind":"trade"}})
	for offer in game.trade.market.offers:
		if result.size() >= 12: break
		if offer.seller == country: continue
		for city in cities:
			var found: = false
			for mode in TransportMarket.MODES:
				if game.trade.market.quote(offer,country,city.id,mode).has("error"): continue
				result.append({"label":"Buy %s from %s for %d via %s" % [offer.cargo,offer.seller,offer.price,mode],"cmd":{"op":"market_buy","id":offer.id,"city":city.id,"mode":mode}})
				found = true; break
			if found: break
	return result.slice(0,12)

func request_plan(country: String, actions: Array) -> void:
	if not enabled or api_key.is_empty() or not eligible(country): return
	var choices: Array = []
	for i in actions.size(): choices.append({"id":i,"action":actions[i].label})
	# No account identifiers, player messages, hidden enemy units or credentials enter the prompt.
	var public_view: = {"country":country,"stock":server.game.production.stockpiles.get(country,{}),"at_war":server.game.match_rules.at_war,"choices":choices}
	var instructions: = "You advise one AI-controlled nation in a fictional strategy game. Play slightly below medium difficulty. Make cautious, imperfect strategic choices rather than maximum-efficiency play. Choose at most one legal action ID from choices; prefer a sensible economy, defence, research and trade balance. Never invent IDs. Return only JSON {\"choices\":[0]}. An empty array means keep the current plan."
	var prompt: = JSON.stringify(public_view)
	if prompt.to_utf8_buffer().size() > 6000: status = "AI prompt too large; built-in AI continues"; return
	var reserved: = instructions.to_utf8_buffer().size() + prompt.to_utf8_buffer().size() + MAX_COMPLETION + 128
	if used_requests >= daily_requests or used_tokens + reserved > daily_tokens: status = "External AI budget reached; built-in AI continues"; return
	used_requests += 1; used_tokens += reserved; _save_budget()
	pending = true
	next_country[country] = server.now + interval
	global_wait = 20.0
	var http: = HTTPRequest.new()
	http.timeout = 15.0; http.body_size_limit = 32768
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free(); pending = false
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			global_wait = 300.0
			status = "External AI unavailable (%d); built-in AI continues" % code
			return
		var response: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not response is Dictionary: status = "Invalid external response; built-in AI continues"; return
		var usage: Dictionary = response.usage if response.get("usage") is Dictionary else {}
		var actual: = int(usage.get("total_tokens",reserved))
		used_tokens += maxi(0,actual)-reserved; _save_budget()
		var answers: Array = response.choices if response.get("choices") is Array else []
		if answers.is_empty() or not answers[0] is Dictionary: return
		var message: Dictionary = answers[0].message if answers[0].get("message") is Dictionary else {}
		var content: String = str(message.get("content",""))
		apply_decision(country,actions,decode(content,actions.size()))
	)
	var body: = {"model":model,"messages":[{"role":"system","content":instructions},{"role":"user","content":prompt}],"max_completion_tokens":MAX_COMPLETION,"reasoning_effort":"low","response_format":{"type":"json_object"}}
	var error: = http.request(URL,["Content-Type: application/json","Authorization: Bearer " + api_key],HTTPClient.METHOD_POST,JSON.stringify(body))
	if error != OK:
		http.queue_free(); pending = false; global_wait = 300.0
		status = "External AI connection unavailable; built-in AI continues"

static func decode(content: String, option_count: int) -> Array:
	if content.length() > 8192: return []
	var parser: = JSON.new()
	if parser.parse(content) != OK: return []
	var response: Variant = parser.data
	if not response is Dictionary or not response.get("choices") is Array: return []
	var selected: Array = []
	for choice in response.choices:
		if not (choice is int or choice is float) or not is_finite(float(choice)) or float(choice) != floor(float(choice)): continue
		var index: = int(choice)
		if index >= 0 and index < option_count and not selected.has(index): selected.append(index)
		if selected.size() == 1: break
	return selected

func apply_decision(country: String, actions: Array, selected: Array) -> void:
	# A player reconnecting or enabling Guard invalidates an in-flight AI decision.
	if not eligible(country): return
	for index in selected.slice(0,1):
		if not index is int or index < 0 or index >= actions.size(): continue
		var command: Dictionary = actions[index].cmd
		if command.op == "ai_strategy":
			if command.get("strategy","") not in ["economy","balanced","defensive"]: continue
			if server.game.match_rules.seat_ai.has(country): server.game.match_rules.seat_ai[country].strategy = command.strategy
		else: server.command(country,command) # normal ownership, resources and rule validation
	status = "Groq strategic plan applied to " + country

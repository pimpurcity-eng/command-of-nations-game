class_name OnlineGames
extends RefCounted
## Account-scoped match identities. A country name alone cannot identify a saved online game.
const SAVE_PATH := "user://online_matches.cfg"
static var pending: Dictionary = {}

static func queue_pending(entry: Dictionary) -> void:
	pending = clean(entry)
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	file.set_value("launch", "pending", pending)
	file.save(SAVE_PATH)

static func pending_entry() -> Dictionary:
	if not pending.is_empty(): return pending.duplicate(true)
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK: return {}
	var entry = file.get_value("launch", "pending", {})
	return clean(entry) if entry is Dictionary and valid(entry) else {}

static func clear_pending() -> void:
	pending.clear()
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	file.erase_section("launch")
	file.save(SAVE_PATH)

static func clean(entry: Dictionary) -> Dictionary:
	var saved: Dictionary = {}
	for field in ["url", "map", "match", "title", "country", "seen", "enabled", "resume", "operation"]:
		if entry.has(field): saved[field] = entry[field]
	return saved

static func account_id() -> String:
	var auth := PlayerAuth.current
	return str(auth.user.get("id", "")) if is_instance_valid(auth) and auth.signed_in() else ""

static func key(entry: Dictionary) -> String:
	return str(entry.get("url", "")) + "|" + str(entry.get("map", "")) + "|" + str(entry.get("match", ""))

static func valid(entry: Dictionary) -> bool:
	var url := str(entry.get("url", ""))
	var trusted := url == "wss://play.warfrontmandate.com" or url.begins_with("wss://play.warfrontmandate.com/") or url.begins_with("ws://127.0.0.1:") or url.begins_with("ws://localhost:")
	return trusted and url.length() < 2048 and str(entry.get("match", "")).length() in range(1, 81) and str(entry.get("map", "")) in [MapDefinition.REGIONAL, MapDefinition.EUROPE]

static func remember(entry: Dictionary, account: String = "") -> Error:
	if account.is_empty(): account = account_id()
	if account.is_empty() or not valid(entry): return ERR_INVALID_PARAMETER
	var file := ConfigFile.new()
	file.load(SAVE_PATH)
	var stored = file.get_value("accounts", account, [])
	var rows: Array = stored if stored is Array else []
	rows = rows.filter(func(item): return item is Dictionary and key(item) != key(entry))
	var saved := clean(entry)
	saved["seen"] = int(Time.get_unix_time_from_system())
	rows.push_front(saved)
	file.set_value("accounts", account, rows.slice(0, 100))
	return file.save(SAVE_PATH)

static func games(account: String = "") -> Array:
	if account.is_empty(): account = account_id()
	if account.is_empty(): return []
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK: return []
	var rows = file.get_value("accounts", account, [])
	if not rows is Array: return []
	return rows.filter(func(item): return item is Dictionary and valid(item)).duplicate(true)

static func configured() -> Array:
	var settings := ConfigFile.new()
	settings.load(GameAudio.SETTINGS_PATH)
	var rows: Array = [{"match": str(settings.get_value("online", "match", "main")), "map": MapDefinition.REGIONAL,
		"url": str(settings.get_value("online", "server_url", "wss://play.warfrontmandate.com")), "title": "Russia vs Ukraine", "enabled": true}]
	if not MapDefinition.is_regional():
		rows.push_front({"match": str(settings.get_value("online", "europe_match", "europe-1")), "map": MapDefinition.EUROPE,
			"url": str(settings.get_value("online", "europe_server_url", "wss://play.warfrontmandate.com/europe")), "title": "Europe · 20 nations", "enabled": true})
	var extra = settings.get_value("online", "matches", [])
	if extra is Array:
		for entry in extra:
			if entry is Dictionary and valid(entry) and not rows.any(func(row): return key(row) == key(entry)): rows.append(entry.duplicate(true))
	return rows

static func find_match(code: String, map_id: String = MapDefinition.id) -> Dictionary:
	for entry in games() + configured():
		if str(entry.match) == code and str(entry.map) == map_id: return entry.duplicate(true)
	return {}

class_name WebExtras
extends Node
## Browser version only. The page downloads a small start pack (map, cities, interface, sounds,
## starting armies); every other weapon model and picture is in its own small pack under extras/
## (tools/split_web_pack.py) and is fetched the first time something needs it.
## Owner 2026-10-15: one 186 MB weapons pack made phone browsers run out of memory ("WebGL context
## lost" in the weapons range), so only what is on screen is downloaded and kept in memory.
## Until a model arrives its unit shows a stand-in; `loaded` tells the game to swap the real one in.
signal loaded
const FOLDER: = "extras/"
const PARALLEL: = 3
static var available: bool = not OS.has_feature("web")
## res:// path -> packs it needs (written by tools/split_web_pack.py as web_extras_index.txt).
static var _needs: Dictionary = {}
static var _loaded: Dictionary = {}
static var _instance: WebExtras
var _queue: Array[int] = []
var _requested: Dictionary = {}
var _active: int = 0

## True when the resource can be loaded now; otherwise starts fetching it and returns false.
static func has(path: String) -> bool:
	if path.is_empty(): return false
	if available: return ResourceLoader.exists(path)
	_read_index()
	if not _needs.has(path): return ResourceLoader.exists(path)
	var ready: = true
	for pack in _needs[path]:
		if not _loaded.has(pack):
			ready = false
			if _instance != null: _instance._want(pack)
	return ready

static func _read_index() -> void:
	if not _needs.is_empty() or not FileAccess.file_exists("res://web_extras_index.txt"): return
	for line in FileAccess.get_file_as_string("res://web_extras_index.txt").split("\n"):
		var parts: = line.split("\t")
		if parts.size() == 2: _needs[parts[0]] = Array(parts[1].split(",")).map(func(n): return int(n))

func _enter_tree() -> void: _instance = self

## Computers have the memory: fetch everything in the background, a few packs at a time.
func start() -> void:
	if available: return
	_read_index()
	var all: Dictionary = {}
	for packs in _needs.values():
		for pack in packs: all[pack] = true
	for pack in all.keys(): _want(pack)

## Fetch everything under a folder in the background (owner 2026-10-15: "where's the art?" -
## the unit pictures only arrived when a menu first asked, so menus showed the old pictures).
func prefetch(prefix: String) -> void:
	if available: return
	_read_index()
	for path in _needs:
		if str(path).begins_with(prefix):
			for pack in _needs[path]: _want(pack)

## urgent: something on screen needs it now, so it goes ahead of background downloads.
func _want(pack: int, urgent: bool = false) -> void:
	if _loaded.has(pack): return
	if _requested.has(pack):
		if urgent and _queue.has(pack):
			_queue.erase(pack)
			_queue.push_front(pack)
		return
	_requested[pack] = true
	if urgent: _queue.push_front(pack)
	else: _queue.append(pack)
	_next()

func _next() -> void:
	while _active < PARALLEL and not _queue.is_empty():
		var pack: int = _queue.pop_front()
		_active += 1
		var http: = HTTPRequest.new()
		http.download_file = "/tmp/warfront_extra_%d.pck" % pack
		http.use_threads = false
		http.download_chunk_size = 4 * 1024 * 1024
		add_child(http)
		http.request_completed.connect(_finished.bind(pack, http))
		var url: String = str(JavaScriptBridge.eval("new URL('%s%d.pck', location.href).href" % [FOLDER, pack]))
		if http.request(url) != OK: _finished(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray(), pack, http)

func _finished(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, pack: int, http: HTTPRequest) -> void:
	_active -= 1
	http.queue_free()
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ProjectSettings.load_resource_pack("/tmp/warfront_extra_%d.pck" % pack, true):
		_loaded[pack] = true
		loaded.emit()
	else:
		push_warning("Weapon pack %d failed (%d / HTTP %d); retrying" % [pack, result, code])
		_requested.erase(pack)
		get_tree().create_timer(5.0).timeout.connect(func(): _want(pack, true))
	_next()

class_name WebExtras
extends Node
## Browser version only (owner 2026-10-14: the 180 MB download was "unacceptable"). The page
## downloads a small start pack (map, cities, interface, sounds, starting armies) and the game
## fetches every other weapon model and picture here, in the background, while you play.
## Until it arrives a unit shows a stand-in and a building its level-1 model; both switch to the
## real models as soon as the pack is loaded. The browser keeps the file, so later visits are quick.
signal loaded
signal progress(fraction: float)
const FILE: = "index.extras.pck"
const LOCAL: = "/tmp/warfront_extras.pck"
static var available: bool = not OS.has_feature("web")
## True when the resource can be loaded now. In the browser version a file from the weapons pack
## is still listed by ResourceLoader.exists before the pack arrives, so look for its import file.
static func has(path: String) -> bool:
	if path.is_empty(): return false
	if not OS.has_feature("web") or available: return ResourceLoader.exists(path)
	return FileAccess.file_exists(path + ".import") or FileAccess.file_exists(path + ".remap") or (FileAccess.file_exists(path) and ResourceLoader.exists(path))
var _http: HTTPRequest
var _size: = 0

func start() -> void:
	if available or _http != null: return
	_http = HTTPRequest.new()
	_http.download_file = LOCAL
	_http.use_threads = false
	# The default 64 KB per frame would take minutes for this file.
	_http.download_chunk_size = 16 * 1024 * 1024
	add_child(_http)
	_http.request_completed.connect(_finished)
	_request()

func _request() -> void:
	var url: String = str(JavaScriptBridge.eval("new URL('%s', location.href).href" % FILE))
	var error: = _http.request(url)
	print("Weapons pack: downloading %s (%s)" % [url, error_string(error)])
	if error != OK: get_tree().create_timer(10.0).timeout.connect(_request)

func fraction() -> float:
	if available: return 1.0
	if _http == null: return 0.0
	var total: = _http.get_body_size()
	return clampf(float(_http.get_downloaded_bytes()) / float(total), 0.0, 1.0) if total > 0 else 0.0

func _process(_delta: float) -> void:
	if _http != null and not available: progress.emit(fraction())

func _finished(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200 and ProjectSettings.load_resource_pack(LOCAL, true):
		available = true
		set_process(false)
		print("Weapons pack: loaded")
		loaded.emit()
		return
	push_warning("Weapons pack download failed (%d / HTTP %d); retrying" % [result, code])
	get_tree().create_timer(10.0).timeout.connect(_request)

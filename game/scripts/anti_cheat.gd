class_name AntiCheat
extends Node
## Warfront Mandate anti-cheat.
##
## 1. START SWEEP  - runs once, after every player has joined and the map has
##    finished loading (not at boot). Checks game files, version, save file and
##    every army/stockpile against the starting baseline. In multiplayer it
##    compares every player's report and the majority wins.
## 2. WATCHDOG     - light checks every few seconds during the match: speed
##    hacks, resources that appear from nowhere, units that appear from nowhere,
##    impossible unit stats.
## 3. SAVE SEAL    - signs the save file so edited saves are caught on load.
##
## Nothing here bans anyone. A flagged match is marked UNRANKED: no medals,
## ranks or achievements are synced to the account. In multiplayer the host can
## also remove the player (see `player_flagged`).
##
## Hook-up (main.gd): see docs/ANTI_CHEAT.md, "Hooking it into the game".

signal sweep_finished(report: Dictionary)
signal player_flagged(player_id: String, verdict: String, findings: Array)
signal match_flagged(reason: String)

const VERSION := "1.0"
const CLEAN := "CLEAN"
const SUSPICIOUS := "SUSPICIOUS"
const CHEATING := "CHEATING"
## Points per finding. 3+ points = CHEATING, 1-2 = SUSPICIOUS.
const WEIGHT := {"info": 0, "warn": 1, "cheat": 3}

## --- Tuning (safe to change) ---
var max_unit_health := 100.0
var max_unit_level := 10
var max_clock_speed := 64.0
## Watchdog runs this often (real seconds).
var check_interval := 2.0
## Real time vs game time may drift this much (0.35 = 35%) before a speed-hack flag.
var speed_tolerance := 0.35
## A resource that jumps by this much with no production event is flagged...
var resource_jump_min := 500.0
## ...but only if the jump is also this big compared with what was there (1.0 = doubled).
var resource_jump_ratio := 1.0
## Ranked matches refuse debug builds.
var ranked := true
## Folder hashed for the game-files fingerprint (empty = find it automatically).
var script_folder := ""

## --- State ---
var game: Node                     # main.gd node (duck-typed: production, units, clock, session)
var flagged := false
var findings: Array = []           # everything found this match
var last_report: Dictionary = {}

var _timer := 0.0
var _wall_start := 0
var _delta_sum := 0.0
var _speed_window_ok := true
var _shadow_stock: Dictionary = {}
var _shadow_units := 0
var _production_events := 0
var _units_produced := 0
var _seen_production_events := 0
var _seen_units_produced := 0
var _armed := false
var _fingerprint_cache := ""

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func attach(main_node: Node) -> void:
	game = main_node
	var production = _read(game, "production")
	if production != null:
		if production.has_signal("changed"):
			production.changed.connect(func(): _production_events += 1)
		if production.has_signal("unit_ready"):
			production.unit_ready.connect(func(_d): _units_produced += 1)
	set_process(false)

# ---------------------------------------------------------------------------
# 1. START SWEEP
# ---------------------------------------------------------------------------

## Call once when everyone has joined and the map is ready.
## `peer_reports`: {player_id: build_report()} from every other player
## (leave empty in single player). Returns the full sweep report.
func run_start_sweep(peer_reports: Dictionary = {}) -> Dictionary:
	findings.clear()
	flagged = false
	var local_id := _local_id()
	var reports: Dictionary = peer_reports.duplicate()
	reports[local_id] = build_report()

	var majority := _majority(reports)
	var players: Dictionary = {}
	for id in reports:
		var report: Dictionary = reports[id]
		var found: Array = _check_report(report, majority)
		var verdict := _verdict(found)
		players[id] = {"verdict": verdict, "findings": found}
		for f in found: findings.append(_tag(f, str(id)))
		if verdict != CLEAN:
			player_flagged.emit(str(id), verdict, found)
			if verdict == CHEATING: _flag_match(str(id) + " failed the start sweep")

	_arm_watchdog()
	last_report = {
		"anti_cheat": VERSION,
		"time": Time.get_datetime_string_from_system(),
		"players": players,
		"match_verdict": CHEATING if flagged else (SUSPICIOUS if findings.any(func(f): return f.level != "info") else CLEAN),
	}
	sweep_finished.emit(last_report)
	return last_report

## Everything a player sends to the host for the sweep. Small and JSON-safe.
func build_report() -> Dictionary:
	var report := {
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"engine": Engine.get_version_info().string,
		"debug_build": OS.is_debug_build(),
		"files": game_fingerprint(),
		"save_seal": _read(game, "anti_cheat_save_ok", true),
		"countries": {},
	}
	var units = _read(game, "units")
	var production = _read(game, "production")
	var counted: Dictionary = {}
	if units != null:
		for unit in units.units:
			var c: String = str(unit.get("country", "?"))
			if not counted.has(c): counted[c] = {"units": 0, "max_health": 0.0, "max_level": 0, "levels": 0}
			counted[c].units += 1
			counted[c].max_health = maxf(counted[c].max_health, float(unit.get("health", 0.0)))
			counted[c].max_level = maxi(counted[c].max_level, int(unit.get("level", 1)))
			counted[c].levels += int(unit.get("level", 1))
	if production != null:
		for c in production.stockpiles:
			if not counted.has(c): counted[c] = {"units": 0, "max_health": 0.0, "max_level": 0, "levels": 0}
			counted[c].stockpile = _rounded(production.stockpiles[c])
	report.countries = counted
	var clock = _read(game, "clock")
	if clock != null: report.clock_speed = float(clock.speed)
	return report

## Hash of every script in the game build. Same build = same hash on every phone.
## A modded APK or edited script gives a different hash.
func game_fingerprint() -> String:
	if not _fingerprint_cache.is_empty(): return _fingerprint_cache
	var files: Array[String] = []
	var folder := script_folder
	if folder.is_empty():
		folder = "res://game/scripts" if DirAccess.dir_exists_absolute("res://game/scripts") else "res://scripts"
	_collect(folder, files)
	files.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in files:
		ctx.update(path.to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(path))
	_fingerprint_cache = ctx.finish().hex_encode() if not files.is_empty() else "no-files"
	return _fingerprint_cache

func _check_report(report: Dictionary, majority: Dictionary) -> Array:
	var out: Array = []
	if report.get("files", "") != majority.get("files", ""):
		out.append(_finding("cheat", "files", "Game files differ from the other players (modded or edited build)"))
	if report.get("game_version", "") != majority.get("game_version", ""):
		out.append(_finding("warn", "version", "Different game version: " + str(report.get("game_version")) + " vs " + str(majority.get("game_version"))))
	if ranked and report.get("debug_build", false):
		out.append(_finding("warn", "debug", "Running a debug build in a ranked match"))
	if not report.get("save_seal", true):
		out.append(_finding("cheat", "save", "Save file was edited outside the game"))
	if float(report.get("clock_speed", 1.0)) > max_clock_speed:
		out.append(_finding("cheat", "speed", "Game speed above the allowed maximum"))
	var countries: Dictionary = report.get("countries", {})
	var base_countries: Dictionary = majority.get("countries", {})
	for c in countries:
		var mine: Dictionary = countries[c]
		if float(mine.get("max_health", 0.0)) > max_unit_health + 0.01:
			out.append(_finding("cheat", "units", c + ": unit health above " + str(max_unit_health)))
		if int(mine.get("max_level", 0)) > max_unit_level:
			out.append(_finding("cheat", "units", c + ": unit level above " + str(max_unit_level)))
		if base_countries.has(c):
			var base: Dictionary = base_countries[c]
			if int(mine.get("units", 0)) != int(base.get("units", 0)):
				out.append(_finding("cheat", "units", c + ": starts with " + str(int(mine.get("units", 0))) + " units, everyone else sees " + str(int(base.get("units", 0)))))
			if int(mine.get("levels", 0)) != int(base.get("levels", 0)):
				out.append(_finding("cheat", "units", c + ": starting unit tiers don't match"))
			if mine.get("stockpile", {}) != base.get("stockpile", {}):
				out.append(_finding("cheat", "resources", c + ": starting resources don't match"))
	return out

## The most common answer for each field becomes the baseline (host breaks ties).
func _majority(reports: Dictionary) -> Dictionary:
	if reports.size() <= 1:
		# Single player: nobody to compare with, so the report is its own baseline.
		# Solo protection comes from the save seal, stat limits and the watchdog.
		return reports.values()[0].duplicate(true)
	var base := {}
	for field in ["files", "game_version"]:
		var votes := {}
		for id in reports: votes[reports[id].get(field, "")] = votes.get(reports[id].get(field, ""), 0) + 1
		var best = reports[_local_id()].get(field, "")
		for value in votes:
			if votes[value] > votes.get(best, 0): best = value
		base[field] = best
	# Country baseline: the most common snapshot of each country.
	var country_votes := {}
	for id in reports:
		var countries: Dictionary = reports[id].get("countries", {})
		for c in countries:
			var key := JSON.stringify(countries[c], "", true)
			if not country_votes.has(c): country_votes[c] = {}
			country_votes[c][key] = country_votes[c].get(key, 0) + 1
	base.countries = {}
	for c in country_votes:
		var best_key := ""
		for key in country_votes[c]:
			if best_key.is_empty() or country_votes[c][key] > country_votes[c][best_key]: best_key = key
		base.countries[c] = JSON.parse_string(best_key)
	return base

# ---------------------------------------------------------------------------
# 2. WATCHDOG (during the match)
# ---------------------------------------------------------------------------

func _arm_watchdog() -> void:
	_armed = true
	_timer = 0.0
	_delta_sum = 0.0
	_wall_start = Time.get_ticks_usec()
	_take_shadow()
	set_process(true)

## Call after loading a save or anything else that legally rewrites the whole game state.
func rebaseline() -> void:
	if _armed: _take_shadow()

func _process(delta: float) -> void:
	_delta_sum += delta
	_timer += delta
	if _timer < check_interval: return
	_timer = 0.0
	run_watchdog()

## One round of in-match checks. Returns any new findings.
func run_watchdog() -> Array:
	var found: Array = []
	found.append_array(_check_speed())
	found.append_array(_check_resources())
	found.append_array(_check_units())
	for f in found:
		findings.append(_tag(f, _local_id()))
		if f.level == "cheat": _flag_match(f.message)
	if not found.is_empty():
		player_flagged.emit(_local_id(), _verdict(found), found)
	return found

## Speed hack: the engine's frame time runs faster than the real clock.
func _check_speed() -> Array:
	var wall := (Time.get_ticks_usec() - _wall_start) / 1000000.0
	var out: Array = []
	if wall >= 10.0:
		var ratio := _delta_sum / wall
		if absf(ratio - 1.0) > speed_tolerance and Engine.time_scale == 1.0:
			out.append(_finding("cheat" if not _speed_window_ok else "warn", "speed", "Game time running at " + str(snappedf(ratio, 0.01)) + "x real time (speed hack)"))
			_speed_window_ok = false
		else:
			_speed_window_ok = true
		_delta_sum = 0.0
		_wall_start = Time.get_ticks_usec()
	var clock = _read(game, "clock")
	if clock != null and float(clock.speed) > max_clock_speed:
		out.append(_finding("cheat", "speed", "Game speed set above the allowed maximum"))
	return out

## Memory editors (GameGuardian etc.) change the number you see on screen.
## The game's production system never knew, so we catch the gap.
func _check_resources() -> Array:
	var out: Array = []
	var production = _read(game, "production")
	if production == null: return out
	var explained := _production_events != _seen_production_events
	for c in production.stockpiles:
		var now: Dictionary = production.stockpiles[c]
		var before: Dictionary = _shadow_stock.get(c, {})
		for r in now:
			var value := float(now[r])
			var old := float(before.get(r, value))
			var jump := value - old
			if is_nan(value) or is_inf(value) or value < -0.01:
				out.append(_finding("cheat", "resources", c + " " + str(r) + " has an impossible value"))
			elif not explained and jump >= resource_jump_min and jump >= absf(old) * resource_jump_ratio:
				out.append(_finding("cheat", "resources", c + " " + str(r) + " jumped " + str(int(old)) + " → " + str(int(value)) + " with no production"))
	_shadow_stock = {}
	for c in production.stockpiles: _shadow_stock[c] = production.stockpiles[c].duplicate()
	_seen_production_events = _production_events
	return out

## Units that appear without being produced, or with impossible stats.
func _check_units() -> Array:
	var out: Array = []
	var units = _read(game, "units")
	if units == null: return out
	var count: int = units.units.size()
	var produced := _units_produced - _seen_units_produced
	if count > _shadow_units + produced:
		out.append(_finding("cheat", "units", str(count - _shadow_units - produced) + " unit(s) appeared without being produced"))
	for unit in units.units:
		if float(unit.get("health", 0.0)) > max_unit_health + 0.01:
			out.append(_finding("cheat", "units", str(unit.get("name", "unit")) + " has " + str(int(unit.health)) + " health"))
		if int(unit.get("level", 1)) > max_unit_level:
			out.append(_finding("cheat", "units", str(unit.get("name", "unit")) + " is level " + str(unit.level)))
	_shadow_units = count
	_seen_units_produced = _units_produced
	return out

func _take_shadow() -> void:
	var production = _read(game, "production")
	_shadow_stock = {}
	if production != null:
		for c in production.stockpiles: _shadow_stock[c] = production.stockpiles[c].duplicate()
	var units = _read(game, "units")
	_shadow_units = units.units.size() if units != null else 0
	_seen_production_events = _production_events
	_seen_units_produced = _units_produced

# ---------------------------------------------------------------------------
# 3. SAVE SEAL
# ---------------------------------------------------------------------------

## Add a seal to the save before writing it.
func seal_save(state: Dictionary) -> Dictionary:
	var clean := state.duplicate(true)
	clean.erase("_seal")
	clean["_seal"] = _sign(clean)
	return clean

## True if the save was written by this game on this phone and not edited.
## Old saves (from before anti-cheat) have no seal and are accepted once.
func verify_save(state: Dictionary) -> bool:
	if not state.has("_seal"): return true
	var copy := state.duplicate(true)
	var seal := str(copy["_seal"])
	copy.erase("_seal")
	return seal == _sign(copy)

func _sign(data: Dictionary) -> String:
	# Canonical text: numbers survive a save/load round trip unchanged.
	var text := JSON.stringify(JSON.parse_string(JSON.stringify(data, "", true)), "", true)
	return Crypto.new().hmac_digest(HashingContext.HASH_SHA256, _key(), text.to_utf8_buffer()).hex_encode()

func _key() -> PackedByteArray:
	var parts := PackedByteArray([87, 70, 77, 45, 97, 99, 45, 50, 54, 45, 115, 101, 97, 108])
	parts.append_array(OS.get_unique_id().to_utf8_buffer())
	return _sha(parts)

func _sha(bytes: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(bytes)
	return ctx.finish()

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _flag_match(reason: String) -> void:
	if flagged: return
	flagged = true
	match_flagged.emit(reason)

func _verdict(found: Array) -> String:
	var score := 0
	for f in found: score += WEIGHT.get(f.level, 0)
	return CHEATING if score >= 3 else (SUSPICIOUS if score >= 1 else CLEAN)

func _finding(level: String, check: String, message: String) -> Dictionary:
	return {"level": level, "check": check, "message": message}

func _tag(f: Dictionary, player: String) -> Dictionary:
	var t := f.duplicate()
	t.player = player
	return t

func _local_id() -> String:
	var mp := get_tree().get_multiplayer() if is_inside_tree() else null
	if mp != null and mp.has_multiplayer_peer() and not (mp.multiplayer_peer is OfflineMultiplayerPeer):
		return str(mp.get_unique_id())
	return "local"

func _read(obj: Object, property: String, fallback = null):
	if obj == null: return fallback
	var value = obj.get(property)
	return fallback if value == null else value

func _rounded(stock: Dictionary) -> Dictionary:
	var out := {}
	for k in stock: out[k] = snappedf(float(stock[k]), 0.01)
	return out

func _collect(folder: String, out: Array[String]) -> void:
	var dir := DirAccess.open(folder)
	if dir == null: return
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdc") or f.ends_with(".remap"): out.append(folder.path_join(f))
	for d in dir.get_directories(): _collect(folder.path_join(d), out)

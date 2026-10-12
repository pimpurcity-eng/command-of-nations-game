class_name GameAudio
extends Node
## Sound effects and music (owner request 2026-10-12). All sounds and both music tracks are
## synthesized by tools/make_sounds.py, so the owner holds every right to them.
## Two switches, remembered in user://settings.cfg: Sound (effects + button clicks) and Music.
## Battle sounds get quieter with distance from the camera's focus and are skipped when far
## off-screen; a few voices per sound and a small pool keep big battles from turning to noise.
signal settings_changed
const SETTINGS_PATH: = "user://settings.cfg"
const SFX_DIR: = "res://assets/audio/sfx/"
const MUSIC_DIR: = "res://assets/audio/music/"
## A licensed start-screen track, if the owner adds one, replaces the synthesized menu theme.
const CUSTOM_MENU_THEME: = ["res://assets/audio/start_theme.ogg", "res://assets/audio/start_theme.mp3"]
## Per-sound loudness (dB) so weapons, alerts and clicks sit together in the mix.
const VOLUME: = {
	"tank_cannon": -3.0, "autocannon": -6.0, "artillery": -2.0, "naval_gun": -2.0,
	"missile_launch": -2.0, "interceptor": -3.0, "air_strike": -4.0, "drone_strike": -6.0,
	"helicopter": -8.0, "explosion_small": -5.0, "explosion_large": -1.0,
	"ui_click": -10.0, "war_declared": -4.0, "victory": -3.0, "defeat": -3.0,
	"build_complete": -6.0, "research_complete": -6.0, "city_captured": -4.0,
	"rifle_fire": -4.0, "sniper_shot": -3.0, "mortar_fire": -4.0, "atgm_launch": -3.0,
	"heavy_machine_gun": -5.0, "mlrs_salvo": -3.0, "ballistic_missile": -1.0, "cruise_missile": -3.0,
	"aa_gun": -5.0, "ciws": -5.0, "jet_cannon": -4.0, "bomber_strike": -4.0, "helicopter_rockets": -4.0,
	"kamikaze_drone": -6.0, "ship_missile": -2.0, "torpedo_launch": -3.0, "sonar_ping": -8.0,
	"depth_explosion": -2.0, "carrier_launch": -3.0,
}
## Every weapon sounds like what it is (owner: "make sound for all weapons"). The first entry
## whose keyword appears in the unit's equipment id, family, name, role or kind wins; "ship" and
## "fighter" pick by what they fire. Works for the 63 families of 0.22 as well as the older set.
const WEAPON_SOUNDS: = [
	[["carrier"], "carrier_launch"],
	[["submarine", "sub_", "_sub"], "torpedo_launch"],
	[["ciws", "kashtan", "phalanx", "goalkeeper"], "ciws"],
	[["frigate", "destroyer", "corvette", "cruiser", "warship", "ship", "naval", "boat"], "ship"],
	[["shilka", "gepard", "tunguska", "aa_gun", "flak", "anti_aircraft_gun"], "aa_gun"],
	[["ballistic", "iskander", "atacms", "tochka", "kinzhal", "oreshnik", "hypersonic", "prsm"], "ballistic_missile"],
	[["cruise", "kalibr", "tomahawk", "storm_shadow", "scalp", "taurus", "alcm", "kh_", "kh-"], "cruise_missile"],
	[["mlrs", "grad", "uragan", "smerch", "tornado", "himars", "m270", "rocket_artillery", "tos_1", "tos1"], "mlrs_salvo"],
	[["mortar"], "mortar_fire"],
	[["sniper"], "sniper_shot"],
	[["atgm", "javelin", "kornet", "nlaw", "rpg", "anti_tank", "antitank"], "atgm_launch"],
	[["infantry", "rifle", "squad", "paratroop", "special_forces", "soldier", "marines"], "rifle_fire"],
	[["shahed", "geran", "lancet", "switchblade", "kamikaze", "loitering"], "kamikaze_drone"],
	[["drone", "uav", "bayraktar", "orlan"], "drone_strike"],
	[["helicopter", "heli", "ka_52", "ka52", "mi_28", "mi28", "mi_24", "apache"], "helicopter_rockets"],
	[["bomber", "tu22", "tu_22", "tu95", "tu_95", "tu160", "tu_160", "b52", "b_52"], "bomber_strike"],
	[["fighter", "strike", "su_", "su57", "su35", "mig", "f16", "f_16", "f35", "f_35", "f18", "rafale", "typhoon", "gripen", "jet"], "fighter"],
	[["apc", "btr", "m113", "stryker", "mrap", "humvee", "support", "truck"], "heavy_machine_gun"],
	[["ifv", "bmp", "bradley", "cv90", "marder", "puma", "warrior"], "autocannon"],
	[["tank", "t_72", "t72", "t_90", "t90", "leopard", "abrams", "challenger", "leclerc", "armata", "t14"], "tank_cannon"],
	[["howitzer", "artillery", "msta", "pzh", "caesar", "paladin", "krab"], "artillery"],
]
const MAX_SAME: = 3
const POOL_SIZE: = 14
const MUSIC_DB: = -9.0
## Combat effect name (CombatSystem / AirBattleSystem) → sound.
const SHOT_SOUNDS: = {"missile": "missile_launch", "artillery": "artillery", "cannon": "tank_cannon",
	"tracer": "autocannon", "interceptor": "interceptor", "air_strike": "air_strike", "drone_strike": "drone_strike"}

static var sound_enabled: = true
static var music_enabled: = true
static var _loaded: = false
## The camera rig, for distance and view checks (optional: menus play everything).
var rig: StrategyCamera
var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _music_name: = ""
var _last_played: Dictionary = {}

static func load_settings() -> void:
	if _loaded: return
	_loaded = true
	var settings: = ConfigFile.new()
	if settings.load(SETTINGS_PATH) == OK:
		sound_enabled = settings.get_value("audio", "sound", true)
		music_enabled = settings.get_value("audio", "music", true)

static func _save() -> void:
	var settings: = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value("audio", "sound", sound_enabled)
	settings.set_value("audio", "music", music_enabled)
	settings.save(SETTINGS_PATH)

func _ready() -> void:
	load_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var player: = AudioStreamPlayer.new()
		add_child(player)
		_pool.append(player)
	_music = AudioStreamPlayer.new()
	_music.volume_db = MUSIC_DB
	add_child(_music)
	# Every button in the game clicks (when Sound is on).
	get_tree().node_added.connect(_watch_button)
	for node in get_tree().root.find_children("*", "BaseButton", true, false): _watch_button(node)

func _watch_button(node: Node) -> void:
	if node is BaseButton and not node.has_meta("audio_click"):
		node.set_meta("audio_click", true)
		node.button_down.connect(func(): play("ui_click"))

func set_sound(enabled: bool) -> void:
	sound_enabled = enabled
	if not enabled:
		for player in _pool: player.stop()
	_save()
	settings_changed.emit()

func set_music(enabled: bool) -> void:
	music_enabled = enabled
	if enabled and not _music_name.is_empty(): _start_music(_music_name)
	elif not enabled: _music.stop()
	_save()
	settings_changed.emit()

func _stream(name: String) -> AudioStream:
	if not _streams.has(name):
		var path: = SFX_DIR + name + ".ogg"
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[name]

## Plays a sound. With a world position, it is quieter the further it is from the camera's
## focus and skipped when far outside the view.
func play(name: String, world_position: Variant = null) -> bool:
	if not sound_enabled: return false
	var stream: = _stream(name)
	if stream == null: return false
	var volume: float = VOLUME.get(name, -6.0)
	if world_position is Vector3 and rig != null:
		var focus: = Vector2(rig.rendered_target.x, rig.rendered_target.z)
		var distance: = focus.distance_to(Vector2(world_position.x, world_position.z))
		var reach: = maxf(rig.rendered_distance, 6.0)
		if distance > reach * 1.1: return false
		# Zoomed far out the whole map is quieter; closer battles are louder.
		volume += -18.0 * clampf(distance / reach, 0.0, 1.0) - 8.0 * smoothstep(20.0, 120.0, rig.rendered_distance)
	# Not the same sound twice within 60 ms, and only a few copies at once.
	var now: = Time.get_ticks_msec()
	if now - int(_last_played.get(name, -1000)) < 60: return false
	var same: = 0
	var free: AudioStreamPlayer = null
	for player in _pool:
		if player.playing and player.stream == stream: same += 1
		elif not player.playing and free == null: free = player
	if same >= MAX_SAME or free == null: return false
	_last_played[name] = now
	free.stream = stream
	free.volume_db = volume
	free.pitch_scale = randf_range(0.94, 1.06)  # the same gun never sounds exactly the same twice
	free.play()
	return true

func play_shot(effect: String, source: Dictionary, world_position: Vector3) -> bool:
	return play(sound_for(source, effect), world_position)

## The sound a unit's weapon makes for a combat effect ("missile", "cannon", "interceptor", ...).
static func sound_for(source: Dictionary, effect: String) -> String:
	var id: = str(source.get("equipment_id", ""))
	var spec: Dictionary = EquipmentIdentity.spec(id) if not id.is_empty() else {}
	var parts: = PackedStringArray([id, str(source.get("visual_kind", ""))])
	for key in ["family", "role", "name", "category", "visual_kind"]: parts.append(str(spec.get(key, "")))
	var text: = "|".join(parts).to_lower().replace("-", "_").replace(" ", "_")
	var name: = ""
	if effect == "interceptor" and source.get("visual_kind", "") == "air_defense" and not text.contains("shilka") and not text.contains("gepard") and not text.contains("tunguska"):
		return "interceptor"  # surface-to-air missiles
	for entry in WEAPON_SOUNDS:
		for word in entry[0]:
			if text.contains(word):
				name = entry[1]
				break
		if not name.is_empty(): break
	match name:
		"ship": return "ship_missile" if effect in ["missile", "interceptor"] else "naval_gun"
		"fighter": return "interceptor" if effect == "interceptor" else "jet_cannon"
		"": return SHOT_SOUNDS.get(effect, "autocannon")
	return name

## "menu_theme" or "battle_theme"; loops until changed. Crossfades between tracks.
func play_music(name: String) -> void:
	if name == _music_name and _music.playing: return
	_music_name = name
	if music_enabled: _start_music(name)

func _start_music(name: String) -> void:
	var path: = MUSIC_DIR + name + ".ogg"
	if name == "menu_theme":
		for custom in CUSTOM_MENU_THEME:
			if ResourceLoader.exists(custom): path = custom
	if not ResourceLoader.exists(path): return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3: stream.loop = true
	var fade: = create_tween()
	if _music.playing:
		fade.tween_property(_music, "volume_db", -40.0, 0.8)
	fade.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -40.0
		_music.play())
	fade.tween_property(_music, "volume_db", MUSIC_DB, 1.2)

func music_playing() -> String:
	return _music_name if _music.playing else ""

class_name SimulationClock
extends Node
const REAL_SECONDS_PER_SIM_SECOND: = 120.0
const SPEEDS: = [1.0, 2.0, 4.0, 10.0]
## Armies and aircraft travel this many times faster than the real-time economy clock, so
## movement is visible on a phone (owner review: units with orders looked frozen; a 2-province
## march took over 30 real minutes). Production, research and combat rounds are unchanged.
## Owner 2026-10-15: "the units are moving way too fast for 1x" - back to the economy clock's pace.
const MOVEMENT_PACE: = 1.0
signal advanced(seconds: float)
signal state_changed
var elapsed: = 0.0
var speed: = 1.0:
	set(value):
		speed = value
		game_speed = value
var paused: = true
var hud_elapsed: = 0.0
var frame_accumulator: = 0.0
func _process(delta: float) -> void :

	if paused:
		frame_accumulator = 0.0
		return
	# Preserve elapsed time while dispatching strategic rules at 10 Hz.
	frame_accumulator += minf(delta, 0.25)
	if frame_accumulator < 0.1: return
	var elapsed_frame: = frame_accumulator
	frame_accumulator = 0.0
	advance(elapsed_frame)
func advance(real_seconds: float) -> void :
	if paused or real_seconds <= 0: return
	var seconds: = real_seconds * speed / REAL_SECONDS_PER_SIM_SECOND
	elapsed += seconds
	advanced.emit(seconds)
	hud_elapsed += real_seconds
	if hud_elapsed >= 0.25:
		hud_elapsed = 0.0
		state_changed.emit()
func set_speed(value: float) -> void :
	if value not in SPEEDS: return
	speed = value
	game_speed = value
	state_changed.emit()
func toggle_pause() -> void :
	paused = not paused
	state_changed.emit()
func snapshot() -> Dictionary:
	return {"elapsed": elapsed, "speed": speed, "paused": paused}
func restore(state: Dictionary) -> void :
	elapsed = state.elapsed
	speed = state.speed
	game_speed = speed
	paused = state.paused
	state_changed.emit()

## Owner 2026-10-15 ("the values should change if it's one times speed, two times speed"): every
## time shown in the game is real time at the speed the match runs at now.
static var game_speed: = 1.0
static func duration(sim_seconds: float, speed_factor: float = 0.0) -> String:
	if speed_factor <= 0.0: speed_factor = game_speed
	var seconds: = maxi(0, ceili(sim_seconds * REAL_SECONDS_PER_SIM_SECOND / speed_factor))
	if seconds >= 3600: return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60: return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%ds" % seconds

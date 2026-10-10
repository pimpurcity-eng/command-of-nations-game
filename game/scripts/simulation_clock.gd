class_name SimulationClock
extends Node
const REAL_SECONDS_PER_SIM_SECOND: = 120.0
## Armies and aircraft travel this many times faster than the real-time economy clock, so
## movement is visible on a phone (owner review: units with orders looked frozen; a 2-province
## march took over 30 real minutes). Production, research and combat rounds are unchanged.
const MOVEMENT_PACE: = 10.0
signal advanced(seconds: float)
signal state_changed
var elapsed: = 0.0
var speed: = 1.0
var paused: = true
var hud_elapsed: = 0.0
func _process(delta: float) -> void :

	advance(minf(delta, 0.25))
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
	if value not in [1.0, 2.0, 4.0]: return
	speed = value
	state_changed.emit()
func toggle_pause() -> void :
	paused = not paused
	state_changed.emit()
func snapshot() -> Dictionary:
	return {"elapsed": elapsed, "speed": speed, "paused": paused}
func restore(state: Dictionary) -> void :
	elapsed = state.elapsed
	speed = state.speed
	paused = state.paused
	state_changed.emit()

static func duration(sim_seconds: float, speed_factor: float = 1.0) -> String:
	var seconds: = maxi(0, ceili(sim_seconds * REAL_SECONDS_PER_SIM_SECOND / speed_factor))
	if seconds >= 3600: return "%dh %02dm" % [seconds / 3600, (seconds % 3600) / 60]
	if seconds >= 60: return "%dm %02ds" % [seconds / 60, seconds % 60]
	return "%ds" % seconds

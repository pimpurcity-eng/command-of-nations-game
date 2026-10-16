extends SceneTree
## Layered air defence (owner 2026-10-14): long-range SAMs cannot see drones; short-range AA cannot
## reach high bombers.   xvfb-run -a godot --path . --script tests/test_layered_air_defense.gd
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
	else: print("PASS ", message)
func _initialize() -> void: call_deferred("run")

func unit(id: String, kind: String, mode: String = "", level: int = 1) -> Dictionary:
	return {"equipment_id": id, "visual_kind": kind, "flight_mode": mode, "level": level}

func run() -> void:
	var sam: = unit("patriot_russia", "air_defense", "", 5)
	var shorad: = unit("skyguard_ukraine", "air_defense")
	var drone: = unit("geran_russia", "fighter", "attack")
	var bomber: = unit("bombers_ukraine", "fighter", "attack")
	var jet_run: = unit("fighters_ukraine", "fighter", "attack")
	var jet_pass: = unit("fighters_ukraine", "fighter", "patrol")
	var heli: = unit("helicopters_ukraine", "fighter", "attack")
	var radar: = unit("a50u_russia", "fighter", "patrol")
	check(not AirBattleSystem.can_engage(sam, drone), "a level-5 long-range SAM cannot see a drone")
	check(AirBattleSystem.can_engage(sam, bomber) and AirBattleSystem.can_engage(sam, radar), "a long-range SAM hits bombers and radar planes")
	check(AirBattleSystem.can_engage(sam, jet_run) and AirBattleSystem.can_engage(sam, heli), "a long-range SAM hits jets and helicopters")
	check(AirBattleSystem.can_engage(shorad, drone), "short-range AA shoots down drones")
	check(AirBattleSystem.can_engage(shorad, heli) and AirBattleSystem.can_engage(shorad, jet_run), "short-range AA hits helicopters and jets on an attack run")
	check(not AirBattleSystem.can_engage(shorad, bomber) and not AirBattleSystem.can_engage(shorad, jet_pass), "short-range AA cannot reach bombers or jets passing high")
	print("RESULT failures=", failures.size())
	quit(1 if not failures.is_empty() else 0)

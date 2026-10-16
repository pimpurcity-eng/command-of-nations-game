extends SceneTree
## Owner 2026-10-16: "sniper should have a bit of range" - a sniper hits an enemy a little beyond
## touching distance without being hit back, and shows its range ring when selected.
##   xvfb-run -a godot --path . --script tests/test_sniper_range.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run():
	var sniper: = {"equipment_id": "snipers_russia", "visual_kind": "infantry", "health": 100.0, "level": 1, "moving": false, "attack_target": "x"}
	var rifle: = {"equipment_id": "infantry_russia", "visual_kind": "infantry", "health": 100.0, "level": 1, "moving": false, "attack_target": "x"}
	var combat: = CombatSystem.new()
	check(CombatSystem.sniper(sniper) and not CombatSystem.sniper(rifle), "snipers are recognised")
	check(combat.attack_reach(sniper) >= 0.85, "a sniper reaches %.2f" % combat.attack_reach(sniper))
	check(combat.attack_reach(rifle) <= CombatSystem.CLOSE_COMBAT_REACH, "riflemen still fight only up close")
	check(combat.potential([sniper], "infantry", true) > 0.0, "a sniper deals damage from range")
	check(RangeRings.reach(sniper) > 0.0 and RangeRings.reach(rifle) == 0.0, "snipers have a range ring, riflemen none")
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)

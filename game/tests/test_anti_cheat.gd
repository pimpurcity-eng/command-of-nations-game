extends SceneTree
## Anti-cheat tests. Run: godot --headless --path <project> --script res://game/tests/test_anti_cheat.gd
## Uses a tiny fake game so it runs without loading the map.
class Production extends Object:
	signal changed
	signal unit_ready(data)
	var stockpiles := {"russia": {"oil": 1000.0, "steel": 800.0}, "europe": {"oil": 1000.0, "steel": 800.0}}
class Units extends Object:
	var units: Array = []
class Clock extends Object:
	var speed := 4.0
class Game extends Node:
	var production := Production.new()
	var units := Units.new()
	var clock := Clock.new()
	var anti_cheat_save_ok := true
var fails := 0
func check(name: String, ok: bool) -> void:
	print(("PASS " if ok else "FAILED ") + name)
	if not ok: fails += 1
func make() -> Array:
	var g = Game.new()
	for i in 6: g.units.units.append({"name": "T-90 #%d" % i, "country": "russia" if i < 3 else "europe", "health": 100.0, "level": [1,3,5][i % 3]})
	root.add_child(g)
	var ac := AntiCheat.new()
	ac.ranked = false
	g.add_child(ac)
	ac.attach(g)
	return [g, ac]
func _initialize() -> void:
	# 1. Clean solo sweep
	var p = make(); var g = p[0]; var ac: AntiCheat = p[1]
	var r := ac.run_start_sweep()
	check("clean solo sweep is CLEAN", r.match_verdict == "CLEAN")
	check("fingerprint hashed real files", ac.game_fingerprint().length() == 64)
	check("clean watchdog finds nothing", ac.run_watchdog().is_empty())
	# 2. Memory-edited resources (no production event)
	g.production.stockpiles.russia.oil = 99999.0
	var f := ac.run_watchdog()
	check("memory-edited oil caught", f.any(func(x): return x.check == "resources") and ac.flagged)
	# 3. Legit production is not flagged
	p = make(); g = p[0]; ac = p[1]; ac.run_start_sweep()
	g.production.stockpiles.russia.oil += 5000.0; g.production.changed.emit()
	check("real production not flagged", ac.run_watchdog().is_empty() and not ac.flagged)
	# 4. Units out of nowhere vs produced
	g.units.units.append({"name": "Free tank", "country": "russia", "health": 100.0, "level": 1})
	check("spawned-from-nothing unit caught", ac.run_watchdog().any(func(x): return x.check == "units"))
	p = make(); g = p[0]; ac = p[1]; ac.run_start_sweep()
	g.units.units.append({"name": "Built tank", "country": "russia", "health": 100.0, "level": 1}); g.production.unit_ready.emit({})
	check("produced unit not flagged", ac.run_watchdog().is_empty())
	# 5. God-mode unit
	g.units.units[0].health = 9999.0
	check("9999 health caught", ac.run_watchdog().any(func(x): return "health" in x.message))
	# 6. Save seal
	p = make(); ac = p[1]
	var state := {"clock": {"elapsed": 3600, "speed": 4.0, "paused": false}, "units": [{"id": "a", "health": 87.5, "level": 3}], "stock": {"oil": 1200.25}}
	var sealed := ac.seal_save(state)
	var reloaded: Dictionary = JSON.parse_string(JSON.stringify(sealed))
	check("untouched save verifies after real save/load", ac.verify_save(reloaded))
	reloaded.stock.oil = 999999.0
	check("edited save rejected", not ac.verify_save(reloaded))
	check("old unsealed save accepted", ac.verify_save(state))
	# 7. Multiplayer sweep: 3 players, one modded + extra units + more oil
	p = make(); g = p[0]; ac = p[1]
	var honest := ac.build_report()
	var cheater: Dictionary = honest.duplicate(true)
	cheater.files = "deadbeef"
	cheater.countries.europe.units = 9
	cheater.countries.europe.stockpile.oil = 50000.0
	r = ac.run_start_sweep({"2": honest.duplicate(true), "3": cheater})
	check("honest host CLEAN", r.players["local"].verdict == "CLEAN")
	check("honest peer CLEAN", r.players["2"].verdict == "CLEAN")
	check("modded peer CHEATING", r.players["3"].verdict == "CHEATING")
	print("   cheater findings: ", r.players["3"].findings.map(func(x): return x.message))
	# 8. Version-only mismatch is a warning, not a cheat
	p = make(); ac = p[1]
	var old := ac.build_report(); old.game_version = "0.22"
	r = ac.run_start_sweep({"2": ac.build_report(), "3": old})
	check("older version = SUSPICIOUS only", r.players["3"].verdict == "SUSPICIOUS")
	# 8b. Debug build refused in ranked matches
	p = make(); ac = p[1]; ac.ranked = true
	var dbg := ac.build_report(); dbg.debug_build = true
	r = ac.run_start_sweep({"2": dbg})
	check("debug build flagged in ranked match", r.players["2"].findings.any(func(x): return x.check == "debug"))
	# 9. Speed check math
	p = make(); ac = p[1]; ac.run_start_sweep()
	ac._delta_sum = 30.0; ac._wall_start = Time.get_ticks_usec() - 10_000_000
	check("3x speed hack caught", ac._check_speed().any(func(x): return x.check == "speed"))
	ac._delta_sum = 10.2; ac._wall_start = Time.get_ticks_usec() - 10_000_000
	check("normal frame timing fine", ac._check_speed().is_empty())
	print("FAILED %d" % fails if fails else "ALL ANTI-CHEAT TESTS PASSED")
	quit(1 if fails else 0)

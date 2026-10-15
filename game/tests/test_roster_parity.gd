extends SceneTree
## Owner 2026-10-15: "Ukraine only gets European weapons" and "look at Call of War, everyone has
## the same amount of units": the live catalogue gives both sides the same units, type for type.
##   godot --headless --path . --script tests/test_roster_parity.gd
var failures: = 0
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1
func _initialize() -> void:
	var foreign: Array = []
	var roster: = {}
	var count: = {"russia": 0, "ukraine": 0}
	for family in EquipmentIdentity.catalog:
		if family.get("retired", false) or not family.get("country", "") in ["russia", "ukraine"]: continue
		count[family.country] += 1
		var kind: = "%s/%s/%s/%s" % [family.get("category", ""), family.get("visual_kind", ""), family.get("role", ""), family.get("production_building", "")]
		if not roster.has(kind): roster[kind] = {"russia": 0, "ukraine": 0}
		roster[kind][family.country] += 1
		if family.country != "ukraine": continue
		for tier in family.get("research_tiers", []):
			var file: String = str(tier.model).get_file()
			if not (file.begins_with("euro_") or file.begins_with("nato_") or file.begins_with("ukraine_") or file.ends_with("_european.glb")) or file.contains("abrams") or str(tier.name).contains("NASAMS"):
				foreign.append(family.id + ": " + str(tier.name))
	check(foreign.is_empty(), "Ukraine has European weapons only " + str(foreign))
	var uneven: = roster.keys().filter(func(k): return roster[k].russia != roster[k].ukraine)
	check(uneven.is_empty() and count.russia == count.ukraine, "Russia and Ukraine have the same units, type for type (%d v %d) %s" % [count.russia, count.ukraine, str(uneven)])
	print("RESULT failures=", failures)
	quit(1 if failures > 0 else 0)

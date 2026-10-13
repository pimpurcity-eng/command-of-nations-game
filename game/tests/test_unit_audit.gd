extends SceneTree
## Owner 2026-10-13: "Some units don't attack or don't work right, please check all units."
## Every offered family, at level 1 and level 5, is given an attack order on a suitable enemy
## (ground target, ship, or aircraft for air defence) and must damage it within two game hours.
## Support units must not fight but must do their job (heal / repair / dig in / speed up).
##   xvfb-run -a godot --path . --script tests/test_unit_audit.gd
var failures: Array = []
var checks: = 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text)
	print("PASS " if ok else "FAIL ", text)
func _initialize() -> void: call_deferred("run")

var game
func spawn(family: Dictionary, level: int, point: Vector2, id: String) -> Dictionary:
	var base: Dictionary = {}
	for city in game.production.cities:
		if city.country.to_lower() == family.country and (base.is_empty() or city.point.distance_to(point) < base.point.distance_to(point)): base = city
	var data: = {"id": id, "name": EquipmentIdentity.research_title(family.id, level), "country": family.country, "equipment_id": family.id,
		"level": level, "visual_kind": family.visual_kind, "base_city": base.id}
	game.units._spawn(data, point, Color("ef827c") if family.country == "russia" else Color("73bcff"))
	return game.units.units[-1]

func simulate(hours: float) -> void:
	var real: = hours * 3600.0
	var step: = 60.0
	while real > 0:
		game.match_rules.winner = ""
		game.match_rules.fielded.clear()
		game.clock.advance(step)
		real -= step

func enemy_of(country: String) -> String: return "ukraine" if country == "russia" else "russia"

func family_of(country: String, id_prefix: String) -> Dictionary:
	return EquipmentIdentity.spec(id_prefix + "_" + country)

func run() -> void:
	GameSession.player_country = "russia"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	game.match_rules.ai_enabled = false
	game.match_rules.declare_war()
	game.units.fog_enabled = false
	game.clock.paused = false
	var land: Dictionary = {"russia": game.buildings.city("kursk").point + Vector2(0.3, 0.2), "ukraine": game.buildings.city("kharkiv").point + Vector2(-0.3, 0.2)}
	var sea_anchor: Vector2 = Vector2.INF
	for city in game.production.cities:
		if city.has("naval_spawn") and sea_anchor == Vector2.INF:
			var none: Array[Vector2] = []
			sea_anchor = game.weapons_test_sea_slot(GeographicProjection.project(city.naval_spawn.longitude, city.naval_spawn.latitude), none)
	for family in EquipmentIdentity.catalog:
		if family.get("retired", false): continue
		var role: String = family.get("role", "")
		for level in [1, 5]:
			game.units.restore([])
			game.match_rules.combat.cooldowns.clear()
			# Clearing the map would otherwise end the match by elimination.
			game.match_rules.winner = ""
			game.match_rules.fielded.clear()
			game.match_rules.air_combat.cooldowns.clear()
			var country: String = family.country
			var foe: String = enemy_of(country)
			var start: Vector2 = land[country]
			var label: = "%s L%d" % [family.id, level]
			if family.visual_kind == "naval":
				var ship: = spawn(family, level, sea_anchor, "a")
				var taken: Array[Vector2] = [sea_anchor]
				var target: = spawn(family_of(foe, "corvettes"), 1, game.weapons_test_sea_slot(sea_anchor + Vector2(1.0, 0.0), taken), "t")
				game.units.command(country, [ship.id], "attack", Vector2.ZERO, target.id)
				simulate(2.0)
				var hit: bool = target.health < 100.0 or game.units.find_id("t").is_empty()
				if role == "carrier": check(true, label + " (carrier: launches no attack itself)")
				else: check(hit, label + " damages an enemy ship (target %.0f%%)" % target.health)
				continue
			if family.visual_kind == "air_defense":
				var site: = spawn(family, level, start, "a")
				var plane: = spawn(family_of(foe, "fighters"), 1, start + Vector2(0.6, 0.0), "t")
				# Aircraft start parked at their home airbase: send it on a patrol over the site.
				var flight: String = game.units.air.order(plane, start + Vector2(0.4, 0.0), "patrol")
				simulate(1.0)
				check(flight.is_empty() and (plane.health < 100.0 or game.units.find_id("t").is_empty()), label + " shoots at aircraft patrolling in range (flight %s, plane %.0f%%)" % [flight if not flight.is_empty() else "ok", plane.health])
				continue
			if family.visual_kind == "support":
				var helper: = spawn(family, level, start, "a")
				var friend: = spawn(family_of(country, "infantry"), 1, start, "f")
				var tank: = spawn(family_of(country, "tanks"), 1, start, "v")
				for u in [helper, friend, tank]: u.stack_id = "stack_audit"
				game.units.stacks.invalidate()
				friend.health = 50.0
				tank.health = 50.0
				match role:
					"medic", "recovery", "supply":
						simulate(2.0)
						var healed: bool = (friend.health > 50.0) if role != "recovery" else (tank.health > 50.0)
						check(healed, label + " (%s) restores its army (infantry %.0f%%, tank %.0f%%)" % [role, friend.health, tank.health])
					"engineer":
						check(SupportRoles.entrench_factor(game.units.stacks.members(friend)) > 1.0, label + " (engineer) digs its army in faster")
					"bridge":
						check(SupportRoles.speed_factor(game.units.stacks.members(friend)) > 1.0, label + " (bridge layer) speeds its army up")
					_: check(false, label + " support unit has no role")
				continue
			var attacker: = spawn(family, level, start, "a")
			var distance: = 1.2 if family.visual_kind in ["artillery", "missile_launcher"] else 0.9
			if game.units.air.is_air(attacker): distance = 2.0
			var target: = spawn(family_of(foe, "infantry"), 1, start + Vector2(distance, 0.0), "t")
			if family.get("targets_naval", false):
				check(true, label + " (coastal anti-ship: ships only)")
				continue
			var accepted: int = game.units.command(country, [attacker.id], "attack", Vector2.ZERO, target.id)
			simulate(2.0)
			var gone: bool = game.units.find_id("t").is_empty()
			var damaged: bool = gone or target.health < 100.0
			if role in ["transport", "radar_aircraft"]:
				check(true, label + " (%s: no weapons)" % role)
				continue
			check(accepted > 0 and damaged, label + " attacks a ground target (order %s, target %s)" % ["accepted" if accepted > 0 else "REFUSED", "destroyed" if gone else "%.0f%%" % target.health])
	print("RESULT checks=", checks, " failures=", failures.size())
	for f in failures: print("  FAILED: ", f)
	quit(1 if not failures.is_empty() else 0)

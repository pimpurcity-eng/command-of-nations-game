extends SceneTree
## Owner 2026-10-16: rally points for new units and the five-unit city queue are FREE for every
## commander; the Premium account (PlayerPremium) adds conveniences such as eight queue slots.
##   xvfb-run -a godot --path . --script tests/test_oct16_premium_rally.gd
var failures: = 0
func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ") + text)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
var game

func texts(node: Node) -> String:
	var out: = ""
	if node is Label or node is Button: out += str(node.text) + "\n"
	for child in node.get_children(): out += texts(child)
	return out

func run():
	root.size = Vector2i(720, 1440)
	GameSession.player_country = "russia"
	PlayerPremium.test_override = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	if not game.boot_finished: await game.boot_ready
	game.mobile_start.hide()
	game.clock.paused = true
	game.match_rules.ai_enabled = false
	for i in 3: await process_frame
	var production: ProductionSystem = game.production
	var units: UnitSystem = game.units

	# --- premium flag parsing (no network) ---
	check(PlayerPremium.parse_time("2030-01-01T00:00:00+00:00") == 1893456000.0, "premium_until with +00:00 parses")
	check(PlayerPremium.parse_time("2030-01-01T02:00:00.123+02:00") == 1893456000.0, "premium_until with fractions and +02:00 parses")
	check(PlayerPremium.parse_time(null) == 0.0, "missing premium_until means no membership")
	PlayerPremium.test_override = -1
	PlayerPremium.apply_profile({"premium_until": "2099-01-01T00:00:00Z"}, "user-1")
	check(PlayerPremium.is_premium() and PlayerPremium.until_text() == "2099-01-01", "a future premium_until makes the commander premium")
	PlayerPremium.apply_profile({"premium_until": "2001-01-01T00:00:00Z"}, "user-1")
	check(not PlayerPremium.is_premium(), "an expired membership is not premium")
	PlayerPremium.apply_profile({}, "user-1")
	check(not PlayerPremium.is_premium(), "no column (migration not applied) means free")
	PlayerPremium.test_override = 0

	# --- pick a city of ours and a weapon it can build ---
	for country in production.stockpiles:
		for resource in ProductionSystem.RESOURCES: production.stockpiles[country][resource] = 1.0e9
	# Owner 2026-10-15: nothing is researched at the start; this test is about the queue, so
	# mark every weapon as researched first.
	for spec in production.catalog: game.research.levels[spec.id] = maxi(1, game.research.level(spec.id))
	# Infantry needs a barracks in the city (cities start without one).
	for place in production.cities:
		if production.controlled(place, "russia"):
			if not game.buildings.levels.has(place.id): game.buildings.levels[place.id] = {}
			game.buildings.levels[place.id]["barracks"] = maxi(1, game.buildings.level(place.id, "barracks"))
	var city: Dictionary = {}
	var weapon: = ""
	for place in production.cities:
		if not production.controlled(place, "russia"): continue
		production.jobs = production.jobs.filter(func(job): return job.city != place.name)
		for spec in production.catalog:
			if spec.country != "russia" or spec.get("requires_port", false) or spec.visual_kind in ["naval", "air", "helicopter"]: continue
			if units.air.is_air({"visual_kind": spec.visual_kind, "equipment_id": spec.id}): continue
			var why: = production.enqueue(spec.id, place.name)
			if OS.has_environment("RALLY_DEBUG"): print(place.name, " ", spec.id, " ", why)
			if why.is_empty():
				weapon = spec.id
				break
		if not weapon.is_empty():
			city = place
			break
	check(not weapon.is_empty(), "found a city and a ground unit to build (%s in %s)" % [weapon, city.get("name", "?")])
	if weapon.is_empty():
		finish()
		return
	production.jobs = production.jobs.filter(func(job): return job.city != city.name)

	# --- free queue: five units per city ---
	for i in 5: production.enqueue(weapon, city.name)
	var sixth: = production.enqueue(weapon, city.name)
	check(production.jobs.filter(func(j): return j.city == city.name).size() == 5 and "full (5)" in sixth, "free commanders queue five units per city; the sixth is refused: " + sixth)
	check("full (5)" in production.schedule(weapon, city.name), "planned (unpaid) orders respect the same limit")
	# --- premium gate: eight with Premium (test toggle) ---
	PlayerPremium.test_override = 1
	check(PlayerPremium.is_premium() and production.plan_limit("russia") == 8, "the test toggle switches Premium on: 8 queue slots")
	check(production.plan_limit("ukraine") == 5, "Premium only applies to the player's own country")
	for i in 3: production.enqueue(weapon, city.name)
	var ninth: = production.enqueue(weapon, city.name)
	check(production.jobs.filter(func(j): return j.city == city.name).size() == 8 and "full (8)" in ninth, "Premium queues eight units; the ninth is refused: " + ninth)
	check(production.validate(production.snapshot()), "a save with eight queued units still loads")
	PlayerPremium.test_override = 0
	check(not PlayerPremium.is_premium() and production.plan_limit("russia") == 5, "toggle off: back to five")
	var city_jobs: Array = production.jobs.filter(func(j): return j.city == city.name)
	for job in city_jobs.slice(5): production.cancel(int(job.id))
	check(production.jobs.filter(func(j): return j.city == city.name).size() == 5, "extra orders cancelled")

	# --- rally point: set from the city panel, tap a spot on the map ---
	var origin: Vector2 = city.point
	var spot: = Vector2.INF
	for t in game.map.territories:
		if not t.playable or t.controller != "russia" or not game.map.province_hubs.has(t.title): continue
		var hub: Vector2 = game.map.province_hubs[t.title]
		if hub.distance_to(origin) > 1.5 and hub.distance_to(origin) < 5.0:
			spot = hub
			break
	check(spot != Vector2.INF, "found a rally spot on our land near %s" % city.name)
	game.city_panel.open(city)
	await process_frame
	check("NO RALLY POINT" in game.city_panel.rally_label.text and game.city_panel.rally_set_button.visible and not game.city_panel.rally_clear_button.visible, "city screen shows 'no rally point' with a Set rally point button")
	check("(+4 · 5/5)" in game.city_panel.production.text.text, "city screen shows the queue is full: " + game.city_panel.production.text.text)
	game.selecting_armies = true  # leftover army-pick mode must not swallow the rally tap
	game.city_panel.rally_set_button.pressed.emit()
	check(game.rally_city == city.id and game.order_mode and not game.selecting_armies and not game.city_panel.visible, "Set rally point closes the city and waits for a tap on the map")
	game.player_order(Vector3(spot.x, 0, spot.y))
	var rally: Dictionary = production.rally_points.get(city.id, {})
	check(rally.get("country", "") == "russia" and Vector2(rally.point[0], rally.point[1]).distance_to(spot) < 0.01, "the tapped spot becomes the city's rally point")
	check(game.rally_city.is_empty() and not game.order_mode, "rally mode ends after the tap")
	var marker: Node3D = game.rally_markers.get(city.id)
	check(marker != null and marker.visible and Vector2(marker.position.x, marker.position.z).distance_to(spot) < 0.05 and marker.get_child_count() >= 2, "a rally flag stands on the map at the spot")
	game.city_panel.open(city)
	await process_frame
	check("RALLY POINT SET" in game.city_panel.rally_label.text and game.city_panel.rally_clear_button.visible and "MOVE" in game.city_panel.rally_set_button.get_meta("caption").text, "city screen shows the rally is set, with Move and Clear")
	check(production.validate(production.snapshot()) and production.snapshot().rally_points.has(city.id), "the rally point is saved with the game")

	# --- every unit from the queue walks to the rally point ---
	var produced: Array = []
	for round in 2:
		var first: Dictionary = production.jobs.filter(func(j): return j.city == city.name)[0]
		first.progress = production.job_duration(first) - 0.0001
		var before: = units.units.size()
		production.advance(1.0)
		await process_frame
		var fresh: Array = units.units.filter(func(u): return u.id == "produced_" + str(int(first.id)))
		check(not fresh.is_empty(), "queued unit %d is produced" % (round + 1))
		if fresh.is_empty(): continue
		var unit: Dictionary = fresh[0]
		produced.append(unit)
		if OS.has_environment("RALLY_DEBUG"): print("UNIT ", fresh.size(), " ", unit.position, " moving=", unit.moving, " path=", unit.get("path", []), " keys=", unit.keys())
		var goal: Vector2 = unit.target
		check(unit.moving and goal.distance_to(spot) < 1.5, "unit %d marches to the rally point (target %.2f from the flag)" % [round + 1, goal.distance_to(spot)])
	check(production.jobs.filter(func(j): return j.city == city.name).size() == 3, "the queue moves on: three orders left")

	# --- clear: new units stay at the city ---
	game.city_panel.rally_clear_button.pressed.emit()
	check(not production.rally_points.has(city.id) and not marker.visible, "Clear removes the rally point and its flag")
	var next: Dictionary = production.jobs.filter(func(j): return j.city == city.name)[0]
	next.progress = production.job_duration(next) - 0.0001
	production.advance(1.0)
	await process_frame
	var stay: Array = units.units.filter(func(u): return u.id == "produced_" + str(int(next.id)))
	check(not stay.is_empty() and not stay[0].moving, "without a rally point the new unit waits at the city")

	# --- premium screen and profile badge ---
	var screen: = PremiumPanel.show_over(root)
	await process_frame
	var shown: = texts(screen.fields)
	check(screen.overlay.visible and "coming soon" in shown.to_lower() and "Rally points" in shown, "Premium screen lists benefits, what stays free, and a coming-soon buy button")
	PlayerPremium.test_override = 1
	var account: = AccountPanel.new()
	root.add_child(account)
	await process_frame
	account.auth.user = {"id": "user-1", "email": "test@example.com", "user_metadata": {"commander_name": "Tester"}}
	account.auth.profile = {"xp": 0}
	PlayerPremium.premium_user = "user-1"
	account.build("profile")
	check("PREMIUM COMMANDER" in texts(account.fields), "the profile shows the Premium badge when active")
	PlayerPremium.test_override = 0
	account.build("profile")
	check(not "PREMIUM COMMANDER" in texts(account.fields) and "Premium membership" in texts(account.fields), "no badge when not premium; the Premium button is always there")
	finish()

func finish() -> void:
	PlayerPremium.test_override = -1
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

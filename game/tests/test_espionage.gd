extends SceneTree
## Espionage (owner 2026-10-14): spies, missions, catching, saving and the AI's spies.
var failures: = 0
var checks: = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	GameSession.player_country = "russia"
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	while not game.boot_finished: await process_frame
	game.mobile_start.hide()
	var rules: MatchSystem = game.match_rules
	var economy: ProductionSystem = game.production
	var spies: Espionage = rules.espionage
	var world: = rules.spy_world()
	var kharkiv: Dictionary = game.buildings.city("kharkiv")
	var belgorod: Dictionary = game.buildings.city("belgorod")
	var ours: Dictionary = economy.stockpiles.russia
	var theirs: Dictionary = economy.stockpiles.ukraine
	check(economy.controller(kharkiv) == "ukraine" and economy.controller(belgorod) == "russia", "Kharkiv is Ukrainian, Belgorod Russian")
	check(not spies.send("russia", belgorod, "steal", "russia", ours).is_empty(), "Enemy missions cannot target your own city")
	check(not spies.send("russia", kharkiv, "counter", "ukraine", ours).is_empty(), "Counter-spies only guard your own cities")
	var money: = float(ours.funds)
	check(spies.send("russia", kharkiv, "steal", "ukraine", ours).is_empty(), "A spy can be sent to steal in Kharkiv")
	check(is_equal_approx(float(ours.funds), money - Espionage.COST.funds), "Sending a spy costs money")
	check(not spies.send("russia", kharkiv, "steal", "ukraine", ours).is_empty(), "Only one spy per mission and city")
	for mission in ["sabotage", "army", "morale", "intel"]: spies.send("russia", kharkiv, mission, "ukraine", ours)
	spies.send("russia", belgorod, "counter", "russia", ours)
	check(spies.owned("russia").size() == 6, "Six spies sent")
	check(not spies.send("russia", game.buildings.city("kyiv"), "intel", "ukraine", ours).is_empty(), "No more than six spies")
	# Never caught while measuring the missions.
	spies.rng.seed = 1
	var defender: Dictionary = {}
	for unit in game.units.units:
		if unit.country == "ukraine" and CitySystem.near_city(Vector2(unit.node.position.x, unit.node.position.z), kharkiv.point): defender = unit
	check(not defender.is_empty(), "Kharkiv has a Ukrainian garrison")
	var health_before: float = defender.health if not defender.is_empty() else 0.0
	var territory: Dictionary = world.territory.call(kharkiv)
	var morale_before: = float(territory.get("morale", 100.0))
	var their_money: = float(theirs.funds)
	var our_money: = float(ours.funds)
	check(not Espionage.reveals(kharkiv.point, "russia"), "Nothing revealed while the spies travel")
	spies.advance(Espionage.TRAVEL, world, "russia")
	check(Espionage.reveals(kharkiv.point + Vector2(1, 0), "russia") and not Espionage.reveals(kharkiv.point, "ukraine"), "Intelligence spy reveals the area around the city")
	check(is_equal_approx(Espionage.sabotage_factor("kharkiv"), Espionage.SABOTAGE_FACTOR) and Espionage.sabotage_factor("kyiv") == 1.0, "Sabotage halves the city's building speed")
	# Nothing happens to money during the day: spies work at the day's end.
	spies.advance(1.0, world, "russia", 1)
	check(is_equal_approx(float(theirs.funds), their_money), "Spies wait for the end of the day")
	var survivors: = spies.spies.size()
	spies.rng.seed = 12345
	var day_reports: = spies.advance(1.0, world, "russia", 2)
	var stolen_ok: bool = float(theirs.funds) < their_money and float(ours.funds) > our_money
	check(spies.spies.size() < survivors or stolen_ok, "At the day's end stealing moves money from the enemy to us")
	check(not stolen_ok or day_reports.any(func(line): return str(line).contains("stole")), "The day's theft is reported")
	if spies.owned("russia").any(func(spy): return spy.mission == "army"):
		check(defender.health < health_before or health_before <= Espionage.ARMY_FLOOR, "Army spy wounds the garrison")
	if spies.owned("russia").any(func(spy): return spy.mission == "morale"):
		check(float(territory.morale) < morale_before or morale_before <= Espionage.MORALE_FLOOR, "Morale spy lowers the province's morale")
	# Catching: over many hours every enemy spy is eventually caught.
	var steal_spy: Dictionary = {"id": 99, "country": "russia", "city": "kharkiv", "mission": "steal", "travel": 0.0}
	var plain: = spies.catch_chance(steal_spy, "ukraine", false)
	spies.spies.append({"id": 98, "country": "ukraine", "city": "kharkiv", "mission": "counter", "travel": 0.0})
	check(spies.catch_chance(steal_spy, "ukraine", true) > plain * 2.0, "Counter-spy and garrison raise the catch chance")
	var reports: Array = []
	for day in 60: reports.append_array(spies.advance(Espionage.HOUR, world, "russia", 3 + day))
	check(spies.owned("russia").all(func(spy): return spy.mission == "counter"), "Enemy-city spies are caught in the end")
	check(reports.any(func(line): return str(line).contains("caught")), "Caught spies are reported")
	# Saving.
	spies.send("russia", kharkiv, "intel", "ukraine", ours)
	var saved: = rules.snapshot()
	var copy: = Espionage.new()
	copy.restore(saved.espionage)
	check(copy.spies.size() == spies.spies.size() and copy.next_id >= spies.next_id and copy.spies.all(func(spy): return spy.id < copy.next_id), "Spies are saved and loaded")
	var bad: = Espionage.new()
	bad.restore({"spies": [{"id": 1, "country": "mars", "mission": "steal"}, {"id": 2, "country": "russia", "mission": "fly"}]})
	check(bad.spies.is_empty(), "Invalid saved spies are dropped")
	# The AI trains spies: first a counter-spy at home, then missions against our cities.
	var ai: = Espionage.new()
	var ukraine_home: Dictionary = game.buildings.capital("ukraine")
	var targets: Array = economy.cities.filter(func(city): return economy.controller(city) == "russia")
	ai.ai_turn("ukraine", targets, ukraine_home, world)
	ai.ai_turn("ukraine", targets, ukraine_home, world)
	check(ai.owned("ukraine").size() == 2 and ai.owned("ukraine")[0].mission == "counter" and ai.owned("ukraine")[1].mission != "counter", "AI sends a counter-spy, then a mission spy")
	# Hackers (paid with gold).
	var net: = Espionage.new()
	var spend: = economy.spend_gold
	var gold_before: = int(economy.gold.russia)
	var their_cash: = float(theirs.funds)
	check(net.hack("russia", "bank", {}, "", "ukraine", int(economy.gold.russia), spend, world).is_empty(), "Bank hack works")
	check(int(economy.gold.russia) == gold_before - Espionage.HACKS.bank.gold and float(theirs.funds) < their_cash, "Bank hack costs gold and takes enemy money")
	check(not net.hack("russia", "blackout", belgorod, "russia", "ukraine", int(economy.gold.russia), spend, world).is_empty(), "No blackout on your own city")
	check(net.hack("russia", "blackout", kharkiv, "ukraine", "ukraine", int(economy.gold.russia), spend, world).is_empty() and is_equal_approx(Espionage.sabotage_factor("kharkiv"), Espionage.BLACKOUT_FACTOR), "Blackout almost stops Kharkiv's production")
	check(net.hack("russia", "satellite", {}, "", "ukraine", int(economy.gold.russia), spend, world).is_empty() and Espionage.reveals(game.buildings.city("lviv").point if not game.buildings.city("lviv").is_empty() else Vector2(-30, 0), "russia"), "Satellite hack shows the whole map")
	check(not net.hack("russia", "satellite", {}, "", "ukraine", int(economy.gold.russia), spend, world).is_empty(), "The same hack cannot run twice")
	net.advance(Espionage.HOUR * 1.01, world, "russia")
	check(not Espionage.reveals(Vector2(-30, 0), "russia"), "Satellite hack ends after an hour")
	net.advance(Espionage.HOUR * 2.0, world, "russia")
	check(Espionage.sabotage_factor("kharkiv") == 1.0, "Blackout ends after three hours")
	economy.gold.ukraine = 5000
	check(net.hack("ukraine", "firewall", {}, "", "russia", 5000, spend, world).is_empty() and net.firewall("ukraine"), "Firewall goes up")
	var gold_now: = int(economy.gold.russia)
	check(net.hack("russia", "bank", {}, "", "ukraine", gold_now, spend, world).begins_with("BLOCKED") and int(economy.gold.russia) < gold_now, "Firewall blocks the hack (gold is still spent)")
	var poor: = Espionage.new()
	check(not poor.hack("russia", "satellite", {}, "", "ukraine", 10, spend, world).is_empty(), "Not enough gold")
	var bot: = Espionage.new()
	economy.gold.ukraine = 5000
	check(bot.ai_hack("ukraine", "russia", [belgorod], 5000, spend, world) == "firewall" and bot.ai_hack("ukraine", "russia", [belgorod], int(economy.gold.ukraine), spend, world) in ["blackout", "satellite", "bank"], "AI puts up a firewall, then hacks")
	var saved_net: = Espionage.new()
	saved_net.restore(bot.snapshot())
	check(saved_net.hacks.size() == bot.hacks.size(), "Hacks are saved and loaded")
	net.hacks.clear(); net._refresh_hacks()
	# The screen opens and sends a spy.
	game.hud.espionage_requested.emit()
	await process_frame
	check(game.espionage_panel != null and game.espionage_panel.visible and game.espionage_panel.city_ids.size() > 0 and game.espionage_panel.hack_city_ids.size() > 0, "Espionage screen opens with enemy cities and hackers")
	print("ESPIONAGE CHECKS ", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)

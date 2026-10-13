extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool,message: String):
 checks += 1
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures += 1
func _initialize():call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 while not game.boot_finished: await process_frame
 await process_frame
 game.mobile_start.hide()
 game.clock.paused = true
 game.match_rules.ai_enabled = false
 GameSession.player_country = "ukraine"
 GameSession.weapons_test = false
 var city: Dictionary = game.buildings.capital("ukraine")
 var income: Dictionary = game.production.city_income(city)
 check(income.electronics>0 and income.fuel==0 and income.materials==0,"city has one commodity plus funds/manpower")
 var gross: Dictionary = game.production.gross_income()
 var maintenance: Dictionary = game.production.upkeep()
 var net: Dictionary = game.production.net_income()
 check(maintenance.ukraine.funds>0,"live army consumes funds upkeep")
 check(is_equal_approx(net.ukraine.funds,gross.ukraine.funds-maintenance.ukraine.funds),"net income includes upkeep exactly once")
 var before: float = game.production.stockpiles.ukraine.funds
 game.production.advance(1.0)
 check(is_equal_approx(game.production.stockpiles.ukraine.funds-before,net.ukraine.funds),"actual stockpile reconciles with displayed rate")
 # Owner 2026-10-13: all resources come from the cities; provinces produce nothing.
 check(game.resource_sites.sites.all(func(s):return not s.city.is_empty()),"no resource sites in provinces")
 check(game.resource_sites.income(1.0).is_empty(),"provinces earn nothing")
 var rural: Dictionary = game.buildings.provinces.places.values()[0]
 check(game.production.province_income(rural).values().all(func(v):return v == 0.0),"province income is zero")
 var city_total: = {"russia":{},"ukraine":{}}
 for c in game.production.cities:
  var who: String = game.production.controller(c)
  var made: Dictionary = game.production.city_income(c)
  for r in made: city_total[who][r] = city_total[who].get(r,0.0)+made[r]
 for who in ["russia","ukraine"]:
  check(ProductionSystem.RESOURCES.all(func(r):return is_equal_approx(city_total[who][r],gross[who][r])),"all of %s's income comes from its cities" % who)
  check(ProductionSystem.RESOURCES.all(func(r):return gross[who][r]>0),"%s's seven cities make every resource" % who)
 check(gross.russia.fuel>gross.ukraine.fuel,"Russia has more oil")
 check(gross.ukraine.electronics>gross.russia.electronics,"Ukraine has more rare earths")
 check(gross.ukraine.food>gross.russia.food,"Ukraine has more food")
 check(ProductionSystem.RESOURCES.has("food") and game.hud.resource_values.has("food"),"food is a resource in the top bar")
 check(game.production.equipment("infantry_russia").cost.food>0,"units cost food")
 var old_save: Dictionary = game.production.snapshot()
 for who in old_save.stockpiles: old_save.stockpiles[who].erase("food")
 check(game.production.validate(old_save),"saves from before food still load")
 game.production.restore(old_save)
 check(game.production.stockpiles.russia.food==300.0,"older saves start with the normal food stock")
 var unit: Dictionary = game.units.units.filter(func(u):return u.country=="ukraine" and u.visual_kind!="fighter")[0]
 for r in ProductionSystem.RESOURCES:game.production.stockpiles.ukraine[r] = 100000.0
 var russian: Dictionary = game.production.stockpiles.russia.duplicate()
 game.research.levels[unit.equipment_id] = 2
 game.units.select_unit(game.units.units.find(unit))
 check(game.research.upgrade(unit).begins_with("Modernization"),"Ukraine upgrade starts")
 check(game.production.stockpiles.russia==russian,"Ukraine upgrade does not debit Russia")
 unit.upgrade_remaining = 0
 GameSession.weapons_test = true
 await game.populate_weapons_test()
 var state: Dictionary = game.session.capture(game.clock,game.map,game.units,game.rig)
 var error: String = game.session.validate(state,game.map,game.units)
 check(error.is_empty(),"new infantry/support/aircraft saves validate: "+error)
 var bad: Dictionary = state.duplicate(true)
 var id = bad.territories.keys()[0]
 bad.territories[id].morale = -1
 check(not game.session.validate(bad,game.map,game.units).is_empty(),"invalid morale is rejected")
 GameSession.weapons_test = false
 var province: Dictionary = game.production.province(city)
 game.match_rules.change_control(province,"russia")
 check(is_equal_approx(province.morale,25.0),"conquest resets morale")
 game.clock.elapsed = ProductionSystem.DAY_SECONDS
 game.match_rules.daily_provinces()
 check(province.morale>25.0,"occupation morale recovers at day change")
 state = game.session.capture(game.clock,game.map,game.units,game.rig)
 check(state.territories[province.id].morale==province.morale,"morale is saved")
 print("RESULT checks=",checks," failures=",failures)
 game.queue_free()
 await process_frame
 quit(0 if failures==0 else 1)

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
 var rural_income: Dictionary = game.production.province_income(rural)
 check(rural_income.funds > 0 and ProductionSystem.RESOURCES.all(func(r):return r == "funds" or rural_income[r] == 0.0),"provinces pay money only (owner 2026-10-13)")
 var city_total: = {"russia":{},"ukraine":{}}
 for c in game.production.cities:
  var who: String = game.production.controller(c)
  var made: Dictionary = game.production.city_income(c)
  for r in made: city_total[who][r] = city_total[who].get(r,0.0)+made[r]
 for who in ["russia","ukraine"]:
  check(ProductionSystem.RESOURCES.all(func(r):return r == "funds" or is_equal_approx(city_total[who][r],gross[who][r])),"all of %s's resources come from its cities" % who)
  check(gross[who].funds > city_total[who].funds,"%s also earns money from provinces" % who)
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
 check(game.production.stockpiles.russia.food==ProductionSystem.START_STOCK.food,"older saves start with the normal food stock")
 # Every city recruits some manpower; recruitment centres add more. Nothing is built at the start
 # (owner), so the test builds the capital's first recruitment centre.
 var kyiv: Dictionary = game.buildings.capital("ukraine")
 var lviv: Dictionary = game.buildings.city("lviv")
 game.buildings.levels[kyiv.id].recruitment_center = 1
 check(game.buildings.level(kyiv.id,"recruitment_center") == 1 and game.production.city_income(kyiv).manpower > 0,"the capital's recruitment centre recruits manpower")
 check(game.buildings.level(lviv.id,"recruitment_center") == 0 and game.production.city_income(lviv).manpower > 0.0 and game.production.city_income(lviv).manpower < game.production.city_income(kyiv).manpower,"a city without a recruitment centre still recruits a little")
 game.buildings.levels[lviv.id].recruitment_center = 2
 check(game.production.city_income(lviv).manpower > game.production.city_income(kyiv).manpower,"more recruitment levels recruit more")
 game.buildings.levels[lviv.id].recruitment_center = 0
 # Call of War scale.
 check(ProductionSystem.START_STOCK.funds >= 30000.0,"starting money is Call of War sized")
 # Gold.
 check(game.production.gold.ukraine == GoldWallet.START and game.production.gold.russia == GoldWallet.START,"every player starts the match with 10,000 gold")
 for r in ProductionSystem.RESOURCES: game.production.stockpiles.ukraine[r] = 1000000.0
 var fuel_before: float = game.production.stockpiles.ukraine.fuel
 check(game.production.buy_with_gold("ukraine","fuel",1000).is_empty() and game.production.stockpiles.ukraine.fuel == fuel_before + 1000.0,"gold buys resources")
 check(game.production.gold.ukraine == GoldWallet.START - GoldWallet.resource_price("fuel",1000),"and costs the shown gold")
 game.production.jobs.clear()
 # Nothing is researched at the start (owner), so research the infantry first.
 game.research.levels["infantry_ukraine"] = 1
 game.buildings.levels[kyiv.id].barracks = 1
 check(game.production.schedule("infantry_ukraine",kyiv.name).is_empty(),"a unit is queued")
 var units_before: int = game.units.units.size()
 var price: int = game.production.unit_speedup_price(game.production.active_job(kyiv.name))
 check(price >= GoldWallet.MINIMUM,"the unit has a gold price to finish now (%d)" % price)
 var gold_before: int = game.production.gold.ukraine
 var finish_error: String = game.production.finish_unit_now(kyiv.name,"ukraine")
 check(finish_error.is_empty() and game.units.units.size() == units_before + 1,"gold finishes the unit at once")
 check(game.production.gold.ukraine == gold_before - price,"finishing costs the shown gold")
 check(game.buildings.schedule(kyiv.id,"industry").is_empty(),"construction is queued")
 var level_before: int = game.buildings.level(kyiv.id,"industry")
 check(game.buildings.finish_now(kyiv.id,"ukraine").is_empty() and game.buildings.level(kyiv.id,"industry") == level_before + 1,"gold finishes construction at once")
 game.production.gold.ukraine = 0
 game.production.schedule("infantry_ukraine",kyiv.name)
 check(not game.production.finish_unit_now(kyiv.name,"ukraine").is_empty(),"no gold, no finishing early")
 var saved: Dictionary = game.production.snapshot()
 check(saved.gold.ukraine == 0 and game.production.validate(saved),"gold is saved with the match")
 saved.erase("gold")
 game.production.restore(saved)
 check(game.production.gold.ukraine == GoldWallet.START,"older saves get the match gold")
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

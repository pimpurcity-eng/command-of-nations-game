extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.mobile_start.hide()
 GameSession.weapons_test=true
 game.populate_weapons_test()
 game.units.fog_enabled=false
 game.clock.paused=true
 var start=Time.get_ticks_usec()
 for i in 30: game.units._process(0.016)
 print("BENCH_UNIT_MS=",(Time.get_ticks_usec()-start)/30000.0," COUNT=",game.units.units.size())
 start=Time.get_ticks_usec()
 game.match_rules.declare_war()
 game.clock.paused=false
 for i in 3: game.clock.advance(0.016)
 print("BENCH_SIM_MS=",(Time.get_ticks_usec()-start)/3000.0)
 for obj in [game.units,game.production,game.buildings,game.match_rules]:
  start=Time.get_ticks_usec()
  for i in 3: obj.advance(0.0001)
  print("BENCH_COMPONENT ",obj.get_script().resource_path,"=",(Time.get_ticks_usec()-start)/3000.0)
 start=Time.get_ticks_usec()
 for i in 3: game.match_rules.advance_battles(0.0001)
 print("BENCH_BATTLES=",(Time.get_ticks_usec()-start)/3000.0)
 for obj in [game.match_rules.combat, game.match_rules.air_combat]:
  start=Time.get_ticks_usec()
  for i in 3: obj.advance(0.0001, game.units, {}, true)
  print("BENCH_WEAPON ",obj.get_script().resource_path,"=",(Time.get_ticks_usec()-start)/3000.0)
 game.queue_free()
 await process_frame
 quit()

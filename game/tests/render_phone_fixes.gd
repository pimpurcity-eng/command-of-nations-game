extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(720,1440)
 GameSession.player_country="russia"
 GameSession.weapons_test=true
 var game=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 3:await process_frame
 game.mobile_start.hide()
 game.rig.set_process(false)
 for entry in [["missiles_russia",1,"Larger_Command_Panel.png"],["silos_ukraine",1,"Silo_Surface_Pad.png"]]:
  var unit=game.units.units.filter(func(u):return u.equipment_id==entry[0] and u.level==entry[1])[0]
  game.units.select_unit(game.units.units.find(unit))
  game.rig.target=Vector3(unit.node.position.x,0,unit.node.position.z)
  game.rig.distance=6
  game.rig._snap(1.0)
  game.refresh_hud()
  for i in 8:await process_frame
  root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(entry[2]))
 game.queue_free()
 await process_frame
 quit()

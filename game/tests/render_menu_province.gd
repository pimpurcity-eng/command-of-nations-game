extends SceneTree
func _initialize():call_deferred("run")
func save(name: String):
 for i in 8:await process_frame
 root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name))
func run():
 root.size=Vector2i(720,1440)
 GameSession.player_country="russia";GameSession.weapons_test=false
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 for i in 3:await process_frame
 game.mobile_start.hide();game.clock.paused=true
 game.research_panel.open()
 await save("Research_Five_Production_Groups.png")
 game.research_panel.show_category(2)
 await save("Support_Research_With_Upgrade_Steps.png")
 game.research_panel.show_category(3)
 await save("Airbase_Research_With_Upgrade_Steps.png")
 game.research_panel.tree_scroll.scroll_vertical=500
 await save("Airbase_Research_Scrolled.png")
 game.research_panel.hide()
 game.production_panel.open("Moscow")
 await save("Production_Real_Equipment_Pictures.png")
 game.production_panel.hide()
 game.city_panel.open(game.buildings.city("moscow"))
 await save("Inland_City_Buildings_No_Naval_Base.png")
 game.city_panel.hide()
 var province: Dictionary = game.buildings.provinces.places.values().filter(func(p):return game.production.controlled(p,"russia"))[0]
 game.hud.show_territory(province.region)
 game.hud.construct_requested.emit()
 await save("Province_Construction_No_Unit_Production.png")
 game.queue_free();await process_frame;quit()

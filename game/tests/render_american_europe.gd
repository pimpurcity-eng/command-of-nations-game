extends SceneTree
## Genuine native phone panels and campaign screenshots; no mockups.
var game: Node
var folder: String
func _initialize() -> void: call_deferred("run")
func frames(count: int = 2) -> void:
	for i in count: await process_frame
func shot(name: String) -> void:
	await frames()
	root.get_texture().get_image().save_png(folder.path_join(name+".png"))
	print("SCREENSHOT ",name)
func run() -> void:
	folder=OS.get_environment("AMERICAN_REVIEW_DIR")
	DirAccess.make_dir_recursive_absolute(folder)
	root.size=Vector2i(720,1440);root.gui_embed_subwindows=true
	GameSession.player_country="poland";MapDefinition.use(MapDefinition.EUROPE)
	UnitSystem.force_mobile=true
	game=load(MapDefinition.scene_path()).instantiate()
	root.add_child(game);current_scene=game
	while not game.boot_finished: await process_frame
	await shot("Europe_Home")
	game.mobile_start.country_picker.show_popup()
	await shot("Europe_Country_Selection")
	game.mobile_start.country_picker.get_popup().hide()
	game.mobile_start.request_start("fresh")
	await frames(2);game.clock.paused=true;game.match_rules.ai_enabled=false
	var capital: Dictionary=game.buildings.capital("poland")
	game.rig.target=Vector3(capital.point.x,0,capital.point.y);game.rig.distance=20;game.rig._snap(1)
	await frames(6)
	await shot("Poland_American_Army")
	root.size=Vector2i(1280,800);game.rig.target=Vector3(0,0,-4);game.rig.distance=130;game.rig._snap(1)
	await shot("Europe_Campaign")
	root.size=Vector2i(720,1440)
	game.research_panel.open();game.research_panel.show_category(3)
	await shot("American_Tank_Research")
	for level in [1,3,5]:
		game.research_panel.open_unit("tanks_poland",level)
		await shot("American_Tank_Level_"+str(level))
	game.research_panel.unit_card.content.get_parent().scroll_vertical=640
	await shot("American_Attack_Defence_Terrain")
	game.research_panel.unit_card.hide();game.research_panel.hide()
	game.production_panel.open(capital.name)
	await shot("American_Production")
	game.production_panel.hide()
	var unit: Dictionary=game.units.units.filter(func(u):return u.country=="poland" and u.visual_kind=="infantry")[0]
	game.units.select_unit(game.units.units.find(unit))
	game.show_stack_info()
	await shot("American_Army_Details")
	game.stack_dialog.content.get_parent().scroll_vertical=950
	await shot("American_Troop_Cards")
	game.stack_dialog.hide()
	print("RESULT AMERICAN_EUROPE_NATIVE screenshots=12")
	game.clock.paused=true
	quit()

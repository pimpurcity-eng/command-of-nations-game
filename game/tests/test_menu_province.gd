extends SceneTree
var failures: = 0
var checks: = 0
func check(ok: bool,msg: String) -> void:
 checks+=1;print("PASS " if ok else "FAIL ",msg)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func touch(position: Vector2,pressed: bool):
 var e: = InputEventScreenTouch.new();e.index=0;e.position=position;e.pressed=pressed;root.push_input(e)
func drag(start: Vector2,finish: Vector2):
 touch(start,true)
 var e: = InputEventScreenDrag.new();e.index=0;e.position=finish;e.relative=finish-start;e.velocity=Vector2.ZERO;root.push_input(e)
 touch(finish,false)
func run():
 root.size=Vector2i(720,1440)
 GameSession.player_country="russia";GameSession.weapons_test=false
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game)
 while not game.boot_finished: await process_frame
 for i in 3:await process_frame
 game.mobile_start.hide();game.clock.paused=true;game.match_rules.ai_enabled=false
 check(game.units.units.size()==EquipmentIdentity.catalog.size()*3,"three starting units per equipment family")
 for family in EquipmentIdentity.catalog:
  var units=game.units.units.filter(func(u):return u.equipment_id==family.id)
  check(units.size()==3 and units.map(func(u):return int(u.level))==[1,3,5],family.id+" early/middle/top starting tiers")
  check(not CowUI.equipment_picture(family.id).resource_path.contains("_flag") and not UnitVisual.preview_texture(family.id).resource_path.contains("_flag"),family.id+" equipment image is not a nation flag")
 check(game.units.units.filter(func(u):return u.visual_kind=="naval").all(func(u):return game.units.sea_navigation.on_sea(Vector2(u.node.position.x,u.node.position.z))),"starting fleet is on water")
 check(game.research.level("tanks_russia")==1,"starting top-tier units do not unlock future production research")
 game.research_panel.open();game.research_panel.show_category(2)
 for i in 4:await process_frame
 var research=game.research_panel
 check(ResearchPanel.CATEGORIES.size()==6,"six research groups")
 var families=research._families(2)
 check(families.any(func(f):return f.category=="Air defense") and families.any(func(f):return f.category=="Artillery"),"artillery and air defence together in Support Factory")
 var card=research.cells[0].card
 check(card.size.x>230 and card.size.y>160,"large air-defence card layout used for support")
 check(research.tree_scroll.get_h_scroll_bar().max_value>research.tree_scroll.get_h_scroll_bar().page,"wide tree can scroll horizontally")
 var old_id=research.selected_id;var old_level=research.selected_level
 drag(Vector2(480,850),Vector2(220,430))
 await process_frame
 check(research.tree_scroll.scroll_horizontal>100 and research.tree_scroll.scroll_vertical>100,"touch swipe over research cards scrolls both axes")
 check(research.selected_id==old_id and research.selected_level==old_level,"swiping does not activate a research card")
 research.hide()
 game.production_panel.open("Moscow")
 for i in 3:await process_frame
 var list=game.production_panel.equipment_list
 var start=list.get_global_transform_with_canvas()*Vector2(200,280)
 drag(start,start-Vector2(0,200));await process_frame
 check(list.get_v_scroll_bar().value>50,"production equipment list responds to finger swipe")
 check(game.production_panel.category_picker.item_count==7,"production uses same six groups plus All")
 game.production_panel.category_picker.select(5);game.production_panel._populate_equipment()
 check(game.production_panel.filtered.is_empty(),"no inland naval production options")
 game.production_panel.hide()
 var moscow=game.buildings.city("moscow")
 game.city_panel.open(moscow);await process_frame
 check(not game.city_panel.rows.naval_base.card.visible,"naval base hidden from inland construction")
 check(not game.buildings.reason("moscow","naval_base").is_empty(),"inland naval base rejected by rules")
 game.city_panel.open(game.buildings.city("rostov_on_don"));await process_frame
 check(game.city_panel.rows.naval_base.card.visible,"naval base available at coastal city")
 game.city_panel.hide()
 var province: Dictionary = game.buildings.provinces.places.values().filter(func(p):return game.production.controlled(p,"russia"))[0]
 for r in ProductionSystem.RESOURCES:game.production.stockpiles.russia[r]=100000
 var before=game.production.province_income(province)
 check(game.buildings.schedule(province.id,"industry").is_empty(),"rural local industry can be queued")
 check(not game.buildings.schedule(province.id,"factory").is_empty(),"rural production factory rejected")
 check(not game.production.schedule("tanks_russia",province.name).is_empty(),"province cannot create units")
 game.buildings.advance(game.buildings.duration("industry",1)+1)
 check(game.buildings.provinces.level(province.id,"industry")==1,"province construction completes")
 check(game.cities.rural_districts.has(province.id) and game.cities.rural_districts[province.id].get_node("industry").visible,"completed province building appears on map")
 check(is_equal_approx(game.production.province_income(province).funds,before.funds*1.25),"local industry actually increases province output")
 check(game.buildings.schedule(province.id,"airbase").is_empty(),"rural airfield can be built")
 game.buildings.advance(game.buildings.duration("airbase",1)+1)
 check(game.units.air.available(province,"russia"),"completed airfield is an aircraft base")
 var state=game.buildings.snapshot()
 check(game.buildings.validate(state),"province buildings validate in campaign save")
 var old=state.duplicate(true);old.erase("provinces")
 check(game.buildings.validate(old),"pre-province saves remain compatible")
 game.buildings.restore(state)
 check(game.buildings.provinces.level(province.id,"industry")==1,"province buildings restore")
 var forged=state.duplicate(true);forged.provinces.levels[province.id].industry=99
 check(not game.buildings.validate(forged),"invalid rural building levels rejected")
 check(CowUI.equipment_picture("apcs_russia").resource_path==str(EquipmentIdentity.research_tier("apcs_russia",1).model).trim_suffix(".glb")+".png","APC thumbnail uses actual model, not Russian flag")
 check(CowUI.equipment_picture("fleet_russia").resource_path==str(EquipmentIdentity.research_tier("fleet_russia",1).preview),"naval thumbnail uses actual ship")
 var research_system=game.research
 game.clock.elapsed=(game.research.upgrade_day("tanks_russia",1)-1)*86400.0/SimulationClock.REAL_SECONDS_PER_SIM_SECOND
 research_system.jobs.clear()
 for r in ProductionSystem.RESOURCES:game.production.stockpiles.russia[r]=100000
 var sample={"equipment_id":"tanks_russia","level":1,"health":100.0,"visual_kind":"armor"}
 var base_damage=CombatSystem.new().damage_value(sample,"armor")
 check(research_system.start_upgrade("tanks_russia",1).is_empty(),"intermediate model upgrade can be researched")
 check(research_system.validate(research_system.snapshot()),"active intermediate research saves")
 research_system.advance(research_system.upgrade_duration(1)+0.01)
 check(research_system.refined("tanks_russia",1) and research_system.level("tanks_russia")==1,"upgrade completes without replacing model or skipping tier")
 check(is_equal_approx(CombatSystem.new().damage_value(sample,"armor"),base_damage*1.06),"intermediate upgrade improves actual combat values")
 var saved_research=research_system.snapshot()
 check(research_system.validate(saved_research),"completed intermediate research validates")
 research_system.restore(saved_research)
 check(research_system.refined("tanks_russia",1),"intermediate upgrades restore")
 var invalid_research=saved_research.duplicate(true);invalid_research.refinements.tanks_russia["4"]=true
 check(not research_system.validate(invalid_research),"unresearched intermediate upgrade rejected")
 print("RESULT checks=",checks," failures=",failures)
 game.queue_free();await process_frame;quit(1 if failures else 0)

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
 # Owner 2026-10-14 start: per city 2 infantry, 3 light tanks, 3 air defence (4 in the capital);
 # one infantry in every province outside the cities; one plane.
 for country in ["russia","ukraine"]:
  var city_count: int = game.production.cities.filter(func(c):return c.country.to_lower()==country).size()
  var mine: Array = game.units.units.filter(func(u):return u.country==country)
  check(mine.all(func(u):return int(u.level)==1),"%s starts with every unit at level 1" % country)
  var count: = func(id: String) -> int: return mine.filter(func(u):return u.equipment_id==id).size()
  check(count.call("light_tank_"+country)==3*city_count,"%s: 3 light tanks per city (%d)" % [country,count.call("light_tank_"+country)])
  check(count.call("skyguard_"+country)==3*city_count+1,"%s: 3 air defence per city, 4 in the capital (%d)" % [country,count.call("skyguard_"+country)])
  check(count.call("infantry_"+country)>2*city_count,"%s: 2 infantry per city plus infantry in the provinces (%d)" % [country,count.call("infantry_"+country)])
  check(count.call(game.STARTING_PLANE[country])==1,"%s starts with one plane" % country)
 for family in EquipmentIdentity.catalog:
  check(not CowUI.equipment_picture(family.id).resource_path.contains("_flag") and not UnitVisual.preview_texture(family.id).resource_path.contains("_flag"),family.id+" equipment image is not a nation flag")
 check(game.units.units.filter(func(u):return u.visual_kind=="naval").all(func(u):return game.units.sea_navigation.on_sea(Vector2(u.node.position.x,u.node.position.z))),"starting fleet is on water")
 check(game.research.level("tanks_russia")==1,"starting top-tier units do not unlock future production research")
 game.research_panel.open();game.research_panel.show_category(2)
 for i in 4:await process_frame
 var research=game.research_panel
 check(ResearchPanel.CATEGORIES.size()==9,"research groups incl. Missiles, Drones and Support (owner 2026-10-13)")
 var families=research._families(2)
 check(families.any(func(f):return f.category=="Air defense") and families.any(func(f):return f.category=="Artillery"),"artillery and air defence together in Support Factory")
 var card=research.cells[0].card
 check(card.size.x>=120 and card.size.y>=120,"square Call of War research cards (owner 2026-10-13)")
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
 check(game.production_panel.category_picker.item_count==10,"production uses the nine groups plus All")
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
 check(not game.buildings.schedule(province.id,"industry").is_empty(),"no industry in provinces (owner 2026-10-13)")
 check(not game.buildings.schedule(province.id,"factory").is_empty(),"rural production factory rejected")
 check(not game.production.schedule("tanks_russia",province.name).is_empty(),"province cannot create units")
 check(game.buildings.schedule(province.id,"bunker").is_empty(),"rural fortifications can be queued")
 game.buildings.advance(game.buildings.duration("bunker",1)+1)
 check(game.buildings.provinces.level(province.id,"bunker")==1,"province construction completes")
 check(game.cities.rural_districts.has(province.id) and game.cities.rural_districts[province.id].get_node("bunker").visible,"completed province building appears on map")
 check(game.buildings.schedule(province.id,"airbase").is_empty(),"rural airfield can be built")
 game.buildings.advance(game.buildings.duration("airbase",1)+1)
 check(game.units.air.available(province,"russia"),"completed airfield is an aircraft base")
 var state=game.buildings.snapshot()
 check(game.buildings.validate(state),"province buildings validate in campaign save")
 var old=state.duplicate(true);old.erase("provinces")
 check(game.buildings.validate(old),"pre-province saves remain compatible")
 game.buildings.restore(state)
 check(game.buildings.provinces.level(province.id,"bunker")==1,"province buildings restore")
 var legacy=state.duplicate(true);legacy.provinces.levels[province.id].industry=1
 check(game.buildings.validate(legacy),"older saves with province industry still load")
 var forged=state.duplicate(true);forged.provinces.levels[province.id].bunker=99
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
 research_system.advance(research_system.upgrade_duration(1)/research_system.rate("russia")+0.01) # Russia researches 15% slower (country traits)
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

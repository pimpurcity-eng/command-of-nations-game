extends SceneTree
## Exercises the real shared controller, not the old map-only viewer.
var checks: = 0
var failures: = 0
var game: Node
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures+=1
func frames(count: int = 4) -> void:
	for i in count: await process_frame
func run() -> void:
	GameSession.player_country="poland"
	MapDefinition.use(MapDefinition.EUROPE)
	UnitSystem.force_mobile=true
	game=load("res://scenes/europe_campaign.tscn").instantiate()
	if game.get_script()==null:
		check(false,"Europe controller loads")
		quit(1);return
	root.add_child(game);current_scene=game
	while not game.boot_finished: await process_frame
	await frames()
	check(game.session.countries.size()==44 and game.cities.cities.size()==164,"full Europe session uses all countries and cities")
	check(game.units.units.size()==672,"600 player troops and 72 small-country garrisons")
	for country in MapDefinition.players():
		var troops: Array = game.units.units.filter(func(unit):return unit.country==country.id)
		check(troops.size()==30,"same 30-unit opening for "+country.id)
		var tally: Dictionary = {}
		for unit in troops:
			var profile: String=UnitStats.profile_id(unit)
			tally[profile]=int(tally.get(profile,0))+1
		check(tally.get("motorized",0)==23 and tally.get("light_tank",0)==3 and tally.get("short_aa",0)==3 and tally.get("light_attack",0)==1,"regional role counts for "+country.id)
	check(game.production.stockpiles.size()==44 and game.match_rules.seat_ai.size()==43,"all other countries have economy and AI")
	game.hud.gold_requested.emit()
	check(game.trade!=null and game.research_panel!=null and game.city_panel!=null and game.gold_panel!=null,"shared trade/research/city/gold panels")
	game.gold_panel.hide()
	check(game.research.level("infantry_poland")==0,"starting troops do not grant free research")
	var city: Dictionary = game.buildings.capital("poland")
	var stock: Dictionary = game.production.stockpiles.poland.duplicate(true)
	check(game.buildings.schedule(city.id,"barracks","poland").is_empty(),"Polish construction uses real queue")
	game.buildings.advance(0.01)
	var building_job: Dictionary=game.buildings.jobs[0]
	check(building_job.paid and game.production.stockpiles.poland.funds<stock.funds,"construction charges resources once")
	var why: String=game.research.start("infantry_poland",1,"poland")
	check(why.is_empty(),"American research starts normally")
	var job: Dictionary=game.research.active("infantry_poland")
	game.research.advance(game.research.job_duration(job)/game.research.rate("poland"))
	check(game.research.level("infantry_poland")==1 and game.research.level("infantry_romania")==0,"completion is country-specific")
	game.buildings.advance(game.buildings.duration("barracks",1)/game.buildings.construction_rate(city.id)+0.1)
	check(game.buildings.level(city.id,"barracks")==1,"same construction timers complete")
	check(game.production.enqueue("infantry_poland",city.name).is_empty(),"American unit enters shared production")
	var order: Dictionary=game.production.jobs[0]
	game.production.advance(game.production.job_duration(order)/game.buildings.production_rate(city.id,game.production.equipment(order.equipment))+0.1)
	check(game.units.units.filter(func(unit):return unit.country=="poland").size()==31,"shared unit-ready callback spawns American troop")
	check(game.production.gold.poland==GoldWallet.START,"normal production does not spend gold")
	check(not game.trade.agreement("poland","romania"),"named map countries are not free neutral imports")
	game.match_rules.diplomacy.relation("poland","romania").trade=true
	check(game.trade.agreement("poland","romania"),"trade agreement uses shared diplomacy")
	game.match_rules.set_guard("poland",true)
	check(game.match_rules.guarded("poland"),"sleep defence available")
	game.match_rules.set_guard("poland",false)
	# Movement on the same province/road graph.
	var army: Dictionary=game.units.units.filter(func(unit):return unit.country=="poland" and unit.visual_kind=="infantry")[0]
	game.units.select_unit(game.units.units.find(army))
	army=game.units.units[game.units.selected]
	var start: = Vector2(army.node.position.x,army.node.position.z)
	var destination: Vector2=city.point
	for territory in game.map.territories:
		if territory.playable and territory.owner=="poland" and territory.center.distance_to(start)>1:
			destination=game.match_rules.capture_point(territory);break
	var path: Array=game.units.path_for(army,start,destination)
	check(not path.is_empty(),"American army uses shared land routing")
	if not path.is_empty():
		check(game.units.order(Vector3(destination.x,0,destination.y)),"shared selection and move command accepted")
		game.units.advance(0.5)
		check(Vector2(army.node.position.x,army.node.position.z).distance_to(start)>0,"American army actually moves")
	# Finite supply and money conservation between actual countries, using the real
	# departure/delivery transaction (geographic route planning is tested separately).
	game.buildings.levels[city.id].train_station=1
	var route: = {"id":900,"country":"poland","partner":"romania","city":city.id,"mode":"rail","cargo":"food","path":[city.point,city.point+Vector2(1,0)]}
	game.production.stockpiles.romania.food=50.0
	var funds: float=game.production.stockpiles.poland.funds+game.production.stockpiles.romania.funds
	var food: float=game.production.stockpiles.poland.food+game.production.stockpiles.romania.food
	game.trade._depart(route)
	check(game.trade.convoys.size()==1 and game.trade.convoys[0].amount==50 and game.trade.convoys[0].seller=="romania","trade only ships seller-owned goods")
	check(is_equal_approx(funds,game.production.stockpiles.poland.funds+game.production.stockpiles.romania.funds),"trade transfers the price without creating money")
	if not game.trade.convoys.is_empty():
		var convoy: Dictionary=game.trade.convoys.pop_back()
		game.trade._arrive(convoy);convoy.node.queue_free()
	check(is_equal_approx(food,game.production.stockpiles.poland.food+game.production.stockpiles.romania.food),"delivery conserves goods")
	game.trade._depart(route)
	check(game.trade.convoys.is_empty(),"empty seller cannot generate free supplies")
	var ports: = 0
	for port in game.production.cities:
		if not port.has("naval_spawn"): continue
		var point: = GeographicProjection.project(port.naval_spawn.longitude,port.naval_spawn.latitude)
		check(game.units.sea_navigation.on_sea(point),"port launch lies at sea: "+port.name)
		ports+=1
	check(ports>20,"Europe has working coastal production locations")
	# The same combat engine damages a declared enemy and leaves neutrals alone.
	var fixture: = UnitSystem.new()
	fixture.stacks.armies=fixture;fixture.air.armies=fixture
	fixture.diplomacy=game.match_rules.diplomacy;fixture.at_war=true;fixture.fog_enabled=false
	for pair in [["tanks_poland","attacker"],["infantry_belarus","defender"],["infantry_germany","neutral"]]:
		var unit: = UnitStats.specimen(pair[0]);unit.merge({"id":pair[1],"stack_id":pair[1],"node":Node3D.new(),"moving":false,"engaged":true,"fire_mode":"at_will","attack_target":"defender" if pair[1]=="attacker" else ""})
		unit.node.position=Vector3(city.point.x+fixture.units.size()*0.1,0,city.point.y)
		fixture.units.append(unit)
	var combat: = CombatSystem.new()
	check(combat.target([fixture.units[0]],fixture.stacks.groups(),fixture).is_empty(),"a global war flag does not authorize attacks on neutral countries")
	fixture.diplomacy.set_war("poland","belarus",true)
	combat.advance(0.1,fixture)
	check(fixture.units[1].health<100 and fixture.units[2].health==100,"American damage reaches only the declared enemy")
	fixture.diplomacy.set_war("poland","belarus",false)
	for unit in fixture.units: unit.node.free()
	fixture.free()
	game.rig.target=Vector3(-61,0,-40);game.rig.distance=130
	# Full new-map save validation, including a distant camera target and all production data.
	var snapshot: Dictionary=game.session.capture(game.clock,game.map,game.units,game.rig)
	var error: String=game.session.validate(snapshot,game.map,game.units)
	check(error.is_empty(),"complete Europe snapshot validates: "+error)
	var save: = "user://qa_europe_campaign.json"
	check(game.session.write_save(save,snapshot).is_empty(),"Europe save writes")
	var loaded: Dictionary=game.session.read_save(save,game.map,game.units)
	check(loaded.has("state"),"Europe save reads and validates: "+str(loaded.get("error","")))
	if loaded.has("state"):
		game.session.restore(loaded.state,game.clock,game.map,game.units,game.rig)
		check(game.research.level("infantry_poland")==1 and game.units.units.size()==673,"research and troops survive resume")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save))
	game.clock.set_speed(10)
	check(game.clock.speed==10,"same 10x clock")
	game.clock.paused=true
	print("RESULT EUROPE_CAMPAIGN checks=",checks," failures=",failures)
	quit(0 if failures==0 else 1)

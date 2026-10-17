extends SceneTree
var checks: = 0
var failures: = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL ",label)
func run() -> void:
	check(MapDefinition.is_regional(),"regional remains default")
	var original_count: = EquipmentIdentity.catalog.size()
	GameSession.player_country="poland"
	MapDefinition.use(MapDefinition.EUROPE)
	check(MapDefinition.players().size()==20 and MapDefinition.countries().size()==44,"20 selectable / 44 total nations")
	check(MapDefinition.save_path()=="user://europe20_save.json","Europe save is separate")
	var countries: Dictionary = {}
	for nation in MapDefinition.countries():
		countries[nation.id]=nation
		var expected: = "american" if nation.id in ["poland","romania"] else "russian" if nation.id in ["russia","belarus","serbia"] else "european"
		check(Doctrine.of(nation.id)==expected,"doctrine "+nation.id)
	var ids: Dictionary = {}
	var counts: Dictionary = {}
	for spec in EquipmentIdentity.catalog:
		check(not ids.has(spec.id),"unique identity "+spec.id)
		ids[spec.id]=true
		check(countries.has(spec.country),"country belongs to map "+spec.id)
		check(spec.research_tiers.size()==5,"five levels "+spec.id)
		counts[spec.country]=int(counts.get(spec.country,0))+1
		for level in range(1,6):
			var unit: = UnitStats.specimen(spec.id,level)
			check(UnitStats.max_hp(unit)>0 and is_finite(UnitStats.max_hp(unit)),"valid HP "+spec.id)
			check(EquipmentEconomy.duration(spec,level)>0,"positive work "+spec.id)
			for target in UnitClasses.ALL:
				check(UnitStats.base_damage(unit,target)>=0 and UnitStats.base_damage(unit,target,true)>=0,"nonnegative combat "+spec.id)
	check(counts.poland==46 and counts.romania==46,"complete American roster for both nations")
	check(EquipmentIdentity.research_tier("tanks_poland",1).model.ends_with("usa_m60a3_patton.glb") and EquipmentIdentity.research_tier("tanks_poland",5).model.ends_with("usa_m1a2_sepv3.glb"),"American tank progression")
	check(EquipmentIdentity.research_tier("tanks_belarus",1).model==EquipmentIdentity.research_tier("tanks_russia",1).model,"Belarus uses Russian originals")
	check(EquipmentIdentity.research_tier("tanks_serbia",5).model==EquipmentIdentity.research_tier("tanks_russia",5).model,"Serbia uses Russian originals")
	check(EquipmentIdentity.research_tier("tanks_turkey",1).model==EquipmentIdentity.research_tier("tanks_ukraine",1).model,"Turkey uses European originals")
	# The American roster fills exactly the current 46 active categories, with no extras.
	var active_profiles: Array = []
	for spec in EquipmentIdentity.catalog:
		if spec.country=="poland":
			check(not str(spec.get("balance_profile","")).is_empty(),"existing role "+spec.id)
			check(not spec.balance_profile in active_profiles,"one family per existing role "+spec.id)
			active_profiles.append(spec.balance_profile)
			for pair in ([[1,2],[3,4]] if spec.research_tiers[0].model.get_file().begins_with("usa_") else []):
				check(EquipmentIdentity.research_tier(spec.id,pair[0]).model==EquipmentIdentity.research_tier(spec.id,pair[1]).model,"same era model "+spec.id)
	var geography: = RegionData.territories()
	var cities: = GeographicProjection.load_cities()
	check(cities.size()==164,"all player and AI cities")
	for nation in MapDefinition.players():
		check(cities.filter(func(city):return city.country_id==nation.id).size()==7,"seven cities "+nation.id)
	for city in cities:
		check(geography.any(func(t):return t.playable and t.owner==city.country_id and RegionData.contains(t,city.point)),"city is on own land "+city.name)
		check(not ResourceSites.city_resources(city.name).is_empty(),"city has resource specialization "+city.name)
		var original: = Vector2(city.longitude,city.latitude)
		check(GeographicProjection.unproject(city.point).distance_to(original)<0.0001,"projection roundtrip "+city.name)
	var economy: = ProductionSystem.new()
	var terrain: = StrategicMap.new();terrain.territories=geography
	var session: = GameSession.new()
	economy.setup(terrain,cities,session.countries)
	var clock: = SimulationClock.new()
	var research: = ResearchSystem.new();research.setup(economy,clock,null);economy.research=research
	check(research.level("infantry_poland")==0 and research.level("infantry_romania")==0,"no technology starts researched, matching current rules")
	research.levels.tanks_poland=2
	check(research.level("tanks_romania")==0,"countries have independent research")
	check(is_equal_approx(research.rate("germany"),1.0/0.85),"European discount retained")
	check(not Doctrine.stealth(UnitStats.specimen("yak130_poland",1)),"ordinary F-16 is not stealth")
	check(Doctrine.stealth(UnitStats.specimen("fighters_poland",3)),"F-22 tier has stealth")
	var panel: = MobileStartPanel.new();root.add_child(panel);panel.setup(StrategyTheme.create(),false)
	check(panel.country_picker.item_count==20 and panel.europe_button.disabled and panel.europe_button.text=="COMING SOON","Europe 20-country selector kept; Games list shows Europe as coming soon (owner 2026-10-17)")
	check(panel.selected_country()=="poland","selected nation preserved")
	check(session._point([-61.0,-40.0]) and not session._point([5000,5000]),"save bounds fit Europe and reject invalid positions")
	panel.free();terrain.free();clock.free()
	MapDefinition.use(MapDefinition.REGIONAL)
	check(EquipmentIdentity.catalog.size()==original_count and MapDefinition.save_path()=="user://regional_save.json","regional catalogue and save restore exactly")
	print("RESULT AMERICAN_EUROPE checks=",checks," failures=",failures," countries=44 American_families=46")
	quit(0 if failures==0 else 1)

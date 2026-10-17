extends "res://scripts/main.gd"
## The existing campaign controller owns every gameplay system. This adapter supplies only
## Europe geography, country starting forces and map framing; it does not fork combat/UI.

var _europe_label_revision: = -1
var _city_visibility: UnitSystem
var _online_session: = false

func begin_online_session() -> void:
	_online_session = true

func autosave(path: String = SAVE_PATH) -> String:
	if _online_session: return "Online matches are saved on the server"
	return super.autosave(path)

func save_game() -> void:
	if _online_session:
		hud.show_status("Online matches are saved on the server")
		return
	super.save_game()

func load_game() -> void:
	if not _online_session: super.load_game()

func return_to_home() -> void:
	if _online_session:
		if online != null: online.leave()
		elif MatchClient.active != null: MatchClient.active.leave()
		paused_to_home = false
		MapDefinition.launch(get_tree(), MapDefinition.EUROPE)
		return
	super.return_to_home()

func sync_remote_view() -> void:
	if _city_visibility != null: _city_visibility.sync(units)

func _ready() -> void:
	MapDefinition.use(MapDefinition.EUROPE)
	await super._ready()
	_city_visibility=load("res://scripts/europe_city_visibility.gd").new()
	add_child(_city_visibility)
	_city_visibility.sync(units)
	cities.armies=_city_visibility
	_configure_europe_view()
	apply_player_country()

func populate_campaign_forces(staged: bool = false) -> void:
	# The loader owns the progress UI. Freeze campaign callbacks while its armies are
	# assembled; otherwise city/garrison scans run against every partial starting army.
	var callbacks: Array = []
	for child in get_children():
		callbacks.append([child,child.process_mode]);child.process_mode=Node.PROCESS_MODE_DISABLED
	staged=staged and DisplayServer.get_name()!="headless"
	units.restore([])
	var spawned: = 0
	var total: = MapDefinition.players().size()*30+int(MapDefinition.data.ai_countries.size())*3
	var city_points: Array = production.cities.map(func(city):return city.point)
	UnitSystem._city_points=PackedVector2Array(city_points)
	for country in session.countries:
		var homes: Array = production.cities.filter(func(city):return city.country.to_lower() == country)
		var capital: = buildings.capital(country)
		if homes.is_empty() or capital.is_empty(): continue
		var player_slot: bool = session.countries[country].get("player_slot",true)
		var others: Array = production.cities.filter(func(city):return city.country.to_lower()!=country)
		var front: Array = homes.filter(func(city):return city.id!=capital.id)
		front.sort_custom(func(a,b):return _border_distance(a.point,others)<_border_distance(b.point,others))
		var front_ids: Array = front.slice(0,2).map(func(city):return city.id)
		var plan: Array = []
		for home in homes:
			var mixed: bool = home.id == capital.id or home.id in front_ids
			for profile in (["motorized","light_tank","short_aa"] if mixed else ["motorized","motorized","motorized"]):
				plan.append([EquipmentRosters.family(country,profile),home])
		if player_slot:
			var airfield: Dictionary = {}
			for place in buildings.provinces.places.values():
				if str(place.country).to_lower()!=country: continue
				if airfield.is_empty() or place.point.distance_to(capital.point)<airfield.point.distance_to(capital.point): airfield=place
			if not airfield.is_empty():
				buildings.provinces.levels[airfield.id].airbase=1
				plan.append([EquipmentRosters.family(country,"light_attack"),airfield])
			var posts: Array = []
			var seen: Dictionary = {}
			for territory in map.territories:
				if not territory.playable or territory.owner!=country or seen.has(territory.title): continue
				seen[territory.title]=true
				var post: = match_rules.capture_point(territory)
				if not buildings.provinces.places.has("province:"+str(territory.title)): continue
				posts.append({"id":"province_"+str(territory.id),"point":post})
			var used: Array = city_points.duplicate()
			for i in 8:
				posts.sort_custom(func(a,b):return _spacing(a.point,used)>_spacing(b.point,used))
				if posts.is_empty(): break
				var post: Dictionary = posts.pop_front()
				used.append(post.point)
				plan.append([EquipmentRosters.family(country,"motorized"),post])
		var number: = 0
		for entry in plan:
			if str(entry[0]).is_empty(): continue
			var family: = EquipmentIdentity.spec(entry[0])
			var home: Dictionary = entry[1]
			var spec: = {"id":"europe_%s_%d"%[country,number],"country":country,"equipment_id":family.id,"name":EquipmentIdentity.research_title(family.id,1),"visual_kind":family.visual_kind,"level":1,"base_city":home.id}
			if family.visual_kind!="fighter": spec.stack_id=("start_ad_" if family.visual_kind=="air_defense" else "start_")+str(home.id)
			units._spawn(spec,home.point,MapDefinition.country_color(country).lightened(0.2))
			number+=1;spawned+=1
			if staged and FrameBudget.spent():
				boot_progress.emit(spawned,total)
				await get_tree().process_frame
				FrameBudget.restart()
	for callback in callbacks: callback[0].process_mode=callback[1]
	boot_progress.emit(total,total)
	if cities!=null: cities.sync_buildings()
	units.fog_enabled=true
	if fog!=null: fog.refresh(true)

func _border_distance(point: Vector2,others: Array) -> float:
	var distance: = INF
	for city in others: distance=minf(distance,point.distance_to(city.point))
	return distance
func _spacing(point: Vector2,used: Array) -> float:
	var distance: = INF
	for other in used: distance=minf(distance,point.distance_to(other))
	return distance

func populate_weapons_test(show_progress: bool = false, scenario: String = "all") -> void:
	# Keep the existing range useful without cloning every shared European model 39 times.
	var full_catalog: Array = EquipmentIdentity.catalog
	EquipmentIdentity.catalog=full_catalog.filter(func(family):return family.country in [GameSession.player_country,GameSession.opponent_country()])
	await super.populate_weapons_test(show_progress,scenario)
	EquipmentIdentity.catalog=full_catalog

func apply_player_country(focus: bool = true) -> void:
	super.apply_player_country(focus)
	var ai_countries: Array = session.countries.keys().filter(func(country):return country!=GameSession.player_country)
	match_rules.set_ai_countries(ai_countries)
	if trade!=null: trade.ai_countries=ai_countries

func _attack_army(target: Dictionary) -> void:
	if target.country!=GameSession.player_country: GameSession.enemy_country=target.country
	super._attack_army(target)

func _with_war(enemy: String, then: Callable) -> void:
	if not match_rules.winner.is_empty(): return
	if GameSession.weapons_test or match_rules.diplomacy.at_war(GameSession.player_country, enemy):
		then.call()
		return
	if war_dialog != null and is_instance_valid(war_dialog): war_dialog.free()
	var dialog: = ConfirmationDialog.new()
	war_dialog = dialog
	dialog.title = "Declare war?"
	dialog.dialog_text = "You are at peace with %s.\nDeclare war and attack?" % MapDefinition.country_name(enemy)
	dialog.ok_button_text = "Declare war"
	dialog.cancel_button_text = "Cancel"
	dialog.add_theme_font_size_override("font_size", 26)
	add_child(dialog)
	dialog.confirmed.connect(func():
		GameSession.enemy_country = enemy
		match_rules.declare_war()
		then.call()
		dialog.queue_free())
	dialog.canceled.connect(func():
		attack_order = false
		_set_order_mode(false)
		dialog.queue_free())
	dialog.popup_centered()

func join_online(operation: String = "") -> void:
	if account_panel == null:
		account_panel = AccountPanel.new()
		add_child(account_panel)
		account_panel.auth.session_changed.connect(refresh_home_commander)
		await get_tree().process_frame
	if not account_panel.auth.signed_in():
		mobile_start.cancel_loading("Sign in to choose your online country")
		account_panel.open()
		return
	var settings: = ConfigFile.new()
	settings.load(GameAudio.SETTINGS_PATH)
	if online != null:
		online.leave()
		online.queue_free()
	online = MatchClient.new()
	add_child(online)
	var lobby: = MatchLobbyPanel.new()
	add_child(lobby)
	lobby.open(hud.get_child(0).theme, online)
	lobby.cancelled.connect(func(): mobile_start.cancel_loading("Choose a match or start an offline campaign"))
	online.welcomed.connect(func(_state):
		_clear_training()
		online.attach(self)
		apply_player_country()
		# Country focusing must not enable local AI while connected.
		match_rules.ai_enabled = false
		mobile_start.hide()
		lobby.queue_free()
		audio.play_music("battle_theme")
		hud.show_status("ONLINE · " + MapDefinition.country_name(online.country) + " · game " + online.match_id))
	online.closed.connect(func(reason):
		mobile_start.cancel_loading(reason if not reason.is_empty() else "Disconnected · open Europe Online to rejoin")
		hud.show_status("Disconnected · open Europe Online to rejoin"))
	var match_id: = operation if not operation.is_empty() else str(settings.get_value("online", "europe_match", "europe-1"))
	var endpoint: = str(settings.get_value("online", "europe_server_url", ONLINE_SERVER + "/europe"))
	var error: = online.preview(endpoint, account_panel.auth.access_token, match_id)
	if error != OK:
		lobby.status.text = "Could not reach the match server · go back and try again"
		mobile_start.cancel_loading("Could not reach the match server")

func _configure_europe_view() -> void:
	rig.bounds=MapDefinition.bounds().grow(-2)
	rig.maximum_distance=140.0
	rig.camera.far=450.0
	for territory in map.territories:
		var material: ShaderMaterial = map.materials[territory.id]
		material.set_shader_parameter("MAP_ORIGIN",MapDefinition.origin())
		material.set_shader_parameter("MAP_EXTENT",MapDefinition.extent())
		material.set_shader_parameter("relief",load("res://assets/materials/relief_europe20.png"))
		var closest: Array = cities.cities.duplicate()
		closest.sort_custom(func(a,b):return a.point.distance_squared_to(territory.center)<b.point.distance_squared_to(territory.center))
		var points: = PackedVector2Array()
		for city in closest.slice(0,12): points.append(city.point)
		material.set_shader_parameter("city_points",points)
		material.set_shader_parameter("city_count",points.size())
	for node in get_children():
		if not node is MeshInstance3D or not node.mesh is PlaneMesh or not node.material_override is ShaderMaterial: continue
		if not str(node.material_override.shader.resource_path).ends_with("ocean.gdshader"): continue
		node.mesh.size=MapDefinition.extent()*3+Vector2(80,80)
		var center: = MapDefinition.bounds().get_center()
		node.position=Vector3(center.x,0,center.y)
		node.material_override.set_shader_parameter("coast_mask",load("res://assets/materials/coast_europe20.png"))
		node.material_override.set_shader_parameter("mask_origin",MapDefinition.origin())
		node.material_override.set_shader_parameter("mask_size",MapDefinition.extent())
	for country in RegionData.countries():
		if country.country in ["Russia","Ukraine"]: continue
		map.add_child(MapBorder.build([country.polygon],map,1.65,Color("343d38")))
	map.territory_selected.connect(func(territory):
		if territory.controller!=GameSession.player_country: GameSession.enemy_country=territory.controller)
	match_rules.diplomacy.changed.connect(_update_europe_relations)
	match_rules.report.connect(func(_message):_update_europe_relations())
	# Cover the old two-country swatch with a country-aware swatch. All city behavior stays shared.
	for swatch in cities.find_children("*","Control",true,false):
		if swatch is CitySystem.FlagSwatch:
			var flag: = CountryFlag.new()
			flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			flag.follow_parent=true
			swatch.add_child(flag)
	var flag: = CountryFlag.new()
	flag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flag.player=true
	hud.flag_badge.add_child(flag)
	hud.detail.text="EUROPE TEST · 20 PLAYER NATIONS · 7 CITIES EACH"
	_refresh_country_names()
	_update_europe_relations()

func _update_europe_relations() -> void:
	for territory in map.territories:
		if not territory.playable: continue
		map.materials[territory.id].set_shader_parameter("hostile",match_rules.diplomacy.at_war(GameSession.player_country,territory.controller))

func _process(delta: float) -> void:
	super._process(delta)
	if boot_finished and _city_visibility!=null and (cities._state_timer<=delta or _city_visibility.terrain_revision!=units.terrain_revision): _city_visibility.sync(units)
	if boot_finished and units.terrain_revision!=_europe_label_revision: _refresh_country_names()

func _refresh_country_names() -> void:
	for label in cities.national_labels: label.queue_free()
	cities.national_labels.clear()
	var largest: Dictionary = {}
	for country in RegionData.countries():
		var box: = Rect2(country.polygon[0],Vector2.ZERO)
		for point in country.polygon: box=box.expand(point)
		if box.get_area()>largest.get(country.country_id,[0.0])[0]: largest[country.country_id]=[box.get_area(),box,country]
	for country in largest:
		var held: = CountryMapLabel.held_centre(country,map.territories)
		if not cities._home_centres.has(country): cities._home_centres[country]=held
		if held==Vector2.ZERO: continue
		var box: Rect2=largest[country][1]
		var polygon: PackedVector2Array=largest[country][2].polygon
		var best: = box.get_center()
		var best_width: = 0.0
		for step in 9:
			var y: = box.position.y+box.size.y*(0.3+0.05*step)
			var hits: Array = []
			for i in polygon.size():
				var a: = polygon[i];var b: = polygon[(i+1)%polygon.size()]
				if (a.y-y)*(b.y-y)<0: hits.append(a.x+(y-a.y)/(b.y-a.y)*(b.x-a.x))
			hits.sort()
			for i in range(0,hits.size()-1,2):
				if hits[i+1]-hits[i]>best_width:
					best_width=hits[i+1]-hits[i];best=Vector2((hits[i]+hits[i+1])*0.5,y)
		var half: = minf(minf(box.size.x*0.32,9.0),best_width*0.4)
		if half<0.6: continue
		best+=held-cities._home_centres[country]
		var label: = CountryMapLabel.new()
		map.add_child(label)
		label.setup(MapDefinition.country_name(country).to_upper(),PackedVector2Array([best-Vector2(half,0),best+Vector2(half,0)]),map)
		label.update_zoom(rig.rendered_distance)
		cities.national_labels.append(label)
	_europe_label_revision=units.terrain_revision
	cities._labels_revision=_europe_label_revision

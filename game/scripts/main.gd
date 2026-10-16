extends Node3D
signal boot_progress(completed: int, total: int)
signal boot_ready
var boot_finished: bool = false
var match_started_msec := 0
var account_panel: AccountPanel
var audio: GameAudio
## Ranks, medals and achievements (kept on the phone, synced to the account when signed in).
var achievements: = Achievements.new()
var lost_city: = false
var tutorial: Tutorial
## Alerts: an army attacked off-screen is announced (at most once every ALERT_GAP seconds).
const ALERT_GAP: = 45.0
var _last_alert: = -1000.0
var used_wmd: = false
var badges: UnitBadges
var test_models: Node3D
var fog: FogOfWar
var map: StrategicMap
var rig: StrategyCamera
var units: UnitSystem
var hud: StrategyHUD
var cities: CitySystem
var combat_effects: CombatEffects
var production: ProductionSystem
var resource_sites: ResourceSites
var production_panel: ProductionPanel
var research: ResearchSystem
var research_panel: ResearchPanel
var buildings: BuildingSystem
var city_panel: CityPanel
var province_panel: ProvincePanel
var exchange_panel: ExchangePanel
var trade: TradeNetwork
var trade_panel: TradePanel
var espionage_panel: EspionagePanel
var weapon_showcase: WeaponShowcase
var mobile_start: MobileStartPanel
var autosave_timer: = 0.0
var browser_callback: JavaScriptObject
var browser_resume_callback: JavaScriptObject
var browser_suspended: = false
var resume_after_background: = false
var resource_country: = GameSession.player_country
var campaign_panel: CampaignPanel
var army_selection: ArmySelectionPanel
var fire_panel: FireControlPanel
var army_command: ArmyCommandPanel
var rally_city: = ""
var rally_markers: Dictionary = {}
var attack_order: = false
var stack_dialog: ArmyDetailsPanel
var result_dialog: AcceptDialog
var append_order: = false
## True until the first point of a waypoint path is tapped (that tap replaces the old route).
var waypoint_first: = false
var order_mode: = false
## Last map tap, so tapping the same spot again steps to the next army or the city under it.
var _tap_cycle: Dictionary = {}
var gold_panel: GoldPanel
## Owner 2026-10-15: 3 light tanks, 3 air defence, 1 plane and 23 infantry a side.
## Each of the seven cities holds three ground units. The capital and two front cities
## hold an infantry, tank and air defence; the other four hold three infantry each.
## The remaining eight infantry occupy separate provinces; the plane keeps its province airport.
const STARTING_ARMY: = {"capital": {"infantry": 1, "light_tank": 1, "skyguard": 1}, "front": {"infantry": 1, "light_tank": 1, "skyguard": 1}, "city": {"infantry": 3}, "front_cities": 2, "border_infantry": 8, "plane": 1}
## Each side's starter light attack jet.
const STARTING_PLANE: = {"russia": "yak130_russia", "ukraine": "hawk_t2_ukraine"}
var selecting_armies: = false
var patrol_order: = false
var clock: SimulationClock
var match_rules: MatchSystem
var session: GameSession
const SAVE_PATH: = "user://regional_save.json"
## Start-up timing in the browser console (speed work, owner 2026-10-15).
func _boot_mark(step: String) -> void: print("BOOT ", step, " at ", Time.get_ticks_msec(), " ms")
func _ready() -> void :
	_boot_mark("main start")
	# Prevent costly detail loading/rendering before the portrait start screen is ready.
	# The start-screen CanvasLayer remains visible independently of the 3D scene.
	if UnitSystem.mobile_device(): visible = false
	var menu_scroll: = MenuTouchScroll.new()
	add_child(menu_scroll)
	# Owner 2026-10-14 (browser on the phone: "It's no good for phone"): the stretch mode already
	# scales the 720x1440 layout to the screen; multiplying by the device pixel ratio as well made
	# everything twice too big and pushed the top bar and side buttons off the screen.
	var environment: = WorldEnvironment.new()
	var settings: = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("0b1925")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("bed6ed")
	settings.ambient_light_energy = 0.36
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.ambient_light_color = Color("b8c8d5")
	environment.environment = settings
	add_child(environment)
	# Owner 2026-10-15: "why are you taking away the quality? I told you not to." Phones get the
	# same full-resolution, smoothed picture as computers; only the shadow map is smaller.
	if UnitSystem.mobile_device():
		get_viewport().msaa_3d = Viewport.MSAA_2X
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
	var sun: = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -35, 0)
	sun.light_color = Color("fff1d5")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	# Map-scale shadows: the defaults (100 m range, 0.1 bias) detached vehicle shadows from
	# their hulls, so tanks looked like they were floating.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 45.0
	# 0.02 / 0.5 caused shadow acne (thin stripes across vehicles on phones).
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	var sea: = MeshInstance3D.new()
	var plane: = PlaneMesh.new()
	plane.size = Vector2(120, 120)
	sea.mesh = plane
	var ocean: = ShaderMaterial.new()
	ocean.shader = load("res://assets/ocean.gdshader")
	ocean.set_shader_parameter("coast_mask", load("res://assets/coast_mask.png"))
	sea.material_override = ocean
	add_child(sea)
	var water_label: = Label3D.new()
	water_label.text = "B L A C K   S E A"
	water_label.position = map_position(33, 43)
	water_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	water_label.font_size = 48
	water_label.pixel_size = 0.018
	water_label.modulate = Color("568291")
	add_child(water_label)
	map = StrategicMap.new()
	add_child(map)
	if not map.build_finished:
		await map.map_ready
		_boot_mark("map")
	rig = StrategyCamera.new()
	add_child(rig)
	audio = get_tree().root.get_node_or_null("GameAudio") as GameAudio
	if audio == null:
		audio = GameAudio.new()
		add_child(audio)
	audio.rig = rig
	audio.play_music("menu_theme")
	units = UnitSystem.new()
	add_child(units)
	session = GameSession.new()
	units.setup(map, session.scenario)
	_boot_mark("units")
	fog = FogOfWar.new()
	add_child(fog)
	fog.setup(units, map)
	clock = SimulationClock.new()
	add_child(clock)
	clock.advanced.connect(units.advance)
	hud = StrategyHUD.new()
	hud.audio = audio
	add_child(hud)
	hud.account_requested.connect(func():
		if account_panel==null:
			account_panel=AccountPanel.new();add_child(account_panel)
			account_panel.operation_requested.connect(join_operation)
		rig.reset_gestures()
		account_panel.open())
	clock.state_changed.connect(refresh_hud)
	hud.pause_requested.connect( func():
		if match_rules == null or match_rules.winner.is_empty(): clock.toggle_pause())
	hud.new_match_requested.connect(new_match)
	hud.home_screen_requested.connect(return_to_home)
	hud.declare_war_requested.connect( func(): match_rules.declare_war())
	hud.merge_requested.connect( func():
		if friendly_selected(): units.stacks.merge_near_selected())
	hud.split_requested.connect( func():
		if friendly_selected(): open_army_command("split"))
	hud.stack_info_requested.connect(show_stack_info)
	hud.weapon_showcase_requested.connect( func():
		if weapon_showcase == null:
			weapon_showcase = WeaponShowcase.new()
			add_child(weapon_showcase)
			weapon_showcase.setup(hud.get_child(0).theme, clock)
		weapon_showcase.open())
	# Owner 2026-10-14: espionage (Call of War style spies).
	hud.espionage_requested.connect(func():
		if espionage_panel == null:
			espionage_panel = EspionagePanel.new()
			add_child(espionage_panel)
			espionage_panel.setup(match_rules, production, hud.get_child(0).theme)
		espionage_panel.open())
	# Owner 2026-10-13: trade (trains and ships to partners) replaces the market.
	hud.exchange_requested.connect( func():
		if trade_panel == null:
			trade_panel = TradePanel.new()
			add_child(trade_panel)
			trade_panel.setup(trade, hud.get_child(0).theme)
		trade_panel.open())
	# Owner 2026-10-15: "when you click on a waypoint, you should move, and there should be another
	# waypoint button there, so you can keep making a path". Waypoint mode stays on after each tap:
	# the first tap starts a fresh route from where the army stands (so a city halfway along the old
	# route can be chosen), every further tap adds the next leg, and Done ends it.
	hud.add_destination_requested.connect( func():
		if units.selected < 0 or units.units[units.selected].country != GameSession.player_country or units.air.is_air(units.units[units.selected]):
			hud.show_status("Select your army first")
			return
		append_order = true
		waypoint_first = true
		patrol_order = false
		attack_order = false
		rally_city = ""
		_set_order_mode(true)
		hud.set_waypoint_mode(true)
		hud.show_status("Tap the first waypoint · keep tapping to add more · Done when finished"))
	hud.speed_requested.connect(clock.set_speed)
	hud.save_requested.connect(save_game)
	hud.load_requested.connect(load_game)
	hud.show_clock(clock.elapsed, clock.speed, clock.paused)
	if match_rules != null:
		hud.navigation_menu.text = "War / View" if match_rules.at_war else "Peace / View"
	if units.selected >= 0 and not units.visible_to_player(units.units[units.selected]):
		units.selected = -1
		units._draw_route()
	map.territory_selected.connect(hud.show_territory)
	map.territory_selected.connect(_annex_hint)
	hud.retreat_requested.connect(retreat_selected)
	hud.annex_requested.connect(annex_selected)
	units.status_changed.connect(hud.show_status)
	hud.campaign_requested.connect(open_campaign)
	hud.select_armies_requested.connect(open_army_selection)
	hud.fire_control_requested.connect(open_fire_control)
	hud.delay_requested.connect( func(): open_army_command("delay"))
	hud.forced_march_requested.connect( func():
		if friendly_selected(): units.toggle_forced_march())
	hud.upgrade_requested.connect( func(): open_army_command("upgrade"))
	hud.rebase_requested.connect( func(): open_army_command("rebase"))
	units.war_requested.connect( func():
		if match_rules.winner.is_empty(): match_rules.declare_war())
	hud.attack_requested.connect( func():
		if not friendly_selected(): hud.show_status("Select your army first");return
		# Owner 2026-10-15 ("I fired on myself by accident, it declared war"): the Attack button
		# only picks a target; war is declared when an enemy is chosen and the player confirms.
		rally_city = ""
		attack_order = true
		_set_order_mode(true)
		hud.show_status("Tap a visible enemy army to attack"))
	hud.stop_requested.connect( func():
		_set_order_mode(false)
		if units.selected >= 0 and units.units[units.selected].country == GameSession.player_country: units.stop_many())
	hud.cancel_order_requested.connect( func():
		var path_done: bool = append_order and not waypoint_first
		_set_order_mode(false)
		append_order = false
		patrol_order = false
		attack_order = false
		rally_city = ""
		if path_done: clear_army_selection()
		hud.show_status("Route set" if path_done else "Order cancelled · existing route unchanged"))
	hud.unit_requested.connect( func(index: int):
		_set_order_mode(false)
		units.select_unit(index)
		if units.selected >= 0:
			rig.target = Vector3(units.units[index].node.position.x, 0, units.units[index].node.position.z)
			rig.distance = 10)
	hud.army_roster_requested.connect( func(): hud.show_army_roster(units.units))
	hud.move_requested.connect( func():
		if units.selected < 0 or units.units[units.selected].country != GameSession.player_country:
			hud.show_status("Select an army belonging to your country.")
			return
		append_order = false
		patrol_order = false
		attack_order = false
		rally_city = ""
		_set_order_mode(true)
		hud.show_status("Tap anywhere within operating range to fly" if units.air.is_air(units.units[units.selected]) else "Tap a sea destination" if units.is_naval(units.units[units.selected]) else "Tap a land destination to issue your order"))
	hud.patrol_requested.connect( func():
		if units.selected < 0 or units.units[units.selected].country != GameSession.player_country or not units.air.is_air(units.units[units.selected]): return
		rally_city = ""
		patrol_order = true
		_set_order_mode(true)
		append_order = false
		hud.show_status("Tap a patrol center within operating range"))
	hud.home_requested.connect(rig.reset)
	hud.zoom_requested.connect(rig.zoom)
	hud.rotate_requested.connect(rig.rotate_view)
	hud.terrain_mode_requested.connect(map.set_terrain_mode)
	cities = CitySystem.new()
	add_child(cities)
	await cities.setup(map, rig)
	_boot_mark("cities")
	cities.armies = units
	badges = UnitBadges.new()
	add_child(badges)
	badges.armies = units
	badges.city_labels = cities.labels
	# Owner 2026-10-13: armies are tapped by their labels from any zoom; in Attack mode an
	# enemy label is the target, in Move mode a label is the destination.
	badges.badge_clicked.connect(func(index: int):
		if index < 0 or index >= units.units.size(): return
		var tapped: Dictionary = units.units[index]
		if attack_order:
			_attack_army(tapped)
			return
		if order_mode and not selecting_armies and units.selected >= 0 and tapped.id != units.units[units.selected].id:
			player_order(tapped.node.position)
			return
		units.select_unit(index))
	production = ProductionSystem.new()
	production.setup(map, cities.cities, session.countries)
	production.armies = units
	resource_sites = ResourceSites.new()
	add_child(resource_sites)
	resource_sites.setup(map, rig)
	resource_sites.armies = units
	production.resource_sites = resource_sites
	buildings = BuildingSystem.new()
	buildings.setup(production, session.countries)
	production.buildings = buildings
	resource_sites.provinces = buildings.provinces
	units.air.economy = production
	cities.setup_buildings(buildings)
	var railway: = RailwayMap.new()
	railway.name = "Railways"
	map.add_child(railway)
	railway.setup(cities,buildings)
	buildings.completed.connect(func(city_id: String, _building: String):
		for city in cities.cities:
			if city.id == city_id:
				match_rules.chronicle.note_building(cities.controller_of(city))
				if cities.controller_of(city) == GameSession.player_country: _award_count("built")
				if cities.controller_of(city) == GameSession.player_country: audio.play("build_complete"))
	research = ResearchSystem.new()
	research.setup(production, clock, units)
	production.research = research
	clock.advanced.connect(research.advance)
	research.completed.connect(func(_equipment: String, country: String):
		match_rules.chronicle.note_research(country)
		if country == GameSession.player_country: _award_count("research")
		if country == GameSession.player_country: audio.play("research_complete"))
	session.production = production
	production.unit_ready.connect(units.spawn_produced)
	production.changed.connect( func(): hud.show_resources(resource_country, production.stockpiles[resource_country]))
	production.changed.connect(refresh_rally_markers)
	units.unit_selected.connect( func(unit: Dictionary):
		hud.stack_count = units.stacks.members(unit).size()
		hud.unit_moving = unit.get("moving", false)
		hud.show_unit(unit)
		resource_country = GameSession.player_country
		hud.show_resources(resource_country, production.stockpiles[resource_country]))
	hud.show_resources(resource_country, production.stockpiles[resource_country])
	# Gold (owner 2026-10-13): 10,000 per match; top-bar "+" opens the gold screen.
	production.changed.connect(func(): hud.show_gold(int(production.gold.get(GameSession.player_country, 0))))
	hud.show_gold(int(production.gold.get(GameSession.player_country, 0)))
	hud.gold_requested.connect(func():
		if gold_panel == null:
			gold_panel = GoldPanel.new()
			add_child(gold_panel)
			gold_panel.setup(production, hud.get_child(0).theme)
		gold_panel.open())
	clock.advanced.connect(production.advance)
	clock.advanced.connect(buildings.advance)
	production_panel = ProductionPanel.new()
	add_child(production_panel)
	production_panel.setup(production, units, hud.get_child(0).theme)
	production_panel.clock = clock
	research_panel = ResearchPanel.new()
	add_child(research_panel)
	research_panel.setup(research, hud.get_child(0).theme)
	city_panel = CityPanel.new()
	add_child(city_panel)
	city_panel.setup(buildings, hud.get_child(0).theme)
	city_panel.clock = clock
	city_panel.research = research
	city_panel.rally_requested.connect( func(id: String):
		rally_city = id
		attack_order = false
		append_order = false
		patrol_order = false
		selecting_armies = false  # owner 2026-10-16: the rally tap must not be taken as an army pick
		_set_order_mode(true)
		hud.show_status("Tap a rally point on land or sea. Each new unit checks its own route."))
	city_panel.production_requested.connect( func(city_name: String): production_panel.open(city_name))
	city_panel.research_requested.connect( func(): research_panel.open())
	hud.research_requested.connect( func():
		city_panel.hide()
		production_panel.hide()
		research_panel.open())
	hud.construct_requested.connect(func():
		var territory: Dictionary = hud.selected_territory
		var rural: = buildings.provinces.for_sector(territory)
		if not rural.is_empty():
			if province_panel == null:
				province_panel = ProvincePanel.new()
				add_child(province_panel)
				province_panel.setup(buildings,hud.get_child(0).theme)
			province_panel.open(rural)
		else:
			for city in cities.cities:
				if city.sector == territory.get("id", ""): city_panel.open(city);return)
	hud.capital_requested.connect( func():
		if match_rules == null or match_rules.winner.is_empty():
			var place: = buildings.capital(GameSession.player_country)
			rig.target = Vector3(place.point.x, 0, place.point.y)
			rig.distance = 12
			cities.select_city(place))
	hud.production_requested.connect( func():
		if match_rules == null or match_rules.winner.is_empty():
			research_panel.hide()
			city_panel.hide()
			production_panel.open())
	hud.detail.text = "REGIONAL COMMAND · " + str(cities.province_labels.size()) + " GAME PROVINCES · 10 CITIES"
	cities.city_selected.connect( func(city: Dictionary):
		if order_mode:
			player_order(map.position_at(city.point))
			return
		clear_army_selection()
		for sector in map.territories:
			if sector.id == city.sector: map.select(sector)
		hud.inspecting_unit = false
		hud.health_bar.visible = false
		var controller: = cities.controller_of(city)
		hud.selection_title.text = city.name.to_upper()
		hud.detail.text = ("YOURS · YOUR COUNTRY" if controller == GameSession.player_country else controller.to_upper()) + (" · CAPITAL" if buildings.is_capital(city) else "")
		hud.show_status("City hub · " + city.name)
		if match_rules == null or match_rules.winner.is_empty(): city_panel.open(city))
	hud.city_choices = func() -> Array:
		var result: Array = []
		for i in cities.cities.size():
			var place: Dictionary = cities.cities[i]
			if not production.controlled(place, GameSession.player_country): continue
			var capital: bool = buildings.is_capital(place)
			var entry: = [place.name + (" · Capital" if capital else ""), i]
			if capital: result.push_front(entry)
			else: result.append(entry)
		return result
	hud.city_requested.connect( func(index: int):
		var city: Dictionary = cities.cities[index]
		rig.target = Vector3(city.point.x, 0, city.point.y)
		rig.distance = 12
		cities.select_city(city))
	rig.map_clicked.connect(_map_click)
	var reach: = Rect2()
	for territory in map.territories:
		if not territory.get("playable", true): continue
		reach = Rect2(territory.center, Vector2.ZERO) if reach.size == Vector2.ZERO and reach.position == Vector2.ZERO else reach.expand(territory.center)
	rig.bounds = reach.grow(2.0)
	rig.ground_height = map.position_at(Vector2.ZERO).y
	rig.input_blocked = _touch_over_ui

	rig.target = Vector3(cities.cities[0].point.x, 0, cities.cities[0].point.y)
	rig.distance = 12
	rig._snap(1.0)
	# Start on the first army (was a fixed index 10); with an empty arsenal, stay on the city.
	# Open the camera on an army, with nothing selected (a selected army would move on the
	# first map tap).
	if units.units.size() > 10:
		rig.target = Vector3(units.units[10].node.position.x, 0, units.units[10].node.position.z)
		rig._snap(1.0)
	match_rules = MatchSystem.new()
	production.annexation = match_rules.annexation
	resource_sites.annexation = match_rules.annexation
	map.annexation = match_rules.annexation
	production.strategic = match_rules.strategic
	resource_sites.strategic = match_rules.strategic
	add_child(match_rules)
	match_rules.setup(map, units, cities.cities, clock)
	combat_effects = CombatEffects.new()
	add_child(combat_effects)
	combat_effects.setup(units, clock, match_rules)
	combat_effects.audio = audio
	match_rules.production = production
	session.match_rules = match_rules
	match_rules.report.connect(hud.show_status)
	match_rules.guard_changed.connect(func(country: String, on: bool):
		if country == GameSession.player_country: hud.set_guard(on))
	match_rules.guard_report.connect(func(country: String, text: String):
		# Online the server sends the report (it ran guard mode); offline it comes from here.
		if country == GameSession.player_country and MatchClient.active == null: show_guard_report(text))
	hud.guard_requested.connect(_toggle_guard)
	match_rules.report.connect(func(_message: String): railway.refresh())
	match_rules.finished.connect(show_result)
	match_rules.finished.connect(_report_result)
	match_rules.finished.connect(func(country: String): audio.play("victory" if country == GameSession.player_country else "defeat"))
	match_rules.report.connect(_report_sound)
	achievements.load_saved()
	match_rules.report.connect(_report_achievements)
	match_rules.unit_destroyed.connect(func(unit: Dictionary):
		if unit.country != GameSession.player_country: _award_count("kills"))
	match_rules.diplomacy.agreed.connect(func(from: String, _to: String, kind: String):
		if from == GameSession.player_country and kind == "peace": _award("peacemaker"))
	match_rules.diplomacy.coalition_created.connect(func(_name: String, leader: String):
		if leader == GameSession.player_country: _award("coalition"))
	match_rules.finished.connect(_campaign_medals)
	match_rules.combat.weapon_fired.connect(_attack_alert)
	match_rules.air_combat.weapon_fired.connect(_attack_alert)
	clock.advanced.connect(match_rules.advance)
	trade = TradeNetwork.new()
	add_child(trade)
	trade.setup(map, units, production, buildings, match_rules.diplomacy)
	match_rules.diplomacy.changed.connect(railway.refresh)
	_boot_mark("systems")
	trade.ai_countries = [GameSession.opponent_country()]
	match_rules.trade = trade
	clock.advanced.connect(trade.advance)
	trade.delivered.connect(func(country: String, partner: String, cargo: String, amount: float):
		if country == GameSession.player_country: hud.show_status("TRADE · %s delivered %d %s" % [trade.partner_name(partner), roundi(amount), cargo]))
	units.status_changed.connect( func(_message: String): refresh_hud())
	hud.show_status("PLANNING · Issue orders and queue production, then tap Play. " + VictoryRules.goal_text())
	apply_player_country()
	if GameSession.weapons_test: populate_weapons_test(); apply_player_country()
	elif session.scenario.has("starting_tiers"):
		# Keep Android's event loop responsive while creating the large starting force.
		# Desktop/headless tests retain synchronous initialization.
		await populate_campaign_forces(not OS.has_feature("headless"))
		_boot_mark("armies")
		apply_player_country()
	if true:
		mobile_start = MobileStartPanel.new()
		add_child(mobile_start)
		mobile_start.audio = audio
		mobile_start.setup(hud.get_child(0).theme, FileAccess.file_exists(SAVE_PATH))
		mobile_start.account_requested.connect(open_home_account)
		visible = false
		mobile_start.visibility_changed.connect(func():
			visible = not mobile_start.visible
			get_viewport().disable_3d = mobile_start.visible
		)
		# The start screen covers the map: do not draw the 3D map behind it from the very first
		# frame (owner 2026-10-14: start screen lagging; it was only switched off after a game).
		get_viewport().disable_3d = mobile_start.visible
		mobile_start.continue_requested.connect( func():
			if paused_to_home:
				# Back from the home screen: the match is still loaded, just carry on.
				paused_to_home = false
				mobile_start.hide()
				audio.play_music("battle_theme")
				clock.paused = false
				refresh_hud()
				return
			load_game()
			start_campaign_play()
			mobile_start.hide())
		mobile_start.fresh_requested.connect(func():
			if GameSession.weapons_test: await restore_campaign_forces()
			GameSession.weapons_test = false
			match_rules.ai_enabled = true
			GameSession.player_country = mobile_start.selected_country()
			apply_player_country()
			start_campaign_play()
			mobile_start.hide())
		mobile_start.online_requested.connect(join_online)
		mobile_start.test_requested.connect(func(scenario: String):
			GameSession.player_country = mobile_start.selected_country()
			# Browser: each weapon's model is fetched when it appears (owner 2026-10-15: waiting for
			# every model at once ran the phone out of memory).
			GameSession.weapons_test = true
			await populate_weapons_test(true, scenario)
			apply_player_country()
			rig.target = Vector3(0, 0, 5)
			rig.distance = 26
			if scenario != "all":
				# Frame the two sides of this test map.
				var middle: = Vector2.ZERO
				for unit in units.units: middle += Vector2(unit.node.position.x, unit.node.position.z)
				middle /= maxf(1.0, units.units.size())
				rig.target = Vector3(middle.x, 0, middle.y)
				rig.distance = 13
			rig._snap(1.0)
			clock.paused = true
			refresh_hud()
			hud.show_status(WeaponScenarios.title(scenario) + " · tap your armies to control them; enemy units can be inspected. Tap Play to move.")
			mobile_start.hide())
	boot_finished = true
	boot_ready.emit()
	if units != null and not GameSession.weapons_test: units.prewarm_models()
	# Closed by the phone in the middle of a match: carry straight on with it.
	if mobile_start != null and mobile_start.visible and _left_mid_match() and FileAccess.file_exists(SAVE_PATH) and not OS.has_feature("headless"):
		mobile_start.continue_requested.emit()
	# Coming back from "Sign in with Google" on the website: finish it and show the account.
	if OS.has_feature("web") and str(JavaScriptBridge.eval("/[#&](access_token|error)=/.test(window.location.hash)")) == "true":
		open_home_account()
		await account_panel.auth.finish_google_from_url()
		account_panel.open()
		refresh_home_commander()
	# The Android app was reopened by the browser after "Sign in with Google": finish it.
	if OS.has_feature("android") and not PlayerAuth.android_return_link().is_empty():
		open_home_account()
		await account_panel.auth.finish_google_from_app()
		refresh_home_commander()
	if OS.has_feature("web") and not WebExtras.available:
		web_extras = WebExtras.new()
		add_child(web_extras)
		web_extras.loaded.connect(_web_extras_loaded)
		# Computers fetch the weapons pack at once; phones only when something first needs it
		# (owner 2026-10-14: "WebGL context lost" - the phone browser ran out of memory).
		if not UnitSystem.mobile_device(): web_extras.start()
	if OS.has_feature("web"):
		browser_callback = JavaScriptBridge.create_callback(_browser_hidden)
		browser_resume_callback = JavaScriptBridge.create_callback(_browser_visible)
		JavaScriptBridge.get_interface("window").conGameHidden = browser_callback
		JavaScriptBridge.get_interface("window").conGameVisible = browser_resume_callback
		JavaScriptBridge.eval("document.addEventListener('visibilitychange',()=>{if(document.hidden)window.conGameHidden();else window.conGameVisible();});window.addEventListener('pagehide',()=>window.conGameHidden());window.addEventListener('pageshow',()=>{if(!document.hidden)window.conGameVisible();});")
var web_extras: WebExtras
## The background weapons download finished: swap stand-ins and early buildings for the real models.
func _web_extras_loaded() -> void:
	for unit in units.units:
		var model: Node3D = unit.node.get_child(0) if unit.node.get_child_count() > 0 else null
		if model != null and (model.get_meta("stand_in_model", false) or model.get_meta("missing_original_model", false)):
			model.set_meta("visual_level", -1)
			# Owner 2026-10-15 (website: "can't see troops"): phones marked a model that was still
			# downloading as missing and never asked for it again. It may have just arrived.
			model.set_meta("missing_original_model", false)
	if cities != null: cities.sync_buildings()
func _process(delta: float) -> void :
	if map != null and rig != null:
		map.set_view_distance(rig.distance)
		# Owner 2026-10-16 ("render a little bit earlier"): models start appearing as soon as the
		# zoom heads past the threshold, not when the gliding camera gets there.
		if units != null: units.view_distance = minf(rig.rendered_distance, rig.distance)
	if session == null or session.match_rules == null: return
	if mobile_start != null and mobile_start.visible: return
	autosave_timer += delta
	if autosave_timer >= 30:
		autosave_timer = 0
		autosave()
func autosave(path: String = SAVE_PATH) -> String:
	if session == null or session.match_rules == null: return "Game is still loading"
	var state: = session.capture(clock, map, units, rig)
	if browser_suspended: state.clock.paused = not resume_after_background
	return session.write_save(path, state)
func _browser_hidden(_arguments: Array) -> void :
	if browser_suspended: return
	browser_suspended = true
	resume_after_background = not clock.paused
	clock.paused = true
	rig.reset_gestures()
	if mobile_start == null or not mobile_start.visible: autosave()
	refresh_hud()
func _browser_visible(_arguments: Array) -> void :
	if not browser_suspended: return
	browser_suspended = false
	if resume_after_background and match_rules.winner.is_empty() and (mobile_start == null or not mobile_start.visible):
		clock.paused = false
	resume_after_background = false
	rig.reset_gestures()
	refresh_hud()
func _map_click(screen: Vector2, order: bool) -> void :
	if selecting_armies:
		# City hubs are destinations even when a garrison overlaps their model.
		# Owner 2026-10-16 ("it's hard to click the units"): one of your armies wins when the
		# finger is on its model or nearer to it than to the city centre.
		var meeting_city: = cities.pick_screen(screen)
		var picked: = units.pick_screen(rig.camera,screen)
		var own_army_tapped: bool = not picked.is_empty() and units.units[picked.index].country == GameSession.player_country and (meeting_city.is_empty() or picked.inside or float(picked.distance) < float(meeting_city.distance))
		if not meeting_city.is_empty() and not units.command_ids.is_empty() and not own_army_tapped:
			player_order(map.position_at(meeting_city.city.point))
			return
		if not picked.is_empty():
			var army: Dictionary = units.units[picked.index]
			if army.country != GameSession.player_country:
				hud.show_status("Choose your armies, then tap their meeting point")
				return
			var ids: Array[String] = units.command_ids.duplicate()
			if ids.has(army.id): ids.erase(army.id)
			else: ids.append(army.id)
			if ids.is_empty():
				units.selected = -1
				units.command_ids.clear()
				hud.clear_unit_selection()
				units._draw_route()
			else: units.select_armies(ids)
			hud.show_status(str(ids.size()) + " armies selected · tap more armies or a meeting point")
			return
		if units.command_ids.is_empty():
			hud.show_status("Tap your armies first, then a meeting point")
			return
		var meeting = Plane(Vector3.UP,0).intersects_ray(rig.camera.project_ray_origin(screen),rig.camera.project_ray_normal(screen))
		var province: = map.pick(rig.camera,screen)
		if not province.is_empty(): meeting = province.position
		if meeting != null: player_order(meeting)
		return
	if not rally_city.is_empty():
		var destination = Plane(Vector3.UP, 0).intersects_ray(rig.camera.project_ray_origin(screen), rig.camera.project_ray_normal(screen))
		var hit: = map.pick(rig.camera, screen)
		if not hit.is_empty(): destination = hit.position
		if destination != null: player_order(destination)
		return
	if attack_order:
		var shipment_hit: = trade.market.pick_screen(rig.camera,screen) if trade != null else {}
		if not shipment_hit.is_empty():
			var error: = trade.market.interdict(GameSession.player_country,int(shipment_hit.id),units.command_ids)
			hud.show_status("Intercept shipping lane ordered" if error.is_empty() else error)
			attack_order = false
			_set_order_mode(false)
			return
		var enemy_hit: = units.pick_screen(rig.camera, screen, true)
		if not enemy_hit.is_empty():
			_attack_army(units.units[enemy_hit.index])
			return
		# No army under the tap: advance on that province to take it.
		var target: = map.pick(rig.camera, screen)
		if target.is_empty(): hud.show_status("Choose an enemy army or province");return
		# Owner 2026-10-16: aircraft attacking an airfield or province strike the enemy there (planes on the ground too).
		if units.selected >= 0 and units.air.is_air(units.units[units.selected]):
			var parked: = units.air.target_near(Vector2(target.position.x, target.position.z), GameSession.player_country)
			if not parked.is_empty():
				_attack_army(parked)
				return
		var land_owner: String = str(target.territory.get("controller", ""))
		if land_owner.is_empty() or land_owner == GameSession.player_country:
			hud.show_status("That is your own land · choose an enemy army or province")
			return
		attack_order = false
		_with_war(land_owner, func(): player_order(target.position))
		return
	var convoy_hit: = trade.market.pick_screen(rig.camera,screen) if trade != null else {}
	if not convoy_hit.is_empty() and not order and not order_mode:
		hud.show_status("SHIPMENT #%d · %s · %d%% health · select an army, then Attack to intercept" % [convoy_hit.id,convoy_hit.mode,roundi(convoy_hit.health)])
		return
	var city_hit: = cities.pick_screen(screen)
	if not order and not order_mode:
		# Owner 2026-10-15 ("click the city and the unit separately"): an army under the finger is
		# selected; otherwise the town under the finger opens. Several armies on one spot are
		# stepped through by tapping again.
		var choices: Array = units.pick_all_screen(rig.camera, screen)
		# Owner 2026-10-16: armies are easier to tap (bigger reach), but a tap nearer the town's
		# centre than to any army still opens the town.
		if not choices.is_empty() and not city_hit.is_empty() and not choices[0].inside and float(city_hit.distance) < float(choices[0].distance): choices = []
		if choices.is_empty():
			_tap_cycle = {}
			if not city_hit.is_empty():
				clear_army_selection()
				cities.select_city(city_hit.city)
				return
			clear_army_selection()
		else:
			var step: = 0
			var near: float = 36.0 * TapScale.of(self)
			if not _tap_cycle.is_empty() and _tap_cycle.screen.distance_to(screen) < near and Time.get_ticks_msec() - int(_tap_cycle.time) < 8000:
				step = (int(_tap_cycle.step) + 1) % choices.size()
			_tap_cycle = {"screen": screen, "step": step, "time": Time.get_ticks_msec()}
			units.select_unit(choices[step].index)
			return
	if (order or order_mode) and units.selected >= 0 and (units.air.is_air(units.units[units.selected]) or units.is_naval(units.units[units.selected])):
		var destination = Plane(Vector3.UP, 0).intersects_ray(rig.camera.project_ray_origin(screen), rig.camera.project_ray_normal(screen))
		if not city_hit.is_empty() and units.air.is_air(units.units[units.selected]):
			var city: Dictionary = city_hit.city
			destination = Vector3(city.point.x,0,city.point.y)
		if destination != null: player_order(destination)
		return
	if not city_hit.is_empty():
		# Owner 2026-10-15: tapping a city as the destination opened the city and left move mode
		# on, so the next tap anywhere sent the army there. A chosen city is the destination and
		# the order ends there.
		if (order or order_mode) and units.selected >= 0:
			player_order(map.position_at(city_hit.city.point))
			return
		cities.select_city(city_hit.city)
		return
	var hit: = map.pick(rig.camera, screen)
	if hit.is_empty():
		hud.show_status("Choose a land sector")
		return
	if order or order_mode:
		player_order(hit.position)
	else:
		# Tapping empty map shows the province; it no longer grabs the nearest army.
		map.select(hit.territory)

func map_position(longitude: float, latitude: float) -> Vector3:
	var point: = GeographicProjection.project(longitude, latitude)
	return Vector3(point.x, 0.15, point.y)

func save_game() -> void :
	var error: = session.write_save(SAVE_PATH, session.capture(clock, map, units, rig))
	hud.show_status("Game saved on this device" if error.is_empty() else error)
func load_game() -> void :
	var result: = session.read_save(SAVE_PATH, map, units)
	if result.has("error"):
		hud.show_status(result.error)
		return
	rally_city = ""
	session.restore(result.state, clock, map, units, rig)
	apply_player_country(false)
	units.fog_enabled = not GameSession.weapons_test
	match_rules.ai_enabled = not GameSession.weapons_test
	if test_models != null: test_models.queue_free(); test_models = null
	combat_effects.clear()
	_set_order_mode(false)
	if result_dialog != null: result_dialog.hide()
	if campaign_panel != null: campaign_panel.hide()
	if army_selection != null: army_selection.hide()
	if army_command != null: army_command.hide()
	if fire_panel != null: fire_panel.hide()
	city_panel.hide()
	production_panel.hide()
	research_panel.hide()
	refresh_hud()
	if not match_rules.winner.is_empty(): show_result(match_rules.winner)
	hud.clear_unit_selection()
	hud.show_status("Saved game restored")

func _touch_over_ui(screen: Vector2) -> bool:
	if account_panel != null and account_panel.overlay.visible: return true
	if badges != null and badges.contains(screen): return true
	if exchange_panel != null and exchange_panel.visible: return true
	if trade_panel != null and trade_panel.visible: return true
	if weapon_showcase != null and weapon_showcase.visible: return true
	if mobile_start != null and mobile_start.visible: return true
	if campaign_panel != null and campaign_panel.visible: return true
	if army_selection != null and army_selection.visible: return true
	if army_command != null and army_command.visible: return true
	if fire_panel != null and fire_panel.visible: return true
	if stack_dialog != null and stack_dialog.visible: return true
	if result_dialog != null and result_dialog.visible: return true
	if production_panel != null and production_panel.visible: return true
	if research_panel != null and research_panel.visible: return true
	if city_panel != null and city_panel.visible: return true
	if province_panel != null and province_panel.visible: return true
	var point: Vector2 = hud.get_final_transform().affine_inverse() * screen
	if hud.command_panel.get_global_rect().has_point(point): return true
	if hud.top_bar.get_global_rect().has_point(point): return true
	if hud.toolbar.get_global_rect().has_point(point): return true
	for label in cities.labels:
		if label.visible and label.get_global_rect().has_point(cities.label_layer.get_final_transform().affine_inverse() * screen): return true
	return false

func _draw_waypoints_now() -> void:
	units._route_drawn_at = -1000
	units._draw_route()
func _set_order_mode(enabled: bool) -> void :
	if not enabled:
		rally_city = ""
		selecting_armies = false
		append_order = false
		waypoint_first = false
		if hud != null: hud.set_waypoint_mode(false)
	order_mode = enabled
	if hud != null: hud.set_order_mode(enabled)
func clear_army_selection() -> void:
	selecting_armies = false
	units.selected = -1
	units.command_ids.clear()
	units._draw_route()
	attack_order = false
	patrol_order = false
	append_order = false
	hud.clear_unit_selection()

func player_order(destination: Vector3) -> void :
	if not match_rules.winner.is_empty(): return
	if not rally_city.is_empty():
		var error: = production.set_rally(rally_city, Vector2(destination.x, destination.z))
		hud.show_status("Rally point set · newly produced units follow it if reachable" if error.is_empty() else error)
		rally_city = ""
		_set_order_mode(false)
		return
	if units.selected < 0 or units.units[units.selected].country != GameSession.player_country:
		hud.show_status("Select an army belonging to your country.")
		return
	var accepted: = units.patrol(destination) if patrol_order and units.air.is_air(units.units[units.selected]) else units.order_many(destination, append_order and not waypoint_first) > 0
	if accepted and append_order:
		# Waypoint path: the army sets off at once and stays selected for the next waypoint.
		waypoint_first = false
		hud.unit_moving = true
		if clock.paused: hud.show_status("Waypoint added · PAUSED · tap Play to begin movement")
		else: hud.show_status("Waypoint added · tap the next one, or Done")
		_draw_waypoints_now()
		return
	if accepted:
		hud.unit_moving = true
		# Movement sound by unit type (owner 2026-10-13): tracks, wheels or jet engines. Owner
		# 2026-10-16: "Take the horse racing sound out of the game" - the marching boots are gone.
		var mover: Dictionary = units.units[units.selected]
		var sound: String = {"heavy": "tracks_moving", "light": "wheels_moving", "air": "jet_flyby"}.get(UnitClasses.of(mover), "")
		if not sound.is_empty(): audio.play(sound, mover.node.position)
		if GameSession.weapons_test and clock.paused:
			clock.paused = false
			refresh_hud()
		if clock.paused: hud.show_status("Order accepted · PAUSED · tap Play to begin movement")
		_set_order_mode(false)
		append_order = false
		patrol_order = false
		# Owner 2026-10-15: "One click, destination" - once the destination is tapped the order
		# panel goes away, so the next tap (a city, another spot) cannot re-route the army.
		var status: String = hud.status_message
		clear_army_selection()
		hud.show_status(status)
	else:
		# Owner 2026-10-13: never leave the player stuck in "choose a destination" needing X;
		# the reason stays on the status line and the army stays selected.
		_set_order_mode(false)
		append_order = false
		patrol_order = false

func refresh_hud() -> void :
	if hud == null: return
	if production != null and not production.stockpiles.is_empty():
		var income: Dictionary = production.net_income()[GameSession.player_country]
		for resource in ProductionSystem.RESOURCES:
			hud.resource_values[resource].tooltip_text = resource.capitalize()+" · net "+("+" if income[resource]>=0 else "")+"%.1f/h" % (income[resource]*30.0)+" at 1× (after upkeep)"
	if match_rules != null:
		hud.city_scores = match_rules.city_score()
		var table: = VictoryRules.standings(map.territories, match_rules.cities, match_rules.production.stockpiles.keys() if match_rules.production != null else ["russia", "ukraine"])
		hud.domination = table.get(GameSession.player_country, {}).get("domination", 0.0) / VictoryRules.DOMINATION_SHARE
		# Owner 2026-10-16: the goal and any domination countdown (either side) are on the top bar.
		hud.victory_goal = VictoryRules.goal_text()
		hud.victory_warning = ""
		for country in match_rules.victory.domination_held:
			var left: float = match_rules.victory.domination_countdown(country)
			if left >= 0.0: hud.victory_warning = ("YOU WIN" if country == GameSession.player_country else country.to_upper() + " WINS") + " IN " + SimulationClock.duration(left, clock.speed)
		map.update_relations(match_rules.at_war)
	hud.show_clock(clock.elapsed, clock.speed, clock.paused)
	if match_rules != null:
		hud.navigation_menu.text = "War / View" if match_rules.at_war else "Peace / View"
	if units.selected >= 0 and not units.visible_to_player(units.units[units.selected]):
		units.selected = -1
		units._draw_route()
	if units.selected >= 0 and units.selected < units.units.size():
		var unit: Dictionary = units.units[units.selected]
		hud.unit_moving = unit.get("moving", false)
		hud.stack_count = units.stacks.members(unit).size()
		hud.show_air_commands(units.air.is_air(unit))
		if hud.inspecting_unit:
			var state: = "WAIT " + SimulationClock.duration(unit.get("delay_remaining", 0.0), clock.speed) if unit.get("delay_remaining", 0.0) > 0 else "MODERNIZING" if unit.get("upgrade_remaining", 0.0) > 0 else CombatSystem.battle_label(unit, units._land_owner(unit)) if unit.engaged else "FIRING" if unit.get("firing_halt", false) else ("MOVING" if unit.moving else "READY")
			var group: = units.stacks.members(unit)
			var hp: = 0.0
			for member in group: hp += member.health
			hud.show_health(hp / maxi(1, group.size()))
			hud.selection_title.text = EquipmentIdentity.research_title(unit.equipment_id, unit.get("level", 1)).to_upper() + " · L" + str(int(unit.get("level", 1)))
			hud.detail.text = unit.country.to_upper() + " · " + str(group.size()) + " UNITS · " + state
			if units.air.is_air(unit):
				hud.detail.text = unit.country.to_upper() + " · " + unit.flight_mode.to_upper() + " · RADIUS " + str(int(units.air.radius(unit) * 40)) + " game km"
				if unit.refuel_remaining > 0: hud.detail.text += " · REFUEL " + SimulationClock.duration(unit.refuel_remaining, clock.speed)
			var next_round: = match_rules.combat.remaining_for(unit)
			if next_round > 0:
				hud.detail.text += " · NEXT FIRE " + SimulationClock.duration(next_round, clock.speed)
			var army_count: = units.command_groups().size()
			if army_count > 1: hud.detail.text = str(army_count) + " ARMIES SELECTED · " + hud.detail.text
			if unit.moving and not unit.engaged and not unit.get("firing_halt", false) and not units.air.is_air(unit):
				hud.detail.text += " · ETA " + SimulationClock.duration(units.travel_time(unit) + unit.get("delay_remaining", 0.0), clock.speed)
				if unit.get("forced_march", false): hud.detail.text += " · FORCED MARCH"
			var point: = Vector2(unit.node.position.x, unit.node.position.z)
			if unit.visual_kind not in ["fighter", "naval"]:
				var biome: = map.terrain_at(point)
				hud.detail.text += " · " + biome.to_upper()
				# Owner 2026-10-16: armies are faster on their own land, slower on enemy land.
				var land_factor: = TerrainRules.territory_speed(unit.country, units.stacks.land_owner(point), units.diplomacy)
				if land_factor != 1.0: hud.detail.text += " · " + TerrainRules.territory_label(land_factor).to_upper()
			for territory in map.territories:
				if match_rules.capture_progress.has(territory.id) and RegionData.contains(territory, point):
					hud.detail.text += " · CAPTURE " + str(mini(100, int(match_rules.capture_progress[territory.id].seconds / MatchSystem.CAPTURE_SECONDS * 100))) + "%"
		if unit.node.get_child(0).get_meta("missing_original_model", false) and not unit.node.get_child(0).get_meta("simple_model", false): hud.detail.text = EquipmentIdentity.research_title(unit.equipment_id, unit.get("level", 1)).to_upper() + " · MODEL LOADING"
		hud.move_button.disabled = unit.country != GameSession.player_country or unit.get("upgrade_remaining", 0.0) > 0 or (match_rules != null and not match_rules.winner.is_empty())
		hud.stop_button.disabled = hud.move_button.disabled
	else:
		hud.show_air_commands(false)
		if hud.inspecting_unit: hud.clear_unit_selection()
		hud.move_button.disabled = true
		hud.stop_button.disabled = true
## Strategic weapons: launch a chemical or nuclear missile from the capital at the selected
## province (or the selected enemy army). Missile defence near the target may shoot it down.
func launch_strategic(kind: String) -> void:
	if not match_rules.at_war:
		hud.show_status("Strategic weapons can only be used at war")
		return
	var target: = Vector2.INF
	if units.selected >= 0 and units.units[units.selected].country != GameSession.player_country:
		var enemy: Dictionary = units.units[units.selected]
		target = Vector2(enemy.node.position.x, enemy.node.position.z)
	else:
		var territory: = _selected_territory()
		if not territory.is_empty(): target = territory.center
	if target == Vector2.INF:
		hud.show_status("Tap a target province or enemy army first")
		return
	if MatchClient.active != null:
		hud.show_status(MatchClient.active.send("strategic_launch", {"kind": kind, "x": target.x, "z": target.y}))
		return
	var result: = match_rules.strategic.launch(GameSession.player_country, kind, target, units, map.territories)
	hud.show_status(result.message)
	if not result.ok: return
	used_wmd = true
	if kind == "nuclear": _award("nuclear")
	match_rules.report.emit("%s launched a %s · %s" % [GameSession.player_country.capitalize(), StrategicWeapons.WEAPONS[kind].name.to_lower(), result.message])
	var start: = Vector3(target.x + 6.0, 1.0, target.y + 6.0)
	for city in cities.cities:
		if city.get("capital", false) and city.country.to_lower() == GameSession.player_country: start = Vector3(city.point.x, 0.6, city.point.y)
	audio.play("ballistic_missile")
	var finish: = Vector3(target.x, map.elevation(target), target.y)
	var flight: = 5.0 if kind == "nuclear" else 1.6
	# Owner 2026-10-13: the whole screen strobes red while a nuke is incoming.
	if kind == "nuclear": combat_effects.nuke_warning(flight)
	combat_effects.launch(start, finish + Vector3.UP * 0.2, "missile", GameSession.player_country, "", flight)
	if not result.intercepted:
		var radius: float = StrategicWeapons.WEAPONS[kind].radius
		get_tree().create_timer(flight).timeout.connect(func():
			if kind == "nuclear":
				combat_effects.nuke(finish, radius, float(StrategicWeapons.WEAPONS.nuclear.fallout))
				nuke_cinematic(finish)
				for city_id in match_rules.nuclear_aftermath(target, radius): cities.devastate(city_id)
				refresh_hud()
				return
			for i in 4:
				var angle: = TAU * i / 4.0
				combat_effects.explode(finish + Vector3(cos(angle), 0.1, sin(angle)) * radius * (0.0 if i == 0 else 0.6), true))
	refresh_hud()
## Owner 2026-10-13 ("make it amazing"): the camera swoops down low beside the blast to watch
## the mushroom cloud rise, then returns to where the player was.
func nuke_cinematic(point: Vector3) -> void:
	var saved: = [rig.target, rig.distance, rig.pitch, rig.yaw]
	rig.target = point + Vector3.UP * 0.8
	rig.distance = 15.0
	rig.pitch = 0.36
	get_tree().create_timer(11.0).timeout.connect(func():
		rig.target = saved[0]
		rig.distance = saved[1]
		rig.pitch = saved[2])
## Retreat: the selected army pulls back to the nearest friendly province centre.
func retreat_selected() -> void:
	if not friendly_selected():
		hud.show_status("Select one of your armies to retreat")
		return
	var unit: Dictionary = units.units[units.selected]
	if MatchClient.active != null:
		MatchClient.active.send_units("retreat", units.command_ids)
		hud.show_status("RETREAT ordered")
		return
	var group: Array = units.stacks.members(unit)
	var destination: = match_rules.retreat(group, Vector2(unit.node.position.x, unit.node.position.z))
	if destination == Vector2.INF:
		hud.show_status("No friendly province to retreat to")
		return
	units.order_many(Vector3(destination.x, 0, destination.y))
	hud.show_status("RETREAT · pulling back, not firing" + (" · retreating under fire costs 10% health" if match_rules.at_war else ""))
## Annexation: the selected (occupied) province produces more after a day and a payment.
func annex_selected() -> void:
	var territory: = _selected_territory()
	if territory.is_empty():
		hud.show_status("Tap a captured province first")
		return
	if MatchClient.active != null:
		hud.show_status(MatchClient.active.send("annex", {"territory": territory.id}))
		return
	var points: = VictoryRules.province_points(map.territories, match_rules.cities)
	var error: = match_rules.annexation.start(territory, GameSession.player_country, production.stockpiles[GameSession.player_country], points)
	hud.show_status(("ANNEXING " + territory.title + " · ready in one game day (" + SimulationClock.duration(VictoryRules.DAY) + ") · output %d%% → %d%%" % [roundi(Annexation.OCCUPIED_OUTPUT * 100), roundi(Annexation.ANNEXED_OUTPUT * 100)]) if error.is_empty() else error)
	refresh_hud()
func _selected_territory() -> Dictionary:
	for t in map.territories:
		if t.id == map.selected_id: return t
	return {}
func _annex_hint(t: Dictionary) -> void:
	if not t.get("playable", false) or t.controller != GameSession.player_country or t.owner == GameSession.player_country: return
	var annex: = match_rules.annexation
	if annex.annexed.get(t.id, "") == t.controller: hud.show_status(t.title + " · ANNEXED · output %d%%" % roundi(Annexation.ANNEXED_OUTPUT * 100))
	elif annex.jobs.has(t.id): hud.show_status(t.title + " · annexation in progress")
	else:
		var points: = VictoryRules.province_points(map.territories, match_rules.cities)
		hud.show_status(t.title + " · OCCUPIED · output %d%% · More → Annex for %d funds" % [roundi(Annexation.OCCUPIED_OUTPUT * 100), roundi(annex.cost(t, points))])
func _attack_alert(_source: Dictionary, target: Dictionary, _effect: String) -> void:
	if target.get("country", "") != GameSession.player_country or not target.has("node"): return
	var now: = Time.get_ticks_msec() / 1000.0
	if now - _last_alert < ALERT_GAP: return
	if rig.camera.is_position_in_frustum(target.node.global_position): return
	_last_alert = now
	var place: = "the front"
	var point: = Vector2(target.node.position.x, target.node.position.z)
	for t in map.territories:
		if t.playable and RegionData.contains(t, point): place = t.title
	hud.show_status("UNDER ATTACK · " + target.get("name", "your army") + " near " + place)
	audio.play("sonar_ping")
## Achievements from match events; new ones are announced in the status bar and sent to the
## signed-in account.
func _award(id: String) -> void:
	if achievements.unlock(id): _announce_achievements()
func _award_count(counter: String) -> void:
	achievements.count(counter)
	_announce_achievements()
func _announce_achievements() -> void:
	for id in achievements.take_new():
		hud.show_status("ACHIEVEMENT UNLOCKED · " + Achievements.LIST[id].name + " · " + Achievements.LIST[id].text)
		audio.play("research_complete")
		if account_panel != null and account_panel.auth.signed_in(): account_panel.auth.unlock_achievement(id)
func _report_achievements(message: String) -> void:
	var me: = GameSession.player_country.capitalize()
	if message.ends_with(" captured by " + me):
		var title: = message.trim_suffix(" captured by " + me)
		for city in cities.cities:
			for t in map.territories:
				if t.id == city.sector and t.title == title and city.country.to_lower() != GameSession.player_country:
					_award("capital_fall" if city.get("capital", false) else "conqueror")
					if city.get("capital", false): _award("conqueror")
	elif " captured by " in message:
		var title: = message.get_slice(" captured by ", 0)
		for city in cities.cities:
			for t in map.territories:
				if t.id == city.sector and t.title == title and city.country.to_lower() == GameSession.player_country: lost_city = true
	elif message.ends_with(" annexed"):
		var title: = message.trim_suffix(" annexed")
		for t in map.territories:
			if t.title == title and match_rules.annexation.annexed.get(t.id, "") == GameSession.player_country: _award_count("annexed")
func _campaign_medals(country: String) -> void:
	if country != GameSession.player_country: return
	var won: = achievements.campaign_won(country, match_rules.victory_type, clock.elapsed / VictoryRules.DAY, lost_city, used_wmd)
	_announce_achievements()
	if not won.is_empty(): hud.show_status("MEDALS · " + ", ".join(won.map(func(id): return Achievements.MEDALS[id].name)))
## Event sounds from the match reports: war declared, provinces/cities captured.
func _report_sound(message: String) -> void:
	if message.begins_with("WAR DECLARED"): audio.play("war_declared")
	elif " captured by " in message: audio.play("city_captured")
func show_result(country: String) -> void :
	_remember_match(false)
	_set_order_mode(false)
	city_panel.hide()
	production_panel.hide()
	research_panel.hide()
	hud.move_button.disabled = true
	hud.stop_button.disabled = true
	if result_dialog == null:
		result_dialog = AcceptDialog.new()
		result_dialog.title = "MATCH COMPLETE"
		result_dialog.ok_button_text = "Play again"
		result_dialog.confirmed.connect(new_match)
		add_child(result_dialog)
	# Owner 2026-10-16 ("I won the game. I don't know how"): the result says how it was decided.
	result_dialog.dialog_text = ("VICTORY" if country == GameSession.player_country else "DEFEAT") + " · " + MatchSystem.VICTORY_NAMES.get(match_rules.victory_type, "VICTORY") + "\n" + country.capitalize() + " wins the regional match.\n\n" + VictoryRules.explain(match_rules, country, match_rules.victory_type)
	result_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_dialog.popup_centered(Vector2i(mini(520, int(get_viewport().get_visible_rect().size.x) - 24), 320))
func new_match() -> void :
	get_tree().reload_current_scene()

func focus_player_army() -> void:
	for index in units.units.size():
		var unit: Dictionary = units.units[index]
		if unit.country != GameSession.player_country: continue
		units.select_unit(index)
		rig.target = Vector3(unit.node.position.x, 0, unit.node.position.z)
		rig._snap(1.0)
		return

func apply_player_country(focus: bool = true) -> void:
	resource_country = GameSession.player_country
	match_rules.ai.country = GameSession.opponent_country()
	hud.show_resources(resource_country, production.stockpiles[resource_country])
	map.relation_signature = ""
	map.update_relations(match_rules.at_war)
	fog.refresh(true)
	if focus: focus_player_army()
	refresh_hud()

func restore_campaign_forces() -> void:
	if session.scenario.has("starting_tiers"):
		await populate_campaign_forces(not OS.has_feature("headless"))
		return
	units.restore([])
	for data in session.scenario.units:
		var offset: Array = data.get("offset", [0.0, 0.0])
		var point: = GeographicProjection.project(data.longitude, data.latitude) + Vector2(offset[0], offset[1])
		var color: = Color.WHITE
		for country in session.scenario.countries:
			if country.id == data.country: color = Color(country.color).lightened(0.3)
		units._spawn(data, point, color)
	units.fog_enabled = true
	if test_models != null: test_models.queue_free(); test_models = null

func populate_campaign_forces(staged: bool = false) -> void:
	units.restore([])
	var count_total: int = 60
	var spawned: int = 0
	var counts: Dictionary = {}
	var occupied_sea: Array[Vector2] = []
	var occupied_air: Array[Vector2] = []
	# Owner 2026-10-14: every city holds a garrison and infantry is scattered through the provinces.
	var city_points: Array = production.cities.map(func(city: Dictionary): return city.point)
	for country in ["russia", "ukraine"]:
		var capital: Dictionary = buildings.capital(country)
		var homes: Array = production.cities.filter(func(city: Dictionary): return city.country.to_lower() == country)
		homes.sort_custom(func(a: Dictionary, b: Dictionary): return a.id == capital.id and b.id != capital.id)
		if homes.is_empty(): continue
		var plan: Array = []  # [family id, city]
		# The front: the cities nearest the enemy capital.
		var enemy_capital: Dictionary = buildings.capital("ukraine" if country == "russia" else "russia")
		var by_front: Array = homes.filter(func(city: Dictionary): return city.id != capital.id)
		if not enemy_capital.is_empty(): by_front.sort_custom(func(a: Dictionary, b: Dictionary): return a.point.distance_to(enemy_capital.point) < b.point.distance_to(enemy_capital.point))
		var front: Array = by_front.slice(0, int(STARTING_ARMY.front_cities)).map(func(city: Dictionary): return city.id)
		for home in homes:
			var garrison: Dictionary = STARTING_ARMY.capital if home.id == capital.id else STARTING_ARMY.front if home.id in front else STARTING_ARMY.city
			for prefix in garrison:
				for i in garrison[prefix]: plan.append([prefix + "_" + country, home])
		# Owner 2026-10-14: "I want the plane in a province" with an airport - the province
		# nearest the capital gets a level-1 airport and the plane starts there, on the ground.
		var airfield: Dictionary = {}
		for place in buildings.provinces.places.values():
			if str(place.country).to_lower() != country: continue
			if airfield.is_empty() or place.point.distance_to(capital.point) < airfield.point.distance_to(capital.point): airfield = place
		if not airfield.is_empty():
			buildings.provinces.levels[airfield.id].airbase = maxi(1, buildings.provinces.level(airfield.id, "airbase"))
			for i in STARTING_ARMY.plane: plan.append([STARTING_PLANE[country], airfield])
		# Border infantry (owner: "scattered along borders"): the provinces nearest the enemy's land,
		# each one placed as far as possible from the cities and the posts already taken.
		var enemy_country: String = "ukraine" if country == "russia" else "russia"
		var enemy_land: Array = map.territories.filter(func(t: Dictionary): return t.playable and t.owner == enemy_country).map(func(t: Dictionary): return t.center)
		var posts: Array = []
		var seen: Dictionary = {}
		for territory in map.territories:
			if not territory.playable or territory.owner != country or seen.has(territory.title): continue
			seen[territory.title] = true
			var post: Vector2 = match_rules.capture_point(territory)
			if city_points.any(func(p: Vector2): return p.distance_to(post) < 0.8): continue
			var gap: = INF
			for other in enemy_land: gap = minf(gap, post.distance_to(other))
			posts.append({"id": "province_" + str(territory.id), "point": post, "front": gap})
		posts.sort_custom(func(a: Dictionary, b: Dictionary): return a.front < b.front)
		posts = posts.slice(0, maxi(int(STARTING_ARMY.border_infantry), int(posts.size() * 0.4)))
		var taken: Array = city_points.duplicate()
		for i in STARTING_ARMY.border_infantry:
			var best: Dictionary = {}
			var best_gap: = -1.0
			for post in posts:
				var gap: = INF
				for other in taken: gap = minf(gap, post.point.distance_to(other))
				if gap > best_gap:
					best_gap = gap
					best = post
			if best.is_empty(): break
			posts.erase(best)  # one starting infantry per province post
			taken.append(best.point)
			plan.append(["infantry_" + country, best])
		for entry in plan:
			var family: Dictionary = EquipmentIdentity.spec(entry[0])
			if family.is_empty(): continue
			var base: Dictionary = entry[1]
			var kind: String = family.visual_kind
			var point: Vector2 = base.point
			if kind == "fighter" and not str(base.id).begins_with("province:"):
				point = weapons_test_air_slot(base.point, country, occupied_air, float(family.get("air_range", 14.0)))
				occupied_air.append(point)
			var number: int = counts.get(family.id, 0)
			counts[family.id] = number + 1
			var data: = {"id": "campaign_%s_%d" % [family.id, number], "name": EquipmentIdentity.research_title(family.id, 1), "country": country, "equipment_id": family.id, "level": 1, "visual_kind": kind, "base_city": base.id}
			# Air defence cannot move, so it gets its own stack and does not pin the army in place.
			if kind != "fighter": data.stack_id = ("start_ad_" if family.get("stationary", false) or kind == "air_defense" else "start_") + base.id
			units._spawn(data, point, Color("ef827c") if country == "russia" else Color("73bcff"))
			spawned += 1
			if staged and FrameBudget.spent():
				boot_progress.emit(spawned, count_total)
				await get_tree().process_frame
				FrameBudget.restart()
	boot_progress.emit(count_total, count_total)
	# The start plane's province airport (set above) must be drawn under it.
	if cities != null: cities.sync_buildings()
	units.fog_enabled = true
	fog.refresh(true)

func populate_weapons_test(show_progress: bool = false, scenario: String = "all") -> void:
	var total: Dictionary = {}
	if show_progress:
		for family in EquipmentIdentity.catalog:
			for tier in family.get("research_tiers",[]): total[tier.get("model",family.id)] = true
	units.restore([])
	if test_models != null: test_models.queue_free(); test_models = null
	var city_data: Array = production.cities
	var represented: Dictionary = {}
	var counts: Dictionary = {}
	var occupied_sea: Array[Vector2] = []
	var occupied_air: Array[Vector2] = []
	var focused: = scenario != "all"
	# A focused test map lines the two sides up face to face: Ukraine's city nearest Moscow and
	# the Russian city nearest that one (Kharkiv and Belgorod).
	var front: Dictionary = {}
	if focused:
		var moscow: Dictionary = buildings.capital("russia")
		for city in city_data:
			if city.country.to_lower() == "ukraine" and not moscow.is_empty() and (front.get("ukraine", {}).is_empty() or city.point.distance_to(moscow.point) < front.ukraine.point.distance_to(moscow.point)): front.ukraine = city
		for city in city_data:
			if city.country.to_lower() == "russia" and front.has("ukraine") and (front.get("russia", {}).is_empty() or city.point.distance_to(front.ukraine.point) < front.russia.point.distance_to(front.ukraine.point)): front.russia = city
	for family in EquipmentIdentity.catalog:
		if family.get("retired", false): continue
		if not WeaponScenarios.includes(scenario, family): continue
		var tiers: Array = family.get("research_tiers", [])
		# Archived campaigns predate tier models; retain their one-army-per-family setup.
		var tiered: bool = not tiers.is_empty()
		if not tiered: tiers = [{"model": UnitVisual.asset_path(family.id)}]
		for index in tiers.size():
			var path: String = tiers[index].get("model", "")
			var unique_key: String = path if tiered else family.id
			if unique_key.is_empty() or represented.has(unique_key): continue
			represented[unique_key] = true
			var kind: String = family.visual_kind
			var bases: Array = city_data.filter(func(city: Dictionary):
				return city.country.to_lower() == family.country and (kind != "naval" or city.has("naval_spawn")))
			if bases.is_empty(): continue
			# A focused test map lines each side up behind its city nearest the enemy capital.
			var enemy: Dictionary = front.get("ukraine" if family.country == "russia" else "russia", {})
			if focused and not enemy.is_empty():
				bases.sort_custom(func(a: Dictionary, b: Dictionary): return a.point.distance_to(enemy.point) < b.point.distance_to(enemy.point))
				bases = bases.slice(0, 1)
			var key: String = family.country + ":" + (scenario if focused else kind)
			var number: int = counts.get(key, 0)
			counts[key] = number + 1
			var base: Dictionary = bases[number % bases.size()]
			var slot: int = number / bases.size()
			var point: Vector2 = base.point + Vector2(-2.0 + float(slot % 4) * 1.5, -1.8 - float(slot / 4) * 1.5)
			if focused and not enemy.is_empty():
				var back: Vector2 = (base.point - enemy.point).normalized()
				point = base.point + back.orthogonal() * (-2.25 + float(slot % 4) * 1.5) + back * (1.8 + float(slot / 4) * 1.5)
			if kind == "fighter":
				point = weapons_test_air_slot(base.point, family.country, occupied_air, float(family.get("air_range",14.0)))
				occupied_air.append(point)
				# Aircraft need an airbase (owner 2026-10-14): the showcase city gets one.
				if buildings.level(base.id, "airbase") < 1: buildings.levels[base.id].airbase = 1
			if kind == "naval":
				var anchor: = GeographicProjection.project(base.naval_spawn.longitude, base.naval_spawn.latitude)
				point = weapons_test_sea_slot(anchor, occupied_sea)
				occupied_sea.append(point)
			var data: = {"id": "weapons_test_" + family.id + "_l" + str(index + 1), "level": index + 1, "name": EquipmentIdentity.research_title(family.id, index + 1), "country": family.country, "equipment_id": family.id, "visual_kind": kind, "base_city": base.id}
			units._spawn(data, point, Color("73bcff") if family.country == "ukraine" else Color("ef827c"))
			if show_progress:
				mobile_start.set_progress(95.0*units.units.size()/maxi(1,total.size()),"Preparing armies")
				await get_tree().process_frame
	units.fog_enabled = false
	match_rules.ai_enabled = false
	clock.paused = true

func weapons_test_air_slot(anchor: Vector2, country: String, occupied: Array[Vector2], flight_range: float) -> Vector2:
	for ring in range(0, 24):
		var radius: float = float(ring) * 0.6
		if radius + 0.7 > flight_range: break
		for step in maxi(1, ring * 12):
			var angle: float = TAU * float(step) / float(maxi(1, ring * 12))
			var point: Vector2 = anchor + Vector2.from_angle(angle) * radius
			if occupied.any(func(other): return other.distance_to(point) < 1.6): continue
			if map.territories.any(func(territory): return territory.playable and territory.controller == country and RegionData.contains(territory,point)): return point
	push_error("No friendly airbase inspection position within operating range")
	return anchor

func weapons_test_sea_slot(anchor: Vector2, occupied: Array[Vector2]) -> Vector2:
	for ring in range(0, 32):
		var radius: float = float(ring) * 0.8
		for step in maxi(1, ring * 12):
			var angle: float = TAU * float(step) / float(maxi(1, ring * 12))
			var point: Vector2 = anchor + Vector2.from_angle(angle) * radius
			if units.sea_navigation.on_sea(point) and not occupied.any(func(other): return other.distance_to(point) < 2.1): return point
	push_error("No open sea berth for all-weapons map")
	return anchor

func add_original_weapon_inspection() -> void:
	if test_models != null: test_models.queue_free()
	test_models = Node3D.new()
	test_models.name = "OriginalWeaponInspection"
	add_child(test_models)
	var represented: Dictionary = {"t90m": true, "armata": true, "abrams": true}
	for spec in EquipmentIdentity.catalog:
		if spec.has("asset_roster_id"): represented[spec.asset_roster_id] = true
	var index: = 0
	for entry in AssetRoster.entries:
		if entry.shared_building or represented.has(entry.id): continue
		var art: = AssetRoster.appearance(entry.id, GameSession.player_country)
		if art.is_empty() or not ResourceLoader.exists(art.model): continue
		var point: = Vector2(-3.6 + float(index % 5) * 1.8, 5.0 + float(index / 5) * 1.6)
		if entry.kind == "naval": point = GeographicProjection.project(31.1, 45.7)
		var model: = (load(art.model) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * 0.65
		model.position = map.position_at(point) if entry.kind != "naval" else Vector3(point.x, 0.15, point.y)
		test_models.add_child(model)
		var label: = Label3D.new()
		label.text = entry.name + "\nMODEL INSPECTION"
		label.font_size = 20
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = model.position + Vector3.UP * 0.7
		test_models.add_child(label)
		index += 1

func friendly_selected() -> bool:
	return units.selected >= 0 and units.units[units.selected].country == GameSession.player_country and match_rules.winner.is_empty()
func show_stack_info() -> void :
	if units.selected < 0: return
	if stack_dialog == null:
		stack_dialog = ArmyDetailsPanel.new()
		add_child(stack_dialog)
		stack_dialog.setup(hud.get_child(0).theme)
		stack_dialog.unit_info_requested.connect(func(id: String, level: int):
			stack_dialog.hide()
			research_panel.open_unit(id, level))
	stack_dialog.open(units, map)

## Online matches (owner request 2026-10-12): the server address is in user://settings.cfg
## [online] server_url (default below, set up per docs/MULTIPLAYER_SERVER.md) and match.
const ONLINE_SERVER: = "wss://play.warfrontmandate.com"
var online: MatchClient
var paused_to_home: = false
## Owner 2026-10-15: in-match button back to the home screen (the match is saved and paused).
## Owner 2026-10-16: "every time I switch the screen over to do something else, it makes me restart
## the game". Phones close games left in the background to free memory. The match is saved the
## moment the game goes to the background, and when it is opened again it goes straight back into
## that match instead of the start screen.
const RESUME_STATE: = "user://resume.cfg"
func _remember_match(running: bool) -> void:
	var state: = ConfigFile.new()
	state.set_value("match", "running", running)
	state.save(RESUME_STATE)
static func _left_mid_match() -> bool:
	var state: = ConfigFile.new()
	return state.load(RESUME_STATE) == OK and bool(state.get_value("match", "running", false))
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST]:
		if boot_finished and session != null and session.match_rules != null and mobile_start != null and not mobile_start.visible and MatchClient.active == null and not GameSession.weapons_test:
			autosave()
func return_to_home() -> void:
	if mobile_start == null: return
	_remember_match(false)
	if MatchClient.active == null and not GameSession.weapons_test: save_game()
	clock.paused = true
	refresh_hud()
	paused_to_home = MatchClient.active == null and not GameSession.weapons_test
	audio.play_music("menu_theme")
	mobile_start.show_paused_match()

func open_home_account() -> void:
	if account_panel == null:
		account_panel = AccountPanel.new()
		add_child(account_panel)
	if not account_panel.operation_requested.is_connected(join_operation): account_panel.operation_requested.connect(join_operation)
	if not account_panel.auth.session_changed.is_connected(refresh_home_commander):
		account_panel.auth.session_changed.connect(refresh_home_commander)
	account_panel.open()
	refresh_home_commander()

func refresh_home_commander() -> void:
	if mobile_start == null or account_panel == null: return
	var name_text: String = str(account_panel.auth.user.get("user_metadata", {}).get("commander_name", "Commander"))
	mobile_start.set_commander(name_text, account_panel.auth.signed_in())

## Alliance operations (owner 2026-10-15): one tap joins the posted match on the posted side.
func join_operation(code: String, side: String) -> void:
	mobile_start.country_picker.select(0 if side == "ukraine" else 1)
	mobile_start.show()
	mobile_start.begin_loading()
	await join_online(code)

func join_online(match_code: String = "") -> void:
	if account_panel == null:
		account_panel = AccountPanel.new()
		add_child(account_panel)
		account_panel.operation_requested.connect(join_operation)
		await get_tree().process_frame
	if not account_panel.auth.signed_in():
		hud.show_status("Sign in to your account to play online")
		mobile_start.cancel_loading("Sign in to your account to play online")
		account_panel.open()
		return
	var settings: = ConfigFile.new()
	settings.load(GameAudio.SETTINGS_PATH)
	if online != null: online.leave(); online.queue_free()
	online = MatchClient.new()
	add_child(online)
	online.welcomed.connect(func(_state: Dictionary):
		online.attach(self)
		mobile_start.hide()
		audio.play_music("battle_theme")
		hud.show_status("ONLINE · you command " + online.country.capitalize() + " · the AI covers you while you are away"))
	online.closed.connect(func(reason: String):
		var text: = "Disconnected from the match" + (": " + reason if not reason.is_empty() else "") + " · tap Online Match to rejoin"
		hud.show_status(text)
		if mobile_start.visible: mobile_start.cancel_loading(text))
	var error: = online.connect_to(str(settings.get_value("online", "server_url", ONLINE_SERVER)), account_panel.auth.access_token, match_code if not match_code.is_empty() else str(settings.get_value("online", "match", "main")), mobile_start.selected_country())
	hud.show_status("Connecting to the match server…" if error == OK else "Could not reach the match server")
	if error == OK: mobile_start.set_progress(50, "Connecting to the match server…")
	else: mobile_start.cancel_loading("Could not reach the match server")

func start_campaign_play() -> void :
	if not match_rules.winner.is_empty(): return
	_remember_match(MatchClient.active == null and not GameSession.weapons_test)
	if match_started_msec == 0: match_started_msec = Time.get_ticks_msec()
	if tutorial == null and not GameSession.weapons_test and not Tutorial.done() and not OS.has_feature("headless_tests"):
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(self, hud.get_child(0).theme)
	audio.play_music("battle_theme")
	clock.paused = false
	refresh_hud()
	hud.show_status("Campaign running at " + str(int(clock.speed)) + "x · select your army, then Move or Fly. Pause stops movement and builds.")

## Attack orders (owner 2026-10-15): never against your own armies, and at peace the player is
## asked before war is declared.
func _attack_army(target: Dictionary) -> void:
	if target.country == GameSession.player_country:
		hud.show_status("That is your own army · choose an enemy army to attack")
		return
	_with_war(target.country, func():
		if units.attack_many(target) > 0:
			if GameSession.weapons_test: clock.paused = false
			attack_order = false
			_set_order_mode(false))

var war_dialog: ConfirmationDialog
func _with_war(enemy: String, then: Callable) -> void:
	if match_rules.at_war or not match_rules.winner.is_empty() or GameSession.weapons_test:
		then.call()
		return
	if war_dialog != null and is_instance_valid(war_dialog): war_dialog.free()
	var dialog: = ConfirmationDialog.new()
	war_dialog = dialog
	dialog.title = "Declare war?"
	dialog.dialog_text = "You are at peace with %s.\nAttacking declares war. Declare war and attack?" % enemy.capitalize()
	dialog.ok_button_text = "Declare war"
	dialog.cancel_button_text = "Cancel"
	dialog.add_theme_font_size_override("font_size", 26)
	add_child(dialog)
	dialog.confirmed.connect(func():
		match_rules.declare_war()
		then.call()
		dialog.queue_free())
	dialog.canceled.connect(func():
		attack_order = false
		_set_order_mode(false)
		hud.show_status("Attack cancelled · still at peace")
		dialog.queue_free())
	dialog.popup_centered()

func open_army_selection() -> void :
	if not friendly_selected(): hud.show_status("Select your army first");return
	attack_order = false
	append_order = false
	patrol_order = false
	rally_city = ""
	_set_order_mode(true)
	selecting_armies = true
	hud.show_status("Tap armies to add or remove them, then tap a meeting point")
func open_fire_control() -> void :
	if friendly_selected() and units.air.is_air(units.units[units.selected]): hud.show_status("Aircraft use Fly, Patrol and Return orders");return
	if not friendly_selected(): hud.show_status("Select one of your armies first");return
	if fire_panel == null:
		fire_panel = FireControlPanel.new()
		add_child(fire_panel)
		fire_panel.setup(hud.get_child(0).theme)
		fire_panel.confirmed.connect(units.set_fire_mode)
	fire_panel.open(units.units[units.selected].get("fire_mode", "at_will"))

func open_campaign(page: String) -> void :
	if campaign_panel == null:
		campaign_panel = CampaignPanel.new()
		add_child(campaign_panel)
		campaign_panel.setup(match_rules, buildings, hud.get_child(0).theme)
		campaign_panel.strategic_launch_requested.connect(launch_strategic)
		campaign_panel.status_message.connect(hud.show_status)
	campaign_panel.open(page)

func open_army_command(action: String) -> void :
	_set_order_mode(false)
	attack_order = false
	append_order = false
	patrol_order = false
	if not friendly_selected(): hud.show_status("Select your army first");return
	if action == "rebase" and not units.air.is_air(units.units[units.selected]): hud.show_status("Rebase is an aircraft command");return
	if army_command == null:
		army_command = ArmyCommandPanel.new()
		add_child(army_command)
		army_command.setup(hud.get_child(0).theme)
		army_command.split_confirmed.connect( func(ids: Array[String]):
			var error: = units.stacks.split_units(ids)
			hud.show_status("New army selected · choose its next order" if error.is_empty() else error))
		army_command.delay_confirmed.connect( func(seconds: float, sync: bool): units.delay_many(seconds, sync))
		army_command.upgrade_confirmed.connect( func():
			if friendly_selected(): hud.show_status(research.upgrade(units.units[units.selected])))
		army_command.rebase_confirmed.connect( func(id: String):
			if not friendly_selected(): return
			var error: = units.air.rebase(units.units[units.selected], buildings.city(id))
			hud.show_status("Transfer ordered" if error.is_empty() else error))
	match action:
		"split": army_command.open_split(units)
		"delay": army_command.open_delay(units)
		"upgrade": army_command.open_upgrade(units, research)
		"rebase": army_command.open_rebase(units)

func refresh_rally_markers() -> void :
	for city in production.cities:
		var rally: Dictionary = production.rally_points.get(city.id, {})
		var show: bool = rally.get("country", "") == GameSession.player_country and production.controlled(city, GameSession.player_country)
		if not rally_markers.has(city.id):
			if not show: continue
			var marker: = MeshInstance3D.new()
			marker.name = "Rally_" + city.id
			var ring: = TorusMesh.new()
			ring.inner_radius = 0.16
			ring.outer_radius = 0.22
			ring.rings = 24
			ring.ring_segments = 5
			marker.mesh = ring
			var ink: = StandardMaterial3D.new()
			ink.albedo_color = Color("edcf78")
			ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			marker.material_override = ink
			marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# Owner 2026-10-16: show the rally spot as a flag on the map (pole and gold cloth).
			var pole: = MeshInstance3D.new()
			var stick: = CylinderMesh.new()
			stick.top_radius = 0.018
			stick.bottom_radius = 0.018
			stick.height = 0.56
			pole.mesh = stick
			pole.position.y = 0.28
			pole.material_override = ink
			pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marker.add_child(pole)
			var cloth: = MeshInstance3D.new()
			var sheet: = BoxMesh.new()
			sheet.size = Vector3(0.26, 0.16, 0.02)
			cloth.mesh = sheet
			cloth.position = Vector3(0.13, 0.47, 0)
			var cloth_ink: = StandardMaterial3D.new()
			cloth_ink.albedo_color = Color("d9a441")
			cloth_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			cloth.material_override = cloth_ink
			cloth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			marker.add_child(cloth)
			add_child(marker)
			rally_markers[city.id] = marker
		var marker: MeshInstance3D = rally_markers[city.id]
		marker.visible = show
		if show: marker.position = map.position_at(Vector2(rally.point[0], rally.point[1])) + Vector3.UP * 0.09

func _report_result(country: String) -> void:
	if account_panel == null or not account_panel.auth.signed_in(): return
	var minutes := int((Time.get_ticks_msec() - match_started_msec) / 60000) if match_started_msec > 0 else 0
	var mine: Dictionary = match_rules.tally.get(GameSession.player_country, {})
	await account_panel.auth.record_result(country == GameSession.player_country, minutes, int(mine.get("destroyed", 0)), int(mine.get("lost", 0)), int(mine.get("provinces", 0)))

## Guard mode (sleep defence, owner 2026-10-13): the AI defends your land while you sleep.
func _toggle_guard() -> void:
	var country: = GameSession.player_country
	var on: = not match_rules.guarded(country)
	if MatchClient.active != null:
		var error: = MatchClient.active.send("guard", {"on": on})
		if not error.is_empty(): hud.show_status(error); return
	else: match_rules.set_guard(country, on)
	hud.show_status("GUARD ON · the AI defends your cities and land while you are away. It will not attack." if on else "GUARD OFF · you are in command")

var guard_popup: CanvasLayer
## "While you were away" report, shown when guard mode is switched off.
func show_guard_report(text: String) -> void:
	if text.is_empty(): return
	if guard_popup == null:
		guard_popup = CanvasLayer.new()
		guard_popup.layer = 20
		add_child(guard_popup)
		var shade: = ColorRect.new()
		shade.color = Color(0, 0, 0, 0.55)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		guard_popup.add_child(shade)
		var card: = PanelContainer.new()
		card.name = "Card"
		card.theme = hud.get_child(0).theme
		card.add_theme_stylebox_override("panel", CowUI.skin("panel_dark", 8))
		card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		card.custom_minimum_size = Vector2(minf(560.0, get_viewport().get_visible_rect().size.x - 40.0), 0)
		guard_popup.add_child(card)
		var column: = VBoxContainer.new()
		column.add_theme_constant_override("separation", 0)
		card.add_child(column)
		var head: = CowUI.header("Guard report", false)
		head.close.pressed.connect(func(): guard_popup.hide())
		column.add_child(head.bar)
		var body: = MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]: body.add_theme_constant_override("margin_" + side, 18)
		column.add_child(body)
		var lines: = CowUI.label("", 18, Color("efe6cf"))
		lines.name = "Lines"
		lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Owner 2026-10-14 (empty dark panel stuck on screen): a wrapping label with no width
		# wraps every word onto its own line and pushes the title and OK button off screen.
		lines.custom_minimum_size.x = card.custom_minimum_size.x - 36.0
		body.add_child(lines)
		var ok: = CowUI.action("OK", "")
		ok.custom_minimum_size = Vector2(160, 52)
		ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ok.pressed.connect(func(): guard_popup.hide())
		var foot: = MarginContainer.new()
		foot.add_theme_constant_override("margin_bottom", 16)
		foot.add_child(ok)
		column.add_child(foot)
	var label: Label = guard_popup.find_child("Lines", true, false)
	label.text = text
	guard_popup.show()
	var card: Control = guard_popup.get_node("Card")
	card.reset_size()
	card.position = (get_viewport().get_visible_rect().size - card.get_combined_minimum_size()) * 0.5
	# Centre again once the text has been laid out (its height is only known after a frame).
	await get_tree().process_frame
	if not is_instance_valid(card): return
	card.reset_size()
	card.position = ((get_viewport().get_visible_rect().size - card.size) * 0.5).max(Vector2(8, 8))

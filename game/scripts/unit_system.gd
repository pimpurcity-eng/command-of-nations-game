class_name UnitSystem
extends Node3D
signal status_changed(message: String)
signal unit_selected(unit: Dictionary)
signal war_requested
var units: Array = []
var selected: = -1
var command_ids: Array[String] = []
var stacks: = ArmyStacks.new()
var air: = AirOperations.new()
var fire_control: = CombatSystem.new()
var at_war: = false
var fog_enabled: = true
const SEA_WATERLINE: = -0.06
# Only a small number of original high-detail vehicles are resident on Android.
# All armies retain their gameplay data and low-cost selection markers.
const MOBILE_MAX_DETAILED_UNITS := 80  # owner 2026-10-15: real 3D models, never blocks
## Zoom levels (owner request 2026-10-13): beyond FAR_ZOOM armies are map symbols only (no 3D
## models); closer, the 3D models show; within CLOSE_ZOOM the health bar and level appear.
## An army whose model is not loaded (phone cap) shows its symbol instead of a placeholder box.
## Owner 2026-10-16 ("make the units render a little bit earlier"): models now show from a
## wider zoom (was 24) and appear 4 a frame, nearest the middle of the screen first.
const FAR_ZOOM := 30.0
const REVEALS_PER_FRAME := 4
const CLOSE_ZOOM := 11.0
var view_distance := 20.0
var _mobile_visual_refresh_budget := 1
const MARCH_HEALTH_PER_SECOND: = 5.0 / (3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND)
func vision_radius(unit: Dictionary) -> float:
	var spec: = EquipmentIdentity.spec(unit.equipment_id)
	if spec.get("role","") == "radar_aircraft": return 7.0 + float(unit.get("level",1)-1)*0.5
	if unit.visual_kind == "naval": return 3.0 + float(unit.get("level",1)-1)*0.25
	return 4.0 if unit.visual_kind in ["fighter", "naval"] else 3.0
## Shared vision and coalitions (MatchSystem.diplomacy, set by MatchSystem.setup).
var diplomacy: Diplomacy
func _sees_for(scout_country: String, country: String) -> bool:
	return scout_country == country or (diplomacy != null and diplomacy.shares_vision(country, scout_country))
func visible_to_country(unit: Dictionary, country: String) -> bool:
	return unit_visible(unit,country)
func point_visible(point: Vector2, country: String = "") -> bool:
	if country.is_empty(): country = GameSession.player_country
	if not fog_enabled: return true
	# Intelligence spies show everything around their city.
	if Espionage.reveals(point, country): return true
	for scout in units:
		if not _sees_for(scout.country, country) or scout.health <= 0: continue
		var origin: = Vector2(scout.node.position.x, scout.node.position.z)
		if origin.distance_to(point) <= vision_radius(scout): return true
	return false
## Who controls the land under a unit (remembered per spot; territory tests are costly).
func _land_owner(unit: Dictionary) -> String:
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	var memo: Array = unit.get("_land_memo", [])
	if memo.size() == 3 and memo[0].distance_squared_to(point) < 0.0025 and memo[2] == terrain_revision: return memo[1]
	var owner: = navigation.controller_at(point) if navigation.terrain != null else ""
	unit._land_memo = [point, owner, terrain_revision]
	return owner
## Phones and tablets, including the browser version opened on one (Godot's "mobile" feature is
## only set for the Android/iOS apps).
static func mobile_device() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios") or force_mobile
## Tests: run the phone model-budget path on desktop.
static var force_mobile: = false
## Bumped when provinces change hands so the cached land owners refresh.
var terrain_revision: = 0
func visible_to_player(unit: Dictionary) -> bool:
	return unit_visible(unit)
## Stealth and radar (owner request 2026-10-12, Conflict of Nations style): stealth units
## (stealth jets, submarines, Western-doctrine aircraft) are seen only within an enemy's radar
## range or up close; only ships' sonar finds submarines.
const CLOSE_RANGE: = 0.8
const STEALTH_WORDS: = ["stealth", "su57", "su_57", "f35", "f_35", "f22", "f_22", "b2_", "b_2", "submarine"]
func stealthy(unit: Dictionary) -> bool:
	if not unit.has("stealth"):
		var spec: = EquipmentIdentity.spec(str(unit.get("equipment_id", "")))
		var text: = (str(unit.get("equipment_id", "")) + "|" + str(spec.get("name", "")) + "|" + str(spec.get("family", ""))).to_lower().replace("-", "_").replace(" ", "_")
		unit.stealth = spec.get("stealth", false) or STEALTH_WORDS.any(func(word: String): return text.contains(word))
	return unit.stealth or Doctrine.stealth(unit)
func is_submarine(unit: Dictionary) -> bool:
	return str(unit.get("equipment_id", "")).to_lower().contains("submarine") or EquipmentIdentity.spec(str(unit.get("equipment_id", ""))).get("submarine", false)
func radar_range(scout: Dictionary, target: Dictionary) -> float:
	if is_submarine(target): return float(EquipmentIdentity.spec(str(scout.get("equipment_id",""))).get("sonar_range",0.0))
	match scout.visual_kind:
		"air_defense": return 4.5
		"naval", "fighter": return 3.0
	return 0.0
func unit_visible(unit: Dictionary, country: String = "") -> bool:
	if country.is_empty(): country = GameSession.player_country
	if unit.country == country: return true
	var point: = Vector2(unit.node.position.x, unit.node.position.z)
	# Owner 2026-10-13 (Call of War): enemies on your own land are always visible, at any zoom.
	if fog_enabled and not stealthy(unit) and _sees_for(_land_owner(unit), country): return true
	if not stealthy(unit): return point_visible(point, country)
	if not fog_enabled: return true
	for scout in units:
		if not _sees_for(scout.country, country) or scout.health <= 0: continue
		var distance: = Vector2(scout.node.position.x, scout.node.position.z).distance_to(point)
		if distance <= radar_range(scout, unit) or (not is_submarine(unit) and distance <= CLOSE_RANGE): return true
	return false
var terrain: StrategicMap
var navigation: = LandRoutes.new()
var sea_navigation: = SeaRoutes.new()
func is_naval(unit: Dictionary) -> bool: return unit.visual_kind == "naval"
func routes_for(unit: Dictionary) -> RefCounted: return sea_navigation if is_naval(unit) else navigation
func path_for(unit: Dictionary, start: Vector2, finish: Vector2) -> Array:
	if stacks.members(unit).any(func(member): return EquipmentIdentity.spec(member.equipment_id).get("stationary", false)): return []
	if is_naval(unit): return sea_navigation.find_path(start, finish)
	navigation.diplomacy = diplomacy
	return navigation.find_path(start, finish, unit.visual_kind, str(unit.get("country", "")))
func surface_position(unit: Dictionary, point: Vector2) -> Vector3:
	if is_naval(unit): return Vector3(point.x, SEA_WATERLINE, point.y)
	return footprint_ground(point)
## Map positions of all ground armies (not aircraft or ships).
func ground_positions(except: Array = []) -> Array:
	var result: = []
	for unit in units:
		if unit in except or air.is_air(unit) or is_naval(unit): continue
		result.append(Vector2(unit.node.position.x, unit.node.position.z))
	return result
func footprint_ground(point: Vector2) -> Vector3:
	# Owner review: vehicles raised to the highest point under them looked like they were
	# floating on slopes. They sit on the ground at their centre and tilt with the slope
	# (ground_normal), so both ends touch the ground.
	return terrain.position_at(point)
## Slope of the ground under a vehicle (sampled over roughly its length).
func ground_normal(point: Vector2) -> Vector3:
	return Vector3.UP  # Current map uses TerrainProfile.FLAT_HEIGHT.
var route: MeshInstance3D
var destination_marker: MeshInstance3D
var route_signature: = ""
var air_range: MeshInstance3D
var range_rings: RangeRings
var order_markers: Dictionary = {}

func _new_order_marker(kind: String) -> Node3D:
	var marker: = Node3D.new()
	marker.set_meta("order_kind",kind)
	var color: = Color("ff796c") if kind == "missile" else Color("78d9ff")
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	var ring: = MeshInstance3D.new()
	var circle: = TorusMesh.new()
	circle.inner_radius = 0.42
	circle.outer_radius = 0.47
	circle.rings = 32
	circle.ring_segments = 4
	ring.mesh = circle
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(ring)
	var icon: = MeshInstance3D.new()
	var surface: = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var polygons: Array = []
	if kind == "patrol":
		# Aircraft silhouette at the centre of its patrol circle.
		polygons = [PackedVector2Array([Vector2(0,-0.3),Vector2(0.06,0.22),Vector2(-0.06,0.22)]),PackedVector2Array([Vector2(0,-0.12),Vector2(0.28,0.12),Vector2(-0.28,0.12)])]
	else:
		# Four target ticks leave the impact point visible.
		for i in 4:
			var angle: float = i*PI*0.5
			var polygon: = PackedVector2Array()
			for p in [Vector2(-0.03,0.13),Vector2(0.03,0.13),Vector2(0.03,0.34),Vector2(-0.03,0.34)]: polygon.append(p.rotated(angle))
			polygons.append(polygon)
	for polygon in polygons:
		var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
		for index in indices: surface.add_vertex(Vector3(polygon[index].x,0.015,polygon[index].y))
	icon.mesh = surface.commit()
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	icon.material_override = material
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.add_child(icon)
	add_child(marker)
	return marker

func _update_order_markers() -> void:
	var active: Dictionary = {}
	for group in stacks.groups():
		var unit: Dictionary = stacks.leader(group)
		if unit.health <= 0 or unit.country != GameSession.player_country: continue
		var kind: = ""
		var point: = Vector2.ZERO
		if air.is_air(unit) and unit.get("flight_mode", "grounded") == "patrol":
			kind = "patrol"
			point = unit.patrol_center
		elif unit.visual_kind == "missile_launcher" and not unit.get("attack_target", "").is_empty():
			var target: = find_id(unit.attack_target)
			if target.is_empty() or target.health <= 0 or not visible_to_player(target): continue
			kind = "missile"
			point = Vector2(target.node.position.x,target.node.position.z)
		if kind.is_empty(): continue
		var key: String = unit.country + ":" + unit.stack_id
		active[key] = true
		if order_markers.has(key) and order_markers[key].get_meta("order_kind") != kind:
			order_markers[key].queue_free()
			order_markers.erase(key)
		if not order_markers.has(key): order_markers[key] = _new_order_marker(kind)
		order_markers[key].position = terrain.position_at(point)+Vector3.UP*0.08
	for key in order_markers.keys():
		if not active.has(key):
			order_markers[key].queue_free()
			order_markers.erase(key)
func setup(map: StrategicMap, scenario: Dictionary) -> void :
	stacks.armies = self
	air.armies = self
	terrain = map
	navigation.terrain = map
	sea_navigation.terrain = map
	for data in ([] if scenario.has("starting_tiers") else scenario.units):
		var point: = GeographicProjection.project(data.longitude, data.latitude)
		# Owner review: ground troops start in their city or province centre (no offsets);
		# aircraft and ships keep the scenario offset.
		if data.get("visual_kind", "armor") in ["fighter", "naval"]:
			var offset: Array = data.get("offset", [0.0, 0.0])
			point += Vector2(offset[0], offset[1])
		var color: = Color.WHITE
		for country in scenario.countries:
			if country.id == data.country: color = Color(country.color).lightened(0.3)
		_spawn(data, point, color)
	route = MeshInstance3D.new()
	route.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var route_ink: = ShaderMaterial.new()
	route_ink.shader = load("res://assets/movement_route.gdshader")
	route.material_override = route_ink
	add_child(route)
	destination_marker = MeshInstance3D.new()
	var destination_ring: = TorusMesh.new()
	destination_ring.inner_radius = 0.14
	destination_ring.outer_radius = 0.19
	destination_ring.rings = 24
	destination_ring.ring_segments = 5
	destination_marker.mesh = destination_ring
	var destination_ink: = StandardMaterial3D.new()
	destination_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	destination_ink.albedo_color = Color("f5cf82")
	destination_marker.material_override = destination_ink
	destination_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	destination_marker.visible = false
	add_child(destination_marker)
	air_range = MeshInstance3D.new()
	var radius_ring: = TorusMesh.new()
	radius_ring.inner_radius = 0.998
	radius_ring.outer_radius = 1.0
	radius_ring.rings = 128
	radius_ring.ring_segments = 4
	air_range.mesh = radius_ring
	var radius_ink: = StandardMaterial3D.new()
	radius_ink.albedo_color = Color(0.5, 0.8, 1.0, 0.55)
	radius_ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	radius_ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	radius_ink.no_depth_test = true
	air_range.material_override = radius_ink
	air_range.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	air_range.visible = false
	add_child(air_range)
	range_rings = RangeRings.new()
	add_child(range_rings)
func _spawn(data: Dictionary, point: Vector2, color: Color) -> void :
	if data.get("visual_kind", "") == "naval" and not sea_navigation.on_sea(point):
		point = sea_navigation.coastal_destination(point)
	if data.get("visual_kind", "armor") not in ["fighter", "naval"]:
		var city = _city_at(point)
		if city != null:
			point = _garrison_spot(city as Vector2, str(data.get("stack_id", "")))
		else:
			var centre: = navigation.hub_for(navigation.nearest_land(point))
			point = navigation.on_road(centre, ground_positions(), 0.7, data.get("country", ""))
	var spec: = [data.name, point, color]
	var marker: = Node3D.new()
	marker.position = Vector3(point.x, SEA_WATERLINE, point.y) if data.get("visual_kind", "") == "naval" else footprint_ground(spec[1])
	add_child(marker)
	var visual_kind: String = data.get("visual_kind", "armor")
	var equipment_id: = EquipmentIdentity.resolve(data)
	if visual_kind == "air_defense": spec[0] = EquipmentIdentity.research_title(equipment_id, int(data.get("level", 1)))
	var model: Node3D
	if UnitSystem.mobile_device():
		model = UnitVisual.lightweight(visual_kind, color, equipment_id, int(data.get("level", 1)))
	else:
		model = UnitVisual.create(visual_kind, color, equipment_id, int(data.get("level", 1)))
	model.scale = Vector3.ONE * 0.65
	marker.add_child(model)
	UnitShadow.create(marker)
	var ring: = MeshInstance3D.new()
	var shape: = TorusMesh.new()
	shape.inner_radius = 0.76
	shape.outer_radius = 0.81
	shape.rings = 32
	shape.ring_segments = 6
	ring.mesh = shape
	ring.position.y = 0.055
	ring.scale = Vector3.ONE * 0.42
	var ink: = StandardMaterial3D.new()
	ink.albedo_color = color
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ink
	marker.add_child(ring)
	units.append({"battle_role": str(data.get("battle_role", "")), "fire_mode": data.get("fire_mode", "at_will"), "attack_target": data.get("attack_target", ""), "firing_halt": false, "level": data.get("level", 1), "upgrade_remaining": data.get("upgrade_remaining", 0.0), "upgrade_target": data.get("upgrade_target", data.get("level", 1)), "stack_id": data.get("stack_id", data.id), "equipment_id": equipment_id, "id": data.id, "country": data.country, "name": spec[0], "visual_kind": visual_kind, "presentation": data.get("presentation", ""), "node": marker, "target": spec[1], "moving": false, "engaged": false, "waypoints": [], "health": 100.0, "heading": _facing_enemy(data.country, point), "ring": ring, "faction_color": color, "icon_only": false})
	model.rotation.y = units[-1].heading
	air.configure(units[-1], data)
	units[-1].forced_march = data.get("forced_march", false)
	units[-1].delay_remaining = float(data.get("delay_remaining", 0.0))
func spawn_produced(data: Dictionary) -> void :
	var color: = Color("73bcff") if data.country == "ukraine" else Color("ef827c")
	_spawn(data, data.point, color)
	if data.has("rally_point"):
		var previous: = selected
		selected = units.size() - 1
		if not order(Vector3(data.rally_point[0], 0, data.rally_point[1])):
			status_changed.emit("Unit completed · rally destination is blocked; unit stays at its launch location")
		selected = previous
	if data.country == GameSession.player_country:
		select_unit(units.size() - 1)
		status_changed.emit(data.name + " completed • selected and ready for orders")
func select_near(position: Vector3) -> bool:
	var nearest: = -1
	var distance: = 0.8
	for i in units.size():
		if not visible_to_player(units[i]): continue
		var separation: float = units[i].node.position.distance_to(position)
		if separation < distance:
			distance = separation
			nearest = i
	if nearest < 0: return false
	select_unit(nearest)
	return true
func select_unit(index: int) -> void :
	if index < 0 or index >= units.size(): return
	index = units.find(stacks.leader(stacks.members(units[index])))
	selected = index
	command_ids.assign([units[index].id])
	for i in units.size():
		units[i].ring.scale = Vector3.ONE * (0.52 if i == selected else 0.42)
		units[i].ring.material_override.albedo_color = Color("f5cf82") if i == selected else units[i].faction_color
	unit_selected.emit(units[index])
	status_changed.emit("Ready for movement orders")
	_draw_route()
func order(position: Vector3, append: bool = false) -> bool:
	if selected < 0:
		status_changed.emit("Select a unit before issuing a movement order")
		return false
	if stacks.members(units[selected]).any(func(member): return EquipmentIdentity.spec(member.equipment_id).get("stationary", false)):
		status_changed.emit("Fixed missile silos cannot move; attack targets within their range")
		return false
	if air.is_air(units[selected]):
		if append:
			status_changed.emit("Aircraft use Fly, Patrol and Return commands")
			return false
		var error: = air.order(units[selected], Vector2(position.x, position.z))
		status_changed.emit("Flight ordered · aircraft returns to base after reaching its destination" if error.is_empty() else error)
		_draw_route()
		return error.is_empty()
	for member in stacks.members(units[selected]):
		if member.get("upgrade_remaining", 0.0) > 0:
			status_changed.emit("Modernization in progress; this army cannot move yet")
			return false
	var destination: = Vector2(position.x, position.z)
	if is_naval(units[selected]): destination = sea_navigation.coastal_destination(destination)
	var current: = Vector2(units[selected].node.position.x, units[selected].node.position.z)
	var origin: Vector2 = units[selected].target if append and units[selected].moving else current
	var path: Array = path_for(units[selected], origin, destination)
	if path.is_empty():
		status_changed.emit("No connected sea route. Ships cannot cross land." if is_naval(units[selected]) else "No connected land route. Ground units cannot cross water or neutral countries.")
		return false
	# Armies go to the province centre by road; the route's end is the real destination.
	if not is_naval(units[selected]):
		destination = path.back()
		# An army sent to a city walks on to the city's army spot (centre or edge).
		var city = _city_at(destination)
		if city != null and CitySystem.garrison_layout != "centre":
			var spot: = _garrison_spot(city as Vector2, str(units[selected].stack_id))
			path.append(spot)
			destination = spot
	if append and units[selected].moving:
		if units[selected].waypoints.size() + path.size() > 256:
			status_changed.emit("Route queue is full")
			return false
		units[selected].waypoints.append_array(path)
	else: units[selected].waypoints = path
	for member in stacks.members(units[selected]): member.attack_target = ""
	units[selected].target = destination
	units[selected].moving = true
	for member in stacks.members(units[selected]):
		member.target = destination
		member.waypoints = units[selected].waypoints.duplicate()
		member.moving = true
	_update_heading(units[selected])
	status_changed.emit(units[selected].name + " • movement order accepted")
	_draw_route()
	return true
var _route_drawn_at: = -1000
const BATTLE_JOIN_REACH: = 0.6
func advance(delta: float) -> void :
	if delta <= 0 or not is_finite(delta): return
	var army_groups: = stacks.groups()
	var nearby: Dictionary = {}
	for candidate in units:
		if air.is_air(candidate): continue
		var cell: = Vector2i(floori(candidate.node.position.x / 1.1), floori(candidate.node.position.z / 1.1))
		if not nearby.has(cell): nearby[cell] = []
		nearby[cell].append(candidate)
	if not at_war:
		for group in army_groups:
			var leader: = stacks.leader(group)
			if leader.get("fire_mode", "") != "aggressive": continue
			if not fire_control.target(group, army_groups, self).is_empty():
				war_requested.emit()
				break
	for group in army_groups:
		var unit: = stacks.leader(group)
		if air.is_air(unit):
			if unit.get("upgrade_remaining", 0.0) > 0:
				unit.upgrade_remaining = maxf(0, unit.upgrade_remaining - delta)
				if unit.upgrade_remaining == 0: unit.level = unit.upgrade_target
			else: air.advance(unit, delta)
			for member in group:
				member.node.position = unit.node.position
				for property in ["base_city", "flight_mode", "flight_used", "refuel_remaining", "patrol_center", "patrol_phase", "target", "moving", "heading", "attack_target", "repeat_target"]: member[property] = unit.get(property, "")
				member.waypoints = unit.waypoints.duplicate()
			continue
		unit.engaged = false
		var current: = Vector2(unit.node.position.x, unit.node.position.z)
		var reach: = CombatSystem.CLOSE_COMBAT_REACH  # armies must actually touch to fight
		var neighbours: Array = []
		if at_war:
			var cell: = Vector2i(floori(current.x / 1.1), floori(current.y / 1.1))
			for dx in range(-1,2):
				for dy in range(-1,2): neighbours.append_array(nearby.get(cell + Vector2i(dx,dy), []))
		for enemy in neighbours:
			if at_war and not air.is_air(enemy) and is_naval(enemy) == is_naval(unit) and enemy.country != unit.country and current.distance_squared_to(Vector2(enemy.node.position.x, enemy.node.position.z)) <= reach * reach and visible_to_country(enemy,unit.country):
				unit.engaged = true
				unit["foe_point"] = Vector2(enemy.node.position.x, enemy.node.position.z)
				unit["foe_id"] = enemy.id
				# Owner 2026-10-16: the army that moved in to fight is the attacker (CombatSystem.battle_role).
				if str(unit.get("battle_role", "")).is_empty(): unit.battle_role = CombatSystem.battle_role(unit.moving or not str(unit.get("attack_target", "")).is_empty(), enemy)
				break
		if not unit.engaged: unit.battle_role = ""
		for member in group:
			member.engaged = unit.engaged
			member.battle_role = unit.battle_role
		var upgrading: = false
		for member in group:
			if member.get("upgrade_remaining", 0.0) <= 0: continue
			upgrading = true
			if not unit.engaged: member.upgrade_remaining = maxf(0, member.upgrade_remaining - delta)
			if member.upgrade_remaining == 0:
				member.level = member.upgrade_target
				status_changed.emit(EquipmentIdentity.title(member.equipment_id) + " modernized to Level " + str(member.level))
		if upgrading: continue
		unit.firing_halt = false
		if not unit.attack_target.is_empty():
			var enemy: = find_id(unit.attack_target)
			if enemy.is_empty() or enemy.health <= 0:
				for member in group: member.attack_target = ""
			elif unit_visible(enemy, unit.country):
				var enemy_point: = Vector2(enemy.node.position.x, enemy.node.position.z)
				# Owner 2026-10-13: artillery/rockets stop and fire once the target is in range;
				# they only move while it is out of range.
				var gun_reach: = 0.0
				for member in group:
					if CombatSystem.shoots_from_range(member):
						var ready: Dictionary = member.duplicate()
						ready.moving = false
						gun_reach = maxf(gun_reach, fire_control.attack_reach(ready))
				if gun_reach > 0.0 and current.distance_to(enemy_point) <= gun_reach:
					for member in group:
						member.moving = false
						member.waypoints.clear()
						member.target = current
				elif enemy_point.distance_to(unit.target) > 0.25:
					var pursuit: = path_for(unit, current, enemy_point)
					if not pursuit.is_empty(): unit.target = enemy_point;unit.waypoints = pursuit;unit.moving = true
		var can_defer: bool = at_war and unit.moving and (unit.fire_mode in ["offensive", "aggressive"] or not unit.attack_target.is_empty()) and group.any( func(member: Dictionary): return CombatSystem.shoots_from_range(member))
		var opponents: Array = fire_control.target(group, army_groups, self) if can_defer else []
		if not opponents.is_empty() and group.any( func(member: Dictionary): return CombatSystem.shoots_from_range(member)):
			unit.firing_halt = current.distance_to(Vector2(opponents[0].node.position.x, opponents[0].node.position.z)) > CombatSystem.CLOSE_COMBAT_REACH
		for member in group: member.firing_halt = unit.firing_halt
		var remaining: = delta
		var waiting: = minf(remaining, unit.delay_remaining)
		for member in group: member.delay_remaining = maxf(0, member.delay_remaining - waiting)
		remaining -= waiting
		if not unit.moving or unit.engaged or unit.firing_halt or remaining <= 0: continue
		if unit.waypoints.is_empty(): unit.waypoints = path_for(unit, current, unit.target)
		while remaining > 1e-06 and not unit.waypoints.is_empty():
			var goal: Vector2 = unit.waypoints[0]
			var distance: = current.distance_to(goal)
			var speed: = stacks.movement_speed(group, current)
			var step: = minf(minf(remaining * speed, distance), 0.1)
			current = current.move_toward(goal, step)
			remaining -= step / speed
			if unit.forced_march and not SupportRoles.prevents_march_wear(group):
				for member in group: member.health = maxf(1.0, member.health - step / speed * MARCH_HEALTH_PER_SECOND)
			if current.distance_to(goal) < 0.001: unit.waypoints.pop_front()
			else: continue
		unit.node.position = surface_position(unit, current)
		_update_heading(unit)
		if unit.waypoints.is_empty():
			unit.moving = false
			for member in group: member.forced_march = false;member.delay_remaining = 0.0
			status_changed.emit(unit.name + " arrived")
		for member in group:
			member.node.position = unit.node.position
			member.target = unit.target
			member.moving = unit.moving
			member.waypoints = unit.waypoints.duplicate()
			member.heading = unit.heading
	# Armies that meet merge into one stack. Performance (owner 2026-10-14, bigger start army):
	# leaders are worked out once and only armies in neighbouring grid cells are compared,
	# instead of every army against every other army.
	var groups: = stacks.groups()
	var leaders: Array = groups.map(func(group: Array): return stacks.leader(group))
	var cells: Dictionary = {}
	for leader in leaders:
		var cell: = Vector2i(floori(leader.node.position.x / BATTLE_JOIN_REACH), floori(leader.node.position.z / BATTLE_JOIN_REACH))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(leader)
	for i in leaders.size():
		var a: Dictionary = leaders[i]
		var cell: = Vector2i(floori(a.node.position.x / BATTLE_JOIN_REACH), floori(a.node.position.z / BATTLE_JOIN_REACH))
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for b in cells.get(cell + Vector2i(dx, dy), []):
					if leaders.find(b) <= i: continue
					var apart: float = a.node.position.distance_to(b.node.position)
					if apart <= 0.3: stacks.join(a, b)
					# Armies fighting side by side (both in the battle, stopped) become one stack.
					elif apart <= BATTLE_JOIN_REACH and a.engaged and b.engaged: stacks.join(a, b, true)
	if selected >= 0:
		selected = units.find(stacks.leader(stacks.members(units[selected])))
	# Route lines are redrawn 5 times a second at most (they cost 12 ms with the bigger army).
	var now: = Time.get_ticks_msec()
	if now - _route_drawn_at >= 200:
		_route_drawn_at = now
		_draw_route()
func _draw_route() -> void :
	if route == null: return
	_update_order_markers()
	# Call of War: every one of your moving armies shows its path; the selected one is
	# brighter. Armies with an attack order show a red arc to their target.
	destination_marker.visible = false
	var selected_key: = ""
	if selected >= 0 and selected < units.size(): selected_key = units[selected].country + ":" + units[selected].stack_id
	var orders: Array = []
	var signature: = selected_key
	for group in stacks.groups():
		var leader: Dictionary = stacks.leader(group)
		if not visible_to_player(leader): continue
		var key: String = leader.country + ":" + leader.stack_id
		var chosen: = key == selected_key
		if leader.country != GameSession.player_country and not chosen: continue
		var start: = Vector2(leader.node.position.x, leader.node.position.z)
		# Owner review: planes fly freely and show no path line.
		if leader.moving and not air.is_air(leader) and leader.visual_kind != "missile_launcher":
			var points: Array = [start]
			points.append_array(leader.waypoints)
			if points.size() == 1: points.append(leader.target)
			orders.append({"move": true, "chosen": chosen, "points": points, "unit": leader})
			signature += key + str(start.snapped(Vector2.ONE * 0.08)) + str(leader.waypoints) + str(leader.target)
		if false: # Target orders remain active; no red attack lines on units.
			var enemy: = find_id(leader.attack_target)
			if not enemy.is_empty() and visible_to_player(enemy):
				var finish: = Vector2(enemy.node.position.x, enemy.node.position.z)
				var bend: = (finish - start).orthogonal() * 0.22
				var arc: Array = []
				for i in 17:
					var t: = i / 16.0
					arc.append(start.lerp(finish, t) + bend * 4.0 * t * (1.0 - t))
				orders.append({"move": false, "chosen": chosen, "points": arc, "unit": leader})
				signature += key + ">" + str(finish.snapped(Vector2.ONE * 0.08)) + str(start.snapped(Vector2.ONE * 0.08))
	route.visible = not orders.is_empty()
	if signature == route_signature: return
	route_signature = signature
	if orders.is_empty(): return
	var surface: = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for order in orders:
		var unit: Dictionary = order.unit
		var tone: = Color(1.0 if order.move else 0.0, 1.0 if order.chosen else 0.0, 0.0)
		var width: = 4.5 if order.chosen else 3.5
		var points: Array = order.points
		var length: = 0.0
		for segment in range(points.size() - 1):
			var a: Vector2 = points[segment]
			var b: Vector2 = points[segment + 1]
			var distance: = a.distance_to(b)
			if distance < 0.0001: continue
			var normal: = (b - a).orthogonal().normalized()
			var steps: = maxi(1, ceili(distance / 0.18))
			for i in steps:
				var from: = a.lerp(b, i / float(steps))
				var to: = a.lerp(b, (i + 1) / float(steps))
				var l0: = length + distance * i / steps
				var l1: = length + distance * (i + 1) / steps
				for corner in [[from, l0, -1.0], [from, l0, 1.0], [to, l1, 1.0], [from, l0, -1.0], [to, l1, 1.0], [to, l1, -1.0]]:
					surface.set_color(tone)
					surface.set_uv(Vector2(corner[1], corner[2]))
					surface.set_uv2(normal * corner[2] * width)
					surface.set_normal(Vector3.UP)
					surface.add_vertex(surface_position(unit, corner[0]) + Vector3.UP * 0.11)
			length += distance
		# Arrowhead at the destination / target.
		var tip: Vector2 = points[-1]
		var back: Vector2 = points[-2] if points.size() > 1 else tip
		var direction: = (tip - back).normalized()
		if direction == Vector2.ZERO: continue
		var side: = direction.orthogonal()
		var arrow_tone: = Color(tone.r, tone.g, 1.0)
		for offset in [direction * 16.0, -direction * 6.0 + side * 12.0, -direction * 6.0 - side * 12.0]:
			surface.set_color(arrow_tone)
			surface.set_uv(Vector2(length, 0))
			surface.set_uv2(offset)
			surface.set_normal(Vector3.UP)
			surface.add_vertex(surface_position(unit, tip) + Vector3.UP * 0.12)
	route.mesh = surface.commit()

func snapshot() -> Array:
	var result: Array = []
	for unit in units:
		if unit.health <= 0.001: continue  # destroyed this frame, removed after combat; never saved
		var saved_route: Array = []
		for point in unit.waypoints: saved_route.append([point.x, point.y])
		result.append({"battle_role": unit.get("battle_role", ""), "forced_march": unit.forced_march, "delay_remaining": unit.delay_remaining, "fire_mode": unit.get("fire_mode", "at_will"), "attack_target": unit.get("attack_target", ""), "level": unit.get("level", 1), "upgrade_remaining": unit.get("upgrade_remaining", 0.0), "upgrade_target": unit.get("upgrade_target", unit.get("level", 1)), "stack_id": unit.stack_id, "route": saved_route, "equipment_id": unit.equipment_id, "id": unit.id, "name": unit.name, "country": unit.country, "visual_kind": unit.visual_kind, "presentation": unit.get("presentation", ""), "position": [unit.node.position.x, unit.node.position.z], "target": [unit.target.x, unit.target.y], "moving": unit.moving, "health": unit.health})
		if air.is_air(unit): result[-1].merge(air.snapshot(unit))
	return result
func restore(state: Array) -> void :
	for unit in units: unit.node.queue_free()
	units.clear()
	stacks.invalidate()
	selected = -1
	command_ids.clear()
	for data in state:
		var point: = Vector2(data.position[0], data.position[1])
		var color: = Color("73bcff") if data.country == "ukraine" else Color("ef827c")
		_spawn(data, point, color)
		var unit: Dictionary = units[-1]
		unit.target = Vector2(data.target[0], data.target[1])
		unit.moving = data.moving
		unit.health = data.get("health", 100.0)
		if unit.moving:
			if data.has("route"):
				for waypoint in data.route: unit.waypoints.append(Vector2(waypoint[0], waypoint[1]))
			else: unit.waypoints = [unit.target] if air.is_air(unit) else path_for(unit, point, unit.target)
		if unit.moving and unit.waypoints.is_empty(): unit.moving = false
		if unit.moving: _update_heading(unit)
		elif unit.country == "ukraine":
			unit.heading = _facing_enemy(unit.country,Vector2(unit.node.position.x,unit.node.position.z))
			unit.node.get_child(0).rotation.y = unit.heading
	_draw_route()

const CITY_SCALE: = 0.55
const CITY_RADIUS: = 0.8
static var _city_points: = PackedVector2Array()
func _city_at(point: Vector2) -> Variant:
	if _city_points.is_empty(): _in_city(point)
	for city_point in _city_points:
		if CitySystem.near_city(point, city_point): return city_point
	return null
## Owner 2026-10-14: "don't put units beside the city, put them in the middle". An army joins its
## stack's spot; the first army stands in the city centre, further ones close by in the park.
func _garrison_spot(city: Vector2, stack_id: String) -> Vector2:
	var stacks_here: Dictionary = {}
	for unit in units:
		if is_naval(unit) or air.is_air(unit): continue
		var at: = Vector2(unit.node.position.x, unit.node.position.z)
		if not CitySystem.near_city(at, city): continue
		if not stack_id.is_empty() and unit.stack_id == stack_id: return at
		stacks_here[unit.stack_id] = true
	var spot: = CitySystem.plaza_point(city)
	if stacks_here.is_empty(): return spot
	return spot + Vector2.from_angle(-PI * 0.25 + PI * 0.5 * (stacks_here.size() - 1)) * 0.14
func _in_city(point: Vector2) -> bool:
	if _city_points.is_empty():
		for city in GeographicProjection.load_cities(): _city_points.append(city.point)
	for city_point in _city_points:
		if CitySystem.near_city(point, city_point): return true
	return false
## Ukrainian idle units face the nearest Russian city; orders face their destination.
func _facing_enemy(country: String, point: Vector2) -> float:
	if country != "ukraine": return deg_to_rad(135.0)
	var nearest: = INF
	var destination: = point + Vector2(1,-1)
	for city in GeographicProjection.load_cities():
		if city.country.to_lower() != "russia": continue
		var distance: float = point.distance_squared_to(city.point)
		if distance > 0.0001 and distance < nearest:
			nearest = distance
			destination = city.point
	var direction: = destination - point
	return atan2(-direction.x,-direction.y)
func _update_heading(unit: Dictionary) -> void :
	var current: = Vector2(unit.node.position.x, unit.node.position.z)
	var direction: Vector2 = (unit.waypoints[0] if not unit.waypoints.is_empty() else unit.target) - current
	if direction.length_squared() > 0.0001:
		unit.heading = atan2( - direction.x, - direction.y)
## Keep the new detailed model at child zero: combat, selection and shadows use it.
func _replace_visual(unit: Dictionary, replacement: Node3D) -> void:
	var old: Node3D = unit.node.get_child(0)
	replacement.rotation = old.rotation
	replacement.scale = old.scale
	unit.node.remove_child(old)
	old.queue_free()
	unit.node.add_child(replacement)
	unit.node.move_child(replacement, 0)

const AIRCRAFT_SCALE: = 1.40
const CITY_GARRISON_SCALE: = 1.40  # owner 2026-10-15: "I don't even know what the unit is"
const SMALL_GARRISON_READABILITY: = 1.15  # owner 2026-10-15: infantry "a little bit too big" at 1.6

static func garrison_scale(unit: Dictionary) -> float:
	# Cached per unit and level: this runs every frame for every ground army.
	var key: = str(unit.get("equipment_id", "")) + ":" + str(unit.get("level", 1))
	if unit.get("_small_key", "") != key:
		var small: bool = unit.visual_kind == "infantry"
		var path: String = EquipmentIdentity.research_tier(unit.equipment_id, int(unit.get("level", 1))).get("model", "")
		unit["_small"] = small or path.get_file().contains("mortar")
		unit["_small_key"] = key
	return CITY_GARRISON_SCALE * (SMALL_GARRISON_READABILITY if unit._small else 1.0)
## Owner 2026-10-15 ("the infantry in the city is bigger ... but I like the size"): armies out in
## the provinces are drawn the same size as in a city.
static func field_scale(unit: Dictionary) -> float:
	return garrison_scale(unit)
func _process(delta: float) -> void :
	# Do not load 3D vehicles behind the campaign's start menu on phones.
	if UnitSystem.mobile_device() and get_parent() is Node3D and not (get_parent() as Node3D).visible:
		return
	if air_range != null:
		air_range.visible = selected >= 0 and air.is_air(units[selected])
		if air_range.visible:
			var place: = air.base(units[selected])
			var radius: = air.radius(units[selected])
			air_range.scale = Vector3(radius, 1, radius)
			air_range.position = terrain.position_at(place.point) + Vector3.UP * 0.1

	if range_rings != null and terrain != null: range_rings.update(self, view_distance)
	var chosen_stacks: Dictionary = {}
	for leader in command_groups(): chosen_stacks[leader.stack_id] = true
	var leader_ids: Dictionary = {}
	for group in stacks.groups(): leader_ids[stacks.leader(group).id] = true
	var camera: = get_viewport().get_camera_3d()
	var view: = get_viewport().get_visible_rect().grow(160)
	var mobile: bool = UnitSystem.mobile_device() or force_mobile
	var detailed: int = 0
	var upgrades_left: int = _mobile_visual_refresh_budget
	var reveals_left: int = REVEALS_PER_FRAME
	# Owner 2026-10-16 ("render a little bit earlier"): on-screen armies are handled selected
	# first, then nearest the middle of the screen, so the reveal and model-load budgets go where
	# the player is looking. Armies just off screen keep their loaded model (a phone used to
	# throw it away at the screen edge and load it again one a frame after every small pan).
	var keep: = get_viewport().get_visible_rect().grow(get_viewport().get_visible_rect().size.length() * 0.5)
	var middle: = get_viewport().get_visible_rect().get_center()
	var ordered: Array = []
	var rest: Array = []
	for unit in units:
		var near: = true
		var on_screen: = true
		if camera != null:
			if camera.is_position_behind(unit.node.position):
				on_screen = false
				near = false
			else:
				var point: = camera.unproject_position(unit.node.position)
				on_screen = view.has_point(point)
				near = keep.has_point(point)
				unit["_reveal_rank"] = -1.0 if chosen_stacks.has(unit.stack_id) else middle.distance_squared_to(point)
		unit["_on_screen"] = on_screen
		unit["_near_screen"] = near
		if on_screen and leader_ids.has(unit.id): ordered.append(unit)
		else: rest.append(unit)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("_reveal_rank", 0.0)) < float(b.get("_reveal_rank", 0.0)))
	ordered.append_array(rest)
	for unit in ordered:
		# Off-screen units should not force fog calculations or keep heavyweight models.
		var on_screen: bool = unit._on_screen
		var is_leader: bool = leader_ids.has(unit.id)
		unit.icon_only = false
		if on_screen and is_leader and view_distance > FAR_ZOOM:
			unit.node.visible = false
			unit.icon_only = visible_to_player(unit)
			continue
		if not on_screen or not is_leader:
			unit.node.visible = false
			if mobile and not unit.node.get_child(0).get_meta("startup_lightweight", false):
				if is_leader and unit._near_screen and detailed < MOBILE_MAX_DETAILED_UNITS: detailed += 1
				else: _replace_visual(unit, UnitVisual.lightweight(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level))
			continue
		# Owner 2026-10-16 ("the camera's getting stuck mid-zoom ... about halfway"): zooming in past
		# FAR_ZOOM used to show every army's 3D model in the same frame; they now appear a few per
		# frame (the map tag stands in for the rest until their turn).
		var showing: bool = visible_to_player(unit)
		if showing and not unit.node.visible:
			# The army just tapped shows at once, whatever the budget.
			if reveals_left <= 0 and not chosen_stacks.has(unit.stack_id):
				unit.icon_only = true
				continue
			reveals_left -= 1
		unit.node.visible = showing
		if not unit.node.visible:
			if mobile and not unit.node.get_child(0).get_meta("startup_lightweight", false):
				_replace_visual(unit, UnitVisual.lightweight(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level))
			continue
		if mobile:
			var visual: Node3D = unit.node.get_child(0)
			if not visual.get_meta("startup_lightweight", false):
				if detailed < MOBILE_MAX_DETAILED_UNITS:
					detailed += 1
				else:
					_replace_visual(unit, UnitVisual.lightweight(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level))
					unit.node.visible = false
					unit.icon_only = true
					continue
			elif upgrades_left > 0 and detailed < MOBILE_MAX_DETAILED_UNITS and not (visual.get_meta("missing_original_model", false) and Time.get_ticks_msec() - int(visual.get_meta("missing_at", 0)) < 5000):
				# One expensive model import per frame; missing originals are not retried forever.
				var replacement: Node3D = UnitVisual.create(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level)
				if replacement.get_meta("missing_original_model", false) and not replacement.get_meta("simple_model", false):
					# Retried every 5 s (owner 2026-10-15: units stayed blank for good).
					visual.set_meta("missing_original_model", true)
					visual.set_meta("missing_at", Time.get_ticks_msec())
					replacement.free()
				else:
					# A simple model of the kind stands in until the real one loads (retried below).
					if replacement.get_meta("missing_original_model", false): replacement.set_meta("missing_at", Time.get_ticks_msec())
					_replace_visual(unit, replacement)
					detailed += 1
				upgrades_left -= 1
		if unit.node.get_child(0).get_meta("startup_lightweight", false):
			# Model not loaded yet (phone cap): show the map symbol, never a placeholder box.
			unit.node.visible = false
			unit.icon_only = true
			continue
		var ground: = Vector3(unit.node.position.x, SEA_WATERLINE, unit.node.position.z) if is_naval(unit) else terrain.position_at(Vector2(unit.node.position.x, unit.node.position.z))
		if is_naval(unit):
			unit.node.position.y = SEA_WATERLINE
			unit.node.get_meta("ground_shadow").hide()
			unit.ring.global_position.y = 0.05
		else: UnitShadow.update(unit, ground)
		var chosen: = chosen_stacks.has(unit.stack_id)
		unit.ring.material_override.albedo_color = Color("f5cf82") if chosen else unit.faction_color
		# Owner 2026-10-16 ("when I click on units in the city the circle doesn't go around them
		# anymore"): the ring is sized to the (now bigger) model so it shows round it, and drawn
		# over the city's park paving.
		unit.ring.scale = Vector3.ONE * maxf(0.52, _model_reach(unit) * 1.25 / 0.81)
		unit.ring.material_override.no_depth_test = chosen
		unit.ring.material_override.render_priority = 5
		# Call of War: only the selected army gets a ring; the map tag shows ownership.
		unit.ring.visible = chosen
		var model: Node3D = unit.node.get_child(0)
		if model.get_meta("missing_original_model", false) and Time.get_ticks_msec() - int(model.get_meta("missing_at", 0)) > 5000 and (not mobile or upgrades_left > 0):
			model.set_meta("visual_level", -1)
			upgrades_left -= 1
		if int(model.get_meta("visual_level", -1)) != int(unit.level):
			var replacement: = UnitVisual.create(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level)
			if replacement.get_meta("missing_original_model", false) and model.get_child_count() > 0:
				# Not loadable yet (owner 2026-10-15: "the tanks are registering nothing"): keep
				# what is shown and try again in a few seconds instead of showing nothing.
				replacement.free()
				model.set_meta("visual_level", unit.level)
				model.set_meta("missing_original_model", true)
				model.set_meta("missing_at", Time.get_ticks_msec())
			else:
				replacement.rotation = model.rotation
				replacement.scale = model.scale
				unit.node.remove_child(model)
				model.queue_free()
				unit.node.add_child(replacement)
				unit.node.move_child(replacement, 0)
				model = replacement
				if replacement.get_meta("missing_original_model", false): replacement.set_meta("missing_at", Time.get_ticks_msec())
			unit.name = EquipmentIdentity.research_title(unit.equipment_id, unit.level)
		if unit.visual_kind == "air_defense":
			if model.has_meta("air_defense_animator"):
				var animator: AirDefenseAnimator = model.get_meta("air_defense_animator")
				animator.moving = unit.moving
				animator.animate(delta)
		if air.is_air(unit): _refuel_crew(unit)
		if model.has_meta("helicopter_animator"):
			var rotor_animator: HelicopterAnimator = model.get_meta("helicopter_animator")
			rotor_animator.animate(delta, unit.get("flight_mode", "grounded") != "grounded" and unit.health > 0)
		# Owner 2026-10-15 ("the units aren't actually touching when they're fighting ... look at
		# Call of War, they kneel down and fire"): armies in a close battle step up to the enemy,
		# face it and crouch while CombatEffects keeps their weapons firing between rounds.
		# Owner 2026-10-16: only for the few seconds after each exchange of fire (CombatEffects.BURST_SECONDS).
		var fighting: bool = unit.engaged and unit.get("fire_burst", 0.0) > 0.0 and unit.has("foe_point") and not is_naval(unit) and not air.is_air(unit)
		var lunge: = Vector3.ZERO
		var crouch: = 0.0
		if fighting:
			var here: = Vector2(unit.node.position.x, unit.node.position.z)
			var towards: Vector2 = unit.foe_point - here
			if towards.length() > 0.01:
				unit.heading = atan2(-towards.x, -towards.y)
				# Step up until the two models meet, never into each other: the gap left between
				# the armies is closed by half from each side, minus how far each model reaches.
				var reach_here: = _model_reach(unit)
				var foe_reach: = reach_here
				var foe: = find_id(str(unit.get("foe_id", "")))
				if not foe.is_empty(): foe_reach = _model_reach(foe)
				var step: = clampf((towards.length() - reach_here - foe_reach) * 0.5 - 0.02, 0.0, 0.22)
				lunge = unit.node.global_transform.basis.inverse() * (Vector3(towards.x, 0, towards.y).normalized() * step)
			crouch = 1.0
		model.position = model.position.lerp(lunge, 1.0 - exp(-delta * 3.0))
		var small: bool = unit.visual_kind == "infantry"
		model.rotation.x = lerpf(model.rotation.x, -0.16 * crouch if small else 0.0, 1.0 - exp(-delta * 4.0))
		model.rotation.y = lerp_angle(model.rotation.y, unit.heading, 1.0 - exp( - delta * 8.0))
		if not is_naval(unit) and not air.is_air(unit):
			var slope: = Quaternion(Vector3.UP, ground_normal(Vector2(unit.node.position.x, unit.node.position.z)))
			unit.node.quaternion = unit.node.quaternion.slerp(slope, 1.0 - exp( - delta * 8.0))
		# Owner 2026-10-13: ground armies standing in a city are drawn bigger so the garrison
		# reads clearly among the buildings (aircraft and ships keep their size).
		var on_land: = not is_naval(unit) and not air.is_air(unit)
		# Owner 2026-10-16 ("make the planes bigger ... still the same size"): aircraft grow with
		# the ground armies (ships keep their size at sea).
		var target_scale: = 0.65 * ((garrison_scale(unit) if _in_city(Vector2(unit.node.position.x, unit.node.position.z)) else field_scale(unit)) if on_land else (AIRCRAFT_SCALE if air.is_air(unit) else 1.0))
		model.scale = model.scale.lerp(Vector3.ONE * target_scale, 1.0 - exp( - delta * 6.0))
		if unit.node.has_meta("detailed_sprite"):
			var sprite: Sprite3D = unit.node.get_meta("detailed_sprite")
			var relative: = wrapf(unit.heading - camera.rotation.y, - PI, PI)
			sprite.frame = [1, 2, 3, 0][int(floor((relative + PI) / (PI * 0.5))) % 4]

## Owner 2026-10-15 ("the airplanes, they should show them refuelling - it takes 30 minutes on a
## 1x map"): a landed aircraft that is refuelling has a fuel truck parked at its wing with the hose
## connected and the time left above it.
## How far an army's model reaches out from its centre on the map (half its longest side).
func _model_reach(unit: Dictionary) -> float:
	if unit.node.get_child_count() == 0: return 0.15
	var model: Node3D = unit.node.get_child(0)
	var box: AABB = model.get_meta("pick_bounds", AABB(Vector3.ZERO, Vector3(0.3, 0.3, 0.3)))
	return maxf(box.size.x, box.size.z) * 0.5 * model.scale.x
## Draws each kind of model on the map once, off screen, while the game is loading, so the phone
## prepares its graphics then rather than in the middle of the first zoom.
func prewarm_models() -> void:
	var view: = SubViewport.new()
	view.size = Vector2i(64, 64)
	view.own_world_3d = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var eye: = Camera3D.new()
	view.add_child(eye)
	eye.position = Vector3(0, 400, 3)
	eye.look_at(Vector3(0, 400, 0))
	eye.current = true
	var seen: Dictionary = {}
	for unit in units:
		var key: = str(unit.equipment_id) + ":" + str(unit.get("level", 1))
		if seen.has(key): continue
		seen[key] = true
		var model: = UnitVisual.create(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.get("level", 1))
		model.position = Vector3(0, 400, 0)
		view.add_child(model)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	view.queue_free()
static var _crew_mesh: ArrayMesh
func _refuel_crew(unit: Dictionary) -> void:
	var crew: Node3D = unit.node.get_node_or_null("RefuelCrew")
	var refuelling: bool = unit.get("flight_mode", "") == "grounded" and float(unit.get("refuel_remaining", 0.0)) > 0.0
	if not refuelling:
		if crew != null: crew.visible = false
		return
	if crew == null:
		crew = Node3D.new()
		crew.name = "RefuelCrew"
		if _crew_mesh == null: _crew_mesh = _fuel_truck_mesh()
		var truck: = MeshInstance3D.new()
		truck.mesh = _crew_mesh
		truck.position = Vector3(0.62, 0.0, 0.15)
		truck.rotation.y = -0.5
		truck.scale = Vector3.ONE * 0.45
		crew.add_child(truck)
		var timer: = Label3D.new()
		timer.name = "Timer"
		timer.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		timer.no_depth_test = true
		timer.render_priority = 12
		timer.fixed_size = true
		timer.pixel_size = 0.0009
		timer.font_size = 30
		timer.outline_size = 10
		timer.modulate = Color("ffd36b")
		timer.outline_modulate = Color("1d2126")
		timer.position = Vector3(0.0, 0.55, 0.0)
		crew.add_child(timer)
		unit.node.add_child(crew)
	crew.visible = true
	var label: Label3D = crew.get_node("Timer")
	label.text = "REFUELING " + SimulationClock.duration(float(unit.refuel_remaining))
func _fuel_truck_mesh() -> ArrayMesh:
	var olive: = StandardMaterial3D.new()
	olive.albedo_color = Color("4d5a3a")
	var tank: = StandardMaterial3D.new()
	tank.albedo_color = Color("8f9688")
	var hose: = StandardMaterial3D.new()
	hose.albedo_color = Color("1e1e1e")
	var tool: = SurfaceTool.new()
	var mesh: = ArrayMesh.new()
	var add: = func(shape: Mesh, at: Transform3D, ink: Material) -> void:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(ink)
		tool.append_from(shape, 0, at)
		tool.commit(mesh)
	var cab: = BoxMesh.new(); cab.size = Vector3(0.16, 0.13, 0.13)
	add.call(cab, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0.2)), olive)
	var bed: = BoxMesh.new(); bed.size = Vector3(0.16, 0.05, 0.34)
	add.call(bed, Transform3D(Basis.IDENTITY, Vector3(0, 0.055, -0.06)), olive)
	var drum: = CylinderMesh.new(); drum.top_radius = 0.075; drum.bottom_radius = 0.075; drum.height = 0.3; drum.radial_segments = 12
	add.call(drum, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.15, -0.06)), tank)
	var pipe: = CylinderMesh.new(); pipe.top_radius = 0.012; pipe.bottom_radius = 0.012; pipe.height = 0.3; pipe.radial_segments = 6
	add.call(pipe, Transform3D(Basis(Vector3.FORWARD, PI * 0.5).rotated(Vector3.UP, 0.35), Vector3(-0.18, 0.04, -0.08)), hose)
	return mesh
func stop_selected() -> void :
	if selected < 0: return
	var unit: Dictionary = units[selected]
	if air.is_air(unit):
		for member in stacks.members(unit): member.repeat_target = ""
		if unit.flight_mode != "grounded": air.return_home(unit)
		status_changed.emit("Returning to home airbase" if unit.flight_mode != "grounded" else "Aircraft is already at its airbase")
		_draw_route()
		return
	unit.moving = false
	for member in stacks.members(unit): member.attack_target = "";member.firing_halt = false;member.delay_remaining = 0.0;member.forced_march = false
	unit.waypoints.clear()
	unit.target = Vector2(unit.node.position.x, unit.node.position.z)
	for member in stacks.members(unit):
		member.moving = false
		member.waypoints.clear()
		member.target = unit.target
	_draw_route()
	status_changed.emit("Movement stopped")
func patrol(position: Vector3) -> bool:
	if selected < 0 or not air.is_air(units[selected]): return false
	var error: = air.order(units[selected], Vector2(position.x, position.z), "patrol")
	status_changed.emit("Patrol ordered · aircraft returns automatically when endurance runs low" if error.is_empty() else error)
	_draw_route()
	return error.is_empty()

func pick_screen(camera: Camera3D, screen: Vector2, enemies_only: bool = false) -> Dictionary:
	var hits: = pick_all_screen(camera, screen, enemies_only)
	return hits[0] if not hits.is_empty() else {}

## Every army under a tap, best match first: armies whose model is under the finger (closest to
## the model centre first), then armies within PICK_RADIUS px (closest first).
## Owner 2026-10-16 ("it's hard to click the units"): a fingertip-sized reach round each army
## (was 28 px). The city still wins a tap on its own centre away from the armies (main.gd).
const PICK_RADIUS: = 44.0
func pick_all_screen(camera: Camera3D, screen: Vector2, enemies_only: bool = false) -> Array:
	var hits: Array = []
	var radius: = PICK_RADIUS * get_window().content_scale_factor
	var leader_ids: Dictionary = {}
	for group in stacks.groups(): leader_ids[stacks.leader(group).id] = true
	for i in units.size():
		if enemies_only and units[i].country == GameSession.player_country: continue
		if not visible_to_player(units[i]): continue
		if not leader_ids.has(units[i].id): continue
		var anchor: Vector3 = units[i].node.global_position + Vector3.UP * 0.2
		if camera.is_position_behind(anchor): continue
		var distance: = camera.unproject_position(anchor).distance_to(screen)
		var inside_model: = false
		var centre_distance: = INF
		# Pick the displayed model, including airborne drones and wing tips.
		if units[i].node.get_child_count() > 0:
			var model: Node3D = units[i].node.get_child(0)
			if model.has_meta("pick_bounds"):
				var bounds: AABB = model.get_meta("pick_bounds")
				# Owner 2026-10-16 ("it's hard to click the city"): the bigger models covered most of a
				# town, so only the middle of a model picks it; taps around it reach the city.
				bounds = bounds.grow(0.0)
				bounds.position += bounds.size * Vector3(0.2, 0.0, 0.2)
				bounds.size *= Vector3(0.6, 0.75, 0.6)
				var hull: PackedVector2Array = []
				var behind: = false
				for corner in 8:
					var world: Vector3 = model.global_transform * bounds.get_endpoint(corner)
					behind = behind or camera.is_position_behind(world)
					hull.append(camera.unproject_position(world))
				# A corner behind the camera projects to nonsense that can cover the whole screen.
				if behind or hull.size() < 3: hull = PackedVector2Array()
				else: hull = Geometry2D.convex_hull(hull)
				if hull.is_empty(): pass
				elif Geometry2D.is_point_in_polygon(screen,hull):
					distance = 0.0
					inside_model = true
					centre_distance = camera.unproject_position(model.to_global(bounds.get_center())).distance_to(screen)
				else:
					for edge in hull.size(): distance = minf(distance,screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,hull[edge],hull[(edge+1)%hull.size()])))
		if inside_model or distance < radius:
			hits.append({"index": i, "distance": distance, "inside": inside_model, "rank": centre_distance if inside_model else distance})
	hits.sort_custom(func(a, b): return a.inside and not b.inside or a.inside == b.inside and a.rank < b.rank)
	return hits

func find_id(id: String) -> Dictionary:
	for unit in units:
		if unit.id == id: return unit
	return {}
func command_groups() -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for id in command_ids:
		var unit: = find_id(id)
		if unit.is_empty() or unit.health <= 0 or unit.country != GameSession.player_country: continue
		var key: String = unit.country + ":" + unit.stack_id
		if seen.has(key): continue
		seen[key] = true
		result.append(stacks.leader(stacks.members(unit)))
	return result
func select_armies(ids: Array[String]) -> void :
	command_ids.assign(ids)
	var leaders: = command_groups()
	if leaders.is_empty(): return
	selected = units.find(leaders[0])
	unit_selected.emit(units[selected])
	_draw_route()
func order_many(destination: Vector3, append: bool = false) -> int:
	if MatchClient.active != null: return MatchClient.active.send_units("move", command_ids, {"x": destination.x, "z": destination.z, "append": append})
	var original: = selected
	var leaders: = command_groups()
	var accepted: = 0
	for leader in leaders:
		selected = units.find(leader)
		if order(destination, append): accepted += 1
	selected = original
	_draw_route()
	status_changed.emit(str(accepted) + " / " + str(leaders.size()) + " armies ordered" + (" · blocked armies keep their previous orders" if accepted < leaders.size() else ""))
	return accepted
func stop_many() -> void :
	if MatchClient.active != null:
		MatchClient.active.send_units("stop", command_ids)
		return
	var original: = selected
	for leader in command_groups():
		selected = units.find(leader)
		stop_selected()
	selected = original
	_draw_route()
## Owner 2026-10-16 ("you can select how your weapon fires"): `leaders` picks the armies (the
## army panel sets one army); by default every selected army. Online, the server is told too.
func set_fire_mode(mode: String, leaders: Array = []) -> void :
	if not FireControlPanel.MODES.has(mode): return
	if leaders.is_empty(): leaders = command_groups()
	if leaders.is_empty() and selected >= 0 and selected < units.size(): leaders = [units[selected]]
	if MatchClient.active != null: MatchClient.active.send_units("fire_mode", leaders.map(func(leader: Dictionary): return leader.id), {"mode": mode})
	for leader in leaders:
		if air.is_air(leader) or leader.country != GameSession.player_country: continue
		for member in stacks.members(leader): member.fire_mode = mode
	status_changed.emit("Fire control: " + FireControlPanel.MODES[mode].title)
const DIRECT_ATTACK_RANGE: = 6.0
func attack_selected(enemy: Dictionary) -> bool:
	if selected < 0 or enemy.is_empty() or enemy.country == units[selected].country or not at_war: return false
	var army: Dictionary = units[selected]
	var group: = stacks.members(army)
	if group.all(func(member): return EquipmentIdentity.spec(member.equipment_id).get("targets_naval", false)) and enemy.visual_kind != "naval":
		status_changed.emit("Coastal missiles target ships")
		return false
	var distance: float = Vector2(army.node.position.x,army.node.position.z).distance_to(Vector2(enemy.node.position.x,enemy.node.position.z))
	var in_range: bool = group.any(func(member):
		var candidate: Dictionary = member.duplicate()
		candidate.attack_target = enemy.id
		return CombatSystem.shoots_from_range(candidate) and fire_control.attack_reach(candidate) >= distance)
	# Nearby enemy with open land in between: drive straight at it (owner: "some units don't
	# attack"). Roads only lead province centre to centre, which can stop short of the enemy.
	var army_point: = Vector2(army.node.position.x, army.node.position.z)
	var enemy_at: = Vector2(enemy.node.position.x, enemy.node.position.z)
	var direct: bool = not in_range and not air.is_air(army) and not is_naval(army) and distance <= DIRECT_ATTACK_RANGE \
		and navigation.on_land(enemy_at) and navigation.clear_segment(army_point, enemy_at) \
		and not group.any(func(m): return EquipmentIdentity.spec(m.equipment_id).get("stationary", false))
	if direct:
		for member in group:
			member.waypoints = [enemy_at]
			member.target = enemy_at
			member.moving = true
		_update_heading(army)
		_draw_route()
	var accepted: bool = in_range or direct or order(enemy.node.position)
	if in_range:
		for member in group:
			member.moving = false
			member.waypoints.clear()
			member.target = Vector2(member.node.position.x,member.node.position.z)
	if accepted:
		var enemy_point: = Vector2(enemy.node.position.x, enemy.node.position.z)
		for member in stacks.members(units[selected]):
			member.attack_target = enemy.id
			if air.is_air(member): member.flight_mode = "attack"
			# Roads end at the province centre; finish the attack with a direct approach to the
			# enemy's actual position so armies parked off the centre are reached and engaged.
			elif not in_range and not direct and not is_naval(member) and member.moving and not member.waypoints.is_empty():
				var last: Vector2 = member.waypoints[-1]
				if last.distance_to(enemy_point) > 0.05 and navigation.on_land(enemy_point) and navigation.clear_segment(last, enemy_point):
					member.waypoints.append(enemy_point)
					member.target = enemy_point
	return accepted

func attack_many(enemy: Dictionary) -> int:
	if MatchClient.active != null: return MatchClient.active.send_units("attack", command_ids, {"target": enemy.get("id", "")})
	var original: = selected
	var leaders: = command_groups()
	var accepted: = 0
	for leader in leaders:
		selected = units.find(leader)
		if attack_selected(enemy): accepted += 1
	selected = original
	_draw_route()
	status_changed.emit(str(accepted) + " / " + str(leaders.size()) + " armies ordered to attack")
	return accepted

## Online matches (server side): orders from a player's client, checked against the sender's
## country. Works on stack leaders like the touch commands; returns how many armies accepted.
func command(country: String, ids: Array, op: String, point: Vector2 = Vector2.ZERO, enemy_id: String = "", append: bool = false) -> int:
	var original: = selected
	var original_ids: = command_ids.duplicate()
	var done: Dictionary = {}
	var accepted: = 0
	var enemy: = find_id(enemy_id) if not enemy_id.is_empty() else {}
	for id in ids.slice(0, 64):
		var unit: = find_id(str(id))
		if unit.is_empty() or unit.country != country or unit.health <= 0: continue
		var leader: = stacks.leader(stacks.members(unit))
		var key: String = leader.country + ":" + leader.stack_id
		if done.has(key): continue
		done[key] = true
		selected = units.find(leader)
		match op:
			"move": if order(Vector3(point.x, 0, point.y), append): accepted += 1
			"stop":
				stop_selected()
				accepted += 1
			"attack": if not enemy.is_empty() and enemy.country != country and unit_visible(enemy, country) and attack_selected(enemy): accepted += 1
	selected = original if original < units.size() else -1
	command_ids.assign(original_ids)
	return accepted

## Online matches (client side): replaces the armies on this phone with what the server says
## this player can see. Positions glide towards the server's (see MatchClient).
func apply_remote(entries: Array) -> void:
	var selected_id: String = units[selected].id if selected >= 0 and selected < units.size() else ""
	var seen: Dictionary = {}
	for data in entries:
		seen[data.id] = true
		var unit: = find_id(data.id)
		var point: = Vector2(data.position[0], data.position[1])
		if unit.is_empty():
			_spawn(data, point, Color("73bcff") if data.country == "ukraine" else Color("ef827c"))
			unit = units[-1]
			unit.node.position = Vector3(point.x, unit.node.position.y, point.y)
		unit.net_position = point
		unit.target = Vector2(data.target[0], data.target[1])
		unit.moving = data.moving
		unit.health = float(data.get("health", 100.0))
		unit.stack_id = data.get("stack_id", unit.stack_id)
		unit.level = data.get("level", unit.level)
		unit.attack_target = data.get("attack_target", "")
		unit.fire_mode = str(data.get("fire_mode", unit.get("fire_mode", "at_will")))
		unit.battle_role = str(data.get("battle_role", ""))
		unit.waypoints.clear()
		for waypoint in data.get("route", []): unit.waypoints.append(Vector2(waypoint[0], waypoint[1]))
		if air.is_air(unit):
			for key in ["base_city", "flight_mode", "flight_used", "refuel_remaining", "patrol_phase"]:
				if data.has(key): unit[key] = data[key]
		_update_heading(unit)
	for i in range(units.size() - 1, -1, -1):
		if seen.has(units[i].id): continue
		units[i].node.queue_free()
		units.remove_at(i)
	selected = -1
	for i in units.size():
		if units[i].id == selected_id: selected = i
	command_ids.assign(command_ids.filter(func(id: String): return seen.has(id)))
	_draw_route()

## Glides armies towards their last server position (called every frame by MatchClient).
func glide(delta: float) -> void:
	for unit in units:
		if not unit.has("net_position"): continue
		var goal: = Vector3(unit.net_position.x, unit.node.position.y, unit.net_position.y)
		unit.node.position = unit.node.position.lerp(goal, clampf(delta * 4.0, 0.0, 1.0))
		if unit.node.get_child_count() > 0: unit.node.get_child(0).rotation.y = unit.heading

func travel_time(unit: Dictionary) -> float:
	if not unit.moving or air.is_air(unit): return 0.0
	var group: = stacks.members(unit)
	var origin: = Vector2(unit.node.position.x, unit.node.position.z)
	var seconds: = 0.0
	for waypoint: Vector2 in unit.waypoints:
		var length: = origin.distance_to(waypoint)
		var samples: = maxi(1, ceili(length / 0.1))
		for i in samples:
			seconds += length / samples / stacks.movement_speed(group, origin.lerp(waypoint, (i + 0.5) / samples))
		origin = waypoint
	return seconds
func delay_many(seconds: float, synchronize: bool = false) -> int:
	if not is_finite(seconds) or seconds < 0 or seconds > 720: return 0
	var leaders: = command_groups().filter( func(unit: Dictionary): return unit.moving and not air.is_air(unit) and unit.get("upgrade_remaining", 0.0) == 0)
	var longest: = 0.0
	if synchronize:
		for leader in leaders: longest = maxf(longest, travel_time(leader))
	for leader in leaders:
		var delay: = minf(720, seconds + maxf(0, longest - travel_time(leader))) if synchronize else seconds
		for member in stacks.members(leader): member.delay_remaining = delay
	status_changed.emit(str(leaders.size()) + " armies delayed" + (" · arrivals synchronized approximately" if synchronize else ""))
	return leaders.size()
func toggle_forced_march() -> int:
	var leaders: = command_groups().filter( func(unit: Dictionary): return unit.moving and not air.is_air(unit) and unit.get("upgrade_remaining", 0.0) == 0)
	if leaders.is_empty(): status_changed.emit("Give ground or naval armies a movement order before enabling forced march");return 0
	var enable: bool = not leaders.all( func(unit: Dictionary): return unit.forced_march)
	for leader in leaders:
		for member in stacks.members(leader): member.forced_march = enable
	status_changed.emit("Forced march " + ("ON · speed +50%, loses 5 HP per game hour while moving" if enable else "OFF"))
	return leaders.size()


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
const MOBILE_MAX_DETAILED_UNITS := 12
## Zoom levels (owner request 2026-10-13): beyond FAR_ZOOM armies are map symbols only (no 3D
## models); closer, the 3D models show; within CLOSE_ZOOM the health bar and level appear.
## An army whose model is not loaded (phone cap) shows its symbol instead of a placeholder box.
const FAR_ZOOM := 24.0
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
	for scout in units:
		if not _sees_for(scout.country, country) or scout.health <= 0: continue
		var origin: = Vector2(scout.node.position.x, scout.node.position.z)
		if origin.distance_to(point) <= vision_radius(scout): return true
	return false
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
	return sea_navigation.find_path(start, finish) if is_naval(unit) else navigation.find_path(start, finish, unit.visual_kind)
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
func _spawn(data: Dictionary, point: Vector2, color: Color) -> void :
	if data.get("visual_kind", "") == "naval" and not sea_navigation.on_sea(point):
		point = sea_navigation.coastal_destination(point)
	if data.get("visual_kind", "armor") not in ["fighter", "naval"]:
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
	if OS.has_feature("mobile"):
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
	units.append({"fire_mode": data.get("fire_mode", "at_will"), "attack_target": data.get("attack_target", ""), "firing_halt": false, "level": data.get("level", 1), "upgrade_remaining": data.get("upgrade_remaining", 0.0), "upgrade_target": data.get("upgrade_target", data.get("level", 1)), "stack_id": data.get("stack_id", data.id), "equipment_id": equipment_id, "id": data.id, "country": data.country, "name": spec[0], "visual_kind": visual_kind, "presentation": data.get("presentation", ""), "node": marker, "target": spec[1], "moving": false, "engaged": false, "waypoints": [], "health": 100.0, "heading": _facing_enemy(data.country, point), "ring": ring, "faction_color": color, "icon_only": false})
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
	if not is_naval(units[selected]): destination = path.back()
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
				for property in ["base_city", "flight_mode", "flight_used", "refuel_remaining", "patrol_center", "patrol_phase", "target", "moving", "heading", "attack_target"]: member[property] = unit[property]
				member.waypoints = unit.waypoints.duplicate()
			continue
		unit.engaged = false
		var current: = Vector2(unit.node.position.x, unit.node.position.z)
		var reach: = 1.1
		var neighbours: Array = []
		if at_war:
			var cell: = Vector2i(floori(current.x / 1.1), floori(current.y / 1.1))
			for dx in range(-1,2):
				for dy in range(-1,2): neighbours.append_array(nearby.get(cell + Vector2i(dx,dy), []))
		for enemy in neighbours:
			if at_war and not air.is_air(enemy) and is_naval(enemy) == is_naval(unit) and enemy.country != unit.country and current.distance_squared_to(Vector2(enemy.node.position.x, enemy.node.position.z)) <= reach * reach and visible_to_country(enemy,unit.country):
				unit.engaged = true
				break
		for member in group: member.engaged = unit.engaged
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
				if enemy_point.distance_to(unit.target) > 0.25:
					var pursuit: = path_for(unit, current, enemy_point)
					if not pursuit.is_empty(): unit.target = enemy_point;unit.waypoints = pursuit;unit.moving = true
		var can_defer: bool = at_war and unit.moving and (unit.fire_mode in ["offensive", "aggressive"] or not unit.attack_target.is_empty()) and group.any( func(member: Dictionary): return member.visual_kind in ["artillery", "missile_launcher", "naval"])
		var opponents: Array = fire_control.target(group, army_groups, self) if can_defer else []
		if not opponents.is_empty() and group.any( func(member: Dictionary): return member.visual_kind in ["artillery", "missile_launcher", "naval"]):
			unit.firing_halt = current.distance_to(Vector2(opponents[0].node.position.x, opponents[0].node.position.z)) > 1.1
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
			if unit.forced_march:
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
	var groups: = stacks.groups()
	for i in groups.size():
		for j in range(i + 1, groups.size()):
			var a: = stacks.leader(groups[i])
			var b: = stacks.leader(groups[j])
			if a.node.position.distance_to(b.node.position) <= 0.3: stacks.join(a, b)
	if selected >= 0:
		selected = units.find(stacks.leader(stacks.members(units[selected])))
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
		result.append({"forced_march": unit.forced_march, "delay_remaining": unit.delay_remaining, "fire_mode": unit.get("fire_mode", "at_will"), "attack_target": unit.get("attack_target", ""), "level": unit.get("level", 1), "upgrade_remaining": unit.get("upgrade_remaining", 0.0), "upgrade_target": unit.get("upgrade_target", unit.get("level", 1)), "stack_id": unit.stack_id, "route": saved_route, "equipment_id": unit.equipment_id, "id": unit.id, "name": unit.name, "country": unit.country, "visual_kind": unit.visual_kind, "presentation": unit.get("presentation", ""), "position": [unit.node.position.x, unit.node.position.z], "target": [unit.target.x, unit.target.y], "moving": unit.moving, "health": unit.health})
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
func _in_city(point: Vector2) -> bool:
	if _city_points.is_empty():
		for city in GeographicProjection.load_cities(): _city_points.append(city.point)
	for city_point in _city_points:
		if point.distance_to(city_point) < CITY_RADIUS: return true
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

func _process(delta: float) -> void :
	# Do not load 3D vehicles behind the campaign's start menu on phones.
	if OS.has_feature("mobile") and get_parent() is Node3D and not (get_parent() as Node3D).visible:
		return
	if air_range != null:
		air_range.visible = selected >= 0 and air.is_air(units[selected])
		if air_range.visible:
			var place: = air.base(units[selected])
			var radius: = air.radius(units[selected])
			air_range.scale = Vector3(radius, 1, radius)
			air_range.position = terrain.position_at(place.point) + Vector3.UP * 0.1

	if selected >= 0 and selected < units.size() and units[selected].visual_kind == "air_defense":
		air_range.visible = true
		var aa_unit: Dictionary = units[selected]
		var aa_radius: float = EquipmentIdentity.air_defense_range(aa_unit)
		air_range.scale = Vector3(aa_radius, 1, aa_radius)
		air_range.position = terrain.position_at(Vector2(aa_unit.node.position.x, aa_unit.node.position.z)) + Vector3.UP * 0.12
	var chosen_stacks: Dictionary = {}
	for leader in command_groups(): chosen_stacks[leader.stack_id] = true
	var leader_ids: Dictionary = {}
	for group in stacks.groups(): leader_ids[stacks.leader(group).id] = true
	var camera: = get_viewport().get_camera_3d()
	var view: = get_viewport().get_visible_rect().grow(160)
	var mobile: bool = OS.has_feature("mobile")
	var detailed: int = 0
	var upgrades_left: int = _mobile_visual_refresh_budget
	for unit in units:
		# Off-screen units should not force fog calculations or keep heavyweight models.
		var on_screen: bool = camera == null or (not camera.is_position_behind(unit.node.position) and view.has_point(camera.unproject_position(unit.node.position)))
		var is_leader: bool = leader_ids.has(unit.id)
		unit.icon_only = false
		if on_screen and is_leader and view_distance > FAR_ZOOM:
			unit.node.visible = false
			unit.icon_only = visible_to_player(unit)
			continue
		if not on_screen or not is_leader:
			unit.node.visible = false
			if mobile and not unit.node.get_child(0).get_meta("startup_lightweight", false):
				_replace_visual(unit, UnitVisual.lightweight(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level))
			continue
		unit.node.visible = visible_to_player(unit)
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
			elif upgrades_left > 0 and detailed < MOBILE_MAX_DETAILED_UNITS and not visual.get_meta("missing_original_model", false):
				# One expensive model import per frame; missing originals are not retried forever.
				var replacement: Node3D = UnitVisual.create(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level)
				if replacement.get_meta("missing_original_model", false):
					visual.set_meta("missing_original_model", true)
					replacement.free()
				else:
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
		unit.ring.scale = Vector3.ONE * (0.52 if chosen else 0.42)
		# Call of War: only the selected army gets a ring; the map tag shows ownership.
		unit.ring.visible = chosen
		var model: Node3D = unit.node.get_child(0)
		if int(model.get_meta("visual_level", -1)) != int(unit.level):
			var replacement: = UnitVisual.create(unit.visual_kind, unit.faction_color, unit.equipment_id, unit.level)
			replacement.rotation = model.rotation
			replacement.scale = model.scale
			unit.node.remove_child(model)
			model.queue_free()
			unit.node.add_child(replacement)
			unit.node.move_child(replacement, 0)
			model = replacement
			unit.name = EquipmentIdentity.research_title(unit.equipment_id, unit.level)
		if unit.visual_kind == "air_defense":
			if model.has_meta("air_defense_animator"):
				var animator: AirDefenseAnimator = model.get_meta("air_defense_animator")
				animator.moving = unit.moving
				animator.animate(delta)
		if model.has_meta("helicopter_animator"):
			var rotor_animator: HelicopterAnimator = model.get_meta("helicopter_animator")
			rotor_animator.animate(delta, unit.get("flight_mode", "grounded") != "grounded" and unit.health > 0)
		model.rotation.y = lerp_angle(model.rotation.y, unit.heading, 1.0 - exp( - delta * 8.0))
		if not is_naval(unit) and not air.is_air(unit):
			var slope: = Quaternion(Vector3.UP, ground_normal(Vector2(unit.node.position.x, unit.node.position.z)))
			unit.node.quaternion = unit.node.quaternion.slerp(slope, 1.0 - exp( - delta * 8.0))
		# Consistent map size while entering/leaving cities, including aircraft and ships.
		var target_scale: = 0.65
		model.scale = model.scale.lerp(Vector3.ONE * target_scale, 1.0 - exp( - delta * 6.0))
		if unit.visual_kind == "air_defense": unit.ring.scale = Vector3.ONE * (0.52 if chosen else 0.42) * (model.scale.x / 0.65)
		if unit.node.has_meta("detailed_sprite"):
			var sprite: Sprite3D = unit.node.get_meta("detailed_sprite")
			var relative: = wrapf(unit.heading - camera.rotation.y, - PI, PI)
			sprite.frame = [1, 2, 3, 0][int(floor((relative + PI) / (PI * 0.5))) % 4]

func stop_selected() -> void :
	if selected < 0: return
	var unit: Dictionary = units[selected]
	if air.is_air(unit):
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
	var nearest: Dictionary = {}
	var radius: = 40.0 * get_window().content_scale_factor
	var model_hit: = false
	var model_distance: = INF
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
				var hull: PackedVector2Array = []
				for corner in 8: hull.append(camera.unproject_position(model.global_transform * bounds.get_endpoint(corner)))
				hull = Geometry2D.convex_hull(hull)
				if Geometry2D.is_point_in_polygon(screen,hull):
					distance = 0.0
					inside_model = true
					centre_distance = camera.unproject_position(model.to_global(bounds.get_center())).distance_to(screen)
				else:
					for edge in hull.size(): distance = minf(distance,screen.distance_to(Geometry2D.get_closest_point_to_segment(screen,hull[edge],hull[(edge+1)%hull.size()])))
		if (inside_model and (not model_hit or centre_distance < model_distance)) or (not model_hit and distance < radius):
			radius = distance
			model_hit = inside_model
			model_distance = centre_distance
			nearest = {"index": i, "distance": distance}
	return nearest

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
func set_fire_mode(mode: String) -> void :
	if not FireControlPanel.MODES.has(mode): return
	for leader in command_groups():
		if air.is_air(leader): continue
		for member in stacks.members(leader): member.fire_mode = mode
	status_changed.emit("Fire control: " + FireControlPanel.MODES[mode].title)
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
		return candidate.visual_kind in ["artillery","missile_launcher","naval"] and fire_control.attack_reach(candidate) >= distance)
	var accepted: bool = in_range or order(enemy.node.position)
	if in_range:
		for member in group:
			member.moving = false
			member.waypoints.clear()
			member.target = Vector2(member.node.position.x,member.node.position.z)
	if accepted:
		for member in stacks.members(units[selected]):
			member.attack_target = enemy.id
			if air.is_air(member): member.flight_mode = "attack"
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


class_name RangeRings
extends Node3D
## Owner 2026-10-15: "I want to see a range ring around everything that has a range."
## Thin rings on the ground: air defence, artillery, rocket and missile launchers and warships.
## Only the selected army's ring shows (owner 2026-10-16): blue for yours, red for an enemy's. Aircraft keep
## their own operating-radius ring around their base (UnitSystem.air_range).
const SHOW_BELOW_DISTANCE: = UnitSystem.FAR_ZOOM
const OWN: = Color(0.45, 0.75, 1.0, 0.45)
const ENEMY: = Color(1.0, 0.35, 0.3, 0.45)
## Owner 2026-10-16 ("the circles are a little bit big"): the selected army's weapon range is a
## faint white line, so it is not mistaken for the gold selection circle round the army itself.
const CHOSEN: = Color(1.0, 1.0, 1.0, 0.45)
var _pool: Array[MeshInstance3D] = []
var _inks: Dictionary = {}
var _ring: TorusMesh

func _ready() -> void:
	_ring = TorusMesh.new()
	_ring.inner_radius = 0.985
	_ring.outer_radius = 1.0
	_ring.rings = 96
	_ring.ring_segments = 3
	for key in ["own", "enemy", "chosen"]:
		var ink: = StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ink.no_depth_test = true
		ink.albedo_color = {"own": OWN, "enemy": ENEMY, "chosen": CHOSEN}[key]
		_inks[key] = ink

## Weapon reach of an army in map units, or 0 when it has no ranged weapon.
static func reach(unit: Dictionary) -> float:
	var spec: = EquipmentIdentity.spec(unit.equipment_id)
	if CombatSystem.sniper(unit): return CombatSystem.SNIPER_RANGE
	match unit.visual_kind:
		"air_defense": return EquipmentIdentity.air_defense_range(unit)
		"artillery": return 2.4
		"missile_launcher": return float(spec.get("strike_range", 8.0))
		"naval": return float(spec.get("sea_range", 2.8))
	return 0.0

func update(armies: UnitSystem, view_distance: float) -> void:
	var used: = 0
	var chosen_ids: Dictionary = {}
	for leader in armies.command_groups(): chosen_ids[leader.country + ":" + leader.stack_id] = true
	# An enemy army tapped for a look counts too.
	if armies.selected >= 0 and armies.selected < armies.units.size():
		var looked: Dictionary = armies.units[armies.selected]
		chosen_ids[looked.country + ":" + looked.stack_id] = true
	var leaders: Dictionary = {}
	for group in armies.stacks.groups(): leaders[armies.stacks.leader(group).id] = group
	for unit in armies.units:
		if not leaders.has(unit.id) or unit.health <= 0: continue
		if armies.air.is_air(unit):
			# Owner 2026-10-16 ("airplanes should have a patrol circle so that anything in them gets
			# hit, like Call of War"): a patrolling squadron shows the circle it strikes inside -
			# always for yours, and for an enemy squadron you tap.
			if unit.get("flight_mode", "") != "patrol" or not armies.visible_to_player(unit): continue
			if unit.country != GameSession.player_country and not chosen_ids.has(unit.country + ":" + unit.stack_id): continue
			used = _place(used, Vector3(unit.patrol_center.x, 0, unit.patrol_center.y), AirBattleSystem.PATROL_STRIKE_REACH, unit, armies)
			continue
		var chosen: bool = chosen_ids.has(unit.country + ":" + unit.stack_id)
		# Owner 2026-10-16: "only have the range when they're clicked, and you can click the enemy's
		# units as well to see their range" - the ring shows only round the selected army, yours
		# (blue) or the enemy's (red).
		if not chosen: continue
		if not armies.visible_to_player(unit): continue
		var radius: = 0.0
		for member in leaders[unit.id]: radius = maxf(radius, reach(member))
		if radius <= 0.0: continue
		used = _place(used, unit.node.position, radius, unit, armies)
	for i in range(used, _pool.size()): _pool[i].visible = false

func _place(used: int, at: Vector3, radius: float, unit: Dictionary, armies: UnitSystem) -> int:
	if used >= _pool.size():
		var mesh: = MeshInstance3D.new()
		mesh.mesh = _ring
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		_pool.append(mesh)
	var ring: = _pool[used]
	ring.visible = true
	ring.material_override = _inks["own" if unit.country == GameSession.player_country else "enemy"]
	ring.position = armies.terrain.position_at(Vector2(at.x, at.z)) + Vector3.UP * 0.06
	ring.scale = Vector3(radius, 1.0, radius)
	return used + 1

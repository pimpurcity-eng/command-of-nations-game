class_name RangeRings
extends Node3D
## Owner 2026-10-15: "I want to see a range ring around everything that has a range."
## Thin rings on the ground: air defence, artillery, rocket and missile launchers and warships.
## Your armies' rings are blue, visible enemies' red, the selected army's gold. They show when the
## map is zoomed in far enough to read (the selected army's ring at any zoom). Aircraft keep
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
	match unit.visual_kind:
		"air_defense": return EquipmentIdentity.air_defense_range(unit)
		"artillery": return 2.4
		"missile_launcher": return float(spec.get("strike_range", 8.0))
		"naval": return float(spec.get("sea_range", 2.8))
	return 0.0

func update(armies: UnitSystem, view_distance: float) -> void:
	var used: = 0
	var chosen_ids: Dictionary = {}
	for leader in armies.command_groups(): chosen_ids[leader.stack_id] = true
	var leaders: Dictionary = {}
	for group in armies.stacks.groups(): leaders[armies.stacks.leader(group).id] = group
	for unit in armies.units:
		if not leaders.has(unit.id) or unit.health <= 0 or armies.air.is_air(unit): continue
		var chosen: bool = chosen_ids.has(unit.stack_id)
		if view_distance > SHOW_BELOW_DISTANCE and not chosen: continue
		if not armies.visible_to_player(unit): continue
		var radius: = 0.0
		for member in leaders[unit.id]: radius = maxf(radius, reach(member))
		if radius <= 0.0: continue
		if used >= _pool.size():
			var mesh: = MeshInstance3D.new()
			mesh.mesh = _ring
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
			_pool.append(mesh)
		var ring: = _pool[used]
		used += 1
		ring.visible = true
		ring.material_override = _inks["chosen" if chosen else ("own" if unit.country == GameSession.player_country else "enemy")]
		var point: = Vector2(unit.node.position.x, unit.node.position.z)
		ring.position = armies.terrain.position_at(point) + Vector3.UP * 0.06
		ring.scale = Vector3(radius, 1.0, radius)
	for i in range(used, _pool.size()): _pool[i].visible = false

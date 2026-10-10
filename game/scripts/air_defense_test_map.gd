extends "res://scripts/main.gd"
## Dedicated owner review map: all ten supplied AA models, no AI attacks or day locks.
## This only sets their initial review heading. Movement and combat still turn normally.
func _ready() -> void:
	GameSession.player_country = "ukraine"
	GameSession.weapons_test = false
	super._ready()
	mobile_start.hide()
	clock.paused = true
	match_rules.ai_enabled = false
	units.fog_enabled = false
	units.restore([])
	var centre: Vector2 = buildings.capital("ukraine").point
	rig.target = map.position_at(centre + Vector2(0, 3.5))
	rig.yaw = 0.0
	rig.pitch = 0.85
	rig.distance = 15.0
	rig._snap(1.0)
	# Projected cab direction is down-left, 30 degrees left of six o'clock.
	var direction: Vector3 = Vector3(-0.5, 0.0, 0.8660254 / sin(rig.rendered_pitch))
	var heading: float = atan2(-direction.x, -direction.z)
	var variants: Array = [["skyguard_", 1], ["skyguard_", 3], ["patriot_", 1], ["patriot_", 3], ["patriot_", 5]]
	for row in 2:
		var country: String = "russia" if row == 0 else "ukraine"
		for column in variants.size():
			var family: String = variants[column][0] + country
			var level: int = variants[column][1]
			var point: Vector2 = centre + Vector2(-1.4 + row * 2.8, 0.8 + column * 1.4)
			units._spawn({"id": "aa_review_" + str(row) + "_" + str(column), "name": EquipmentIdentity.research_title(family, level), "country": country, "equipment_id": family, "visual_kind": "air_defense", "level": level}, point, Color.WHITE)
			var unit: Dictionary = units.units[-1]
			unit.node.position = map.position_at(point)
			unit.target = point
			unit.heading = heading
			unit.node.get_child(0).rotation.y = heading
	# In this isolated review map, selecting either column gives control of that side.
	units.unit_selected.connect(func(unit: Dictionary):
		if GameSession.player_country != unit.country:
			GameSession.player_country = unit.country
			apply_player_country(false)
			hud.show_unit(unit))
	units.select_unit(9)
	refresh_hud()
	hud.show_status("AIR DEFENSE TEST · Ten original models · Tap a unit for its range · Tap the map to move")

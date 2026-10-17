class_name FogOfWar
extends Node

const SIZE: = 128
const BOUNDS: = Rect2(-24, -27, 50, 48)
var armies: UnitSystem
var terrain: StrategicMap
var mask: ImageTexture
var elapsed: = 0.0
var signature: = ""
var sight_outline: MeshInstance3D
var sight_signature: = ""
func bounds() -> Rect2: return BOUNDS if MapDefinition.is_regional() else MapDefinition.bounds()
func setup(units: UnitSystem, map: StrategicMap) -> void :
	armies = units
	terrain = map
	refresh(true)
func _process(delta: float) -> void :
	elapsed += delta
	if elapsed < 0.5: return
	elapsed = 0
	refresh()
func refresh(force: bool = false) -> void :
	_update_sight_outline()
	if not armies.fog_enabled:
		for sector in terrain.territories: terrain.materials[sector.id].set_shader_parameter("fog_enabled",false)
		signature = "disabled"
		return
	var next: = str(armies.fog_enabled)
	var scouts: Array = []
	for unit in armies.units:
		if unit.country != GameSession.player_country or unit.health <= 0: continue
		var point: = Vector2(unit.node.position.x, unit.node.position.z)
		scouts.append([point, armies.vision_radius(unit)])
		next += str(point.snapped(Vector2.ONE * 0.1)) + str(armies.vision_radius(unit))
	if force or next != signature:
		signature = next
		var image: = Image.create(SIZE, SIZE, false, Image.FORMAT_R8)
		image.fill(Color.BLACK)
		for scout in scouts:
			var center: Vector2 = scout[0]
			var radius: float = scout[1]
			var low: Vector2 = (center-Vector2.ONE*radius-bounds().position)/bounds().size*SIZE
			var high: Vector2 = (center+Vector2.ONE*radius-bounds().position)/bounds().size*SIZE
			for y in range(maxi(0,floori(low.y)),mini(SIZE,ceili(high.y))):
				for x in range(maxi(0,floori(low.x)),mini(SIZE,ceili(high.x))):
					var point: = bounds().position + Vector2((x+0.5)/SIZE,(y+0.5)/SIZE)*bounds().size
					var sight: = clampf((radius-point.distance_to(center))/0.8,0,1)
					if sight > image.get_pixel(x,y).r: image.set_pixel(x,y,Color(sight,0,0))
		if mask == null: mask = ImageTexture.create_from_image(image)
		else: mask.update(image)
	for sector in terrain.territories:
		var material: ShaderMaterial = terrain.materials[sector.id]
		material.set_shader_parameter("visibility_mask", mask)
		material.set_shader_parameter("fog_enabled", armies.fog_enabled and sector.playable and sector.controller != GameSession.player_country)

func _update_sight_outline() -> void :
	if armies.selected < 0 or not armies.fog_enabled:
		if sight_outline != null: sight_outline.hide()
		return
	var scout: Dictionary = armies.units[armies.selected]
	if scout.country != GameSession.player_country or scout.health <= 0:
		if sight_outline != null: sight_outline.hide()
		return
	var point: = Vector2(scout.node.position.x, scout.node.position.z)
	var radius: = armies.vision_radius(scout)
	var next: String = scout.id + str(point.snapped(Vector2.ONE * 0.05)) + str(radius)
	if next != sight_signature:
		sight_signature = next
		if sight_outline != null: sight_outline.queue_free()
		var ring: = PackedVector2Array()
		for i in 96: ring.append(point + Vector2.from_angle(TAU * i / 96.0) * radius)
		sight_outline = MapBorder.build([ring], terrain, 0.9, Color(0.65, 0.84, 0.87, 0.55))
		sight_outline.name = "SelectedUnitSight"
		terrain.add_child(sight_outline)
	sight_outline.show()

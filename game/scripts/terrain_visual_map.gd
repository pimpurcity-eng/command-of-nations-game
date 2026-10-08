class_name TerrainVisualMap
extends RefCounted


const ORIGIN: = Vector2(-24, -27)
const EXTENT: = Vector2(50, 48)
const RESOLUTION: = 256
const KINDS: = ["plains", "forest", "hills", "mountains", "urban", "wetlands"]
static var image: Image
static var texture: ImageTexture
static func get_texture() -> ImageTexture:
	if texture != null: return texture
	image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_R8)
	for y in RESOLUTION:
		for x in RESOLUTION:
			var point: = ORIGIN + Vector2(x + 0.5, y + 0.5) / float(RESOLUTION) * EXTENT
			var index: = KINDS.find(TerrainProfile.sample(point))
			image.set_pixel(x, y, Color(maxi(index, 0) / 255.0, 0, 0))
	texture = ImageTexture.create_from_image(image)
	return texture
static func kind_at(point: Vector2) -> String:
	get_texture()
	var uv: = (point - ORIGIN) / EXTENT
	var x: = clampi(int(uv.x * RESOLUTION), 0, RESOLUTION - 1)
	var y: = clampi(int(uv.y * RESOLUTION), 0, RESOLUTION - 1)
	return KINDS[clampi(roundi(image.get_pixel(x, y).r * 255), 0, KINDS.size() - 1)]

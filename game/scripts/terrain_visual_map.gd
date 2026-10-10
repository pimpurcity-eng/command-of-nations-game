class_name TerrainVisualMap
extends RefCounted


const ORIGIN: = Vector2(-24, -27)
const EXTENT: = Vector2(50, 48)
const RESOLUTION: = 256
const KINDS: = ["plains", "forest", "hills", "mountains", "urban", "wetlands", "desert"]
static var image: Image
static var texture: ImageTexture
static var weights: ImageTexture
static func get_texture() -> ImageTexture:
	if texture != null: return texture
	image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_R8)
	for y in RESOLUTION:
		for x in RESOLUTION:
			var point: = ORIGIN + Vector2(x + 0.5, y + 0.5) / float(RESOLUTION) * EXTENT
			var index: = KINDS.find(TerrainProfile.sample(point, false))
			image.set_pixel(x, y, Color(maxi(index, 0) / 255.0, 0, 0))
	texture = ImageTexture.create_from_image(image)
	return texture
## Blend weights for the terrain shader: R forest, G hills, B mountains, A desert.
## Sampled with linear filtering and blurred, so terrain changes are soft natural edges
## instead of the 256x256 pixel squares the old nearest-filtered index map produced.
static func get_weights() -> ImageTexture:
	if weights != null: return weights
	get_texture()
	var one_hot: = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	for y in RESOLUTION:
		for x in RESOLUTION:
			var kind: String = KINDS[roundi(image.get_pixel(x, y).r * 255)]
			one_hot.set_pixel(x, y, Color(1.0 if kind in ["forest", "wetlands"] else 0.0, 1.0 if kind == "hills" else 0.0, 1.0 if kind == "mountains" else 0.0, 1.0 if kind == "desert" else 0.0))
	# Native down/up-scaling acts as a cheap blur (fast enough for phones).
	one_hot.resize(RESOLUTION / 4, RESOLUTION / 4, Image.INTERPOLATE_BILINEAR)
	one_hot.resize(RESOLUTION, RESOLUTION, Image.INTERPOLATE_CUBIC)
	weights = ImageTexture.create_from_image(one_hot)
	return weights
static func kind_at(point: Vector2) -> String:
	get_texture()
	var uv: = (point - ORIGIN) / EXTENT
	var x: = clampi(int(uv.x * RESOLUTION), 0, RESOLUTION - 1)
	var y: = clampi(int(uv.y * RESOLUTION), 0, RESOLUTION - 1)
	return KINDS[clampi(roundi(image.get_pixel(x, y).r * 255), 0, KINDS.size() - 1)]

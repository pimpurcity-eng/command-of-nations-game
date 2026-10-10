class_name CountryMapLabel
extends Node3D


var glyphs: Array[Label3D] = []

func setup(country_name: String, points: PackedVector2Array, terrain: StrategicMap) -> void :
	name = country_name.capitalize() + "MapLabel"
	var curve: = Curve3D.new()
	for point in points:
		curve.add_point(Vector3(point.x, 0, point.y))
	var path_length: = curve.get_baked_length()
	if path_length <= 0 or country_name.is_empty(): return
	var font: Font = ThemeDB.fallback_font
	var font_size: = 64
	var widths: = PackedFloat32Array()
	var total_width: = 0.0
	for i in country_name.length():
		var width: = font.get_char_size(country_name.unicode_at(i), font_size).x
		widths.append(width)
		total_width += width
	var pixel_size: = path_length / maxf(total_width, 1.0) * 0.84
	var offset: = path_length * 0.08
	for i in country_name.length():
		var advance: = widths[i] * pixel_size
		var glyph_offset: = clampf(offset + advance * 0.5, 0, path_length)
		var pos: = curve.sample_baked(glyph_offset)
		pos.y = terrain.elevation(Vector2(pos.x, pos.z)) + 0.12
		var tangent: = curve.sample_baked(minf(glyph_offset + 0.01, path_length)) - curve.sample_baked(maxf(glyph_offset - 0.01, 0))
		if tangent.length_squared() < 1e-12: tangent = Vector3.RIGHT
		var local_x: = tangent.normalized()
		var local_z: = Vector3.UP
		var local_y: = local_z.cross(local_x).normalized()
		var glyph: = Label3D.new()
		glyph.text = country_name[i]
		glyph.font = font
		glyph.font_size = font_size
		glyph.outline_size = 5
		glyph.outline_modulate = Color("343b32")
		glyph.modulate = Color("eee8d3")
		glyph.pixel_size = pixel_size
		glyph.shaded = false
		glyph.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		glyph.alpha_cut = Label3D.ALPHA_CUT_OPAQUE_PREPASS
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		glyph.transform = Transform3D(Basis(local_x, local_y, local_z), pos)
		add_child(glyph)
		glyphs.append(glyph)
		offset += advance

func update_zoom(distance: float) -> void :
	visible = distance >= 38.0

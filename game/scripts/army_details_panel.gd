class_name ArmyDetailsPanel
extends CanvasLayer
var panel: PanelContainer
var content: VBoxContainer
func setup(theme: Theme) -> void :
	layer = 13
	var root: = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = theme
	add_child(root)
	var dim: = ColorRect.new()
	dim.color = Color(0.01, 0.025, 0.04, 0.85)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	root.add_child(panel)
	var column: = VBoxContainer.new()
	panel.add_child(column)
	var close: = Button.new()
	close.text = "ARMY DETAILS · Close"
	close.custom_minimum_size.y = 48
	close.pressed.connect(hide)
	column.add_child(close)
	var scroll: = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	get_viewport().size_changed.connect(_layout)
	hide()
func _layout() -> void :
	var size: = get_viewport().get_visible_rect().size
	panel.position = Vector2(maxf(12, (size.x - 600) * 0.5), 12)
	panel.size = Vector2(minf(600, size.x - 24), size.y - 24)
func section(title: String, text: String) -> void :
	var toggle: = Button.new()
	toggle.text = title + " · −"
	toggle.custom_minimum_size.y = 48
	content.add_child(toggle)
	var body: = Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(body)
	toggle.pressed.connect( func(): body.visible = not body.visible;toggle.text = title + (" · −" if body.visible else " · +"))
func open(armies: UnitSystem, terrain: StrategicMap) -> void :
	for child in content.get_children(): content.remove_child(child);child.queue_free()
	var unit: Dictionary = armies.units[armies.selected]
	var group: = armies.stacks.members(unit)
	var portrait: = TextureRect.new()
	portrait.custom_minimum_size.y = 130
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = UnitVisual.preview_texture(unit.equipment_id)
	content.add_child(portrait)
	var hp: = 0.0
	var classes: Dictionary = {}
	var text: = ""
	for member in group:
		hp += member.health
		classes[member.visual_kind] = classes.get(member.visual_kind, 0) + 1
		text += EquipmentIdentity.title(member.equipment_id) + " · L" + str(member.get("level", 1)) + " · " + str(int(member.health)) + "/100 HP\n"
	section("ARMY STATUS", unit.country.capitalize() + " · " + armies.stacks.summary(unit) + "\nHealth " + str(int(hp)) + " / " + str(group.size() * 100) + "\n" + ("Battle in progress" if unit.engaged else ("Moving" if unit.moving else "Ready for orders")))
	section("UNITS", text)
	if not armies.air.is_air(unit): section("FIRE CONTROL", FireControlPanel.MODES.get(unit.get("fire_mode", "at_will"), FireControlPanel.MODES.at_will).title + " · " + ("Movement deferred while firing" if unit.get("firing_halt", false) else "Current orders active"))
	var cards_scroll: = ScrollContainer.new()
	cards_scroll.custom_minimum_size.y = 180
	cards_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(cards_scroll)
	var cards: = HBoxContainer.new()
	cards_scroll.add_child(cards)
	var families: Dictionary = {}
	for member in group:
		var key: String = member.equipment_id + ":" + str(member.get("level", 1))
		if not families.has(key): families[key] = {"unit": member, "count": 0, "health": 0.0}
		families[key].count += 1
		families[key].health += member.health
	for family in families.values():
		var frame: = PanelContainer.new()
		frame.custom_minimum_size.x = 150
		cards.add_child(frame)
		var card: = VBoxContainer.new()
		frame.add_child(card)
		var picture: = TextureRect.new()
		picture.custom_minimum_size = Vector2(130, 70)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.texture = UnitVisual.preview_texture(family.unit.equipment_id)
		card.add_child(picture)
		var label: = Label.new()
		label.text = EquipmentIdentity.title(family.unit.equipment_id) + "\n" + str(family.count) + " units · L" + str(family.unit.get("level", 1)) + "\n" + str(int(family.health)) + " / " + str(family.count * 100) + " HP"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
		var health: = ProgressBar.new()
		health.custom_minimum_size.y = 8
		health.show_percentage = false
		health.value = family.health / family.count
		card.add_child(health)
	var biome: = terrain.terrain_at(Vector2(unit.node.position.x, unit.node.position.z))
	text = "Terrain: " + biome.capitalize() + "\nGround stacks move at the speed of their slowest member.\n"
	for member in group:
		if armies.air.is_air(member) or armies.is_naval(member): continue
		text += EquipmentIdentity.title(member.equipment_id) + ": speed " + str(roundi(TerrainRules.multiplier(member.visual_kind, biome, "speed") * 100)) + "%, attack " + str(roundi(TerrainRules.multiplier(member.visual_kind, biome, "attack") * 100)) + "%, defensive fire " + str(roundi(TerrainRules.multiplier(member.visual_kind, biome, "defense") * 100)) + "%\n"
	section("TERRAIN INFLUENCES", text)
	text = ""
	for kind in classes: text += str(kind).capitalize() + ": " + str(classes[kind]) + "\n"
	section("CLASS DISTRIBUTION", text)
	if not armies.air.is_air(unit):
		var combat: = CombatSystem.new()
		text = "Attack / defensive fire per combat round, at current health and terrain. Actual attacks also require range and an eligible firing state.\n"
		for target in ["armor", "ifv", "artillery", "air_defense", "missile_launcher", "naval"]:
			text += target.capitalize() + ": " + str(snappedf(combat.potential(group, target), 0.1)) + " / " + str(snappedf(combat.potential(group, target, false, true), 0.1)) + "\n"
		section("COMBAT STATISTICS", text)
	_layout()
	show()

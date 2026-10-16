extends UnitSystem
## Rendering view of the real armies. CitySystem only needs visible garrisons and sight,
## so a continent's hidden armies do not repeat the same fog test for every town.
var source: UnitSystem
var _sight: Dictionary = {}
func sync(real_armies: UnitSystem) -> void:
	source=real_armies
	navigation=source.navigation;sea_navigation=source.sea_navigation
	terrain=source.terrain;diplomacy=source.diplomacy
	units=source.units.filter(func(unit):return source.visible_to_player(unit))
	terrain_revision=source.terrain_revision
	_sight.clear()
func visible_to_player(_unit: Dictionary) -> bool: return true
func point_visible(point: Vector2,country: String = "") -> bool:
	var key: = str(point)+":"+country
	if not _sight.has(key): _sight[key]=source.point_visible(point,country)
	return _sight[key]
func _process(_delta: float) -> void: pass

class_name UnitMapSize
extends RefCounted

## Strategic map dimensions before UnitSystem's 0.65 scale. These are readable
## symbols, not metres at the geographical map scale. Preserve model proportions.
const FOOTPRINT := {
	"helicopter": 0.95, "bomber": 1.35, "armor": 0.8, "ifv": 0.74,
	"artillery": 0.77, "air_defense": 0.77, "missile_launcher": 0.83,
	"silo": 0.88, "fighter": 0.89, "drone": 0.65, "naval": 1.3,
	"submarine": 1.1, "carrier": 2.3, "support": 0.77, "transport": 1.35,
	"radar_aircraft": 1.35, "infantry": 0.25,
	"supply": 0.77, "medic": 0.77, "engineer": 0.77,
	"bridge": 0.83, "recovery": 0.77,
}
const HEIGHT := {
	"helicopter": 0.35, "bomber": 0.4, "armor": 0.32, "ifv": 0.32,
	"artillery": 0.38, "air_defense": 0.55, "missile_launcher": 0.48,
	"silo": 0.7, "fighter": 0.3, "drone": 0.25, "naval": 0.4,
	"submarine": 0.28, "carrier": 0.45, "support": 0.38,
	"transport": 0.45, "radar_aircraft": 0.45, "infantry": 0.3,
}

static func limits(role: String, path: String = "") -> Vector2:
	# A portable mortar cannot occupy a self-propelled howitzer's footprint.
	# Use the tier's actual model, since an 81/82 mm family upgrades to 120 mm.
	var model := path.get_file().get_basename()
	if model.contains("mortar"):
		if model.contains("2b14") or model.contains("l16"):
			return Vector2(0.2, 0.22)
		return Vector2(0.34, 0.3)
	# Effects keep their existing visual scale; this change is for units only.
	if role == "projectile": return Vector2(0.62, INF)
	return Vector2(FOOTPRINT.get(role, 0.37), HEIGHT.get(role, 0.38))

static func fit_factor(size: Vector3, role: String, path: String = "") -> float:
	var envelope := limits(role, path)
	return minf(envelope.x / maxf(maxf(size.x, size.z), 0.001),
		envelope.y / maxf(size.y, 0.001))

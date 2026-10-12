class_name Doctrine
extends RefCounted
## Military doctrines (owner request 2026-10-12, Conflict of Nations style). Each country follows
## one; the player picks theirs on the start screen, AI countries get their country's default.
## - WESTERN: air power, navy and air defence +15%; fighters and bombers are stealthy; ground
##   forces -5%.
## - EUROPEAN: every army defends +10%; research is 15% faster.
## - EASTERN: tanks, artillery and missiles attack +15% and defend +5%; aircraft -5%.
const DOCTRINES: = {
	"western": {"name": "Western", "summary": "Air power, navy and air defence +15%. Stealth fighters and bombers. Ground forces -5%."},
	"european": {"name": "European", "summary": "All armies defend +10%. Research 15% faster."},
	"eastern": {"name": "Eastern", "summary": "Tanks, artillery and missiles attack +15%, defend +5%. Aircraft -5%."},
}
const DEFAULTS: = {"russia": "eastern", "ukraine": "european", "united_states": "western", "united_kingdom": "western", "france": "european", "germany": "european", "china": "eastern"}
const AIR: = ["fighter", "bomber", "drone", "helicopter"]
const HEAVY: = ["armor", "artillery", "missile_launcher"]
static var chosen: Dictionary = {}

static func of(country: String) -> String:
	return chosen.get(country, DEFAULTS.get(country, "european"))

static func choose(country: String, doctrine: String) -> void:
	if DOCTRINES.has(doctrine): chosen[country] = doctrine

## Combat strength factor for a unit attacking ("attack") or defending ("defense").
static func combat_factor(unit: Dictionary, effect: String) -> float:
	var kind: String = unit.get("visual_kind", "")
	match of(str(unit.get("country", ""))):
		"western":
			if kind in AIR or kind in ["naval", "air_defense"]: return 1.15
			return 0.95
		"eastern":
			if kind in HEAVY: return 1.15 if effect == "attack" else 1.05
			if kind in AIR: return 0.95
		"european":
			if effect == "defense": return 1.10
	return 1.0

static func research_factor(country: String) -> float:
	return 1.15 if of(country) == "european" else 1.0

## Western aircraft are stealthy (seen only by radar or up close, UnitSystem.unit_visible).
static func stealth(unit: Dictionary) -> bool:
	return of(str(unit.get("country", ""))) == "western" and unit.get("visual_kind", "") in AIR

static func snapshot() -> Dictionary:
	return chosen.duplicate()

static func restore(state: Dictionary) -> void:
	chosen = state.duplicate()

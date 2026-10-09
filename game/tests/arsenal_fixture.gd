class_name ArsenalFixture
extends RefCounted
## The live arsenal is empty while the owner's new weapons are made (2026-10-09). Tests that
## need armies run against the archived arsenal. Call before instancing scenes/main.tscn.
const ARCHIVE: = "res://data/archive/weapons_2026-10-09/"
static func use_archive() -> void:
	EquipmentIdentity.catalog = JSON.parse_string(FileAccess.get_file_as_string(ARCHIVE + "equipment.json"))
	GameSession.scenario_path = ARCHIVE + "scenario_regional.json"
	WeaponShowcase.source = ARCHIVE + "weapon_showcase.json"

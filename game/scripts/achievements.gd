class_name Achievements
extends RefCounted
## Ranks, medals and achievements (owner request 2026-10-12, Call of War style).
## - RANK comes from the commander's level (PlayerAuth.level_for(xp)).
## - ACHIEVEMENTS unlock once per player and are kept on the phone (user://achievements.cfg);
##   signed-in players also send them to their account (backend migration 003).
## - MEDALS are awarded at the end of each campaign for how it was won.
const PATH: = "user://achievements.cfg"
const RANKS: = [
	[1, "Private"], [2, "Corporal"], [3, "Sergeant"], [5, "Lieutenant"], [7, "Captain"], [9, "Major"],
	[12, "Lieutenant Colonel"], [15, "Colonel"], [19, "Brigadier"], [24, "Major General"],
	[30, "Lieutenant General"], [37, "General"], [45, "Field Marshal"],
]
const LIST: = {
	"first_blood": {"name": "First Blood", "text": "Destroy an enemy army."},
	"veteran": {"name": "Veteran", "text": "Destroy 50 enemy armies in total."},
	"conqueror": {"name": "Conqueror", "text": "Capture an enemy city."},
	"capital_fall": {"name": "Fall of the Capital", "text": "Capture the enemy capital."},
	"annexer": {"name": "New Borders", "text": "Annex 5 provinces in total."},
	"first_victory": {"name": "Victor", "text": "Win a campaign."},
	"domination": {"name": "Dominator", "text": "Win a domination victory."},
	"economic": {"name": "Tycoon", "text": "Win an economic victory."},
	"elimination": {"name": "Annihilator", "text": "Win by eliminating the enemy."},
	"points": {"name": "On Points", "text": "Win on points at the time limit."},
	"both_sides": {"name": "Both Sides of the Front", "text": "Win as Russia and as Ukraine."},
	"peacemaker": {"name": "Peacemaker", "text": "Get the enemy to accept peace."},
	"coalition": {"name": "Coalition Builder", "text": "Found a coalition."},
	"strategist": {"name": "Strategist", "text": "Complete 25 research projects in total."},
	"builder": {"name": "Builder", "text": "Finish 25 construction projects in total."},
	"nuclear": {"name": "Point of No Return", "text": "Launch a nuclear missile."},
	"shield": {"name": "Missile Shield", "text": "Shoot down an enemy strategic missile."},
}
const MEDALS: = {
	"blitz": {"name": "Blitz Medal", "text": "Win within 5 game days."},
	"iron_wall": {"name": "Iron Wall", "text": "Win without losing a city."},
	"economist": {"name": "Order of Prosperity", "text": "Win an economic victory."},
	"no_nukes": {"name": "Clean Hands", "text": "Win without weapons of mass destruction."},
}

var unlocked: Dictionary = {}   # id -> unix time
var counters: Dictionary = {}   # counter -> value
var medals: Dictionary = {}     # medal id -> count
var newly: Array = []           # unlocked since last read (for toasts)

static func rank(level: int) -> String:
	var name: String = RANKS[0][1]
	for entry in RANKS:
		if level >= entry[0]: name = entry[1]
	return name

func load_saved() -> void:
	var file: = ConfigFile.new()
	if file.load(PATH) != OK: return
	unlocked = file.get_value("progress", "unlocked", {})
	counters = file.get_value("progress", "counters", {})
	medals = file.get_value("progress", "medals", {})

func save() -> void:
	var file: = ConfigFile.new()
	file.set_value("progress", "unlocked", unlocked)
	file.set_value("progress", "counters", counters)
	file.set_value("progress", "medals", medals)
	file.save(PATH)

func unlock(id: String) -> bool:
	if not LIST.has(id) or unlocked.has(id): return false
	unlocked[id] = int(Time.get_unix_time_from_system())
	newly.append(id)
	save()
	return true

## Adds to a counter and unlocks the achievement at its threshold.
func count(counter: String, amount: int = 1) -> void:
	counters[counter] = int(counters.get(counter, 0)) + amount
	var thresholds: = {"kills": [[1, "first_blood"], [50, "veteran"]], "annexed": [[5, "annexer"]], "research": [[25, "strategist"]], "built": [[25, "builder"]]}
	for pair in thresholds.get(counter, []):
		if counters[counter] >= pair[0]: unlock(pair[1])
	save()

## Medals and achievements for a finished campaign the player won.
func campaign_won(country: String, kind: String, days: float, lost_city: bool, used_wmd: bool) -> Array:
	unlock("first_victory")
	if LIST.has(kind): unlock(kind)
	counters["won_" + country] = 1
	if counters.get("won_russia", 0) and counters.get("won_ukraine", 0): unlock("both_sides")
	var won: = []
	if days <= 5.0: won.append("blitz")
	if not lost_city: won.append("iron_wall")
	if kind == "economic": won.append("economist")
	if not used_wmd: won.append("no_nukes")
	for medal in won: medals[medal] = int(medals.get(medal, 0)) + 1
	save()
	return won

func take_new() -> Array:
	var result: = newly.duplicate()
	newly.clear()
	return result

class_name Annexation
extends RefCounted
## Occupied and annexed land (owner request 2026-10-12, Conflict of Nations style).
## A captured province is OCCUPIED: its cities and resources produce OCCUPIED_OUTPUT of normal.
## Its holder can ANNEX it (cost in funds, one game day) to raise output to ANNEXED_OUTPUT.
## Losing the province ends the annexation. Victory points still count it as foreign land.
const OCCUPIED_OUTPUT: = 0.25
const ANNEXED_OUTPUT: = 0.6
const ANNEX_TIME: = VictoryRules.DAY
const BASE_COST: = 4000.0  # economy x10 (owner 2026-10-13)
const COST_PER_POINT: = 1200.0

var annexed: Dictionary = {}   # territory id -> country that annexed it
var jobs: Dictionary = {}      # territory id -> {"country", "remaining"}

## Output factor of land held by `country` whose homeland owner is `owner`.
func output(territory_id: String, owner: String, controller: String) -> float:
	if owner == controller: return 1.0
	return ANNEXED_OUTPUT if annexed.get(territory_id, "") == controller else OCCUPIED_OUTPUT

func cost(territory: Dictionary, points: Dictionary) -> float:
	return BASE_COST + COST_PER_POINT * float(points.get(territory.id, [1])[0])

## "" when the country may annex the province now, else the reason.
func reason(territory: Dictionary, country: String, funds: float, points: Dictionary) -> String:
	if not territory.get("playable", false): return "Not a province"
	if territory.controller != country: return "You must hold the province first"
	if territory.owner == country: return "Already your homeland"
	if annexed.get(territory.id, "") == country: return "Already annexed"
	if jobs.has(territory.id): return "Annexation in progress"
	if funds < cost(territory, points): return "Needs %d funds" % roundi(cost(territory, points))
	return ""

func start(territory: Dictionary, country: String, stockpile: Dictionary, points: Dictionary) -> String:
	var why: = reason(territory, country, float(stockpile.get("funds", 0.0)), points)
	if not why.is_empty(): return why
	stockpile.funds -= cost(territory, points)
	jobs[territory.id] = {"country": country, "remaining": ANNEX_TIME}
	return ""

## Advances annexations; returns the titles finished this step. Jobs and annexations end
## when the province changes hands.
func advance(seconds: float, territories: Array) -> Array:
	var by_id: = {}
	for t in territories: by_id[t.id] = t
	var finished: = []
	for id in jobs.keys():
		var job: Dictionary = jobs[id]
		var t: Dictionary = by_id.get(id, {})
		if t.is_empty() or t.controller != job.country:
			jobs.erase(id)
			continue
		job.remaining -= seconds
		if job.remaining <= 0:
			annexed[id] = job.country
			jobs.erase(id)
			finished.append(t.title)
	for id in annexed.keys():
		if by_id.has(id) and by_id[id].controller != annexed[id]: annexed.erase(id)
	return finished

func snapshot() -> Dictionary:
	return {"annexed": annexed.duplicate(), "jobs": jobs.duplicate(true)}

func restore(state: Dictionary) -> void:
	annexed = state.get("annexed", {}).duplicate()
	jobs = state.get("jobs", {}).duplicate(true)

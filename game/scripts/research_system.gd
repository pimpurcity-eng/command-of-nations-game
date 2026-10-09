class_name ResearchSystem
extends RefCounted
signal changed
const DAYS: = [1, 1, 2, 4, 6]
const HOURS: = [0, 2, 4, 6, 8]
const SLOTS: = 2
var economy: ProductionSystem
var clock: SimulationClock
var armies: UnitSystem
var levels: Dictionary = {}
var jobs: Array = []

func setup(production: ProductionSystem, time: SimulationClock, units: UnitSystem) -> void :
	economy = production
	clock = time
	armies = units
	for spec in economy.catalog: levels[spec.id] = 1

func day() -> int:
	return 1 + int(clock.elapsed * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 86400.0)
func unlock_day(id: String, target: int) -> int:
	var days: Array = economy.equipment(id).get("research_days", DAYS)
	return int(days[clampi(target - 1, 0, days.size() - 1)])
func level(id: String) -> int:
	return int(levels.get(id, 1))
func duration(target: int) -> float:
	return HOURS[target - 1] * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func cost(id: String, target: int) -> Dictionary:
	var result: Dictionary = {}
	var spec: = economy.equipment(id)
	if spec.is_empty(): return result
	for resource in ProductionSystem.RESOURCES:
		result[resource] = ceili(spec.cost[resource] * (0.5 + 0.3 * (target - 2)))
	return result
func active(id: String) -> Dictionary:
	for job in jobs:
		if job.equipment == id: return job
	return {}
## Owner review 2026-10-09: research is national and separate from the cities. It no
## longer depends on a capital research-center building and is opened from the Research tab.
func rate(_country: String) -> float:
	return 1.0
func capital_status(_country: String = "") -> String:
	return "National research · " + str(SLOTS) + " research slots"
func reason(id: String, target: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return "Choose your country's equipment"
	if rate(country) <= 0: return capital_status(country)
	if target < 2 or target > 5: return "Level 1 is available from the start"
	if target <= level(id): return "Already researched"
	if target != level(id) + 1: return "Research the previous level first"
	if day() < unlock_day(id, target): return "Available on Day " + str(unlock_day(id, target))
	if not active(id).is_empty(): return "This family is already being researched"
	var count: = 0
	for job in jobs:
		if economy.equipment(job.equipment).country == country: count += 1
	if count >= SLOTS: return "Both research slots are occupied"
	for resource in ProductionSystem.RESOURCES:
		if economy.stockpiles[country][resource] < cost(id, target)[resource]: return "Insufficient " + resource
	return ""
func start(id: String, target: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var error: = reason(id, target, country)
	if not error.is_empty(): return error
	for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] -= cost(id, target)[resource]
	jobs.append({"equipment": id, "level": target, "progress": 0.0})
	economy.changed.emit()
	changed.emit()
	return ""
func cancel(id: String, country: String = "") -> void :
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return
	for i in jobs.size():
		if jobs[i].equipment != id: continue
		var remaining: float = 1.0 - jobs[i].progress / duration(jobs[i].level)
		for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] += floor(cost(id, jobs[i].level)[resource] * remaining)
		jobs.remove_at(i)
		economy.changed.emit()
		changed.emit()
		return
func advance(seconds: float) -> void :
	if seconds <= 0: return
	var completed: = false
	for i in range(jobs.size() - 1, -1, -1):
		var country: String = economy.equipment(jobs[i].equipment).country
		jobs[i].progress += seconds * rate(country)
		if jobs[i].progress >= duration(jobs[i].level):
			levels[jobs[i].equipment] = jobs[i].level
			jobs.remove_at(i)
			completed = true

	for spec in economy.catalog:
		if spec.country == GameSession.opponent_country() and level(spec.id) < 5 and reason(spec.id, level(spec.id) + 1, GameSession.opponent_country()).is_empty():
			start(spec.id, level(spec.id) + 1, GameSession.opponent_country())
	if completed: changed.emit()
func upgrade(unit: Dictionary) -> String:
	if unit.country != GameSession.player_country: return "Select your army"
	var group: = armies.stacks.members(unit)
	var bill: Dictionary = {}
	for resource in ProductionSystem.RESOURCES: bill[resource] = 0.0
	var duration_seconds: = 0.0
	var eligible: Array = []
	for member in group:
		if member.moving or member.engaged or member.get("upgrade_remaining", 0.0) > 0 or member.get("refuel_remaining", 0.0) > 0: return "Stop this army and leave combat before upgrading"
		if member.get("level", 1) >= level(member.equipment_id): continue
		eligible.append(member)
		var spec: = economy.equipment(member.equipment_id)
		for resource in ProductionSystem.RESOURCES: bill[resource] += ceil(spec.cost[resource] * 0.5)
		duration_seconds = maxf(duration_seconds, spec.seconds * 0.5)
	if eligible.is_empty(): return "This army already has the highest researched levels"
	for resource in ProductionSystem.RESOURCES:
		if economy.stockpiles.russia[resource] < bill[resource]: return "Insufficient " + resource
	for resource in ProductionSystem.RESOURCES: economy.stockpiles.russia[resource] -= bill[resource]
	for member in eligible:
		member.upgrade_remaining = duration_seconds
		member.upgrade_target = level(member.equipment_id)
	economy.changed.emit()
	return "Modernization started; this army remains stationary until complete"
func snapshot() -> Dictionary:
	return {"levels": levels.duplicate(), "jobs": jobs.duplicate(true)}
func validate(state: Variant) -> bool:
	if not state is Dictionary or not state.get("levels") is Dictionary or not state.get("jobs") is Array or state.jobs.size() > 4: return false
	for id in state.levels:
		var value = state.levels[id]
		if economy.equipment(str(id)).is_empty() or not (value is int or value is float) or not is_finite(float(value)) or value != floor(value) or value < 1 or value > 5: return false
	var seen: Dictionary = {}
	var counts: Dictionary = {}
	for job in state.jobs:
		if not job is Dictionary or not job.get("equipment") is String: return false
		var spec: = economy.equipment(job.equipment)
		if spec.is_empty() or seen.has(job.equipment): return false
		seen[job.equipment] = true
		counts[spec.country] = counts.get(spec.country, 0) + 1
		if counts[spec.country] > SLOTS: return false
		var target = job.get("level")
		if not (target is int or target is float) or target < 2 or target > 5 or target != int(state.levels.get(job.equipment, 1)) + 1: return false
		var progress = job.get("progress")
		if not (progress is int or progress is float) or not is_finite(float(progress)) or progress < 0 or progress >= duration(int(target)): return false
	return true
func restore(state: Dictionary) -> void :
	for id in levels: levels[id] = int(state.get("levels", {}).get(id, 1))
	jobs = state.get("jobs", []).duplicate(true)
	changed.emit()

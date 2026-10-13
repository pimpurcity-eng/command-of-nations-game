class_name ResearchSystem
extends RefCounted
signal changed
signal completed(equipment_id: String, country: String)
const DAYS: = [1, 1, 2, 4, 6]
const HOURS: = [1, 2, 4, 6, 8]  # level 1 must now be researched too (owner 2026-10-13)
const SLOTS: = 2
var economy: ProductionSystem
var clock: SimulationClock
var armies: UnitSystem
var levels: Dictionary = {}
var jobs: Array = []
var refinements: Dictionary = {}

func setup(production: ProductionSystem, time: SimulationClock, units: UnitSystem) -> void :
	economy = production
	clock = time
	armies = units
	refinements.clear()
	EquipmentIdentity.refinements = refinements
	for spec in economy.catalog + EconomyResearch.catalog(): levels[spec.id] = initial_level(spec)
	EconomyResearch.levels = levels

## Owner 2026-10-13: "beginning of game no research is done". Only the weak starter units
## (spec "starter") are known at the start; everything else, level 1 included, is researched.
## Economy upgrades are city buildings now and stay at their neutral level 1.
static func initial_level(spec: Dictionary) -> int:
	# Catalogues from before this rule (archived test arsenals, older data) have no "starter"
	# flags: everything in them stays known, as before.
	if not spec.has("starter"): return 1
	return 1 if spec.starter else 0

func day() -> int:
	return 1 + int(clock.elapsed * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 86400.0)
func unlock_day(id: String, target: int) -> int:
	var days: Array = economy.equipment(id).get("research_days", DAYS)
	return int(days[clampi(target - 1, 0, days.size() - 1)])
func level(id: String) -> int:
	return int(levels.get(id, initial_level(economy.equipment(id)) if economy != null else 1))
func duration(target: int) -> float:
	return HOURS[target - 1] * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func cost(id: String, target: int) -> Dictionary:
	var result: Dictionary = {}
	var spec: = economy.equipment(id)
	if spec.is_empty(): return result
	for resource in ProductionSystem.RESOURCES:
		result[resource] = ceili(spec.cost[resource] * maxf(0.3, 0.5 + 0.3 * (target - 2)))
	return result
func active(id: String) -> Dictionary:
	for job in jobs:
		if job.equipment == id: return job
	return {}
## Owner review 2026-10-09: research is national and separate from the cities. It no
## longer depends on a capital research-center building and is opened from the Research tab.
func rate(country: String) -> float:
	return Doctrine.research_factor(country)
func capital_status(_country: String = "") -> String:
	return "National research · " + str(SLOTS) + " research slots"
func reason(id: String, target: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return "Choose your country's equipment"
	if rate(country) <= 0: return capital_status(country)
	if spec.get("retired", false): return "No longer in service"
	if target < 1 or target > 5: return "Choose a level from 1 to 5"
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
	if MatchClient.active != null: return MatchClient.active.send("research", {"id": id, "target": target})
	if country.is_empty(): country = GameSession.player_country
	var error: = reason(id, target, country)
	if not error.is_empty(): return error
	for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] -= cost(id, target)[resource]
	jobs.append({"equipment": id, "level": target, "progress": 0.0})
	economy.changed.emit()
	changed.emit()
	return ""
func refined(id: String, tier: int) -> bool:
	return refinements.get(id,{}).get(str(tier),false)
func upgrade_day(id: String, tier: int) -> int:
	return ceili((unlock_day(id,tier)+unlock_day(id,mini(5,tier+1)))/2.0)
func upgrade_duration(tier: int) -> float:
	return tier * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func upgrade_cost(id: String, tier: int) -> Dictionary:
	var result: Dictionary = {}
	for resource in ProductionSystem.RESOURCES: result[resource] = ceili(economy.equipment(id).cost[resource] * (0.2+0.1*(tier-1)))
	return result
func upgrade_reason(id: String, tier: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return "Choose your country's equipment"
	if tier < 1 or tier > 4: return "Choose an intermediate upgrade"
	if level(id) < tier: return "Research this model first"
	if refined(id,tier): return "Already upgraded"
	if day() < upgrade_day(id,tier): return "Available on Day "+str(upgrade_day(id,tier))
	if not active(id).is_empty(): return "This family is already being researched"
	if jobs.filter(func(j):return economy.equipment(j.equipment).country == country).size() >= SLOTS: return "Both research slots are occupied"
	var bill: = upgrade_cost(id,tier)
	for resource in bill:
		if economy.stockpiles[country][resource] < bill[resource]: return "Insufficient "+resource
	return ""
func start_upgrade(id: String, tier: int, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	var error: = upgrade_reason(id,tier,country)
	if not error.is_empty(): return error
	var bill: = upgrade_cost(id,tier)
	for resource in bill: economy.stockpiles[country][resource] -= bill[resource]
	jobs.append({"equipment":id,"level":tier,"refinement":true,"progress":0.0})
	economy.changed.emit();changed.emit()
	return ""
func job_duration(job: Dictionary) -> float:
	return upgrade_duration(int(job.level)) if job.get("refinement",false) else duration(int(job.level))
func job_cost(job: Dictionary) -> Dictionary:
	return upgrade_cost(job.equipment,int(job.level)) if job.get("refinement",false) else cost(job.equipment,int(job.level))
func cancel(id: String, country: String = "") -> void :
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return
	for i in jobs.size():
		if jobs[i].equipment != id: continue
		var remaining: float = 1.0 - jobs[i].progress / job_duration(jobs[i])
		for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] += floor(job_cost(jobs[i])[resource] * remaining)
		jobs.remove_at(i)
		economy.changed.emit()
		changed.emit()
		return
func advance(seconds: float) -> void :
	if seconds <= 0: return
	var finished_any: = false
	for i in range(jobs.size() - 1, -1, -1):
		var country: String = economy.equipment(jobs[i].equipment).country
		jobs[i].progress += seconds * rate(country)
		if jobs[i].progress >= job_duration(jobs[i]):
			if jobs[i].get("refinement",false):
				if not refinements.has(jobs[i].equipment): refinements[jobs[i].equipment] = {}
				refinements[jobs[i].equipment][str(int(jobs[i].level))] = true
			else: levels[jobs[i].equipment] = jobs[i].level
			completed.emit(jobs[i].equipment, country)
			jobs.remove_at(i)
			finished_any = true

	for spec in economy.catalog:  # economy upgrades are buildings now; retired families are skipped
		if spec.get("retired", false): continue
		if spec.country == GameSession.opponent_country() and level(spec.id) < 5 and reason(spec.id, level(spec.id) + 1, GameSession.opponent_country()).is_empty():
			start(spec.id, level(spec.id) + 1, GameSession.opponent_country())
	if finished_any: changed.emit()
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
		if economy.stockpiles[GameSession.player_country][resource] < bill[resource]: return "Insufficient " + resource
	for resource in ProductionSystem.RESOURCES: economy.stockpiles[GameSession.player_country][resource] -= bill[resource]
	for member in eligible:
		member.upgrade_remaining = duration_seconds
		member.upgrade_target = level(member.equipment_id)
	economy.changed.emit()
	return "Modernization started; this army remains stationary until complete"
func snapshot() -> Dictionary:
	return {"levels": levels.duplicate(), "jobs": jobs.duplicate(true), "refinements":refinements.duplicate(true)}
func validate(state: Variant) -> bool:
	if not state is Dictionary or not state.get("levels") is Dictionary or not state.get("jobs") is Array or state.jobs.size() > 4: return false
	for id in state.levels:
		var value = state.levels[id]
		if economy.equipment(str(id)).is_empty() or not (value is int or value is float) or not is_finite(float(value)) or value != floor(value) or value < 0 or value > 5: return false
	var saved_refinements = state.get("refinements",{})
	if not saved_refinements is Dictionary: return false
	for id in saved_refinements:
		if economy.equipment(str(id)).is_empty() or not saved_refinements[id] is Dictionary: return false
		for key in saved_refinements[id]:
			if str(key) not in ["1","2","3","4"] or saved_refinements[id][key] != true or int(key)>int(state.levels.get(id,1)): return false
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
		if not (target is int or target is float) or not is_finite(float(target)) or target != floor(target): return false
		if job.has("refinement") and not job.refinement is bool: return false
		if job.get("refinement",false):
			if target < 1 or target > 4 or target > int(state.levels.get(job.equipment,1)) or saved_refinements.get(job.equipment,{}).get(str(int(target)),false): return false
		elif target < 1 or target > 5 or target != int(state.levels.get(job.equipment, initial_level(spec)))+1: return false
		var progress = job.get("progress")
		if not (progress is int or progress is float) or not is_finite(float(progress)) or progress < 0 or progress >= job_duration(job): return false
	return true
func restore(state: Dictionary) -> void :
	refinements = state.get("refinements",{}).duplicate(true)
	EquipmentIdentity.refinements = refinements
	# Families added after a save was made start at their normal opening level.
	for id in levels: levels[id] = int(state.get("levels", {}).get(id, initial_level(economy.equipment(id))))
	jobs = state.get("jobs", []).duplicate(true)
	changed.emit()

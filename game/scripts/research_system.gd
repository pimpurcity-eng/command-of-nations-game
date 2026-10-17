class_name ResearchSystem
extends RefCounted
signal changed
signal completed(equipment_id: String, country: String)
const DAYS: = [1, 1, 2, 4, 6]
## Owner 2026-10-16: "Level one units to research about 30 minutes at one time, up to 2 hours
## depending on what it is." Level 1 takes 30 min (basic families, complexity 0.75) up to 2 h
## (complexity 2.0: strategic missiles, carriers) at 1x; each later level is a multiple of that.
const LEVEL_ONE_MIN_HOURS: = 0.5
const LEVEL_ONE_MAX_HOURS: = 2.0
const HOURS: = [1.0, 2.0, 4.0, 6.0, 9.0]  # multiples of the family's level-1 time
const REFINEMENT_HOURS: = [1.0, 1.5, 2.5, 4.0]  # multiples of the family's level-1 time
const COST_FACTORS: = [0.4, 0.65, 0.95, 1.3, 1.7]
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
	# Owner 2026-10-15: "Nothing's supposed to be researched. There's light tanks on the map,
	# but it doesn't mean it's researched." The starting armies are on the map; every level,
	# starter units included, is researched first.
	return 0

func day() -> int:
	return 1 + int(clock.elapsed * SimulationClock.REAL_SECONDS_PER_SIM_SECOND / 86400.0)
func unlock_day(id: String, target: int) -> int:
	var days: Array = economy.equipment(id).get("research_days", DAYS)
	return int(days[clampi(target - 1, 0, days.size() - 1)])
func level(id: String) -> int:
	return int(levels.get(id, initial_level(economy.equipment(id)) if economy != null else 1))
## Real hours at 1x for level 1 of a family of this complexity (research_factor 0.75 .. 2.0).
static func level_one_hours(complexity: float) -> float:
	return clampf(LEVEL_ONE_MIN_HOURS + (complexity - 0.75) * 1.2, LEVEL_ONE_MIN_HOURS, LEVEL_ONE_MAX_HOURS)
func _complexity(id: String) -> float:
	return float(economy.equipment(id).get("research_factor", 1.0)) if economy != null and not id.is_empty() else 1.0
func duration(target: int, id: String = "") -> float:
	return HOURS[clampi(target - 1, 0, 4)] * level_one_hours(_complexity(id)) * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func cost(id: String, target: int) -> Dictionary:
	var result: Dictionary = {}
	var spec: = economy.equipment(id)
	if spec.is_empty(): return result
	for resource in ProductionSystem.RESOURCES:
		result[resource] = ceili(float(spec.cost.get(resource, 0.0)) * COST_FACTORS[clampi(target - 1, 0, 4)])
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
func reason(id: String, target: int, country: String = "", check_resources: bool = true) -> String:
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return "Choose your country's equipment"
	if spec.get("supplied_only", false): return "Imported equipment · obtain through aid or trade"
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
	if check_resources:
		for resource in ProductionSystem.RESOURCES:
			if economy.stockpiles[country][resource] < cost(id, target)[resource]: return "Insufficient " + resource
	return ""
func start(id: String, target: int, country: String = "") -> String:
	if MatchClient.active != null: return MatchClient.active.send("research", {"id": id, "target": target})
	if country.is_empty(): country = GameSession.player_country
	var error: = reason(id, target, country)
	if not error.is_empty(): return error
	for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] -= cost(id, target)[resource]
	jobs.append({"equipment": id, "level": target, "progress": 0.0, "paid_cost": cost(id, target)})
	economy.changed.emit()
	changed.emit()
	return ""
func refined(id: String, tier: int) -> bool:
	return refinements.get(id,{}).get(str(tier),false)
func upgrade_day(id: String, tier: int) -> int:
	return ceili((unlock_day(id,tier)+unlock_day(id,mini(5,tier+1)))/2.0)
func upgrade_duration(tier: int, id: String = "") -> float:
	return REFINEMENT_HOURS[clampi(tier - 1, 0, 3)] * level_one_hours(_complexity(id)) * 3600.0 / SimulationClock.REAL_SECONDS_PER_SIM_SECOND
func upgrade_cost(id: String, tier: int) -> Dictionary:
	var result: Dictionary = {}
	for resource in ProductionSystem.RESOURCES: result[resource] = ceili(float(economy.equipment(id).cost.get(resource, 0.0)) * (0.2+0.1*(tier-1)))
	return result
func upgrade_reason(id: String, tier: int, country: String = "", check_resources: bool = true) -> String:
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return "Choose your country's equipment"
	if spec.get("research_only",false): return "Cargo capacity increases through the five research levels"
	if tier < 1 or tier > 4: return "Choose an intermediate upgrade"
	if level(id) < tier: return "Research this model first"
	if refined(id,tier): return "Already upgraded"
	if day() < upgrade_day(id,tier): return "Available on Day "+str(upgrade_day(id,tier))
	if not active(id).is_empty(): return "This family is already being researched"
	if jobs.filter(func(j):return economy.equipment(j.equipment).country == country).size() >= SLOTS: return "Both research slots are occupied"
	var bill: = upgrade_cost(id,tier)
	if check_resources:
		for resource in bill:
			if economy.stockpiles[country][resource] < bill[resource]: return "Insufficient "+resource
	return ""
func start_upgrade(id: String, tier: int, country: String = "") -> String:
	if MatchClient.active != null: return MatchClient.active.send("research_upgrade", {"id":id,"target":tier})
	if country.is_empty(): country = GameSession.player_country
	var error: = upgrade_reason(id,tier,country)
	if not error.is_empty(): return error
	var bill: = upgrade_cost(id,tier)
	for resource in bill: economy.stockpiles[country][resource] -= bill[resource]
	jobs.append({"equipment":id,"level":tier,"refinement":true,"progress":0.0,"paid_cost":bill})
	economy.changed.emit();changed.emit()
	return ""
func job_duration(job: Dictionary) -> float:
	return upgrade_duration(int(job.level), str(job.equipment)) if job.get("refinement",false) else duration(int(job.level), str(job.equipment))
func job_cost(job: Dictionary) -> Dictionary:
	return upgrade_cost(job.equipment,int(job.level)) if job.get("refinement",false) else cost(job.equipment,int(job.level))
func cancel(id: String, country: String = "") -> void :
	if country.is_empty(): country = GameSession.player_country
	var spec: = economy.equipment(id)
	if spec.is_empty() or spec.country != country: return
	for i in jobs.size():
		if jobs[i].equipment != id: continue
		var remaining: float = 1.0 - jobs[i].progress / job_duration(jobs[i])
		var bill: Dictionary = jobs[i].get("paid_cost", _previous_job_cost(jobs[i]))
		for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] += floor(float(bill.get(resource, 0.0)) * remaining)
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

	# The opponent AI looks for new research only when it has a free slot (performance).
	var opponent: = GameSession.opponent_country()
	var busy: = jobs.filter(func(job: Dictionary): return economy.equipment(job.equipment).country == opponent).size()
	for spec in (economy.catalog if busy < SLOTS else []):  # economy upgrades are buildings now; retired families are skipped
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
		var target: = level(member.equipment_id)
		var unit_cost: = economy.cost(member.equipment_id, target)
		for resource in ProductionSystem.RESOURCES: bill[resource] += ceil(float(unit_cost[resource]) * 0.5)
		duration_seconds = maxf(duration_seconds, economy.duration(member.equipment_id, target) * 0.5)
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
		if job.has("paid_cost") and not EquipmentEconomy.valid_paid_cost(job.paid_cost): return false
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
	for job in jobs:
		if not job.has("paid_cost"): job.paid_cost = _previous_job_cost(job)
	changed.emit()

func _previous_job_cost(job: Dictionary) -> Dictionary:
	var bill: = EquipmentEconomy.previous_cost(economy.equipment(str(job.equipment)))
	var target: = int(job.level)
	var factor: = (0.2 + 0.1 * (target - 1)) if job.get("refinement", false) else maxf(0.3, 0.5 + 0.3 * (target - 2))
	for resource in bill: bill[resource] = ceili(float(bill[resource]) * factor)
	return bill

## Gold to finish a running research now.
func speedup_price(job: Dictionary) -> int:
	var country: String = economy.equipment(job.equipment).country
	return GoldWallet.speedup((job_duration(job) - float(job.progress)) / maxf(rate(country), 0.001))

## Finishes the research of `id` now, for gold.
func finish_now(id: String, country: String, max_gold: int = -1) -> String:
	if MatchClient.active != null:
		var job: = active(id)
		if job.is_empty(): return "Nothing is being researched"
		return MatchClient.active.send("gold_research", {"id":id,"target":int(job.level),"refinement":job.get("refinement",false),"max_gold":speedup_price(job) if max_gold < 0 else max_gold})
	for job in jobs:
		if job.equipment != id: continue
		if economy.equipment(id).country != country: return "Not your research"
		var error: = economy.pay_gold_quote(country, GoldWallet.quote((job_duration(job) - float(job.progress)) / maxf(rate(country), 0.001)), max_gold)
		if not error.is_empty(): return error
		job.progress = job_duration(job)
		advance(0.000001)
		return ""
	return "Nothing is being researched"

func gold_reason(id: String, target: int, country: String = "", refinement: bool = false) -> String:
	if country.is_empty(): country = GameSession.player_country
	var job: = active(id)
	if not job.is_empty() and int(job.level) == target and bool(job.get("refinement",false)) == refinement:
		return "" if economy.equipment(id).country == country else "Choose your country's equipment"
	return upgrade_reason(id,target,country,false) if refinement else reason(id,target,country,false)

func gold_quote(id: String, target: int, refinement: bool = false) -> Dictionary:
	var country: String = economy.equipment(id).get("country", "")
	var job: = active(id)
	if not job.is_empty() and int(job.level) == target and bool(job.get("refinement",false)) == refinement:
		return GoldWallet.quote((job_duration(job) - float(job.progress)) / maxf(rate(country), 0.001))
	var work: = upgrade_duration(target,id) if refinement else duration(target,id)
	var bill: = upgrade_cost(id,target) if refinement else cost(id,target)
	return GoldWallet.quote(work / maxf(rate(country), 0.001), bill, economy.stockpiles.get(country, {}))

## Buy only missing resources, consume the available remainder, and finish eligible research.
func buy_now(id: String, target: int, country: String = "", refinement: bool = false, max_gold: int = -1) -> String:
	if country.is_empty(): country = GameSession.player_country
	if MatchClient.active != null: return MatchClient.active.send("gold_research", {"id":id,"target":target,"refinement":refinement,"max_gold":int(gold_quote(id,target,refinement).total) if max_gold < 0 else max_gold})
	var why: = gold_reason(id,target,country,refinement)
	if not why.is_empty(): return why
	if not active(id).is_empty(): return finish_now(id,country,max_gold)
	var error: = economy.pay_gold_quote(country, gold_quote(id,target,refinement), max_gold)
	if not error.is_empty(): return error
	GoldWallet.consume_available(economy.stockpiles[country], upgrade_cost(id,target) if refinement else cost(id,target))
	if refinement:
		if not refinements.has(id): refinements[id] = {}
		refinements[id][str(target)] = true
	else: levels[id] = target
	completed.emit(id,country)
	economy.changed.emit(); changed.emit()
	return ""

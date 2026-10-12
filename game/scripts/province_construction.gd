class_name ProvinceConstruction
extends RefCounted
## Rural construction shares city costs/queues, but never joins the city production list.
const ALLOWED: = ["industry", "bunker", "infrastructure", "airbase"]
const NAMES: = {"industry":"Local industry", "bunker":"Fortifications", "infrastructure":"Roads & logistics", "airbase":"Airfield"}
var _owner: WeakRef
var buildings: BuildingSystem:
 get: return _owner.get_ref() if _owner != null else null
var places: Dictionary = {}
var levels: Dictionary = {}
var jobs: Array = []
var next_id: = 1
var _roads: Array = []
var _forts: Array = []
func setup(owner: BuildingSystem) -> void:
 _owner = weakref(owner)
 places.clear()
 var city_titles: Dictionary = {}
 for city in owner.economy.cities:
  for region in owner.economy.terrain.territories:
   if region.id == city.sector: city_titles[region.title] = true
 for region in owner.economy.terrain.territories:
  if not region.playable or city_titles.has(region.title): continue
  var id: String = "province:" + region.title
  if places.has(id): continue
  places[id] = {"id":id,"name":region.title,"country":str(region.owner).capitalize(),"sector":region.id,"point":owner.economy.terrain.province_hubs.get(region.title,region.center),"rural":true,"region":region}
 reset()
func reset() -> void:
 levels.clear();jobs.clear();_roads.clear();_forts.clear();next_id = 1
 for id in places: levels[id] = {"industry":0,"bunker":0,"infrastructure":0,"airbase":0}
func place(id: String) -> Dictionary: return places.get(id,{})
func for_sector(region: Dictionary) -> Dictionary: return place("province:" + str(region.get("title","")))
func level(id: String, building: String) -> int: return int(levels.get(id,{}).get(building,0))
func reason(id: String, building: String, country: String = "", charge: bool = false) -> String:
 if country.is_empty(): country = GameSession.player_country
 if not places.has(id): return "Choose a rural province"
 if building not in ALLOWED: return "This building is city-only; provinces cannot produce units"
 if not buildings.economy.controlled(place(id),country): return "Recover this province first"
 if level(id,building) >= int(buildings.spec(building).max_level): return "Maximum level reached"
 var here: = jobs.filter(func(j): return j.city == id)
 if here.any(func(j):return j.building == building): return "This building is already queued"
 if here.size() >= BuildingSystem.QUEUE_LIMIT: return "Province construction queue is full"
 if charge:
  var bill: = buildings.cost(building,level(id,building)+1)
  for resource in bill:
   if buildings.economy.stockpiles[country][resource] < bill[resource]: return "Insufficient " + resource
 return ""
func schedule(id: String, building: String, country: String = "") -> String:
 if country.is_empty(): country = GameSession.player_country
 var error: = reason(id,building,country)
 if not error.is_empty(): return error
 jobs.append({"id":next_id,"city":id,"building":building,"level":level(id,building)+1,"progress":0.0,"country":country,"paid":false})
 next_id += 1
 buildings.changed.emit()
 return ""
func enqueue(id: String, building: String, country: String = "") -> String:
 if country.is_empty(): country = GameSession.player_country
 var error: = reason(id,building,country,true)
 if not error.is_empty(): return error
 error = schedule(id,building,country)
 if not error.is_empty(): return error
 var job: Dictionary = jobs[-1]
 var bill: = buildings.cost(building,job.level)
 for resource in bill: buildings.economy.stockpiles[country][resource] -= bill[resource]
 job.paid = true
 buildings.economy.changed.emit()
 return ""
func cancel(id: int) -> String:
 for i in jobs.size():
  var job: Dictionary = jobs[i]
  if job.id != id: continue
  if job.country != GameSession.player_country: return "This order belongs to another country"
  if job.paid:
   var bill: = buildings.cost(job.building,job.level)
   var remaining: = clampf(1.0-job.progress/buildings.duration(job.building,job.level),0,1)
   for resource in bill: buildings.economy.stockpiles[job.country][resource] += floor(bill[resource]*remaining)
  jobs.remove_at(i)
  buildings.economy.changed.emit();buildings.changed.emit()
  return "Construction cancelled"
 return "Order is no longer queued"
func advance(seconds: float) -> void:
 if seconds <= 0 or not is_finite(seconds): return
 var active: Dictionary = {}
 for job in jobs: active[job.city] = true
 for id in active:
  var remaining: = seconds
  while remaining > 0:
   var index: = -1
   for i in jobs.size():
    if jobs[i].city == id: index = i;break
   if index < 0: break
   var job: Dictionary = jobs[index]
   if not buildings.economy.controlled(place(id),job.country): break
   if not job.paid:
    var bill: = buildings.cost(job.building,job.level)
    if bill.keys().any(func(r):return buildings.economy.stockpiles[job.country][r] < bill[r]): break
    for resource in bill: buildings.economy.stockpiles[job.country][resource] -= bill[resource]
    job.paid = true
   var speed: = construction_rate(id)
   var total: = buildings.duration(job.building,job.level)
   var step: = minf(remaining,(total-job.progress)/speed)
   job.progress += step*speed;remaining -= step
   if job.progress < total: break
   levels[id][job.building] = int(job.level)
   _refresh_effects()
   jobs.remove_at(index)
   buildings.completed.emit(id,job.building);buildings.changed.emit()
func construction_rate(id: String) -> float:
 return (1.0+0.15*level(id,"infrastructure"))*clampf(float(place(id).region.get("morale",100.0))/80.0,0.25,1.0)
func income_factor(title: String) -> float: return 1.0 + 0.25 * level("province:"+title,"industry")
func movement_factor(point: Vector2,country: String) -> float:
 for id in _roads:
  var p: Dictionary = places[id]
  if buildings.economy.controlled(p,country) and RegionData.contains(p.region,point): return 1.0+0.1*level(id,"infrastructure")
 return 1.0
func protection(unit: Dictionary) -> float:
 var point: = Vector2(unit.node.position.x,unit.node.position.z)
 var result: = 0.0
 for id in _forts:
  var p: Dictionary = places[id]
  if buildings.economy.controlled(p,unit.country) and p.point.distance_to(point)<=0.6: result=maxf(result,0.2*level(id,"bunker"))
 return result
func _refresh_effects() -> void:
 _roads.clear();_forts.clear()
 for id in levels:
  if level(id,"infrastructure")>0:_roads.append(id)
  if level(id,"bunker")>0:_forts.append(id)
func snapshot() -> Dictionary: return {"levels":levels.duplicate(true),"jobs":jobs.duplicate(true),"next_id":next_id}
func validate(state: Variant) -> bool:
 if state is Dictionary and state.is_empty(): return true  # Pre-province saves.
 if not state is Dictionary or not state.get("levels") is Dictionary or not state.get("jobs") is Array or not buildings._integer(state.get("next_id"),1,1000000000): return false
 if state.levels.size() != places.size() or state.jobs.size()>places.size()*BuildingSystem.QUEUE_LIMIT: return false
 for id in state.levels:
  if not places.has(id) or not state.levels[id] is Dictionary or state.levels[id].size()!=ALLOWED.size(): return false
  for building in ALLOWED:
   if not buildings._integer(state.levels[id].get(building),0,int(buildings.spec(building).max_level)): return false
 var ids: Dictionary = {};var pending: Dictionary = {};var counts: Dictionary = {}
 for job in state.jobs:
  if not job is Dictionary or not buildings._integer(job.get("id"),1,int(state.next_id)-1) or ids.has(job.id): return false
  ids[job.id] = true
  if not places.has(job.get("city", "")) or job.get("building") not in ALLOWED or job.get("country") not in buildings.economy.stockpiles: return false
  if not buildings._integer(job.get("level"),1,buildings.spec(job.building).max_level) or job.level != state.levels[job.city][job.building]+1: return false
  var key: String = job.city+":"+job.building
  if pending.has(key): return false
  pending[key] = true
  counts[job.city] = counts.get(job.city,0)+1
  if counts[job.city]>BuildingSystem.QUEUE_LIMIT: return false
  if not job.get("paid") is bool: return false
  var progress = job.get("progress")
  if not (progress is int or progress is float) or not is_finite(float(progress)) or progress<0 or progress>=buildings.duration(job.building,job.level) or (not job.paid and progress!=0): return false
 return true
func restore(state: Dictionary) -> void:
 reset()
 if state.is_empty(): return
 levels=state.levels.duplicate(true);jobs=state.jobs.duplicate(true);next_id=int(state.next_id)
 _refresh_effects()

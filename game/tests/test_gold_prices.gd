extends SceneTree
## Real transactions and command dispatch, without licensed model files or payment services.
class CommandGame extends Node:
	var production: ProductionSystem
	var buildings: BuildingSystem
	var research: ResearchSystem
	var units: UnitSystem
	var match_rules: MatchSystem
class RecordingClient extends MatchClient:
	var sent: Array = []
	func send(op: String, data: Dictionary = {}) -> String:
		sent.append({"op":op,"data":data.duplicate(true)})
		return ""
var checks: = 0
var failures: = 0
var economy: ProductionSystem
var buildings: BuildingSystem
var research: ResearchSystem
var clock: SimulationClock
var armies: UnitSystem
var terrain: StrategicMap
var ready: Array = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL ",message)
func reset(stock: float = 0.0, gold: int = 100000) -> void:
	economy.jobs.clear(); buildings.jobs.clear(); research.jobs.clear(); ready.clear()
	for country in economy.stockpiles:
		economy.gold[country] = gold
		for resource in ProductionSystem.RESOURCES: economy.stockpiles[country][resource] = stock
func run() -> void:
	GameSession.player_country = "russia"
	terrain = StrategicMap.new()
	terrain.territories = [{"id":"r","title":"Moscow","controller":"russia","owner":"russia","morale":100.0,"playable":true,"center":Vector2.ZERO},{"id":"u","title":"Kyiv","controller":"ukraine","owner":"ukraine","morale":100.0,"playable":true,"center":Vector2(4,0)}]
	economy = ProductionSystem.new()
	economy.setup(terrain,[{"id":"moscow","name":"Moscow","country":"Russia","sector":"r","point":Vector2.ZERO},{"id":"kyiv","name":"Kyiv","country":"Ukraine","sector":"u","point":Vector2(4,0)}],{"russia":{},"ukraine":{}})
	buildings = BuildingSystem.new(); buildings.setup(economy,{"russia":{"capital_city":"moscow"},"ukraine":{"capital_city":"kyiv"}})
	economy.buildings = buildings
	armies = UnitSystem.new(); clock = SimulationClock.new()
	research = ResearchSystem.new(); research.setup(economy,clock,armies); economy.research = research
	for country in ["russia","ukraine"]:
		research.levels["infantry_"+country] = 1
		research.levels["tanks_"+country] = 1
	buildings.levels.moscow.barracks = 1; buildings.levels.moscow.tank_plant = 1
	economy.unit_ready.connect(func(unit): ready.append(unit))
	reset()
	check(GoldWallet.CURRENCY == "CAD" and GoldWallet.PURCHASE_GOLD == 10000 and GoldWallet.PURCHASE_CAD_CENTS == 1000 and GoldWallet.cad_label(10000) == "CA$10.00", "exact Canadian dollar package basis")
	check(GoldWallet.speedup(GoldWallet.HOUR * 2) == 1600 and GoldWallet.speedup(GoldWallet.HOUR) == 800 and GoldWallet.speedup(GoldWallet.HOUR / 2) == 400 and GoldWallet.speedup(0) == 0, "time charge declines to zero with remaining work")
	check(GoldWallet.speedup(GoldWallet.HOUR * 6.25) == 5000, "5000 gold covers 6.25 game hours")
	for resource in ProductionSystem.RESOURCES:
		var before: float = economy.stockpiles.russia[resource]
		var old_gold: int = economy.gold.russia
		var price: = GoldWallet.resource_price(resource,1000)
		check(economy.buy_with_gold("russia",resource,1000).is_empty() and economy.stockpiles.russia[resource] == before+1000 and economy.gold.russia == old_gold-price, "resource purchase reconciles " + resource)
		check(GoldWallet.resource_price(resource,5000) == price*5, "no hidden bulk discount " + resource)
	for resource in WorldMarketPrices.BASE:
		check(GoldWallet.resource_price(resource,1000) <= GoldWallet.resource_price("funds",1000*WorldMarketPrices.BASE[resource]), "gold-funded money cannot undercut the resource store at world floors " + resource)
	check(not economy.buy_with_gold("russia","fake",1000).is_empty() and not economy.buy_with_gold("russia","fuel",-1).is_empty(), "invalid resource purchases rejected")
	var old_gold: int = economy.gold.russia
	check(not economy.spend_gold("russia",-5000).is_empty() and economy.gold.russia == old_gold, "negative gold payment cannot mint currency")
	# All roles/levels use the same split; stock ownership never changes the time component.
	for spec in economy.catalog:
		for level in range(1,6):
			var work: = economy.duration(spec.id,level) / CountryTraits.build_factor(spec.country)
			var bill: = economy.cost(spec.id,level)
			var stocked: = GoldWallet.quote(work,bill,bill)
			var empty: = GoldWallet.quote(work,bill,{})
			var halfway: = GoldWallet.quote(work/2,bill,bill)
			check(stocked.resources == 0 and stocked.total == stocked.time, "stocked order charges only time " + spec.id)
			check(empty.total == empty.time + GoldWallet.bill_price(bill) and empty.total > stocked.total, "missing stock adds the exact resource bill " + spec.id)
			check(halfway.total < stocked.total, "progress lowers every unit's quote " + spec.id)
			for speed in [1.0,4.0,10.0]:
				clock.set_speed(speed)
				check(GoldWallet.quote(work,bill,{}).total == empty.total, "speed cannot discount gold " + spec.id)
	clock.set_speed(1)

	# An unpaid infantry order: no stock, partial stock, insufficient gold, then success.
	reset(); economy.schedule("infantry_russia","Moscow")
	var job: Dictionary = economy.jobs[0]
	var price: = economy.unit_gold_quote(job)
	# Owner 2026-10-16: infantry costs money, manpower, food and metal only.
	check(price.time == 1600 and price.resources == 4095 and price.total == 5695, "Russian infantry full purchase costs 5695, rather than an army for 5000")
	var bill: = economy.cost("infantry_russia",1)
	economy.stockpiles.russia.funds = bill.funds
	price = economy.unit_gold_quote(job)
	check(price.resources == 3015 and price.total == 4615, "only the missing resources are added to time")
	economy.gold.russia = price.total-1
	var stock: Dictionary = economy.stockpiles.russia.duplicate()
	check(not economy.finish_unit_now("Moscow","russia",price.total,int(job.id)).is_empty() and economy.gold.russia == price.total-1 and economy.stockpiles.russia == stock and not economy.jobs[0].paid, "failed payment changes no resources, jobs or gold")
	economy.gold.russia = price.total
	check(economy.finish_unit_now("Moscow","russia",price.total,int(job.id)).is_empty() and economy.gold.russia == 0 and ready.size() == 1 and economy.jobs.is_empty(), "partial stock plus gold completes exactly one unit")
	check(economy.stockpiles.russia.values().all(func(v):return v >= 0 and v < 0.001), "only owned resources are consumed; no negative or surplus purchased stock")
	check(not economy.finish_unit_now("Moscow","russia").is_empty(), "a completed order cannot be bought twice")

	# Resources paid when normal production started must never be bought a second time.
	reset(100000); economy.enqueue("infantry_russia","Moscow"); job = economy.jobs[0]
	for resource in ProductionSystem.RESOURCES: economy.stockpiles.russia[resource] = 0
	check(economy.unit_gold_quote(job).resources == 0, "paid job has no resource surcharge even with an empty stockpile")
	job.progress = economy.job_duration(job)/2
	check(economy.unit_speedup_price(job) == 800, "half-complete paid infantry costs 800")
	var wallet_before: int = economy.gold.russia
	check(not economy.finish_unit_now("Moscow","ukraine",800,int(job.id)).is_empty() and economy.gold.russia == wallet_before, "other country cannot finish the order")
	check(not economy.finish_unit_now("Moscow","russia",800,int(job.id)+1).is_empty() and economy.gold.russia == wallet_before, "stale order identity cannot finish a different purchase")
	check(economy.finish_unit_now("Moscow","russia",800,int(job.id)).is_empty() and economy.gold.russia == wallet_before-800, "paid order spends only its remaining-time price")
	reset(); economy.schedule("tanks_russia","Moscow"); job=economy.jobs[0]
	price=economy.unit_gold_quote(job)
	check(price.time == 4800 and price.total == 12900, "full tank price includes 8100 resources plus 4800 time")
	economy.stockpiles.russia.funds = 1000
	var capped: = economy.unit_speedup_price(job)
	economy.stockpiles.russia.funds = 0
	wallet_before = economy.gold.russia
	check(economy.finish_unit_now("Moscow","russia",capped,int(job.id)).begins_with("Price changed") and economy.gold.russia == wallet_before, "a higher quote is refused until reviewed")
	buildings.levels.moscow.tank_plant=0
	check(not economy.finish_unit_now("Moscow","russia",price.total,int(job.id)).is_empty() and economy.gold.russia == wallet_before, "gold cannot bypass a required factory")
	buildings.levels.moscow.tank_plant=1

	# Buildings use the identical paid/unpaid contract.
	reset(); buildings.levels.moscow.industry=0; buildings.schedule("moscow","industry")
	price=buildings.gold_quote("moscow"); job=buildings.jobs[0]
	check(price.resources == GoldWallet.bill_price(buildings.cost("industry",1)) and price.time == GoldWallet.speedup(buildings.duration("industry",1)), "construction adds missing resources and full time %s" % price)
	wallet_before=economy.gold.russia
	check(buildings.finish_now("moscow","russia",price.total,int(job.id)).is_empty() and buildings.level("moscow","industry")==1 and economy.gold.russia == wallet_before-price.total, "gold funds missing construction stock and finishes")
	reset(100000); buildings.enqueue("moscow","industry");job=buildings.jobs[0]
	job.progress=buildings.duration("industry",2)*0.75
	check(buildings.gold_quote("moscow").resources==0 and buildings.speedup_price("moscow")==GoldWallet.speedup(buildings.duration("industry",2)*0.25), "paid higher-level construction charges its last quarter only %s" % buildings.gold_quote("moscow"))

	# Research can be bought before starting, with only its shortfall charged.
	reset(); research.levels.infantry_ukraine=0
	price=research.gold_quote("infantry_ukraine",1)
	# Times follow the live research/construction data (other owners tune those); resources are exact.
	check(price.time==GoldWallet.speedup(research.duration(1,"infantry_ukraine")/research.rate("ukraine")) and price.resources==1820 and price.total==price.time+1820, "European research uses exact time discount and missing-resource bill %s" % price)
	check(research.buy_now("infantry_ukraine",1,"ukraine",false,price.total).is_empty() and research.level("infantry_ukraine")==1 and economy.gold.ukraine==100000-price.total, "gold buys missing research resources and completes eligible research")
	check(not research.buy_now("infantry_ukraine",1,"ukraine",false,price.total).is_empty(), "research cannot be bought twice")
	check(not research.buy_now("infantry_russia",3,"russia").is_empty(), "gold cannot skip prior research")
	reset(100000); research.levels.infantry_russia=0
	check(research.start("infantry_russia",1,"russia").is_empty(), "normal research starts")
	job=research.active("infantry_russia");job.progress=research.job_duration(job)*0.5
	for resource in ProductionSystem.RESOURCES:economy.stockpiles.russia[resource]=0
	price=research.gold_quote("infantry_russia",1)
	check(price.resources==0 and price.total==GoldWallet.speedup(research.job_duration(job)*0.5/research.rate("russia")), "active research charges half the remaining time and no resources %s" % price)
	check(research.buy_now("infantry_russia",1,"russia",false,price.total).is_empty(), "active research finishes at its quote")
	clock.elapsed=VictoryRules.DAY*3
	price=research.gold_quote("infantry_russia",1,true)
	check(research.buy_now("infantry_russia",1,"russia",true,price.total).is_empty() and research.refined("infantry_russia",1), "gold refinement follows the same resource-plus-time rules")

	# All gold actions reach the authenticated server rather than editing a local wallet.
	var game: = CommandGame.new(); game.production=economy;game.buildings=buildings;game.research=research;game.units=armies;game.match_rules=MatchSystem.new()
	var server: = MatchServer.new(); server.game=game
	reset(); wallet_before=economy.gold.russia
	check(server.command("russia",{"op":"gold_resource","resource":"fuel","quantity":1000}).is_empty() and economy.gold.russia==wallet_before-2000 and economy.stockpiles.russia.fuel==1000, "server resource command debits the sender")
	research.levels.infantry_russia=1
	check(server.command("russia",{"op":"produce_queue","equipment":"infantry_russia","city":"Moscow"}).is_empty(), "server accepts an unpaid production queue")
	job=economy.jobs[0];price=economy.unit_gold_quote(job)
	check(server.command("russia",{"op":"gold_unit","city":"Moscow","job":job.id,"max_gold":price.total}).is_empty() and ready.size()==1, "server computes and charges the real finish price")
	check(not server.command("russia",{"op":"gold_unit","city":"Moscow","max_gold":99999}).is_empty(), "server requires reviewed order identity")
	research.levels.infantry_ukraine=0
	price=research.gold_quote("infantry_ukraine",1)
	check(not server.command("russia",{"op":"gold_research","id":"infantry_ukraine","target":1,"max_gold":price.total}).is_empty(), "server rejects buying another country's research")
	check(server.command("ukraine",{"op":"gold_research","id":"infantry_ukraine","target":1,"max_gold":price.total}).is_empty(), "server supports a new research gold purchase")
	var client: = RecordingClient.new(); MatchClient.active=client
	wallet_before=economy.gold.russia
	economy.buy_with_gold("russia","fuel",1000)
	check(client.sent[-1].op=="gold_resource" and economy.gold.russia==wallet_before, "online gold purchase sends a command without local debit")
	MatchClient.active=null; client.free()

	# Hack prices cannot provide a cheaper bank-to-resources conversion.
	var spies: = Espionage.new()
	var world: = {"stockpile":func(country):return economy.stockpiles[country]}
	var haul: = Espionage.bank_haul({"funds":1000000000,"materials":1000000000})
	check(haul.funds==2000 and haul.materials==2000 and spies.hack_price("bank","ukraine",world) > GoldWallet.bill_price(haul), "bank cap and price prevent cheap resource purchases")
	check(GoldWallet.HACK_PRICE.firewall < GoldWallet.HACK_PRICE.blackout, "defence costs less than offensive blackout")
	reset(100000)
	var before_resources: Dictionary = economy.stockpiles.russia.duplicate()
	price={"total":spies.hack_price("bank","ukraine",world)}
	check(spies.hack("russia","bank",{},"","ukraine",int(economy.gold.russia),economy.spend_gold,world,int(price.total)).is_empty() and economy.gold.russia==100000-int(price.total) and economy.stockpiles.russia.materials>before_resources.materials, "bank transaction charges its shown fixed quote")
	server.free();game.match_rules.free();game.free();terrain.free();armies.free();clock.free()
	print("RESULT GOLD_PRICES checks=",checks," families=94 levels=5 failures=",failures)
	quit(0 if failures==0 else 1)

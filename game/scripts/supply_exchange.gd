class_name SupplyExchange
extends RefCounted

const PRICES: = {"materials": {"buy": 3.0, "sell": 2.0}, "electronics": {"buy": 8.0, "sell": 5.0}, "fuel": {"buy": 4.0, "sell": 2.0}}
var economy: ProductionSystem
func transact(resource: String, quantity: float, buying: bool, country: String = "") -> String:
	if country.is_empty(): country = GameSession.player_country
	if not PRICES.has(resource): return "This resource is not traded"
	if not is_finite(quantity) or quantity <= 0 or quantity != floor(quantity) or quantity > 10000: return "Choose a whole quantity between 1 and 10,000"
	if not economy.stockpiles.has(country): return "Unknown country"
	var stock: Dictionary = economy.stockpiles[country]
	var price: float = PRICES[resource]["buy" if buying else "sell"] * quantity
	if buying and stock.funds < price: return "Insufficient funds"
	if not buying and stock[resource] < quantity: return "Insufficient resources"
	stock.funds += - price if buying else price
	stock[resource] += quantity if buying else - quantity
	economy.changed.emit()
	return ""

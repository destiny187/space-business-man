class_name FrontierCatalog
extends RefCounted

static var _data: Dictionary = {}

static func all() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
		assert(parsed is Dictionary, "Invalid game catalog")
		_data = parsed
	return _data

static func table(key: String) -> Dictionary:
	return all()[key]

static func entry(category: String, key: String) -> Dictionary:
	if category=="resources" and FrontierSpecimenItems.is_item(key):return FrontierSpecimenItems.entry(key)
	if category=="resources" and not table(category).has(key):
		var product:=FrontierProductionTier2.product(key)
		return product if not product.is_empty() else FrontierMinerals.entry(key)
	if category=="buildings" and FrontierCombatCover.config().buildings.has(key):return FrontierCombatCover.config().buildings[key]
	if category=="buildings" and not table(category).has(key):return FrontierPlanetWeather.config().buildings.get(key,FrontierTerraformTier3.config().buildings.get(key,{}))
	return table(category).get(key, {})

static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in cost:
		parts.append("%s %d" % [entry("resources", key).get("name", key), cost[key]])
	return "  ".join(parts)

static func stock_text(stock: Dictionary) -> String:
	var present: Dictionary={}
	for id in stock:
		if int(stock[id])>0:present[id]=stock[id]
	return "비어 있음" if present.is_empty() else cost_text(present)

static func total(items: Dictionary) -> int:
	var result: int = 0
	for amount in items.values():
		result += int(amount)
	return result

static func can_pay(inventory: Dictionary, cost: Dictionary) -> bool:
	for key in cost:
		if int(inventory.get(key, 0)) < int(cost[key]):
			return false
	return true

static func add(inventory: Dictionary, items: Dictionary, sign_value: int = 1) -> void:
	for key in items:
		inventory[key] = int(inventory.get(key, 0)) + int(items[key]) * sign_value

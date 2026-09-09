class_name FrontierPlanetFactory
extends RefCounted

static func make(kind: String, planet_id: String, seed_value: int, round_number: int) -> Dictionary:
	var definition: Dictionary = FrontierCatalog.entry("planets", kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var nodes: Array = []
	var locations: Array = [[-27,-28], [30,-32], [-35,22], [34,34]]
	for i in range(1,locations.size()):
		locations[i] = [float(locations[i][0])+rng.randf_range(-7,7),float(locations[i][1])+rng.randf_range(-7,7)]
	var keys: Array = FrontierCatalog.table("resources").keys()
	for index in range(65):
		var resource: String = keys[index % keys.size()]
		var point: Vector2
		if index < 5:
			point = [Vector2(-8,-10), Vector2(7,-12), Vector2(-12,-2), Vector2(12,-2), Vector2(16,-20)][index]
		else:
			for attempt in range(1000):
				var angle: float = rng.randf_range(0,TAU)
				var distance: float = rng.randf_range(20,74)
				point = Vector2.from_angle(angle)*distance
				if _clear_site(point,nodes,locations): break
			assert(_clear_site(point,nodes,locations),"Planet generator ran out of safe mineral sites")
		var amount: int = rng.randi_range(200, 420)
		if resource == "crystal":
			amount = rng.randi_range(35, 90)
		if kind == "glacial" and resource == "ice": amount = roundi(amount*1.7)
		if kind == "sulfur" and resource == "crystal": amount = roundi(amount*1.8)
		nodes.append({"id": "%s:n%d" % [planet_id, index], "resource": resource, "amount": amount, "initial": amount, "position": [point.x, point.y], "scale": rng.randf_range(0.85, 1.35)})
	var events: Array = []
	var types: Array = ["ruin", "microbe", "animal"]
	for index in range(types.size()):
		events.append({"id": "%s:e%d" % [planet_id, index], "kind": types[index], "position": locations[index], "discovered": false, "choice": "", "reward": "", "health": 100.0})
	return {
		"id": planet_id, "kind": kind, "seed": seed_value, "name": "%s-%03d" % [definition.prefix, 117 + round_number * 13],
		"purchase_price": int(definition.price), "time": 0.0,
		"environment": {"oxygen": definition.oxygen, "pressure": definition.pressure, "toxicity": definition.toxicity, "temperature": definition.temperature, "water": definition.water, "ecology": 0.0, "stable_seconds": 0.0},
		"inventory": {"iron": 0, "copper": 0, "stone": 30, "ice": 0, "crystal": 0},
		"player": {"position": [0.0, 5.0], "cargo": {}, "yaw": 0.0},
		"nodes": nodes, "buildings": [{"id": "%s:base" % planet_id, "type": "base", "position": [0.0,0.0], "rotation": 0, "enabled": true, "active": true}],
		"robots": [], "jobs": [], "events": events, "power_supply": 2, "power_demand": 0,
		"microbes": false, "conflict": "", "conflict_resolved": "", "exports": [], "cash_income": 0, "cash_spent": 0
	}

static func _clear_site(point: Vector2,nodes: Array,events: Array) -> bool:
	for node in nodes:
		if Vector2(node.position[0],node.position[1]).distance_to(point) < 6.5: return false
	for location in events:
		if Vector2(location[0],location[1]).distance_to(point) < 7: return false
	return true

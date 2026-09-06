class_name FrontierEvaluator
extends RefCounted

static func scores(env: Dictionary) -> Dictionary:
	var oxygen: float = clampf(100.0 - absf(float(env.oxygen) - 0.21) * 500.0, 0, 100)
	var pressure: float = clampf(100.0 - absf(float(env.pressure) - 1.0) * 110.0, 0, 100)
	return {
		"atmosphere": minf(minf(oxygen, pressure), 100.0 - float(env.toxicity)),
		"temperature": clampf(100.0 - absf(float(env.temperature) - 18.0) * 1.7, 0, 100),
		"water": clampf(float(env.water) * 1.5, 0, 100),
		"ecology": clampf(float(env.ecology), 0, 100),
		"stability": clampf(float(env.stable_seconds) / 120.0 * 100.0, 0, 100)
	}

static func report(planet: Dictionary, recovered: Array = []) -> Dictionary:
	if planet.is_empty():
		return {}
	var s: Dictionary = scores(planet.environment)
	var score: float = s.atmosphere * 0.3 + s.temperature * 0.25 + s.water * 0.2 + s.ecology * 0.15 + s.stability * 0.1
	var restricted: bool = minf(s.atmosphere, minf(s.temperature, s.water)) < 60.0 or s.stability < 100.0
	var grade: String = "F"
	for item in [[90, "S"], [80, "A"], [70, "B"], [55, "C"], [35, "D"]]:
		if score >= item[0]:
			grade = item[1]
			break
	if restricted and grade in ["S", "A", "B"]:
		grade = "C"
	var effective: float = minf(score, 69.0) if restricted else score
	var multiplier: float = 0.5 + effective / 100.0 * 3.0
	var base: int = roundi(float(planet.purchase_price) * multiplier)
	var residual: int = 0
	for building in planet.buildings:
		if building.type != "base":
			residual += material_value(FrontierCatalog.entry("buildings", building.type).cost)
	for robot in planet.robots:
		if robot.id not in recovered:
			residual += roundi(material_value(FrontierCatalog.entry("robots", robot.model).cost) * float(FrontierCatalog.entry("grades", robot.grade).multiplier))
	var discoveries: int = 0
	var civilization: float = 1.0
	for event in planet.events:
		if event.kind == "ruin" and event.choice == "preserve":
			discoveries += 1600
		if event.kind == "animal" and event.choice == "protect":
			discoveries += 800
		if event.kind == "civilization" and event.choice == "protect":
			civilization = 0.45
		elif event.kind == "civilization" and event.choice == "enslave":
			civilization = 0.8
	var cleanup: int = 600 if planet.get("conflict_resolved", "") == "destroy" else 0
	var price: int = maxi(0, roundi((base + residual + discoveries - cleanup) * civilization))
	return {"scores": s, "score": score, "grade": grade, "restricted": restricted, "base": base, "residual": residual, "discoveries": discoveries, "civilization": civilization, "cleanup": cleanup, "price": price}

static func material_value(cost: Dictionary) -> int:
	var result: int = 0
	for key in cost:
		result += int(cost[key]) * int(FrontierCatalog.entry("resources", key).value)
	return result

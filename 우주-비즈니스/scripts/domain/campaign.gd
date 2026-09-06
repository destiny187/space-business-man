class_name FrontierCampaign
extends RefCounted

signal changed
signal message(text: String)

var state: Dictionary = {}
var store: FrontierSaveStore
var persistence_enabled: bool = true
var planet: Dictionary:
	get: return state.get("planet", {})
var profile: Dictionary:
	get: return state.get("profile", {})

func _init(save_path: String = "user://campaign.json") -> void:
	store = FrontierSaveStore.new(save_path)

func new_campaign(seed_value: int = 71491) -> String:
	var fresh: Dictionary = {
		"version": 1, "counter": 0, "seed": seed_value, "transactions": {}, "checkpoint": {}, "planet": {},
		"profile": {"credits": 12000, "technologies": [], "ship": 0, "hangar": [], "round": 0, "codex": [], "history": [], "rare_stock": ["advanced", "ancient"], "settings": {"sensitivity": 0.0025, "volume": 0.7, "fullscreen": false}},
		"last_report": {}
	}
	fresh.checkpoint = fresh.duplicate(true)
	fresh.profile.onboarding = FrontierOnboarding.fresh()
	fresh.checkpoint.profile.onboarding = FrontierOnboarding.fresh()
	fresh.checkpoint.checkpoint = {}
	return _commit(fresh)

func load_campaign() -> bool:
	var loaded: Dictionary = store.read_state()
	if loaded.is_empty():
		return false
	state = loaded
	changed.emit()
	return true

func save() -> String:
	if persistence_enabled and not store.write(state):
		return store.last_error
	return ""

func _commit(next: Dictionary) -> String:
	FrontierOnboarding.sync(next)
	var error: String = FrontierSaveStore.validate(next)
	if not error.is_empty():
		return error
	if persistence_enabled and not store.write(next):
		return store.last_error
	state = next
	changed.emit()
	return ""

func _id(next: Dictionary, prefix: String) -> String:
	next.counter = int(next.counter) + 1
	return "%s_%d_%d" % [prefix, int(next.seed), int(next.counter)]

func has_tech(key: String) -> bool:
	return key.is_empty() or key in profile.get("technologies", [])

func ship_slots() -> int:
	return int(FrontierCatalog.all().ships[int(profile.ship)].slots)

func buy_technology(key: String) -> String:
	var definition: Dictionary = FrontierCatalog.entry("technologies", key)
	if definition.is_empty(): return "알 수 없는 기술입니다."
	if has_tech(key): return "이미 보유한 기술입니다."
	if not has_tech(definition.requires): return "선행 기술이 필요합니다."
	if definition.rare and int(profile.round) < 1: return "레어 상점은 첫 행성 판매 후 열립니다."
	if definition.rare and key not in profile.rare_stock: return "현재 레어 상점에 없는 기술입니다."
	if profile.credits < definition.price: return "크레딧이 부족합니다."
	var next: Dictionary = state.duplicate(true)
	next.profile.credits -= definition.price
	next.profile.technologies.append(key)
	if not next.planet.is_empty(): next.planet.cash_spent += definition.price
	return _commit(next)

func upgrade_ship() -> String:
	var level: int = int(profile.ship) + 1
	if level >= FrontierCatalog.all().ships.size(): return "최상위 우주선입니다."
	var price: int = FrontierCatalog.all().ships[level].price
	if profile.credits < price: return "크레딧이 부족합니다."
	var next: Dictionary = state.duplicate(true)
	next.profile.credits -= price
	next.profile.ship = level
	if not next.planet.is_empty(): next.planet.cash_spent += price
	return _commit(next)

func buy_planet(kind: String, crew: Array = []) -> String:
	if not planet.is_empty(): return "먼저 현재 행성을 정산하세요."
	var definition: Dictionary = FrontierCatalog.entry("planets", kind)
	if definition.is_empty(): return "존재하지 않는 행성입니다."
	if profile.credits < definition.price: return "행성 구매 자금이 부족합니다."
	var reserve: int = 0
	for key in ["robotics","atmosphere","thermal","water","biotech"]:
		if not has_tech(key): reserve += int(FrontierCatalog.entry("technologies",key).price)
	if int(profile.credits)-int(definition.price) < reserve:
		return "이 행성 구매 후 필수 연구 준비금 %d Cr가 필요합니다. 더 저렴한 행성을 선택하거나 사업을 복구하세요." % reserve
	if crew.size() > ship_slots(): return "우주선 수송 한도를 초과했습니다."
	if not crew.is_empty() and not has_tech("recovery"): return "궤도 회수 기술이 필요합니다."
	var unique: Dictionary = {}
	for id in crew:
		if unique.has(id) or find_by_id(profile.hangar, id).is_empty(): return "잘못된 출발 편성입니다."
		unique[id] = true
	var next: Dictionary = state.duplicate(true)
	var checkpoint: Dictionary = next.duplicate(true)
	checkpoint.checkpoint = {}
	next.checkpoint = checkpoint
	var planet_id: String = _id(next, "planet")
	next.planet = FrontierPlanetFactory.make(kind, planet_id, int(next.seed) + int(next.counter) * 7919, int(profile.round))
	next.profile.credits -= definition.price
	for id in crew:
		var robot: Dictionary = find_by_id(next.profile.hangar, id)
		next.profile.hangar.erase(robot)
		_reset_robot(robot, [3.0 + next.planet.robots.size() * 2.0, 4.0])
		next.planet.robots.append(robot)
	return _commit(next)

func restart_business() -> String:
	if state.get("checkpoint", {}).is_empty(): return "복구할 시작점이 없습니다."
	var restored: Dictionary = state.checkpoint.duplicate(true)
	restored.checkpoint = state.checkpoint.duplicate(true)
	restored.checkpoint.checkpoint = {}
	return _commit(restored)

func capacity() -> int:
	var result: int = 900
	for building in planet.get("buildings", []):
		if building.type == "storage": result += 600
	return result

func mine(node_id: String, max_amount: int = 16) -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var node: Dictionary = find_by_id(planet.nodes, node_id)
	if node.is_empty() or node.amount <= 0: return "고갈된 자원입니다."
	if point(node.position).distance_to(point(planet.player.position)) > 5.0: return "자원에 더 가까이 접근하세요."
	var amount: int = mini(mini(int(node.amount), max_amount), 140 - FrontierCatalog.total(planet.player.cargo))
	if amount <= 0: return "화물이 가득 찼습니다. 기지나 보관함에 반납하세요."
	node.amount -= amount
	FrontierCatalog.add(planet.player.cargo, {node.resource: amount})
	FrontierOnboarding.record(state,"mined",amount)
	FrontierOnboarding.sync(state)
	changed.emit()
	return ""

func deposit() -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var near: bool = false
	for building in planet.buildings:
		if building.type in ["base", "storage"] and point(building.position).distance_to(point(planet.player.position)) < 6:
			near = true
	if not near: return "기지나 보관함 근처에서 반납할 수 있습니다."
	var room: int = capacity() - FrontierCatalog.total(planet.inventory)
	if room <= 0: return "공유 보관함이 가득 찼습니다."
	for key in planet.player.cargo.keys():
		var count: int = mini(int(planet.player.cargo[key]), room)
		FrontierCatalog.add(planet.inventory, {key: count})
		planet.player.cargo[key] -= count
		FrontierOnboarding.record(state,"deposited",count)
		room -= count
	FrontierOnboarding.sync(state)
	changed.emit()
	return ""

func discard_inventory(resource: String,amount: int) -> String:
	if planet.is_empty() or amount <= 0 or FrontierCatalog.entry("resources",resource).is_empty(): return "폐기할 자원이 올바르지 않습니다."
	if int(planet.inventory.get(resource,0)) < amount: return "보관 자원이 부족합니다."
	var next: Dictionary = state.duplicate(true)
	next.planet.inventory[resource] -= amount
	return _commit(next)

func set_guide(enabled: bool) -> String:
	var next: Dictionary = state.duplicate(true)
	if not next.profile.has("onboarding"): next.profile.onboarding = FrontierOnboarding.fresh()
	next.profile.onboarding.enabled = enabled
	return _commit(next)

func pulse_attack(event_id: String) -> String:
	if planet.is_empty() or planet.conflict != event_id: return "작전이 승인된 목표에만 피해를 줄 수 있습니다."
	var event: Dictionary = find_by_id(planet.events,event_id)
	if event.is_empty() or point(event.position).distance_to(point(planet.player.position)) > float(FrontierCatalog.all().manual_tool.pulse_range): return "사거리 밖입니다."
	var next: Dictionary = state.duplicate(true)
	var target: Dictionary = find_by_id(next.planet.events,event_id)
	target.health = maxf(0,float(target.health)-float(FrontierCatalog.all().manual_tool.pulse_damage))
	return _commit(next)

func placement_error(kind: String, location: Vector2) -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var definition: Dictionary = FrontierCatalog.entry("buildings", kind)
	if definition.is_empty(): return "알 수 없는 시설입니다."
	if not has_tech(definition.tech): return "필요한 기술을 먼저 구매하세요."
	if absf(location.x) > 76 or absf(location.y) > 76: return "건설 가능한 구역을 벗어났습니다."
	var radius: float = definition.radius
	for building in planet.buildings:
		var other_radius: float = 3.4 if building.type == "base" else FrontierCatalog.entry("buildings", building.type).radius
		if point(building.position).distance_to(location) < radius + other_radius + 0.8: return "다른 시설과 너무 가깝습니다."
	for node in planet.nodes:
		if node.amount > 0 and point(node.position).distance_to(location) < radius + 1.5: return "광맥 위에는 건설할 수 없습니다."
	for event in planet.events:
		if point(event.position).distance_to(location) < radius + 3: return "발견 구역을 침범합니다."
	if point(planet.player.position).distance_to(location) < radius + 0.8: return "수동장비와 겹치는 위치입니다."
	for robot in planet.robots:
		if point(robot.position).distance_to(location) < radius + 1.0: return "로봇이 이동 중인 위치입니다. 잠시 뒤 배치하세요."
	if not FrontierCatalog.can_pay(planet.inventory, definition.cost): return "보관 자원이 부족합니다: " + FrontierCatalog.cost_text(definition.cost)
	return ""

func build(kind: String, location: Vector2, rotation: int = 0) -> String:
	var error: String = placement_error(kind, location)
	if not error.is_empty(): return error
	var next: Dictionary = state.duplicate(true)
	FrontierCatalog.add(next.planet.inventory, FrontierCatalog.entry("buildings", kind).cost, -1)
	next.planet.buildings.append({"id": _id(next, "building"), "type": kind, "position": [location.x, location.y], "rotation": rotation, "enabled": true, "active": false, "work": 0.0})
	return _commit(next)

func demolish(id: String) -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var building: Dictionary = find_by_id(planet.buildings, id)
	if building.is_empty() or building.type == "base": return "착륙 기지는 철거할 수 없습니다."
	if building.type == "factory":
		for job in planet.jobs:
			if job.factory_id == id: return "제작 중인 작업을 먼저 취소하세요."
	var next: Dictionary = state.duplicate(true)
	FrontierCatalog.add(next.planet.inventory, FrontierCatalog.entry("buildings", building.type).cost)
	next.planet.buildings.erase(find_by_id(next.planet.buildings, id))
	# Construction refunds can temporarily exceed capacity; withdrawals remain possible.
	return _commit(next)

func toggle_building(id: String) -> String:
	var building: Dictionary = find_by_id(planet.get("buildings", []), id)
	if building.is_empty() or building.type == "base": return "변경할 수 없는 시설입니다."
	building.enabled = not building.enabled
	changed.emit()
	return ""

func craft(model: String) -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var definition: Dictionary = FrontierCatalog.entry("robots", model)
	if definition.is_empty(): return "알 수 없는 로봇입니다."
	if not has_tech(definition.tech): return "제작 기술을 먼저 구매하세요."
	if not FrontierCatalog.can_pay(planet.inventory, definition.cost): return "재료가 부족합니다: " + FrontierCatalog.cost_text(definition.cost)
	var factory_id: String = ""
	for building in planet.buildings:
		if building.type != "factory" or not building.get("active", false): continue
		var occupied: bool = false
		for job in planet.jobs:
			if job.factory_id == building.id: occupied = true
		if not occupied:
			factory_id = building.id
			break
	if factory_id.is_empty(): return "전력이 공급되는 빈 제작기가 필요합니다."
	var next: Dictionary = state.duplicate(true)
	FrontierCatalog.add(next.planet.inventory, definition.cost, -1)
	var job_id: String = _id(next, "craft")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(next.seed) + int(next.counter) * 104729
	var total_weight: int = 0
	for item in FrontierCatalog.table("grades").values(): total_weight += int(item.weight)
	var roll: int = rng.randi_range(1, total_weight)
	var grade: String = "standard"
	for key in FrontierCatalog.table("grades"):
		roll -= int(FrontierCatalog.entry("grades",key).weight)
		if roll <= 0:
			grade = key
			break
	var pool: Array = ["efficient", "cargo", "fast"] if definition.role == "miner" else ["efficient", "sturdy"]
	var traits: Array = []
	for index in range(int(FrontierCatalog.entry("grades", grade).traits)):
		var selected: int = rng.randi_range(0, pool.size() - 1)
		traits.append(pool.pop_at(selected))
	var robot: Dictionary = {"id": _id(next, "robot"), "model": model, "name": "%s · %03d" % ["MINE" if definition.role == "miner" else "WARD", next.counter], "grade": grade, "traits": traits, "health": 100.0, "filter": "all"}
	_reset_robot(robot, [3.5, 4.5])
	next.planet.jobs.append({"id": job_id, "factory_id": factory_id, "model": model, "progress": 0.0, "seconds": definition.seconds, "cost": definition.cost.duplicate(), "result": robot})
	return _commit(next)

func cancel_craft(job_id: String) -> String:
	var job: Dictionary = find_by_id(planet.get("jobs", []), job_id)
	if job.is_empty(): return "이미 완료되었거나 취소된 작업입니다."
	var next: Dictionary = state.duplicate(true)
	FrontierCatalog.add(next.planet.inventory, job.cost)
	next.planet.jobs.erase(find_by_id(next.planet.jobs, job_id))
	return _commit(next)

func assign_robot(robot_id: String, filter_key: String) -> String:
	var robot: Dictionary = find_by_id(planet.get("robots", []), robot_id)
	if robot.is_empty(): return "로봇이 없습니다."
	if filter_key != "all" and not FrontierCatalog.table("resources").has(filter_key): return "알 수 없는 자원입니다."
	robot.filter = filter_key
	robot.target = ""
	robot.path = []
	robot.enabled = true
	robot.charging = false
	robot.delivering = false
	robot.path_token = ""
	changed.emit()
	return ""

func toggle_robot(robot_id: String) -> String:
	var robot: Dictionary = find_by_id(planet.get("robots",[]),robot_id)
	if robot.is_empty(): return "로봇을 찾을 수 없습니다."
	var next: Dictionary = state.duplicate(true)
	var selected: Dictionary = find_by_id(next.planet.robots,robot_id)
	selected.enabled = not selected.enabled
	return _commit(next)

func rescue_robot(robot_id: String) -> String:
	var robot: Dictionary = find_by_id(planet.get("robots", []), robot_id)
	if robot.is_empty(): return "로봇이 없습니다."
	var next: Dictionary = state.duplicate(true)
	var rescued: Dictionary = find_by_id(next.planet.robots, robot_id)
	FrontierCatalog.add(next.planet.inventory, rescued.cargo)
	_reset_robot(rescued, [4.0, 3.0])
	rescued.health = 100.0
	return _commit(next)

func discover(event_id: String) -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var event: Dictionary = find_by_id(planet.events, event_id)
	if event.is_empty(): return "신호가 없습니다."
	if point(event.position).distance_to(point(planet.player.position)) > 7.0: return "신호에 더 가까이 접근하세요."
	if event.discovered: return ""
	var next: Dictionary = state.duplicate(true)
	find_by_id(next.planet.events, event_id).discovered = true
	if event.kind not in next.profile.codex: next.profile.codex.append(event.kind)
	return _commit(next)

func choose_event(event_id: String, choice: String) -> String:
	if planet.is_empty(): return "활성 행성이 없습니다."
	var event: Dictionary = find_by_id(planet.events, event_id)
	if event.is_empty() or not event.discovered: return "먼저 현장에서 신호를 조사하세요."
	if not event.choice.is_empty(): return "이미 선택을 확정했습니다."
	var choices: Dictionary = {"ruin": ["preserve", "extract", "analyze"], "microbe": ["cultivate", "observe"], "animal": ["protect", "capture"], "civilization": ["protect", "destroy", "enslave"]}
	if choice not in choices[event.kind]: return "유효하지 않은 선택입니다."
	if choice == "analyze" and not has_tech("analysis"): return "고대 기술 분석이 필요합니다."
	if event.kind == "civilization" and choice in ["destroy", "enslave"]:
		var guards: int = 0
		for robot in planet.robots:
			if FrontierCatalog.entry("robots", robot.model).role == "combat": guards += 1
		if guards == 0: return "먼저 전투 AI 경비로봇을 제작하세요."
	var next: Dictionary = state.duplicate(true)
	var selected: Dictionary = find_by_id(next.planet.events, event_id)
	selected.choice = choice
	var reward: String = "기록을 보존했습니다."
	if event.kind == "ruin":
		if choice == "preserve": reward = "유적 보존 · 행성 평가 +1,600 Cr"
		elif choice == "extract":
			next.profile.credits += 1800
			next.planet.cash_income += 1800
			reward = "유물 지구 반출 · 1,800 Cr 수령"
		elif choice == "analyze":
			if "ancient" not in next.profile.technologies:
				next.profile.technologies.append("ancient")
				reward = "고대 에너지 코어 기술 해독"
			else:
				next.profile.credits += 1200
				next.planet.cash_income += 1200
				reward = "중복 설계도 연구 보상 · 1,200 Cr"
	elif event.kind == "microbe" and choice == "cultivate":
		next.planet.microbes = true
		reward = "황산 적응 미생물 정착 · 독성 감소·산소 생성력 55"
	elif event.kind == "animal":
		if choice == "protect": reward = "서식지 보존 · 생태 정착 촉진·평가 +800 Cr"
		else:
			next.profile.credits += 900
			next.planet.cash_income += 900
			reward = "야생동물 지구 반출·판매 · 900 Cr"
	elif event.kind == "civilization":
		if choice == "protect":
			var candidates: Array = []
			for key in FrontierCatalog.table("technologies"):
				if key not in next.profile.technologies: candidates.append(key)
			var rng := RandomNumberGenerator.new()
			rng.seed = int(next.seed) + int(next.counter) + 1337
			if not candidates.is_empty() and rng.randf() > 0.35:
				var key: String = candidates[rng.randi_range(0, candidates.size() - 1)]
				next.profile.technologies.append(key)
				reward = "문명의 선물 · " + FrontierCatalog.entry("technologies", key).name
			else:
				next.profile.credits += 2400
				next.planet.cash_income += 2400
				reward = "문명의 보물 · 2,400 Cr"
			reward += " / 행성 판매 단가 55% 감소"
		else:
			selected.choice = choice + "_pending"
			next.planet.conflict = event_id
			next.planet.conflict_order = choice
			reward = "경비로봇 작전 개시 · 현장에서 진행 상황을 확인하세요."
	selected.reward = reward
	next.transactions[_id(next, "event")] = {"event": event_id, "choice": choice}
	return _commit(next)

func sell_planet(expected_id: String, recovered: Array = []) -> String:
	if planet.is_empty() or planet.id != expected_id: return "이미 정산되었거나 다른 행성입니다."
	if not planet.conflict.is_empty(): return "진행 중인 문명 작전을 먼저 완료하세요."
	if recovered.size() > ship_slots(): return "회수 한도를 초과했습니다."
	if not recovered.is_empty() and not has_tech("recovery"): return "궤도 회수 기술이 필요합니다."
	var unique: Dictionary = {}
	for id in recovered:
		if unique.has(id) or find_by_id(planet.robots, id).is_empty(): return "잘못된 회수 대상입니다."
		unique[id] = true
	var next: Dictionary = state.duplicate(true)
	# Resolve unfinished inputs and carried materials before the valuation snapshot.
	for job in next.planet.jobs: FrontierCatalog.add(next.planet.inventory, job.cost)
	next.planet.jobs.clear()
	FrontierCatalog.add(next.planet.inventory, next.planet.player.cargo)
	next.planet.player.cargo.clear()
	for robot in next.planet.robots:
		FrontierCatalog.add(next.planet.inventory, robot.cargo)
		robot.cargo.clear()
	var report: Dictionary = FrontierEvaluator.report(next.planet, recovered)
	for id in recovered:
		var robot: Dictionary = find_by_id(next.planet.robots, id).duplicate(true)
		_reset_robot(robot, [0.0, 0.0])
		next.profile.hangar.append(robot)
	next.profile.credits += report.price
	next.profile.round += 1
	report.planet_name = planet.name
	report.planet_id = planet.id
	report.recovered = recovered.size()
	report.purchase_price = planet.purchase_price
	report.cash_spent = planet.cash_spent
	report.cash_income = planet.cash_income
	report.profit = report.price + planet.cash_income - planet.purchase_price - planet.cash_spent
	next.last_report = report
	next.profile.history.append(report.duplicate(true))
	next.transactions[_id(next, "sale")] = report.duplicate(true)
	next.planet = {}
	return _commit(next)

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func find_by_id(items: Array, id: String) -> Dictionary:
	for item in items:
		if item.id == id: return item
	return {}

static func _reset_robot(robot: Dictionary, location: Array) -> void:
	robot.position = location
	robot.battery = 100.0
	robot.cargo = {}
	robot.status = "대기"
	robot.target = ""
	robot.path = []
	robot.work = 0.0
	robot.enabled = true
	robot.filter = robot.get("filter", "all")

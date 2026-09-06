class_name FrontierSimulation
extends RefCounted

var nav := AStarGrid2D.new()
var nav_signature: String = ""
var accumulator: float = 0.0
var pending_messages: Array[String] = []

func step(campaign: FrontierCampaign, delta: float) -> void:
	if campaign.planet.is_empty() or delta <= 0: return
	var p: Dictionary = campaign.planet
	var previous: Dictionary = campaign.state.duplicate(true) if not p.jobs.is_empty() or not p.conflict.is_empty() else {}
	var previous_accumulator: float = accumulator
	pending_messages.clear()
	p.time += delta
	_update_navigation(p)
	_power(p)
	var critical: bool = _craft(p, delta, campaign)
	for robot in p.robots:
		_robot(p, robot, delta, campaign)
	accumulator += delta
	while accumulator >= 1.0:
		accumulator -= 1.0
		_environment(p)
	if not p.conflict.is_empty():
		var event: Dictionary = FrontierCampaign.find_by_id(p.events, p.conflict)
		if not event.is_empty() and event.health <= 0:
			event.choice = p.conflict_order
			event.reward = "작전 완료 · 문명 파괴" if event.choice == "destroy" else "통제 확립 · 채광 생산 +20%, 판매 가치 20% 감소"
			p.conflict_resolved = p.conflict_order
			p.conflict = ""
			if event.choice == "destroy":
				p.environment.toxicity = minf(100, p.environment.toxicity + 10)
				p.environment.ecology = maxf(0, p.environment.ecology - 10)
			critical = true
			pending_messages.append(event.reward)
	if critical:
		var error: String = campaign.save()
		if not error.is_empty():
			if not previous.is_empty(): campaign.state = previous
			accumulator = previous_accumulator
			campaign.message.emit(error)
		else:
			for notice in pending_messages: campaign.message.emit(notice)
		campaign.changed.emit()

func _power(p: Dictionary) -> void:
	var supply: float = 2.0
	var demand: float = 0.0
	for b in p.buildings:
		if b.type == "base": continue
		var power: float = FrontierCatalog.entry("buildings", b.type).power
		var was_active: bool = b.get("active",false)
		b.active = b.enabled and power <= 0
		if not b.enabled: b.status = "정지"
		elif power < 0: b.status = "발전 중"
		elif power == 0: b.status = "사용 가능"
		elif not was_active: b.status = "전력 대기"
		if b.enabled:
			if power < 0: supply -= power
			else: demand += power
	var available: float = supply
	# Charging and manufacturing take priority over environment machines.
	for type in ["charger", "factory", "storage", "atmosphere", "thermal", "water", "biolab"]:
		for b in p.buildings:
			if b.type != type or not b.enabled: continue
			var power: float = FrontierCatalog.entry("buildings", type).power
			if power <= available:
				b.active = true
				if b.get("status","") in ["","정지","전력 대기"]: b.status = "가동 중"
				available -= power
			else: b.status = "전력 대기"
	p.power_supply = supply
	p.power_demand = demand

func _craft(p: Dictionary, delta: float, campaign: FrontierCampaign) -> bool:
	var completed: Array = []
	for job in p.jobs:
		var factory: Dictionary = FrontierCampaign.find_by_id(p.buildings, job.factory_id)
		if factory.is_empty() or not factory.active: continue
		job.progress = minf(job.seconds, job.progress + delta)
		if job.progress >= job.seconds:
			var spawn := Vector2(INF,INF)
			for i in range(16):
				var candidate: Vector2 = FrontierCampaign.point(factory.position) + Vector2.from_angle(PI/2+i*TAU/16)*5
				if _cell_solid(_cell(candidate)): continue
				var occupied: bool = false
				for other in p.robots:
					if FrontierCampaign.point(other.position).distance_to(candidate) < 1.5: occupied = true; break
				if not occupied: spawn = candidate; break
			if not is_finite(spawn.x): factory.status = "출고 공간 필요"; continue
			var robot: Dictionary = job.result.duplicate(true)
			robot.position = [spawn.x, spawn.y]
			p.robots.append(robot)
			completed.append(job)
			pending_messages.append("%s 등급 로봇 제작 완료 · %s" % [FrontierCatalog.entry("grades", robot.grade).name, robot.name])
	for job in completed: p.jobs.erase(job)
	return not completed.is_empty()

func _environment(p: Dictionary) -> void:
	var e: Dictionary = p.environment
	for b in p.buildings:
		if not b.get("active", false): continue
		match b.type:
			"atmosphere":
				e.oxygen = move_toward(float(e.oxygen), 0.21, 0.0007)
				e.pressure = move_toward(float(e.pressure), 1.0, 0.0035)
				e.toxicity = move_toward(float(e.toxicity), 0.0, 0.3)
			"thermal": e.temperature = move_toward(float(e.temperature), 18.0, 0.22)
			"water":
				if e.water >= 100: b.status = "목표 달성"; continue
				b.status = "얼음 부족" if p.inventory.get("ice",0) <= 0 else "가동 중"
				b.work = float(b.get("work", 0)) + 1
				if b.work >= 4:
					if p.inventory.get("ice", 0) > 0:
						p.inventory.ice -= 1
						e.water = minf(100, e.water + 1.2)
						b.work = 0.0
					else: b.status = "얼음 부족"
			"biolab":
				var s: Dictionary = FrontierEvaluator.scores(e)
				if s.atmosphere >= 50 and s.temperature >= 50 and e.water >= 25:
					b.status = "가동 중"
					e.ecology = minf(100, e.ecology + 0.32)
				else: b.status = "생태 조건 대기"
	if p.microbes and e.temperature > -45 and e.temperature < 90:
		e.toxicity = maxf(0, e.toxicity - 0.055)
		e.oxygen = minf(0.21, e.oxygen + 0.00011)
	for event in p.events:
		if event.kind == "animal" and event.choice == "protect" and e.water > 30 and e.temperature > -5:
			e.ecology = minf(100, e.ecology + 0.055)
	var score: Dictionary = FrontierEvaluator.scores(e)
	if minf(score.atmosphere, minf(score.temperature, score.water)) >= 60:
		e.stable_seconds = minf(120, e.stable_seconds + 1)
	else: e.stable_seconds = 0.0

func _robot(p: Dictionary, r: Dictionary, dt: float, campaign: FrontierCampaign) -> void:
	if not r.enabled: r.status = "수동 대기"; return
	if r.health <= 0: r.status = "파손 · 구조 필요"; return
	if r.battery <= 0: r.status = "배터리 고갈 · 구조 필요"; return
	var def: Dictionary = FrontierCatalog.entry("robots", r.model)
	var speed: float = def.speed * float(FrontierCatalog.entry("grades", r.grade).multiplier)
	var low: float = maxf(20, FrontierCampaign.point(r.position).length() * 0.32 + 10)
	if r.battery < low or r.get("charging", false):
		r.charging = true
		var charger: Dictionary = _nearest_building(p, r, ["charger"], true)
		if charger.is_empty(): r.status = "전원이 켜진 충전기 필요"; return
		r.status = "충전기 이동"
		if _travel(r, FrontierCampaign.point(charger.position), speed, dt):
			r.status = "충전 중"
			r.battery = minf(100, r.battery + dt * 15)
			if r.battery >= 99:
				r.charging = false
				r.target = ""
		return
	if def.role == "combat":
		_combat(p, r, speed, dt)
		return
	var cargo_max: int = roundi(def.cargo * (1.25 if "cargo" in r.traits else 1.0))
	if FrontierCatalog.total(r.cargo) >= cargo_max or r.get("delivering", false):
		r.delivering = true
		var storage: Dictionary = _nearest_building(p, r, ["base", "storage"], false)
		if storage.is_empty(): r.status = "보관함 없음"; return
		var destination: Vector2 = _approach(FrontierCampaign.point(storage.position), FrontierCampaign.point(r.position), 4.6 if storage.type == "base" else 3.0)
		r.status = "자원 운반"
		if _travel(r, destination, speed, dt):
			var room: int = campaign.capacity() - FrontierCatalog.total(p.inventory)
			if room <= 0: r.status = "보관함 가득 참"; return
			for key in r.cargo.keys():
				var count: int = mini(int(r.cargo[key]), room)
				FrontierCatalog.add(p.inventory, {key: count})
				FrontierOnboarding.record(campaign.state,"delivered",count)
				r.cargo[key] -= count
				room -= count
			if FrontierCatalog.total(r.cargo) == 0:
				r.delivering = false
				r.target = ""
		return
	var target: Dictionary = FrontierCampaign.find_by_id(p.nodes, r.target)
	if target.is_empty() or target.amount <= 0:
		r.target = ""
		target = {}
		var closest: float = INF
		for node in p.nodes:
			if node.amount <= 0 or (r.filter != "all" and node.resource != r.filter): continue
			var distance: float = FrontierCampaign.point(r.position).distance_to(FrontierCampaign.point(node.position))
			if distance < closest:
				var approach: Vector2 = _approach(FrontierCampaign.point(node.position),FrontierCampaign.point(r.position),3.0)
				if not _reachable(FrontierCampaign.point(r.position),approach): continue
				closest = distance
				target = node
		if target.is_empty() or target.amount <= 0:
			if FrontierCatalog.total(r.cargo) > 0: r.delivering = true
			r.status = "지정 자원 없음"
			return
		r.target = target.id
	r.status = "광맥 이동"
	var goal: Vector2 = _approach(FrontierCampaign.point(target.position), FrontierCampaign.point(r.position), 3.0)
	if _travel(r, goal, speed, dt):
		r.status = "채광 중"
		var production: float = def.mining * float(FrontierCatalog.entry("grades", r.grade).multiplier)
		if "fast" in r.traits: production *= 1.1
		if p.conflict_resolved == "enslave": production *= 1.2
		r.work += production * dt
		var amount: int = mini(mini(int(r.work), int(target.amount)), cargo_max - FrontierCatalog.total(r.cargo))
		if amount > 0:
			target.amount -= amount
			r.work -= amount
			FrontierCatalog.add(r.cargo, {target.resource: amount})
		r.battery = maxf(0, r.battery - dt * (0.15 if "efficient" in r.traits else 0.18))

func _combat(p: Dictionary, r: Dictionary, speed: float, dt: float) -> void:
	if p.conflict.is_empty(): r.status = "기지 경비"; return
	var event: Dictionary = FrontierCampaign.find_by_id(p.events, p.conflict)
	if event.is_empty(): return
	r.status = "작전 구역 이동"
	var goal: Vector2 = _approach(FrontierCampaign.point(event.position), FrontierCampaign.point(r.position), 7)
	if _travel(r, goal, speed, dt):
		r.status = "전투 작전 중"
		event.health = maxf(0, event.health - dt * 3.0 * float(FrontierCatalog.entry("grades", r.grade).multiplier))
		r.health = maxf(0, r.health - dt * (0.8 if "sturdy" in r.traits else 1.0))
		r.battery = maxf(0, r.battery - dt * 0.15)

func _nearest_building(p: Dictionary, r: Dictionary, types: Array, needs_power: bool) -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = INF
	for b in p.buildings:
		if b.type not in types or (needs_power and not b.active): continue
		var current: float = FrontierCampaign.point(b.position).distance_to(FrontierCampaign.point(r.position))
		if current < distance:
			var destination: Vector2 = FrontierCampaign.point(b.position)
			if b.type != "charger": destination = _approach(destination,FrontierCampaign.point(r.position),4.6 if b.type == "base" else 3.0)
			if not _reachable(FrontierCampaign.point(r.position),destination): continue
			distance = current
			nearest = b
	return nearest

func _approach(target: Vector2, origin: Vector2, distance: float) -> Vector2:
	var direction: Vector2 = (origin - target).normalized()
	if direction.is_zero_approx(): direction = Vector2.DOWN
	var desired: Vector2 = target + direction * distance
	if not _cell_solid(_cell(desired)): return desired
	for i in range(16):
		var candidate: Vector2 = target + Vector2.from_angle(i * TAU / 16) * (distance + 1)
		if not _cell_solid(_cell(candidate)): return candidate
	return desired

func _travel(r: Dictionary, destination: Vector2, speed: float, dt: float) -> bool:
	var origin: Vector2 = FrontierCampaign.point(r.position)
	if origin.distance_to(destination) < 0.75: return true
	var goal_cell: Vector2i = _cell(destination)
	var goal_token: String = "%d:%d:%s" % [goal_cell.x, goal_cell.y, nav_signature]
	if r.get("path_token", "") != goal_token or r.path.is_empty():
		r.path = []
		var start: Vector2i = _cell(origin)
		if _cell_solid(start) or _cell_solid(goal_cell): r.status = "경로 없음 · 구조 또는 시설 이동"; return false
		var route: PackedVector2Array = nav.get_point_path(start, goal_cell)
		for item in route: r.path.append([item.x, item.y])
		if not r.path.is_empty():
			r.path.pop_front()
			r.path.append([destination.x,destination.y])
		r.path_token = goal_token
		if r.path.is_empty(): r.status = "경로 없음 · 시설 배치 확인"; return false
	while not r.path.is_empty() and origin.distance_to(FrontierCampaign.point(r.path[0])) < 0.3:
		r.path.pop_front()
	if r.path.is_empty(): return origin.distance_to(destination) < 2.0
	var next: Vector2 = origin.move_toward(FrontierCampaign.point(r.path[0]), speed * dt)
	r.battery = maxf(0, r.battery - origin.distance_to(next) * (0.23 if "efficient" in r.traits else 0.27))
	r.position = [next.x, next.y]
	return false

func _reachable(origin: Vector2,destination: Vector2) -> bool:
	var start: Vector2i = _cell(origin)
	var goal: Vector2i = _cell(destination)
	return not _cell_solid(start) and not _cell_solid(goal) and not nav.get_id_path(start,goal).is_empty()

func _cell_solid(cell: Vector2i) -> bool:
	return not nav.region.has_point(cell) or nav.is_point_solid(cell)

func _update_navigation(p: Dictionary) -> void:
	var signature: String = str(p.id) + ":" + str(p.buildings.size())
	for b in p.buildings: signature += b.id
	for node in p.nodes:
		if node.amount <= 0: signature += node.id
	if signature == nav_signature: return
	nav_signature = signature
	nav.clear()
	nav.region = Rect2i(0, 0, 81, 81)
	nav.cell_size = Vector2(2, 2)
	nav.offset = Vector2(-80, -80)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	var obstacles: Array = []
	for b in p.buildings:
		if b.type == "charger": continue
		obstacles.append([FrontierCampaign.point(b.position), 3.1 if b.type == "base" else (1.0 if b.type == "solar" else float(FrontierCatalog.entry("buildings", b.type).radius) + 0.2)])
	for node in p.nodes:
		if node.amount > 0: obstacles.append([FrontierCampaign.point(node.position), 1.8])
	for event in p.events: obstacles.append([FrontierCampaign.point(event.position), 2.8])
	for obstacle in obstacles:
		var cell: Vector2i = _cell(obstacle[0])
		for x in range(cell.x - 3, cell.x + 4):
			for y in range(cell.y - 3, cell.y + 4):
				var candidate := Vector2i(x, y)
				if nav.region.has_point(candidate) and nav.get_point_position(candidate).distance_to(obstacle[0]) < obstacle[1]:
					nav.set_point_solid(candidate)

func _cell(location: Vector2) -> Vector2i:
	return Vector2i(roundi((location.x + 80.0) / 2.0), roundi((location.y + 80.0) / 2.0))

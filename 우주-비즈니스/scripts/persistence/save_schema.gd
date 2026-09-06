class_name FrontierSaveSchema
extends RefCounted

static func validate(state: Dictionary,checkpoint: bool = false) -> String:
	if not _integer(state.get("version"),1,1): return "지원하지 않는 저장 버전"
	for key in ["profile","planet","transactions","checkpoint","last_report"]:
		if not state.get(key) is Dictionary: return "저장 필드 형식 오류: "+key
	if not _integer(state.get("counter"),0) or not _integer(state.get("seed"),0): return "잘못된 저장 식별자"
	var error: String = _profile(state.profile)
	if not error.is_empty(): return error
	var ids: Dictionary = {}
	for robot in state.profile.hangar:
		error = _robot(robot,ids)
		if not error.is_empty(): return error
	if not state.planet.is_empty():
		error = _planet(state.planet,ids)
		if not error.is_empty(): return error
	if not state.checkpoint.is_empty():
		if checkpoint: return "재시작 지점의 중첩 오류"
		if not state.checkpoint.get("planet") is Dictionary or not state.checkpoint.planet.is_empty(): return "재시작 지점은 지구 상태여야 합니다."
		error = validate(state.checkpoint,true)
		if not error.is_empty(): return "재시작 지점: "+error
	for report in state.profile.history:
		if not _report(report): return "정산 이력 형식 오류"
	if not state.last_report.is_empty() and not _report(state.last_report): return "마지막 정산 형식 오류"
	for transaction in state.transactions.values():
		if not transaction is Dictionary: return "거래 이력 형식 오류"
	return ""

static func _profile(p: Dictionary) -> String:
	if not _integer(p.get("credits"),0) or not _integer(p.get("round"),0): return "유효하지 않은 계정 자산"
	if not _integer(p.get("ship"),0,FrontierCatalog.all().ships.size()-1): return "유효하지 않은 우주선 등급"
	for key in ["technologies","hangar","codex","history","rare_stock"]:
		if not p.get(key) is Array: return "프로필 필드 형식 오류: "+key
	if not _unique_strings(p.technologies,FrontierCatalog.table("technologies")): return "알 수 없거나 중복된 기술"
	if not _unique_strings(p.rare_stock,FrontierCatalog.table("technologies")): return "희귀 상점 데이터 오류"
	if not _unique_strings(p.codex,{"ruin":true,"microbe":true,"animal":true,"civilization":true}): return "도감 데이터 오류"
	if not p.get("settings") is Dictionary: return "설정 데이터 누락"
	if p.has("onboarding"):
		if not p.onboarding is Dictionary: return "입문 안내 형식 오류"
		var guide: Dictionary = p.onboarding
		if not guide.get("enabled") is bool or not _number(guide.get("travel"),0,100): return "입문 안내 상태 오류"
		for key in ["mined","deposited","delivered"]:
			if not _integer(guide.get(key),0,100000): return "입문 진행도 오류"
		var allowed: Dictionary = {}
		for key in FrontierOnboarding.STEPS: allowed[key] = true
		if not _unique_strings(guide.get("completed"),allowed): return "입문 단계 오류"
	var settings: Dictionary = p.settings
	if settings.has("graphics"):
		if not settings.graphics is String or not FrontierGraphics.data().profiles.has(settings.graphics): return "그래픽 품질 설정 오류"
	if not _number(settings.get("sensitivity"),0.0001,0.1) or not _number(settings.get("volume"),0,1) or not settings.get("fullscreen") is bool: return "설정값 범위 오류"
	if settings.has("bindings"):
		if not settings.bindings is Dictionary: return "키 설정 형식 오류"
		var used: Dictionary = {}
		for key in FrontierInput.DEFAULTS:
			var code: Variant = settings.bindings.get(key,FrontierInput.DEFAULTS[key])
			if not _integer(code,1,1<<25) or code == KEY_ESCAPE or used.has(code): return "키 설정 중복 또는 범위 오류"
			used[code] = true
	return ""

static func _planet(p: Dictionary,ids: Dictionary) -> String:
	for key in ["id","kind","name","conflict","conflict_resolved"]:
		if not p.get(key) is String: return "행성 문자열 필드 오류: "+key
	if p.id.is_empty() or FrontierCatalog.entry("planets",p.kind).is_empty(): return "알 수 없는 행성"
	for key in ["seed","purchase_price","cash_income","cash_spent"]:
		if not _integer(p.get(key),0): return "행성 수치 오류: "+key
	if not _number(p.get("time"),0) or not _number(p.get("power_supply"),0) or not _number(p.get("power_demand"),0): return "행성 시뮬레이션 수치 오류"
	if not _inventory(p.get("inventory")) or not p.get("player") is Dictionary or not p.get("environment") is Dictionary: return "행성 상태 형식 오류"
	if not _position(p.player.get("position")) or not _number(p.player.get("yaw"),-INF,INF) or not _inventory(p.player.get("cargo")): return "수동장비 상태 오류"
	if FrontierCatalog.total(p.player.cargo) > 140: return "수동장비 화물 한도 초과"
	if not _environment(p.environment): return "환경 수치 범위 오류"
	for key in ["robots","buildings","nodes","events","jobs","exports"]:
		if not p.get(key) is Array: return "행성 목록 형식 오류: "+key
	if not p.get("microbes") is bool: return "미생물 상태 오류"
	var node_ids: Dictionary = {}
	for node in p.nodes:
		if not node is Dictionary or not _identity(node,ids): return "광맥 ID 오류"
		if not node.get("resource") is String or FrontierCatalog.entry("resources",node.resource).is_empty(): return "알 수 없는 광물"
		if not _integer(node.get("initial"),1) or not _integer(node.get("amount"),0,float(node.initial)): return "광맥 잔량 오류"
		if not _position(node.get("position")) or not _number(node.get("scale"),0.1,5): return "광맥 배치 오류"
		node_ids[node.id] = true
	var building_ids: Dictionary = {}
	var bases: int = 0
	for b in p.buildings:
		if not b is Dictionary or not _identity(b,ids): return "시설 ID 오류"
		if not b.get("type") is String: return "시설 유형 오류"
		if b.type == "base": bases += 1
		elif FrontierCatalog.entry("buildings",b.type).is_empty(): return "알 수 없는 시설"
		if not _position(b.get("position")) or not _integer(b.get("rotation"),0,359) or int(b.rotation)%90 != 0: return "시설 배치 오류"
		if not b.get("enabled") is bool or not b.get("active") is bool or not _number(b.get("work",0),0): return "시설 가동 상태 오류"
		building_ids[b.id] = b.type
	if bases != 1: return "착륙 기지 수량 오류"
	for robot in p.robots:
		var error: String = _robot(robot,ids)
		if not error.is_empty(): return error
	var factories: Dictionary = {}
	for job in p.jobs:
		if not job is Dictionary or not _identity(job,ids): return "제작 작업 ID 오류"
		if not job.get("factory_id") is String or building_ids.get(job.factory_id) != "factory" or factories.has(job.factory_id): return "제작기 예약 오류"
		factories[job.factory_id] = true
		if not job.get("model") is String or FrontierCatalog.entry("robots",job.model).is_empty(): return "제작 모델 오류"
		if not _number(job.get("seconds"),0.01) or not _number(job.get("progress"),0,float(job.seconds)): return "제작 진행도 오류"
		if not _inventory(job.get("cost")): return "제작 예약 재료 오류"
		var error: String = _robot(job.get("result"),ids)
		if not error.is_empty(): return "제작 결과: "+error
		if job.result.model != job.model: return "제작 결과 모델 불일치"
	var events: Dictionary = {}
	var choices: Dictionary = {"ruin":["","preserve","extract","analyze"],"microbe":["","cultivate","observe"],"animal":["","protect","capture"],"civilization":["","protect","destroy","enslave","destroy_pending","enslave_pending"]}
	for event in p.events:
		if not event is Dictionary or not _identity(event,ids): return "발견 ID 오류"
		if not event.get("kind") is String or not choices.has(event.kind): return "알 수 없는 발견"
		if not event.get("choice") is String or event.choice not in choices[event.kind]: return "발견 선택 오류"
		if not event.get("reward") is String or not event.get("discovered") is bool or not _position(event.get("position")) or not _number(event.get("health"),0,100): return "발견 상태 오류"
		if not event.discovered and not event.choice.is_empty(): return "발견하지 않은 이벤트의 확정 결과"
		events[event.id] = event
	if not p.conflict.is_empty():
		if not events.has(p.conflict) or events[p.conflict].kind != "civilization": return "작전 대상 오류"
		if p.get("conflict_order","") not in ["destroy","enslave"] or events[p.conflict].choice != p.conflict_order+"_pending": return "작전 명령 오류"
	return ""

static func _robot(value: Variant,ids: Dictionary) -> String:
	if not value is Dictionary: return "로봇 형식 오류"
	var r: Dictionary = value
	if not _identity(r,ids): return "로봇 ID·소유권 중복 오류"
	for key in ["model","grade","name","status","target","filter"]:
		if not r.get(key) is String: return "로봇 필드 형식 오류: "+key
	if FrontierCatalog.entry("robots",r.model).is_empty() or FrontierCatalog.entry("grades",r.grade).is_empty(): return "알 수 없는 로봇 정의"
	if not _unique_strings(r.get("traits"),FrontierCatalog.table("traits")): return "로봇 특성 오류"
	if r.traits.size() != int(FrontierCatalog.entry("grades",r.grade).traits): return "로봇 등급별 특성 수 오류"
	if not _number(r.get("health"),0,100) or not _number(r.get("battery"),0,100) or not _number(r.get("work"),0): return "로봇 수치 오류"
	if not r.get("enabled") is bool or not _inventory(r.get("cargo")) or not _position(r.get("position")): return "로봇 상태 오류"
	if r.filter != "all" and FrontierCatalog.entry("resources",r.filter).is_empty(): return "로봇 작업 자원 오류"
	if not r.get("path") is Array: return "로봇 경로 형식 오류"
	for location in r.path:
		if not _position(location): return "로봇 경로 좌표 오류"
	for key in ["charging","delivering"]:
		if r.has(key) and not r[key] is bool: return "로봇 이동 상태 오류"
	return ""

static func _environment(e: Dictionary) -> bool:
	for key in ["toxicity","water","ecology"]:
		if not _number(e.get(key),0,100): return false
	return _number(e.get("oxygen"),0,1) and _number(e.get("pressure"),0,100) and _number(e.get("temperature"),-273.15,1000) and _number(e.get("stable_seconds"),0,120)

static func _inventory(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if not key is String or FrontierCatalog.entry("resources",key).is_empty() or not _integer(value[key],0): return false
	return true

static func _identity(value: Dictionary,ids: Dictionary) -> bool:
	if not value.get("id") is String or value.id.is_empty() or ids.has(value.id): return false
	ids[value.id] = true
	return true

static func _unique_strings(value: Variant,allowed: Dictionary) -> bool:
	if not value is Array: return false
	var seen: Dictionary = {}
	for item in value:
		if not item is String or not allowed.has(item) or seen.has(item): return false
		seen[item] = true
	return true

static func _number(value: Variant,minimum: float,maximum: float = 1e14) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer(value: Variant,minimum: float,maximum: float = 1e14) -> bool:
	return _number(value,minimum,maximum) and float(value) == floor(float(value))

static func _position(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0],-80,80) and _number(value[1],-80,80)

static func _report(value: Variant) -> bool:
	if not value is Dictionary: return false
	for key in ["grade","planet_name","planet_id"]:
		if not value.get(key) is String: return false
	for key in ["price","recovered","purchase_price","cash_spent","cash_income"]:
		if not _integer(value.get(key),0): return false
	return _number(value.get("profit"),-1e14,1e14) and value.grade in ["S","A","B","C","D","F"]

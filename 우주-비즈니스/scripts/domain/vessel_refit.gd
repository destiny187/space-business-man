class_name FrontierVesselRefit
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/vessel_refit.json"))
	return _config
static func signature() -> String:return FrontierUniverse.fingerprint(config())
static func create(seed_value: int,realm: String="") -> Dictionary:
	return {"version":1,"rules_hash":signature(),"id":(realm+":kestrel:"+str(seed_value)).sha256_text(),"counter":0,"draws":0,"parts":0,"modules":{},"loadout":{"propulsion":"","utility":""},"last_draw":{}}
static func grade_index(grade: String) -> int:return config().grades.find(grade)
static func definition(kind: String) -> Dictionary:return config().modules.get(kind,{})
static func stats(world: Dictionary) -> Dictionary:
	var cfg:=config()
	var hull:=FrontierSpaceStation.hull(world.get("vessel",{}))
	var result: Dictionary={"stellar_range":stellar_range(world),"mass":float(hull.mass),"power":float(cfg.base_power),"speed":float(hull.speed),"research_speed":1.0,"hangar":int(hull.hangar),"maximum_mass":float(hull.maximum_mass),"reactor_power":float(hull.reactor_power)}
	var vessel: Dictionary=world.get("vessel",{})
	for id in vessel.get("loadout",{}).values():
		if id.is_empty():continue
		var module: Dictionary=vessel.modules[id];var def:=definition(module.type);var grade:=grade_index(module.grade)
		result.mass+=float(def.mass[grade]);result.power+=float(def.power[grade])
		for key in ["speed","research_speed"]:
			if def.has(key):result[key]*=float(def[key][grade])
		if def.has("hangar"):result.hangar+=int(def.hangar[grade])
	result.mass+=world.get("business",{}).get("hangar",{}).size()*float(cfg.robot_mass)
	return result
static func constraints(world: Dictionary) -> String:
	var value:=stats(world)
	if value.power>float(value.reactor_power):return "원정선 전력 한도를 넘습니다. 다른 모듈 또는 등급 조합을 선택하세요."
	if value.mass>float(value.maximum_mass):return "원정선 적재 질량 한도를 넘습니다."
	if world.get("business",{}).get("hangar",{}).size()>int(value.hangar):return "적재한 로봇을 먼저 재파견해야 격납고 용량을 줄일 수 있습니다."
	return ""
static func add_module(vessel: Dictionary,kind: String,grade: String) -> String:
	for module in vessel.modules.values():
		if module.type==kind and module.grade==grade:return ""
	vessel.counter+=1
	var id: String="module:"+str(int(vessel.counter))
	vessel.modules[id]={"id":id,"type":kind,"grade":grade};return id
static func apply(world: Dictionary,actor: String,action: String,args: Dictionary) -> String:
	if actor!=world.crew.owner_id:return "호스트가 공동 원정선의 제작·개조를 확정합니다."
	if not FrontierCrewSurface.landed(world) or FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "착륙한 우주선 주변에서 정비하세요."
	if not world.has("business"):return "먼저 무료 사업 등록으로 공동 사업 장부를 여세요."
	if not world.has("vessel"):world.vessel=create(int(world.manifest.seed),world.crew.world_id)
	var vessel: Dictionary=world.vessel
	var kind: String=str(args.get("module_type",""));var id: String=str(args.get("module_id",""))
	var site:=FrontierExpeditionBusiness.site(world)
	if action in ["vessel_build","vessel_draw","vessel_upgrade"] and (site.is_empty() or site.state!="active"):return "진행 중인 현장 사업의 재료 창고가 필요합니다."
	var credits:=0;var materials: Dictionary={};var parts:=0
	match action:
		"vessel_build":
			if definition(kind).is_empty():return "제작할 모듈 종류를 선택하세요."
			for module in vessel.modules.values():
				if module.type==kind and module.grade=="standard":return "이미 보유한 표준 모듈입니다. 개량하거나 다른 모듈을 제작하세요."
			credits=int(config().build_credits);materials=config().build_materials
		"vessel_draw":
			if definition(kind).is_empty():return "확정 획득 시 원하는 모듈 종류를 선택하세요."
			credits=int(config().draw_credits);materials=config().draw_materials
		"vessel_upgrade":
			if not vessel.modules.has(id):return "개량할 보유 모듈을 선택하세요."
			var module: Dictionary=vessel.modules[id];var grade:=grade_index(module.grade)
			if grade>=2:return "최고 개량 단계입니다."
			if grade==1 and world.get("engineering",{}).get("projects",{}).get(definition(module.type).research,{}).get("stage")!="certified":return "고급 개량에는 해당 생물공학 설계도 인증이 필요합니다."
			for other in vessel.modules.values():
				if other.id!=id and other.type==module.type and other.grade==config().grades[grade+1]:return "동일한 상위 모듈이 이미 있습니다."
			credits=int(config().upgrade_credits[grade]);parts=int(config().upgrade_parts[grade]);materials=FrontierProductionTier2.config().vessel_upgrade_cost if grade==0 else config().upgrade_materials
			if grade==0:parts=0
		"vessel_equip":
			if not vessel.modules.has(id):return "장착할 모듈을 선택하세요."
			var slot: String=definition(vessel.modules[id].type).slot
			if vessel.loadout[slot]==id:return "이미 장착한 모듈입니다."
			vessel.loadout[slot]=id
		"vessel_unequip":
			var slot: String=str(args.get("slot",""))
			if slot not in config().slots or vessel.loadout[slot].is_empty():return "장착된 슬롯을 선택하세요."
			vessel.loadout[slot]=""
		"vessel_salvage":
			if not vessel.modules.has(id) or id in vessel.loadout.values():return "해제한 보유 모듈을 선택하세요."
			vessel.parts+=int(config().salvage_parts[grade_index(vessel.modules[id].grade)]);vessel.modules.erase(id)
		_:return "지원하지 않는 선박 정비 작업입니다."
	if int(world.business.credits)<credits or int(vessel.parts)<parts or (not materials.is_empty() and not FrontierExpeditionBusiness.affordable(site.inventory,materials)):return "공동 크레딧·현장 재료·연구 부품이 부족합니다."
	if action=="vessel_build":add_module(vessel,kind,"standard")
	elif action=="vessel_upgrade":vessel.modules[id].grade=config().grades[grade_index(vessel.modules[id].grade)+1]
	elif action=="vessel_draw":
		vessel.draws+=1
		var seed_value: int=FrontierUniverse.derive(int(world.manifest.seed),"vessel-draw:"+str(int(vessel.draws)))
		var types: Array=config().modules.keys();types.sort()
		var selected: String=types[seed_value%types.size()]
		var roll: int=FrontierUniverse.derive(seed_value,"quality")%100
		var quality: String="standard" if roll<int(config().weights[0]) else ("improved" if roll<int(config().weights[0])+int(config().weights[1]) else "rare")
		var guaranteed: bool=int(vessel.draws)%int(config().pity_interval)==0
		if guaranteed:selected=kind;quality="improved"
		var created:=add_module(vessel,selected,quality)
		if created.is_empty():vessel.parts+=int(config().duplicate_parts)
		vessel.last_draw={"index":int(vessel.draws),"type":selected,"grade":quality,"duplicate":created.is_empty(),"guaranteed":guaranteed,"module_id":created}
	world.business.credits-=credits;vessel.parts-=parts
	if not materials.is_empty():FrontierExpeditionBusiness.transfer(site.inventory,materials,-1)
	var reason:=constraints(world)
	if not reason.is_empty():return reason
	for member in world.crew.members.values():member.ready=false
	return ""
static func validate(value: Variant,seed_value: int,realm: String="") -> String:
	if not value is Dictionary or value.get("version")!=1 or value.get("rules_hash")!=signature() or value.get("id")!=create(seed_value,realm).id:return "원정선 개조 원형·식별 오류"
	if value.has("hull") or value.has("hulls"):
		if not value.get("hulls") is Array or value.hulls.is_empty() or value.hulls.size()>FrontierSpaceStation.config().hulls.size() or value.get("hull") not in value.hulls or "kestrel" not in value.hulls:return "보유 선체 구조 오류"
		var hull_seen: Dictionary={}
		for id in value.hulls:
			if not id is String or not FrontierSpaceStation.config().hulls.has(id) or hull_seen.has(id):return "보유 선체 정의 오류"
			hull_seen[id]=true
	for key in ["counter","draws","parts"]:
		if not FrontierExpeditionBusiness.integer(value.get(key),0,10000000):return "원정선 제작·추첨 기록 오류"
	if not value.get("modules") is Dictionary or value.modules.size()>int(config().maximum_modules) or not value.get("loadout") is Dictionary or value.loadout.size()!=config().slots.size() or not value.get("last_draw") is Dictionary:return "원정선 모듈 구조 오류"
	var seen: Dictionary={}
	for id in value.modules:
		var module: Variant=value.modules[id]
		if not id is String or not module is Dictionary or module.get("id")!=id or not module.get("type") is String or definition(module.type).is_empty() or module.get("grade") not in config().grades:return "선박 모듈 정의 오류"
		if id!="module:"+str(int(id.trim_prefix("module:"))) or not id.begins_with("module:") or not id.trim_prefix("module:").is_valid_int() or int(id.trim_prefix("module:"))<1 or int(id.trim_prefix("module:"))>int(value.counter):return "모듈 고유 순번 오류"
		var identity: String=module.type+":"+module.grade
		if seen.has(identity):return "같은 모듈 품질이 중복 소유됐습니다."
		seen[identity]=true
	for slot in config().slots:
		var id: Variant=value.loadout.get(slot)
		if not id is String or (not id.is_empty() and (not value.modules.has(id) or definition(value.modules[id].type).slot!=slot)):return "선박 슬롯 연결 오류"
	if (value.draws==0)!=value.last_draw.is_empty():return "추첨 횟수와 최근 결과가 맞지 않습니다."
	if not value.last_draw.is_empty():
		var row: Dictionary=value.last_draw
		if row.get("index")!=value.draws or not row.get("type") is String or definition(row.type).is_empty() or row.get("grade") not in config().grades or not row.get("duplicate") is bool or not row.get("guaranteed") is bool or not row.get("module_id") is String:return "선박 추첨 결과 오류"
		if row.guaranteed!=(int(value.draws)%int(config().pity_interval)==0) or (row.guaranteed and row.grade!="improved") or row.duplicate!=row.module_id.is_empty():return "선박 확정 추첨 기록 오류"
	return ""

static var navigation_rules: Dictionary={}
static func stellar_range(world: Dictionary) -> float:
	if navigation_rules.is_empty():navigation_rules=JSON.parse_string(FileAccess.get_file_as_string("res://data/stellar_navigation.json"))
	var rules: Dictionary=navigation_rules
	var vessel: Dictionary=world.get("vessel",{})
	var result: float=rules.hull_range.get(vessel.get("hull","kestrel"),rules.hull_range.kestrel)
	var module: Dictionary=vessel.get("modules",{}).get(vessel.get("loadout",{}).get("propulsion",""),{})
	if not module.is_empty():result*=float(rules.propulsion_range_multiplier[maxi(0,grade_index(module.grade))])
	return result

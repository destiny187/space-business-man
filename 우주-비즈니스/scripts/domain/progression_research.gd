class_name FrontierProgressionResearch
extends RefCounted
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/progression_research.json"))
	return _config
static func personal(member: Dictionary,key: String) -> int:
	return int(member.get("loadout",{}).get("research",{}).get(key,0))
static func shared(world: Dictionary) -> int:return int(world.get("business",{}).get("efficiency",0))
static func multiplier(level: int) -> float:return 1.0+float(config().increment)*clampi(level,0,int(config().maximum_level))
static func level(world: Dictionary,actor: String,key: String) -> int:
	return shared(world) if key=="industry" else personal(world.crew.members[actor],key)
static func cost(key: String,level: int) -> Dictionary:
	var base: Dictionary=config().fields[key].get("cost",{}).duplicate()
	for resource in base:base[resource]=int(base[resource])*(level+1)
	return base
static func reason(world: Dictionary,actor: String,key: String) -> String:
	if not config().fields.has(key):return "연구 분야를 선택하세요."
	if not FrontierCrewSurface.landed(world):return "착륙선 연구실에서 연구하세요."
	if FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "착륙선 연구실에 접근하세요."
	if not world.has("business"):return "착륙 현장을 먼저 준비하세요."
	var current:=level(world,actor,key)
	if current>=int(config().maximum_level):return "최고 연구 단계입니다."
	if key=="industry":
		if actor!=world.crew.owner_id:return "공동 설비 연구는 호스트가 진행합니다."
		if int(world.business.credits)<int(config().fields[key].price)*(current+1):return "공동 크레딧이 부족합니다."
	elif not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),cost(key,current)):return "가방의 연구 부품이 부족합니다."
	return ""
static func apply(world: Dictionary,actor: String,args: Dictionary) -> String:
	var key:=str(args.get("field",""));var error:=reason(world,actor,key)
	if not error.is_empty():return error
	var current:=level(world,actor,key)
	if key=="industry":world.business.credits-=int(config().fields[key].price)*(current+1);world.business.efficiency=current+1
	else:
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],cost(key,current),-1)
		if not world.crew.members[actor].has("loadout"):world.crew.members[actor].loadout=FrontierEquipment.create(world.crew.members[actor].profile)
		var loadout: Dictionary=world.crew.members[actor].loadout
		if not loadout.has("research"):loadout.research={}
		loadout.research[key]=current+1
	return ""
static func valid_personal(value: Variant) -> bool:
	if not value is Dictionary or value.size()>2:return false
	for key in value:
		if key not in ["mining","logistics"] or not FrontierExpeditionBusiness.integer(value[key],0,int(config().maximum_level)):return false
	return true

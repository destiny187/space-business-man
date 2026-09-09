class_name FrontierCrewAugmentation
extends RefCounted
## Character growth belongs to the host world's member, not equipped items or profiles.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_augmentation.json"))
	return _config
static func create(mobility: int=0) -> Dictionary:
	return {"version":1,"levels":{"mobility":mobility,"combat":0,"vitality":0}}
static func ensure(member: Dictionary) -> void:
	# Run after save validation. Retain the paid speed once, independently of bag upgrades.
	if not member.has("augmentation"):member.augmentation=create(FrontierProgressionResearch.personal(member,"logistics"))
static func level(member: Dictionary,key: String) -> int:
	if not member.has("augmentation"):
		return FrontierProgressionResearch.personal(member,"logistics") if key=="mobility" else 0
	return int(member.augmentation.levels.get(key,0))
static func multiplier(member: Dictionary,key: String) -> float:
	return 1.0+float(config().fields[key].increment)*level(member,key)
static func maximum_health(member: Dictionary) -> float:
	return float(FrontierCrewVitals.config().maximum_health)*multiplier(member,"vitality")
static func validate(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=2 or value.get("version")!=1:return false
	var levels: Variant=value.get("levels")
	if not levels is Dictionary or levels.size()!=config().fields.size():return false
	for key in config().fields:
		if not FrontierExpeditionBusiness.integer(levels.get(key),0,int(config().maximum_level)):return false
	return true

static func cost(key: String,current: int) -> Dictionary:
	if not config().fields.has(key) or current<0 or current>=int(config().maximum_level):return {}
	var definition: Dictionary=config().fields[key]
	return {str(definition.gem):int(definition.base_cost)*(current+1)}
static func reason(world: Dictionary,actor: String,args: Dictionary,station: Dictionary) -> String:
	# Neither the target character, price nor station transform comes from the client.
	if args.size()!=3 or args.get("station_id")!="ship:augmentation" or not args.get("field") is String or not config().fields.has(args.field):return "증강 계열과 장치를 선택하세요."
	if not FrontierExpeditionBusiness.integer(args.get("expected_level"),0,int(config().maximum_level)):return "증강 단계 요청 오류"
	if not world.get("crew",{}).get("members",{}).has(actor):return "참가한 캐릭터가 없습니다."
	var member: Dictionary=world.crew.members[actor]
	if world.has("local_shuttle") or FrontierShuttles.aboard(world,actor):return "공동 원정선의 증강 장치를 이용하세요."
	if station.get("enabled")!=true or not station.get("position") is Vector3 or not station.position.is_finite():return "사용 가능한 증강 장치가 없습니다."
	if station.get("area") not in ["cabin","surface"] or member.area!=station.area:return "증강 장치가 있는 공간으로 이동하세요."
	if member.area=="surface":
		if not FrontierCrewSurface.landed(world) or station.get("body_id")!=world.crew.landing.body_id or member.aboard:return "같은 행성의 착륙선 증강 장치에 접근하세요."
	elif FrontierCrewSurface.landed(world) or not member.aboard:return "공동 원정선의 증강 장치에 접근하세요."
	if FrontierCrewWorld.vector(member.position).distance_to(station.position)>(float(FrontierCrewSurface.config().boarding_distance) if station.get("ship_terminal",false) else float(config().interaction_range)):return "증강 장치 %.0fm 안에서 실행하세요."%float(config().interaction_range)
	var current:=level(member,args.field)
	if int(args.expected_level)!=current:return "증강 단계가 바뀌었습니다. 현재 능력을 다시 확인하세요."
	if current>=int(config().maximum_level):return "최고 증강 단계입니다."
	if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),cost(args.field,current)):return "자기 배낭의 보석이 부족합니다."
	return ""
static func apply(world: Dictionary,actor: String,args: Dictionary,station: Dictionary) -> String:
	var error:=reason(world,actor,args,station)
	if not error.is_empty():return error
	var member: Dictionary=world.crew.members[actor]
	ensure(member)
	var current:=level(member,args.field)
	FrontierExpeditionBusiness.transfer(world.business.bags[actor],cost(args.field,current),-1)
	member.augmentation.levels[args.field]=current+1
	# Raising maximum health is not an instant heal; vitals remain unchanged.
	return ""
static func outcome(member: Dictionary,key: String) -> Dictionary:
	var current:=level(member,key)
	return {"field":key,"previous_level":current-1,"level":current,"spent":cost(key,current-1),"multiplier":multiplier(member,key),"maximum_health":maximum_health(member)}

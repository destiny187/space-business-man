class_name FrontierExpeditionResearch
extends RefCounted
## Shared world knowledge. No RPC accepts a stage, discovery proof or license.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition_research.json"))
	return _config
static func create(legacy: bool=false) -> Dictionary:
	var result: Dictionary={"version":1,"origin":"legacy" if legacy else "new","licenses":{},"projects":{}}
	for id in config().projects:
		result.projects[id]={"stage":"unseen","evidence":{},"contributions":{}}
		if legacy:result.licenses[config().projects[id].license]="legacy"
	return result
static func ensure(world: Dictionary) -> void:
	# Only missing old-world state migrates; malformed/future versions must fail validation first.
	if world.has("expedition_research"):return
	world.expedition_research=create(true)
	for row in world.get("crew",{}).get("survey",{}).values():
		if FrontierUniverse.ordinal_of(world.manifest,row.body_id)>=0 and not row.vein_id.is_empty():record(world,row.body_id,row.resource,row.vein_id,int(row.tier),"legacy_scan","")
static func record(world: Dictionary,body_id: String,resource: String,vein_id: String,tier: int,source: String,actor: String) -> void:
	ensure(world)
	for id in config().projects:
		var definition: Dictionary=config().projects[id]
		if resource not in definition.sample_resources or tier>int(definition.maximum_evidence_tier):continue
		var project: Dictionary=world.expedition_research.projects[id]
		if project.evidence.has(resource):continue
		project.evidence[resource]={"body_id":body_id,"vein_id":vein_id,"tier":tier,"source":source,"actor":actor}
		if project.stage=="unseen":project.stage="discovered"
static func sample_count(project: Dictionary) -> int:
	var count:=0
	for contribution in project.contributions.values():
		for amount in contribution.values():count+=int(amount)
	return count
static func licensed(world: Dictionary,definition: String) -> bool:
	var value: Dictionary=world.get("expedition_research",create(true))
	return value.licenses.has(definition)
static func craft_reason(world: Dictionary,definition: String) -> String:
	var recipe: Dictionary=FrontierEquipment.config().items.get(definition,{})
	if recipe.is_empty():return "제작 설계도 오류"
	# Availability is separate from ownership. A05 does not ship the A07 crafting content early.
	if not recipe.get("craftable",true):return "현재 제작은 Mk.2까지 지원합니다."
	for project in config().projects.values():
		if project.license==definition and not licensed(world,definition):return project.name+" 연구를 완료하세요."
	return ""
static func reason(world: Dictionary,actor: String,args: Dictionary,station: Dictionary) -> String:
	if args.size()!=5 or args.get("station_id")!="ship:research" or not args.get("project") is String or not config().projects.has(args.project):return "연구 프로젝트와 장치를 선택하세요."
	var definition: Dictionary=config().projects[args.project]
	if not args.get("resource") is String or args.resource not in definition.sample_resources or not FrontierExpeditionBusiness.integer(args.get("amount"),1,int(definition.analysis_samples)):return "투입할 표본과 수량을 선택하세요."
	if args.get("expected_stage")!="discovered":return "현재 연구 단계를 다시 확인하세요."
	if not world.get("crew",{}).get("members",{}).has(actor):return "참가한 캐릭터가 없습니다."
	if world.has("local_shuttle") or FrontierShuttles.aboard(world,actor):return "공동 원정선의 표본 연구대를 이용하세요."
	var member: Dictionary=world.crew.members[actor]
	if station.get("enabled")!=true or not station.get("position") is Vector3 or not station.position.is_finite():return "사용 가능한 표본 연구대가 없습니다."
	if station.get("area") not in ["cabin","surface"] or station.area!=member.area:return "연구대가 있는 공간으로 이동하세요."
	if member.area=="surface":
		if not FrontierCrewSurface.landed(world) or member.aboard or station.get("body_id")!=world.crew.landing.body_id:return "같은 행성의 연구대에 접근하세요."
	elif FrontierCrewSurface.landed(world) or not member.aboard:return "공동 원정선의 연구대에 접근하세요."
	if FrontierCrewWorld.vector(member.position).distance_to(station.position)>float(config().interaction_range):return "연구대 3m 안에서 표본을 투입하세요."
	var project: Dictionary=world.expedition_research.projects[args.project]
	if project.stage!=args.expected_stage:return "연구 단계가 바뀌었습니다. 현재 연구를 다시 확인하세요."
	if not project.evidence.has(args.resource):return "이 표본의 발견 기록이 필요합니다."
	if int(args.amount)>int(definition.analysis_samples)-sample_count(project):return "이미 기여한 표본입니다. 남은 수량만 투입하세요."
	if int(FrontierExpeditionBusiness.bag(world,actor).get(args.resource,0))<int(args.amount):return "자기 배낭의 표본이 부족합니다."
	return ""
static func contribute(world: Dictionary,actor: String,args: Dictionary,station: Dictionary) -> String:
	ensure(world)
	var error:=reason(world,actor,args,station)
	if not error.is_empty():return error
	var project: Dictionary=world.expedition_research.projects[args.project]
	FrontierExpeditionBusiness.transfer(world.business.bags[actor],{args.resource:int(args.amount)},-1)
	if not project.contributions.has(actor):project.contributions[actor]={}
	var own: Dictionary=project.contributions[actor]
	own[args.resource]=int(own.get(args.resource,0))+int(args.amount)
	if sample_count(project)==int(config().projects[args.project].analysis_samples):project.stage="analyzed"
	return ""
static func validate(world: Dictionary) -> String:
	if not world.has("expedition_research"):return ""
	var value: Variant=world.expedition_research
	if not value is Dictionary or value.size()!=4 or value.get("version")!=1 or value.get("origin") not in ["new","legacy"]:return "공동 연구 버전·이행 기록 오류"
	if not value.get("licenses") is Dictionary or not value.get("projects") is Dictionary or value.projects.size()!=config().projects.size():return "공동 연구 원장 형식 오류"
	var licenses: Array=[]
	for id in config().projects:
		var definition: Dictionary=config().projects[id];licenses.append(definition.license)
		var project: Variant=value.projects.get(id)
		if not project is Dictionary or project.size()!=3 or project.get("stage") not in ["unseen","discovered","analyzed"]:return "공동 연구 단계 오류"
		if not project.get("evidence") is Dictionary or project.evidence.size()>definition.sample_resources.size() or not project.get("contributions") is Dictionary or project.contributions.size()>128:return "공동 연구 증거·기여 형식 오류"
		for resource in project.evidence:
			var row: Variant=project.evidence[resource]
			if resource not in definition.sample_resources or not row is Dictionary or row.size()!=5:return "공동 연구 표본 증거 오류"
			if not row.get("body_id") is String or FrontierUniverse.ordinal_of(world.manifest,row.body_id)<0 or not row.get("vein_id") is String or row.vein_id.is_empty() or row.vein_id.length()>128:return "공동 연구 발견 위치 오류"
			if not FrontierExpeditionBusiness.integer(row.get("tier"),1,int(definition.maximum_evidence_tier)) or row.get("source") not in ["scan","legacy_scan","extraction"]:return "공동 연구 발견 출처 오류"
			if not row.get("actor") is String or (not row.actor.is_empty() and not world.get("crew",{}).get("members",{}).has(row.actor)):return "공동 연구 발견자 오류"
		for actor in project.contributions:
			var contribution: Variant=project.contributions[actor]
			if not world.get("crew",{}).get("members",{}).has(actor) or not contribution is Dictionary or contribution.is_empty() or contribution.size()>definition.sample_resources.size():return "공동 연구 기여자 오류"
			for resource in contribution:
				if not project.evidence.has(resource) or not FrontierExpeditionBusiness.integer(contribution[resource],1,int(definition.analysis_samples)):return "공동 연구 표본 수량 오류"
		var total:=sample_count(project)
		if total>int(definition.analysis_samples):return "공동 연구 표본 초과"
		var stage: String="unseen" if project.evidence.is_empty() else ("analyzed" if total==int(definition.analysis_samples) else "discovered")
		if project.stage!=stage:return "공동 연구 단계와 증거 불일치"
	for license in value.licenses:
		if license not in licenses or value.origin!="legacy" or value.licenses[license]!="legacy":return "공동 연구 사용권 오류"
	if value.origin=="legacy" and value.licenses.size()!=licenses.size():return "이전 세계 사용권 누락"
	return ""

class_name FrontierFieldEngineering
extends RefCounted
## Purchased foundations plus observed biological principles become paid facility retrofits.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/field_engineering.json"))
	return _config
static func signature() -> String:return FrontierUniverse.fingerprint(config())
static func create() -> Dictionary:return {"version":1,"rules_hash":signature(),"projects":{}}
static func definition(key: String) -> Dictionary:return config().projects.get(key,{})
static func evidence(ecology: Dictionary,key: String) -> Dictionary:
	var def:=definition(key)
	if def.is_empty():return {}
	for environment in def.environments:
		if not ecology.get("research",{}).has(environment):continue
		var form_id: String=ecology.research[environment].form_id
		for row in ecology.get("observations",{}).values():
			if row.form_id==form_id:return {"form_id":form_id,"source_body":row.body_id}
	return {}
static func uses(world: Dictionary,body_id: String,facility_id: String="") -> bool:
	for row in world.get("engineering",{}).get("projects",{}).values():
		if row.stage in ["prototype","trial"] and row.body_id==body_id and (facility_id.is_empty() or row.facility_id==facility_id):return true
	return false
static func factor(world: Dictionary,building: Dictionary) -> float:
	var key: String=building.get("engineering","")
	var row: Dictionary=world.get("engineering",{}).get("projects",{}).get(key,{})
	if row.get("stage")!="certified" or definition(key).get("building")!=building.type:return 1.0
	return float(definition(key).factor)
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var site:=FrontierExpeditionBusiness.site(world)
	if site.is_empty() or not FrontierPlanetSupply.operating(site) or not FrontierCrewSurface.landed(world):return "착륙한 활성 사업에서 공학 연구를 진행하세요."
	var key: String=str(args.get("project",""));var def:=definition(key)
	if def.is_empty():return "공학 연구 과제를 선택하세요."
	var id: String=str(args.get("building_id",""))
	if not site.buildings.has(id):return "작업할 현장 설비를 선택하세요."
	var b: Dictionary=site.buildings[id]
	if FrontierExpeditionBusiness.point(b.position).distance_to(FrontierExpeditionBusiness.point(world.crew.members[actor].position))>float(FrontierExpeditionBusiness.config().interaction_range):return "연구 설비 8m 이내로 접근하세요."
	if kind=="business_research_cancel":
		var records: Dictionary=world.get("engineering",{}).get("projects",{})
		var row: Dictionary=records.get(key,{})
		if row.get("stage") not in ["prototype","trial"] or row.get("body_id")!=world.location or row.get("facility_id")!=id:return "중지할 현장 실험과 시설을 선택하세요."
		if row.stage=="prototype":records.erase(key)
		else:row.stage="prototype_ready";row.progress=float(config().prototype_seconds)
		return ""
	if not b.active or not b.enabled:return "전력이 공급되는 가동 설비가 필요합니다."
	if not world.has("engineering"):world.engineering=create()
	var records: Dictionary=world.engineering.projects
	var cost: Dictionary={}
	match kind:
		"business_research_prototype":
			if records.has(key):return "이미 시작한 과제입니다. 시제품 완료 후 현장 시험을 진행하세요."
			if b.type!="factory":return "시제품은 로봇 제작소에서 제작합니다."
			if uses(world,world.location,id) or not site.jobs.is_empty() or not b.get("production",{}).is_empty():return "제작소의 진행 작업을 먼저 완료하세요."
			var proof:=evidence(world.get("ecology",{}),key)
			if proof.is_empty():return "관련 서식 환경의 생물 스캔과 기초 분석이 필요합니다."
			cost=config().prototype_cost
			if not FrontierExpeditionBusiness.affordable(site.inventory,cost):return "시제품 제작 재료가 부족합니다."
			records[key]={"stage":"prototype","form_id":proof.form_id,"source_body":proof.source_body,"body_id":world.location,"facility_id":id,"progress":0.0}
		"business_research_trial":
			if not records.has(key) or records[key].stage!="prototype_ready":return "먼저 시제품 제작을 완료하세요."
			if b.type!=def.building or uses(world,world.location,id):return "과제에 맞는 가동 설비를 선택하세요."
			if (b.type=="water" and site.environment.water>=100) or (b.type=="biolab" and site.environment.ecology>=100):return "아직 처리 여유가 있는 현장의 설비에서 시험하세요."
			cost=config().trial_cost
			if not FrontierExpeditionBusiness.affordable(site.inventory,cost):return "현장 시험 재료가 부족합니다."
			records[key].stage="trial";records[key].body_id=world.location;records[key].facility_id=id;records[key].progress=0.0
		"business_research_install":
			if not records.has(key) or records[key].stage!="certified":return "현장 시험을 완료하고 설계도를 확정하세요."
			if b.type!=def.building:return "개조 대상 시설 종류가 다릅니다."
			if not b.get("engineering","").is_empty():return "이미 개조한 설비입니다. 효과는 중첩되지 않습니다."
			cost=config().install_cost
			if not FrontierExpeditionBusiness.affordable(site.inventory,cost):return "설비 개조 재료가 부족합니다."
			b.engineering=key
		_:return "지원하지 않는 공학 작업입니다."
	FrontierExpeditionBusiness.transfer(site.inventory,cost,-1)
	return ""
static func tick(world: Dictionary,dt: float) -> void:
	var site:=FrontierExpeditionBusiness.site(world)
	for row in world.get("engineering",{}).get("projects",{}).values():
		if row.stage not in ["prototype","trial"] or row.body_id!=world.location:continue
		var b: Dictionary=site.buildings.get(row.facility_id,{})
		if b.is_empty() or not b.active:continue
		if row.stage=="trial" and not trial_ready(site,b):continue
		var seconds: float=config().prototype_seconds if row.stage=="prototype" else config().trial_seconds
		row.progress=minf(seconds,float(row.progress)+dt*float(FrontierVesselRefit.stats(world).research_speed))
		if row.progress>=seconds:row.stage="prototype_ready" if row.stage=="prototype" else "certified"
static func trial_ready(site: Dictionary,building: Dictionary) -> bool:
	if building.type=="water":return int(site.inventory.ice)>0 and float(site.environment.water)<100
	if building.type=="biolab":
		var scores:=FrontierEvaluator.scores(site.environment)
		return int(site.inventory.ice)>0 and float(site.environment.ecology)<100 and minf(scores.atmosphere,minf(scores.temperature,scores.water))>=60
	return true
static func validate(value: Variant,manifest: Dictionary) -> String:
	if not value is Dictionary or value.get("version")!=1 or value.get("rules_hash")!=signature() or not value.get("projects") is Dictionary:return "현장 공학 연구 버전·형식 오류"
	if value.projects.size()>config().projects.size():return "연구 과제 수 오류"
	for key in value.projects:
		if not key is String or definition(key).is_empty():return "알 수 없는 공학 과제"
		var row: Variant=value.projects[key]
		if not row is Dictionary or row.get("stage") not in ["prototype","prototype_ready","trial","certified"]:return "공학 단계 오류"
		for field in ["form_id","source_body","body_id","facility_id"]:
			if not row.get(field) is String:return "공학 증거 형식 오류"
		if FrontierUniverse.ordinal_of(manifest,row.source_body)<0 or FrontierUniverse.ordinal_of(manifest,row.body_id)<0:return "공학 원산지 오류"
		if FrontierEcologyCatalog.form(row.form_id).get("environment") not in definition(key).environments:return "연구 원리에 맞지 않는 생물 증거"
		var seconds: float=config().prototype_seconds if row.stage in ["prototype","prototype_ready"] else config().trial_seconds
		if not FrontierUniverse._finite(row.get("progress"),0,seconds):return "공학 진행 수치 오류"
		if row.stage in ["prototype_ready","certified"] and row.progress!=seconds:return "완료되지 않은 공학 검증 기록"
	return ""
static func validate_world(world: Dictionary) -> String:
	var value: Dictionary=world.get("engineering",create())
	var error:=validate(value,world.manifest)
	if not error.is_empty():return error
	var sites: Dictionary=world.get("business",{}).get("sites",{})
	for key in value.projects:
		var row: Dictionary=value.projects[key]
		var observations: Dictionary=world.get("ecology",{}).get("observations",{})
		if not observations.has(row.source_body+":"+row.form_id):return "관측 원본 없는 공학 연구"
		var environment: String=FrontierEcologyCatalog.form(row.form_id).environment
		if world.get("ecology",{}).get("research",{}).get(environment,{}).get("form_id")!=row.form_id:return "기초 분석 없는 공학 연구"
		if row.stage in ["prototype","trial"]:
			if not sites.has(row.body_id) or not FrontierPlanetSupply.operating(sites[row.body_id]) or not sites[row.body_id].buildings.has(row.facility_id):return "공학 실험 시설 연결 오류"
			var expected: String="factory" if row.stage=="prototype" else definition(key).building
			if sites[row.body_id].buildings[row.facility_id].type!=expected:return "공학 실험 시설 종류 오류"
	for site in sites.values():
		for b in site.buildings.values():
			var key: String=b.get("engineering","")
			if not key.is_empty() and (value.projects.get(key,{}).get("stage")!="certified" or definition(key).get("building")!=b.type):return "미검증 공학 설비 개조"
	return ""

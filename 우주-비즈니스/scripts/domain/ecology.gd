class_name FrontierEcology
extends RefCounted
## Sparse world history; a scan never creates a physical specimen.
static func create() -> Dictionary:
	return {"version":"ecology-v1","catalog_hash":FrontierEcologyCatalog.signature(),
		"rules_hash":FrontierUniverse.fingerprint(FrontierEcologyCatalog.config()),
		"planets":{},"observations":{},"research":{},"specimens":{}}

static func profile(body: Dictionary) -> Dictionary:
	var cfg:=FrontierEcologyCatalog.config()
	var climate: Dictionary=cfg.world_climate.get(body.kind,cfg.world_climate.basalt)
	var seed_value: int=int(body.streams.ecology)
	var roll:=FrontierUniverse.derive(seed_value,"native-origin")%100
	var weights: Dictionary=cfg.native_origin_weights
	var result: Dictionary={"environment":cfg.surface_environments.get(body.kind,"gas_cloud"),
		"origin":"sterile" if roll<int(weights.sterile) else ("dormant" if roll<int(weights.sterile)+int(weights.dormant) else "established"),
		"temperature":lerpf(climate.temperature[0],climate.temperature[1],float(FrontierUniverse.derive(seed_value,"temperature")%1001)/1000.0),
		"pressure":lerpf(climate.pressure[0],climate.pressure[1],float(FrontierUniverse.derive(seed_value,"pressure")%1001)/1000.0),
		"moisture":climate.moisture}
	if not body.get("terrain_traits",{}).is_empty():
		result.temperature=body.traits.temperature;result.pressure=body.traits.pressure;result.moisture=float(body.traits.water)/100.0
	var expansion: Dictionary=body.get("ecology_rules",{})
	if int(expansion.get("version",0))>=2:
		var tier:=str(clampi(int(body.planet_tier),1,5))
		weights=expansion.native_origin_by_tier[tier]
		result.origin="sterile" if roll<int(weights.sterile) else ("dormant" if roll<int(weights.sterile)+int(weights.dormant) else "established")
		result.environment=expansion.archetype_environments.get(body.get("traits",{}).get("id",""),result.environment)
		if not body.get("terrain_traits",{}).is_empty():result.pressure=float(result.pressure)*100.0
		result.pressure_unit="kPa";result.rules_version=2
	if body.has("native_ecology"):
		result.origin=body.native_ecology.origin;result.rules_version=3
		result.native_archetype=body.get("traits",{}).get("id","")
	return result

static func ensure_planet(ecology: Dictionary,body: Dictionary) -> Dictionary:
	if ecology.planets.has(body.id):return ecology.planets[body.id]
	var p:=profile(body)
	var lineages: Array=[]
	if body.has("native_ecology"):
		var native: Dictionary={"profile":p,"lineages":body.native_ecology.lineages.duplicate(true),"collected":{},"plot":{},"introductions":{}}
		ecology.planets[body.id]=native
		return native
	for environment in [p.environment,"cave"]:
		if p.origin=="sterile":break
		for category in ["microbe","plant","animal"]:
			if int(p.get("rules_version",0))>=2:
				var count:=int(body.ecology_rules.get("non_animal_lineages_per_layer",{}).get(category,1))
				if category=="animal":count=int(body.ecology_rules.animals_by_tier[str(clampi(int(body.planet_tier),1,5))]["cave" if environment=="cave" else "surface"])
				lineages.append_array(FrontierEcologyCatalog.choose_diverse(FrontierUniverse.derive(int(body.streams.ecology),environment+":"+category),environment,category,count,body.ecology_rules.has("flora_catalog_hash")))
				continue
			for slot in (2 if category=="animal" else 1):
				var selected:=FrontierEcologyCatalog.choose(FrontierUniverse.derive(int(body.streams.ecology),"%s:%s:%d"%[environment,category,slot]),environment,category)
				if not selected.is_empty() and selected not in lineages:lineages.append(selected)
	var record: Dictionary={"profile":p,"lineages":lineages,"collected":{},"plot":{},"introductions":{}}
	ecology.planets[body.id]=record
	return record

static func climate_at(record: Dictionary,point: Vector3,layer: String) -> Dictionary:
	var p: Dictionary=record.profile.duplicate(true)
	# Older planet traits were stored in bar while habitat limits are kPa. Keep the
	# saved profile/ancestry intact and correct the unit only at the climate boundary.
	if not p.has("pressure_unit") and float(p.pressure)<10.0:p.pressure=float(p.pressure)*100.0
	if layer=="cave":
		p.environment="cave";p.temperature=12.0;p.moisture=.5
	if not record.plot.is_empty() and float(record.plot.support_remaining)>0 and point.distance_to(Vector3(record.plot.center[0],record.plot.center[1],record.plot.center[2]))<=float(FrontierEcologyCatalog.config().plot_radius):
		var habitat: Dictionary=FrontierEcologyCatalog.config().habitats[record.plot.environment]
		if int(p.get("rules_version",0))>=3 and not str(p.get("native_archetype","")).is_empty():
			habitat=FrontierEcologyCatalog.habitat({"environment":record.plot.environment,"adaptation_id":p.native_archetype})
		p.environment=record.plot.environment
		for key in ["temperature","pressure","moisture"]:p[key]=(float(habitat[key][0])+float(habitat[key][1]))*.5
		p["restored"]=true
	return p

static func unsuitable(form: Dictionary,climate: Dictionary,layer: String) -> String:
	var aerial: bool=form.get("locomotion_medium","")=="atmosphere"
	if not FrontierEcologyCatalog.ground_form(form) and not aerial:return "수중 또는 공중 이동 서식처가 필요합니다."
	if aerial and (climate.environment!="gas_cloud" or layer!="surface"):return "거대행성의 대기층 서식처가 필요합니다."
	if form.get("locomotion_medium","")=="surface_air":
		if layer!="surface" or climate.environment=="gas_cloud":return "대기가 있는 지상 비행 서식처가 필요합니다."
		if float(climate.pressure)<float(form.flight.minimum_pressure_kpa):return "날개 비행에 필요한 대기 압력이 부족합니다."
	if form.environment!=climate.environment:return "서식 기질이 다릅니다: "+str(form.get("environment_label",form.environment))
	if form.environment=="cave" and layer!="cave":return "빛을 차단한 지하 서식처가 필요합니다."
	if form.environment!="cave" and layer=="cave":return "지표의 빛과 기질이 필요합니다."
	var habitat:=FrontierEcologyCatalog.habitat(form)
	for key in ["temperature","pressure","moisture"]:
		if float(climate[key])<float(habitat[key][0]) or float(climate[key])>float(habitat[key][1]):
			return {"temperature":"온도","pressure":"압력","moisture":"기질 수분"}[key]+" 조건이 맞지 않습니다."
	return ""

static func status(record: Dictionary,form: Dictionary,point: Vector3,layer: String) -> String:
	if record.profile.origin=="sterile":return "absent"
	var climate:=climate_at(record,point,layer)
	if not unsuitable(form,climate,layer).is_empty():return "dormant"
	if record.profile.origin=="dormant":
		if not climate.get("restored",false):return "dormant"
		if float(record.plot.age_seconds)<float(FrontierEcologyCatalog.config().succession_seconds[form.category]):return "dormant"
	return "active"

static func scan(ecology: Dictionary,body_id: String,encounter: Dictionary) -> String:
	var form:=FrontierEcologyCatalog.form(encounter.form_id)
	var key: String=body_id+":"+encounter.form_id
	if ecology.observations.has(key):return "이미 기록한 생명체입니다. 중복 연구 보상은 없습니다."
	ecology.observations[key]={"body_id":body_id,"form_id":form.id,"look_id":encounter.look_id,"origin":"native" if not encounter.get("introduced",false) else "introduced"}
	return "스캔 완료 · "+str(form.name)+" · 우주선 연구실에서 분석할 수 있습니다."

static func analyze(ecology: Dictionary,form_id: String,logistics: Dictionary) -> String:
	var form:=FrontierEcologyCatalog.form(form_id)
	if form.is_empty():return "연구 대상을 찾을 수 없습니다."
	var observed:=false
	for row in ecology.observations.values():
		if row.form_id==form_id:observed=true
	if not observed:return "먼저 현장에서 스캔하세요."
	if ecology.research.has(form.environment):return "이 서식 환경의 기초 분석은 완료했습니다."
	var cost: int=int(FrontierEcologyCatalog.config().analysis_rock_cost)
	if int(logistics.depot_rock)<cost:return "실험용 광물 %d개가 착륙지 창고에 필요합니다."%cost
	logistics.depot_rock-=cost
	ecology.research[form.environment]={"form_id":form_id,"stage":"analyzed"}
	if form.get("locomotion_medium","")=="atmosphere":return "대기층 생리 분석 완료 · 부유 구조와 기질 교환 기록"
	return "대조 실험 완료 · "+str(FrontierEcologyCatalog.habitat(form).principle)+" · 국소 서식지 복원 장치 해금"

static func collect(ecology: Dictionary,body_id: String,encounter: Dictionary) -> String:
	if FrontierEcologyCatalog.form(encounter.form_id).get("locomotion_medium","")=="atmosphere":return "대기층 생명체는 궤도에서 관측합니다. 지상 표본 채집 대상이 아닙니다."
	var record: Dictionary=ecology.planets[body_id]
	if encounter.get("introduced",false):return "이식한 개체군은 현장에 보존합니다."
	if not ecology.observations.has(body_id+":"+encounter.form_id):return "생태 안전을 위해 먼저 스캔하세요."
	if record.collected.has(encounter.id):return "이미 확보한 표본입니다."
	var count:=0
	for sample in ecology.specimens.values():
		if sample.state=="cargo":count+=1
	if int(ecology.get("item_storage_version",0))==0 and count>=int(FrontierEcologyCatalog.config().cargo_capacity):return "표본 보관 공간이 가득 찼습니다."
	var id: String=(body_id+":"+encounter.id).sha256_text()
	ecology.specimens[id]={"id":id,"source_body":body_id,"source_encounter":encounter.id,"form_id":encounter.form_id,"look_id":encounter.look_id,"state":"cargo","destination":""}
	record.collected[encounter.id]=id
	return "생체 표본을 확보했습니다."

static func restore_plot(ecology: Dictionary,body_id: String,environment_id: String,point: Vector3,layer: String,logistics: Dictionary) -> String:
	if environment_id=="gas_cloud":return "대기층에는 지상 실험 구획을 설치할 수 없습니다."
	var record: Dictionary=ecology.planets[body_id]
	if not ecology.research.has(environment_id):return "해당 서식 환경의 기초 분석이 필요합니다."
	if environment_id!=("cave" if layer=="cave" else record.profile.environment):return "이곳의 기질에 맞는 서식지 복원 기술을 선택하세요."
	if not record.plot.is_empty():return "이 행성에는 이미 실험 구획이 설치돼 있습니다."
	var cost: int=int(FrontierEcologyCatalog.config().plot_rock_cost)
	if int(logistics.depot_rock)<cost:return "장치 제작용 광물 %d개가 착륙지 창고에 필요합니다."%cost
	logistics.depot_rock-=cost
	record.plot={"environment":environment_id,"center":[point.x,point.y,point.z],"support":"ship_tether","biomass":0.0,"age_seconds":0.0,"support_remaining":float(FrontierEcologyCatalog.config().plot_support_seconds)}
	return "우주선 연결 실험 구획 설치 · 반경 %dm · 전력·수분 순환·급이 지원 가동"%int(FrontierEcologyCatalog.config().plot_radius)

static func introduce(ecology: Dictionary,body_id: String,sample_id: String,point: Vector3,layer: String) -> String:
	if not ecology.specimens.has(sample_id) or ecology.specimens[sample_id].state!="cargo":return "운송 중인 실물 표본이 필요합니다."
	var sample: Dictionary=ecology.specimens[sample_id]
	var record: Dictionary=ecology.planets[body_id]
	if not ecology.research.has(FrontierEcologyCatalog.form(sample.form_id).environment):return "방출 전 기초 분석이 필요합니다."
	if sample.source_body==body_id:return "다른 행성으로 운송한 표본을 선택하세요."
	var climate:=climate_at(record,point,layer)
	if not climate.get("restored",false):return "먼저 관리 가능한 실험 구획을 설치하세요."
	var error:=unsuitable(FrontierEcologyCatalog.form(sample.form_id),climate,layer)
	if not error.is_empty():return error
	for row in record.introductions.values():
		if row.form_id==sample.form_id:return "이 형태의 이식 시험은 이미 진행 중입니다."
	record.introductions[sample_id]={"id":sample_id,"form_id":sample.form_id,"look_id":sample.look_id,"position":[point.x,point.y,point.z],"layer":layer}
	sample.state="introduced";sample.destination=body_id
	return "격리 시험 구획에 이식했습니다. 생물량과 토양 형성이 탐사 시간에 따라 증가합니다."

static func resupply_plot(ecology: Dictionary,body_id: String,logistics: Dictionary) -> String:
	var plot: Dictionary=ecology.planets[body_id].plot
	if plot.is_empty():return "먼저 관리 구획을 설치하세요."
	var cfg:=FrontierEcologyCatalog.config()
	if float(plot.support_remaining)>float(cfg.plot_support_seconds)-60:return "지원 팩이 아직 충분합니다."
	if int(logistics.depot_rock)<int(cfg.plot_resupply_rock_cost):return "여과·영양 팩 제작용 광물 %d개가 착륙지 창고에 필요합니다."%int(cfg.plot_resupply_rock_cost)
	logistics.depot_rock-=int(cfg.plot_resupply_rock_cost)
	plot.support_remaining=float(cfg.plot_support_seconds)
	return "여과·영양 팩을 보충하고 우주선 지원 연결을 정비했습니다."

static func advance(ecology: Dictionary,body_id: String,seconds: float) -> void:
	var record: Dictionary=ecology.planets[body_id]
	if record.plot.is_empty() or float(record.plot.support_remaining)<=0:return
	var dt: float=minf(clampf(seconds,0,1),float(record.plot.support_remaining))
	record.plot.age_seconds=minf(1000000,float(record.plot.age_seconds)+dt)
	var point:=Vector3(record.plot.center[0],record.plot.center[1],record.plot.center[2])
	var layer: String="cave" if record.plot.environment=="cave" else "surface"
	var supported: int=record.introductions.size()
	# Biological support is driven by ancestry and the managed habitat, never visibility or LOD.
	for lineage in record.lineages:
		var form:=FrontierEcologyCatalog.form(lineage.form_id)
		if status(record,form,point,layer)=="active":supported+=1
	record.plot.biomass=minf(100.0,float(record.plot.biomass)+dt*supported*.035)
	record.plot.support_remaining=maxf(0,float(record.plot.support_remaining)-dt)

static func validate(value: Variant,manifest: Dictionary) -> String:
	if not value is Dictionary or value.get("version")!="ecology-v1":return "생태 저장 버전 오류"
	if value.get("catalog_hash")!=FrontierEcologyCatalog.signature() or value.get("rules_hash")!=FrontierUniverse.fingerprint(FrontierEcologyCatalog.config()):return "생태 원형 또는 규칙 버전이 달라 원본 저장을 보존합니다."
	if manifest.settings.has("ecology_rules") and not FrontierEcologyCatalog.extension_compatible(str(manifest.settings.ecology_rules.get("catalog_hash",""))):return "추가 생물 카탈로그 버전이 달라 원본 저장을 보존합니다."
	if manifest.settings.get("ecology_rules",{}).has("flora_catalog_hash") and manifest.settings.ecology_rules.flora_catalog_hash!=FrontierEcologyCatalog.flora_signature():return "추가 식물·미생물 카탈로그 버전이 달라 원본 저장을 보존합니다."
	if not FrontierExpeditionBusiness.integer(value.get("item_storage_version",0),0,1):return "표본 아이템 저장 버전 오류"
	for key in ["planets","observations","research","specimens"]:
		if not value.get(key) is Dictionary:return "생태 기록 형식 오류: "+key
	for id in value.planets:
		if not id is String or FrontierUniverse.ordinal_of(manifest,id)<0:return "생태 행성 주소 오류"
		var record: Variant=value.planets[id]
		if not record is Dictionary:return "행성 생태 기록 오류"
		for key in ["profile","collected","plot","introductions"]:
			if not record.get(key) is Dictionary:return "행성 생태 필드 오류"
		if FrontierUniverse.fingerprint(record.profile)!=FrontierUniverse.fingerprint(profile(FrontierUniverse.body_from_id(manifest,id))):return "행성 고유 생태 원형 오류"
		var lineage_limit: int=int(manifest.settings.get("ecology_rules",{}).get("native_biota",{}).get("max_lineages_per_planet",24 if manifest.settings.has("ecology_rules") else 8))
		if not record.get("lineages") is Array or record.lineages.size()>lineage_limit:return "고유 생명 계통 오류"
		var expected: Dictionary={"planets":{}}
		if ensure_planet(expected,FrontierUniverse.body_from_id(manifest,id)).lineages!=record.lineages:return "고유 생명 계통이 시드와 다릅니다."
		if not record.plot.is_empty():
			var plot: Dictionary=record.plot
			if plot.get("environment") not in [record.profile.environment,"cave"] or not FrontierUniverse._vector3_array(plot.get("center")) or plot.get("support")!="ship_tether" or not FrontierUniverse._finite(plot.get("biomass"),0,100) or not FrontierUniverse._finite(plot.get("age_seconds"),0,1000000) or not FrontierUniverse._finite(plot.get("support_remaining"),0,float(FrontierEcologyCatalog.config().plot_support_seconds)):return "생태 실험 구획 오류"
			if not value.research.has(plot.environment):return "분석되지 않은 생태 실험 구획"
		for encounter_id in record.collected:
			if not encounter_id is String or not record.collected[encounter_id] is String or not value.specimens.has(record.collected[encounter_id]):return "채집 표본 연결 오류"
			var specimen: Variant=value.specimens[record.collected[encounter_id]]
			if not specimen is Dictionary or specimen.get("source_body")!=id or specimen.get("source_encounter")!=encounter_id:return "채집 표본의 원산지 오류"
			var identity:=FrontierEcologyPlacement.resolve_identity(FrontierUniverse.body_from_id(manifest,id),record,encounter_id)
			if identity.is_empty() or identity.form_id!=specimen.get("form_id") or identity.look_id!=specimen.get("look_id"):return "채집 개체가 행성 시드와 다릅니다."
		for sample_id in record.introductions:
			var introduction: Variant=record.introductions[sample_id]
			if not introduction is Dictionary or not _identity_valid(introduction) or introduction.get("id")!=sample_id or not FrontierUniverse._vector3_array(introduction.get("position")) or introduction.get("layer") not in ["surface","cave"]:return "이식 개체 기록 오류"
			if record.plot.is_empty() or not value.specimens.has(sample_id):return "이식 표본 연결 오류"
			var sample: Variant=value.specimens[sample_id]
			if not sample is Dictionary or sample.get("state")!="introduced" or sample.get("destination")!=id or sample.get("form_id")!=introduction.form_id or sample.get("look_id")!=introduction.look_id:return "이식 표본이 중복되거나 원본과 다릅니다."
	for key in value.observations:
		var row: Variant=value.observations[key]
		if not row is Dictionary or not _identity_valid(row) or not row.get("body_id") is String or not value.planets.has(row.body_id) or key!=row.body_id+":"+row.form_id or row.get("origin") not in ["native","introduced"]:return "관측 기록 오류"
		var identified:=false
		var record: Dictionary=value.planets[row.body_id]
		if row.origin=="native" and record.profile.origin!="sterile":
			for lineage in record.lineages:
				if lineage.form_id==row.form_id and lineage.look_id==row.look_id:identified=true
		elif row.origin=="introduced":
			for introduction in record.introductions.values():
				if introduction.form_id==row.form_id and introduction.look_id==row.look_id:identified=true
		if not identified:return "관측 개체가 행성의 고유 계통 또는 이식 기록과 다릅니다."
	for environment_id in value.research:
		var research: Variant=value.research[environment_id]
		if not research is Dictionary or not research.get("form_id") is String or research.get("stage")!="analyzed":return "생태 연구 기록 오류"
		var form:=FrontierEcologyCatalog.form(research.form_id)
		if form.is_empty() or environment_id!=form.environment:return "연구 환경 오류"
		var observed:=false
		for row in value.observations.values():
			if row.form_id==research.form_id:observed=true
		if not observed:return "관측되지 않은 연구 기록"
	var cargo_count:=0
	for id in value.specimens:
		var sample: Variant=value.specimens[id]
		if not sample is Dictionary or not _identity_valid(sample) or sample.get("id")!=id or not sample.get("source_body") is String or not sample.get("source_encounter") is String or not sample.get("destination") is String or sample.get("state") not in ["cargo","introduced"]:return "생체 표본 형식 오류"
		if id!=(sample.source_body+":"+sample.source_encounter).sha256_text() or not value.planets.has(sample.source_body):return "생체 표본 식별 오류"
		if value.planets[sample.source_body].collected.get(sample.source_encounter)!=id:return "채집 원본이 없는 생체 표본"
		if not value.observations.has(sample.source_body+":"+sample.form_id):return "미관측 생체 표본"
		if sample.state=="cargo":
			cargo_count+=1
			if sample.destination!="":return "화물과 이식 상태 중복"
		else:
			if sample.destination==sample.source_body or not value.planets.has(sample.destination) or not value.planets[sample.destination].introductions.has(id):return "이식 목적지 오류"
	if int(value.get("item_storage_version",0))==0 and cargo_count>int(FrontierEcologyCatalog.config().cargo_capacity):return "표본 보관 용량 초과"
	return preload("res://scripts/domain/species_functions.gd").validate(value)

static func _identity_valid(row: Dictionary) -> bool:
	if not row.get("form_id") is String or not row.get("look_id") is String:return false
	return not FrontierEcologyCatalog.look(row.form_id,row.look_id).is_empty()

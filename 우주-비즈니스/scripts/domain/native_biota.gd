class_name FrontierNativeBiota
extends RefCounted
## A species has one natural home planet, including within a stellar system.
## Assignment is complete at galaxy creation and independent of visit order.
static var _validated: Dictionary={}
const WorldSnapshot=preload("res://scripts/persistence/world_snapshot.gd")

static func enabled(m: Dictionary) -> bool:
	return m.settings.get("ecology_rules",{}).has("native_biota")

static func spatial_weight(point: Vector2,sun: Vector2,rules: Dictionary) -> float:
	if point.x>sun.x:return float(rules.outward_weight)
	if point.x<0:return float(rules.off_corridor_weight)
	var y:=point.y/float(rules.corridor_width)
	return float(rules.off_corridor_weight)+float(rules.coreward_weight)*exp(-.5*y*y)

static func compatible(form: Dictionary,body: Dictionary,climate: Dictionary) -> bool:
	var aerial: bool=form.get("locomotion_medium","")=="atmosphere"
	if aerial!=(body.kind in ["gas_giant","ice_giant"]):return false
	if not aerial and not FrontierEcologyCatalog.ground_form(form):return false
	if form.has("native_archetypes") and body.traits.id not in form.native_archetypes:return false
	var c:=climate.duplicate(true)
	var layer: String="cave" if form.environment=="cave" else "surface"
	if layer=="cave":c.temperature=12.0;c.moisture=.5;c.environment="cave"
	return FrontierEcology.unsuitable(form,c,layer).is_empty()

static func create(m: Dictionary) -> Dictionary:
	var rules: Dictionary=m.settings.ecology_rules.native_biota
	var forms:=FrontierEcologyCatalog.all_forms();var counts: Dictionary={}
	for form in forms:
		for archetype in form.get("native_archetypes",[]):counts[archetype]=int(counts.get(archetype,0))+1
	var kinds: Array=counts.keys();kinds.sort()
	var total:=0.0
	for amount in counts.values():total+=float(amount)
	var quotas: Dictionary={};var assigned_quota:=0
	for tier in range(1,6):
		var budget:=int(rules.planet_budget_by_tier[tier-1]);var used:=0;var keys: Array=[]
		for kind in kinds:
			var key: String=str(tier)+":"+str(kind);quotas[key]=maxi(1,floori(float(counts[kind])/total*budget));used+=int(quotas[key]);keys.append(key)
		keys.sort_custom(func(a,b):return FrontierUniverse.derive(int(m.seed),"quota:"+a)<FrontierUniverse.derive(int(m.seed),"quota:"+b))
		for i in maxi(0,budget-used):quotas[keys[i%keys.size()]]+=1
		for key in keys:assigned_quota+=int(quotas[key])
	var sun:=FrontierUniverse.map_position(m,0);var systems: Array=[]
	var count:=int(m.settings.planet_count)/int(m.settings.planets_per_system)
	for index in range(1,count):
		var point:=FrontierUniverse.map_position(m,index);var weight:=spatial_weight(point,sun,rules)
		var uniform: float=(float(FrontierUniverse.derive(int(m.seed),"native-system:"+str(index)))+1.0)/2147483649.0
		systems.append({"index":index,"score":-log(uniform)/weight,"weight":weight})
	systems.sort_custom(func(a,b):return a.score<b.score if not is_equal_approx(a.score,b.score) else a.index<b.index)
	var worlds: Dictionary={};var candidates: Dictionary={};var taken: Dictionary={};var inspected:=0
	for system_row in systems.slice(0,mini(systems.size(),int(rules.candidate_system_limit))):
		var system_index:=int(system_row.index);inspected+=1
		for slot in FrontierUniverse.body_count(m,system_index):
			var ordinal:=FrontierUniverse.first_ordinal(m,system_index)+slot
			var body:=FrontierUniverse.body(m,ordinal,false)
			if body.origin!="fictional" or body.get("traits",{}).is_empty():continue
			var key: String=str(body.planet_tier)+":"+str(body.traits.id)
			if int(taken.get(key,0))>=int(quotas.get(key,0)):continue
			if body.kind not in ["gas_giant","ice_giant"] and FrontierCorporateSites.body_info(m,ordinal).get("managed",false):continue
			var climate:=FrontierEcology.profile(body)
			var aerial: bool=body.kind in ["gas_giant","ice_giant"]
			var example: Dictionary={"environment":"gas_cloud" if aerial else climate.environment,"adaptation_id":body.traits.id,"locomotion_medium":"atmosphere" if aerial else "ground"}
			if not FrontierEcology.unsuitable(example,climate,"surface").is_empty():continue
			var id:=str(ordinal);taken[key]=int(taken.get(key,0))+1
			worlds[id]={"lineages":[],"origin":"established" if FrontierUniverse.derive(int(m.seed),"native-origin:"+id)%100<int(rules.established_percent_by_tier[int(body.planet_tier)-1]) else "dormant","tier":body.planet_tier,"archetype":body.traits.id,"coreward":float(system_row.weight)>1.0,"spatial_weight_milli":roundi(float(system_row.weight)*1000.0)}
			candidates[id]={"body":body,"climate":climate}
		if worlds.size()>=assigned_quota:break
	var ordered:=forms.duplicate();ordered.sort_custom(func(a,b):return FrontierUniverse.derive(int(m.seed),"native-form:"+a.id)<FrontierUniverse.derive(int(m.seed),"native-form:"+b.id))
	var matches: Dictionary={};var unavailable: Array=[];var assigned:=0
	for form in ordered:
		var group: String=str(form.get("adaptation_id","legacy"))+":"+str(form.environment)+":"+str(form.get("locomotion_medium",""))+":"+str(FrontierEcologyCatalog.ground_form(form))
		if not matches.has(group):
			var options: Array=[]
			for id in candidates:
				if compatible(form,candidates[id].body,candidates[id].climate):options.append(id)
			options.sort_custom(func(a,b):return FrontierUniverse.derive(int(m.seed),"native-destination:"+a)<FrontierUniverse.derive(int(m.seed),"native-destination:"+b))
			matches[group]=options
		var target: String="";var best:=INF
		for id in matches[group]:
			var record: Dictionary=worlds[id]
			if record.lineages.size()>=int(rules.max_lineages_per_planet):continue
			var tier:=int(record.tier)-1
			var desired: float=float(rules.species_budget_weight_by_tier[tier])/float(rules.planet_budget_by_tier[tier])
			var score: float=float(record.lineages.size()+1)/desired
			if score<best:best=score;target=id
		if target.is_empty():unavailable.append(form.id);continue
		var look_id:=FrontierEcologyCatalog.look_for_seed(form.id,FrontierUniverse.derive(int(m.seed),"native-look:"+form.id))
		worlds[target].lineages.append({"form_id":form.id,"look_id":look_id});assigned+=1
	for id in worlds.keys():
		if worlds[id].lineages.is_empty():worlds.erase(id)
	return {"version":1,"planets":worlds,"assigned_species":assigned,"unassigned_species":unavailable,"inspected_systems":inspected,"catalog_hash":FrontierEcologyCatalog.biota_signature()}

static func validate(m: Dictionary) -> String:
	if not enabled(m):return ""
	var value: Variant=m.get("native_biota")
	if not value is Dictionary or value.get("version")!=1 or not value.get("planets") is Dictionary or not value.get("unassigned_species") is Array:return "행성 고유 생태 배정 형식 오류"
	if value.get("catalog_hash")!=FrontierEcologyCatalog.biota_signature():return "8,000종 생태 카탈로그 버전이 달라 원본 저장을 보존합니다."
	var owned:=WorldSnapshot._entry(m)
	var signature: String="owned:"+str(owned.digest) if not owned.is_empty() else FrontierUniverse.fingerprint({"biota":value,"settings":m.settings,"seed":m.seed,"id":m.id})
	if _validated.has(signature):return ""
	var seen: Dictionary={};var limit:=int(m.settings.ecology_rules.native_biota.max_lineages_per_planet)
	for id in value.planets:
		if not id is String or not id.is_valid_int() or str(int(id))!=id or int(id)<8 or int(id)>=int(m.settings.planet_count):return "생태 원산 행성 주소 오류"
		var record: Variant=value.planets[id]
		if not record is Dictionary or record.get("origin") not in ["dormant","established"] or not record.get("lineages") is Array or record.lineages.is_empty() or record.lineages.size()>limit:return "고유 생태 계통 배정 오류"
		var body:=FrontierUniverse.body(m,int(id));var climate:=FrontierEcology.profile(body)
		if body.kind not in ["gas_giant","ice_giant"] and not FrontierUniverse.landable(body):return "접근할 수 없는 관리 행성에 자연종이 배정되었습니다."
		for row in record.lineages:
			if not row is Dictionary or not row.get("form_id") is String or seen.has(row.form_id):return "같은 기본종이 다른 행성에 중복 배정되었습니다."
			var form:=FrontierEcologyCatalog.form(row.form_id)
			if form.is_empty() or FrontierEcologyCatalog.look(row.form_id,str(row.get("look_id",""))).is_empty() or not compatible(form,body,climate):return "고유종의 외형 또는 원산 환경 오류"
			seen[row.form_id]=true
	if seen.size()!=int(value.get("assigned_species",-1)):return "고유종 배정 수량 오류"
	for id in value.unassigned_species:
		if not id is String or seen.has(id) or FrontierEcologyCatalog.form(id).is_empty():return "미배정 기본종 목록 오류"
		if FrontierEcologyCatalog.form(id).get("collection","")=="biota-7000":return "새 기본종의 원산 행성이 누락되었습니다."
		seen[id]=true
	if seen.size()!=FrontierEcologyCatalog.all_forms().size():return "생태 카탈로그와 원산지 배정 수량이 다릅니다."
	if _validated.size()>8:_validated.clear()
	_validated[signature]=true
	return ""

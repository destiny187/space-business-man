class_name FrontierSurfaceSurvey
extends RefCounted
## A shared host-authored inspection result. No client-provided discovery or reward.
static func key(body_id: String,row: Dictionary) -> String:
	return body_id+"/"+str(row.kind)+"/"+str(row.get("form_id",row.get("resource","")))
static func target(world: Dictionary,actor: String,aim: Vector3,wildlife_observers: Array[Vector3]=[]) -> Dictionary:
	if not FrontierCrewSurface.landed(world) or not world.crew.members.has(actor):return {}
	var member: Dictionary=world.crew.members[actor]
	if member.area!="surface" or not FrontierCrewSurface.owns(member,"survey_scanner"):return {}
	var native:=FrontierNativeIncidents.scan_target(world,actor,aim)
	var bio:=FrontierCrewSurface.target(world,actor,aim,wildlife_observers)
	if not bio.is_empty():bio=bio.duplicate(true);bio.kind="biology"
	var body:=FrontierUniverse.body_from_id(world.manifest,world.crew.landing.body_id)
	var origin:=FrontierCrewWorld.vector(member.position)+Vector3.UP*1.72
	var terrain:=FrontierCrewSurface.field(world)
	var discovery:=FrontierExplorationDiscoveries.target(world,actor,aim)
	var corporation:=FrontierCorporations.target(world,actor,aim)
	var selected: Dictionary=bio
	var nearest: float=origin.distance_to(bio.point+Vector3.UP) if not bio.is_empty() else float(FrontierCrewSurface.config().scan_distance)
	for vein in FrontierExpeditionBusiness.veins(body,origin):
		# Buried resources require exposed space; generic surface scan cannot see through rock.
		if vein.get("underground",false):continue
		if Vector2(float(vein.position[0])-origin.x,float(vein.position[2])-origin.z).length()>float(FrontierCrewSurface.config().scan_distance)+2:continue
		var point:=FrontierExpeditionBusiness.ground(terrain,vein.position[0],vein.position[2])
		if not point.is_finite():continue
		var center:=point+Vector3.UP
		var delta:=center-origin;var along:=delta.dot(aim)
		if along<=0 or delta.length()>nearest or (delta-aim*along).length()>1.25:continue
		if not FrontierCrewSurface.visible_in_field(terrain,origin,center):continue
		selected=vein.duplicate(true);selected.kind="mineral";selected.point=point;nearest=delta.length()
	if not native.is_empty() and (selected.is_empty() or origin.distance_to(native.point)<origin.distance_to(selected.point)):
		selected=native;nearest=origin.distance_to(native.point)
	if not discovery.is_empty() and (selected.is_empty() or origin.distance_to(discovery.point)<nearest):
		selected=discovery;nearest=origin.distance_to(discovery.point)
	if not corporation.is_empty() and (selected.is_empty() or origin.distance_to(corporation.point)<nearest):return corporation
	return selected
static func known(world: Dictionary,row: Dictionary) -> bool:
	if row.kind=="corporation":return FrontierCorporations.known(world,row)
	if row.kind=="native_incident":return world.incidents.records[row.id].native_observed
	if row.kind=="discovery":return FrontierExplorationDiscoveries.known(world,row)
	var body_id: String=world.crew.landing.body_id
	if row.kind=="biology":return world.ecology.observations.has(body_id+":"+row.form_id)
	return world.crew.get("survey",{}).has(key(body_id,row))
static func record(world: Dictionary,row: Dictionary,actor: String="") -> void:
	if row.kind=="corporation":FrontierCorporations.record(world,row);return
	if row.kind=="native_incident":FrontierNativeIncidents.observe(world,row.id);return
	if row.kind=="discovery":FrontierExplorationDiscoveries.scan(world,row,actor);return
	if row.kind=="biology":FrontierEcology.scan(world.ecology,world.crew.landing.body_id,row);return
	if not world.crew.has("survey"):world.crew.survey={}
	var site:=FrontierExpeditionBusiness.site(world)
	if not site.is_empty():FrontierRobotWork.discover(site,row.resource)
	var id:=key(world.crew.landing.body_id,row)
	# Discovery is per planet/material, not an unbounded entry for every physical rock.
	FrontierExpeditionResearch.record(world,world.crew.landing.body_id,row.resource,row.id,int(row.required_tier),"scan",actor)
	world.crew.survey[id]={"body_id":world.crew.landing.body_id,"resource":row.resource,"vein_id":row.id,"tier":int(row.required_tier)}
static func biology_info(form: Dictionary) -> Dictionary:
	var c:=FrontierEcologyCatalog.config()
	var notes: Array=[{"icon":"scan","text":"관찰 → 기초 분석 → 서식지 복원"},{"icon":"inventory","text":"실물 표본 → 다른 행성 시험 구획 이식"}]
	if form.get("locomotion_medium","")=="atmosphere":notes=[{"icon":"scan","text":"궤도 관측 → 대기층 생리 분석"}]
	for project in FrontierFieldEngineering.config().projects.values():
		if form.environment in project.environments:notes.append({"icon":"build","text":project.name+" · 연구·설치 후 처리 속도 +%d%%"%roundi((float(project.factor)-1)*100)})
	var habitat:=FrontierEcologyCatalog.habitat(form)
	return {"kind":"biology","name":form.name,"icon":FrontierResourceIcons.specimen_id(form),"subtitle":form.environment_label+" · "+form.habitat_note,"notes":notes,"condition":"정착 조건: %s · %.0f~%.0f°C"%[habitat.get("label",form.environment_label),float(habitat.get("temperature",[0,0])[0]),float(habitat.get("temperature",[0,0])[1])]}
static func result(world: Dictionary,row: Dictionary,actor: String) -> Dictionary:
	if row.kind=="corporation":return FrontierCorporations.info(row)
	if row.kind=="native_incident":return FrontierNativeIncidents.info(world,row)
	if row.kind=="discovery":return FrontierExplorationDiscoveries.result(world,row)
	if row.kind=="biology":
		var info:=biology_info(FrontierEcologyCatalog.form(row.form_id))
		info.id=row.id;info.point=[row.point.x,row.point.y,row.point.z];info.form_id=row.form_id
		info.action="Q  표본 채집 · 4m 이내" if not row.get("introduced",false) else "이식 개체 · 현장 보존"
		if world.ecology.planets[world.crew.landing.body_id].collected.has(row.id):info.action="표본 확보 완료"
		return info
	var site:=FrontierExpeditionBusiness.site(world)
	var remaining: int=int(site.get("remaining",{}).get(row.id,row.capacity))
	var tool:=FrontierEquipment.active(world.crew.members[actor])
	var usable: bool=tool.get("kind")=="miner" and int(tool.get("tier",0))>=int(row.required_tier)
	var action: String="클릭 유지  채집" if usable else "채집기 %d등급 장착 필요"%int(row.required_tier)
	if remaining<=0:action="고갈된 광맥"
	var usage: PackedStringArray=[]
	for recipe in FrontierEquipment.config().items.values():
		if int(recipe.get("cost",{}).get(row.resource,0))>0:usage.append(recipe.name)
	for recipe in FrontierProductionTier2.config().products.values():
		if int(recipe.cost.get(row.resource,0))>0:usage.append(recipe.name)
	return {"kind":"mineral","id":row.id,"name":FrontierCatalog.entry("resources",row.resource).name,"icon":row.resource,"point":[row.point.x,row.point.y,row.point.z],"subtitle":"광물 조사 · 채집기 %d등급 필요"%int(row.required_tier),"remaining":remaining,"capacity":int(row.capacity),"notes":[{"icon":"inventory","text":"매장량 %d / %d"%[remaining,int(row.capacity)]},{"icon":"build","text":"제작: "+(" · ".join(usage.slice(0,2)) if not usage.is_empty() else "현장 재료 · 상세 용도 조사 중")}],"condition":"같은 행성의 같은 자원은 기록을 공유합니다.","action":action}
static func valid(records: Variant) -> bool:
	if not records is Dictionary or records.size()>1000000*FrontierMinerals.all().size():return false
	for id in records:
		var row: Variant=records[id]
		if not id is String or not row is Dictionary:return false
		for field in ["body_id","resource","vein_id"]:
			if not row.get(field) is String or str(row[field]).length()>128:return false
		if id!=str(row.body_id)+"/mineral/"+str(row.resource):return false
		if FrontierCatalog.entry("resources",row.resource).is_empty() or not FrontierUniverse._finite(row.get("tier"),1,3):return false
	return true

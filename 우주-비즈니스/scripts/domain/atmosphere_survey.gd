class_name FrontierAtmosphereSurvey
extends RefCounted
## A held orbital observation resolves only locally native atmospheric lineages.
static func target(manifest: Dictionary,nav: Dictionary,aim: Vector3) -> Dictionary:
	if not FrontierNativeBiota.enabled(manifest) or nav.mode!="idle":return {}
	var rules: Dictionary=manifest.settings.ecology_rules.native_biota.atmosphere_survey
	var origin:=FrontierCrewWorld.vector(nav.position);var best: Dictionary={};var closest:=INF
	for slot in FrontierUniverse.body_count(manifest,int(nav.system)):
		var ordinal:=FrontierUniverse.first_ordinal(manifest,int(nav.system))+slot
		var body:=FrontierUniverse.body(manifest,ordinal,false)
		if body.kind not in ["gas_giant","ice_giant"] or body.origin!="fictional":continue
		var offset:=FrontierUniverse.position(manifest,ordinal,float(nav.orbit_time))-origin
		var clearance:=offset.length()-FrontierUniverse.navigation_radius(body)
		if clearance<0 or clearance>float(rules.range_above_envelope) or offset.normalized().dot(aim.normalized())<float(rules.aim_dot):continue
		if offset.length()<closest:closest=offset.length();best=body
	return best

static func observable(body: Dictionary) -> Array:
	var result: Array=[]
	for row in body.get("native_ecology",{}).get("lineages",[]):
		var form:=FrontierEcologyCatalog.form(row.form_id)
		if form.get("locomotion_medium","")!="atmosphere":continue
		if body.native_ecology.origin=="dormant" and form.category=="animal":continue
		result.append(row)
	return result

static func step(authority: FrontierCrewAuthority,peer: int,local: Dictionary,delta: float) -> bool:
	var body:=target(local.manifest,local.crew.navigation,authority.inputs[peer].aim)
	if body.is_empty():return false
	var previous: Dictionary=authority.scans.get(peer,{})
	# Hold the confirmed result until release, so continued input does not skip it.
	if previous.get("kind","")=="atmosphere" and previous.get("body_id","")==body.id and previous.get("known",false):return true
	var candidates:=observable(body);var selected: Dictionary={}
	for row in candidates:
		if not authority.world.ecology.observations.has(body.id+":"+row.form_id):selected=row;break
	var id: String=body.id+":"+str(selected.get("form_id","atmosphere-clear"))
	var progress: float=float(previous.get("progress",0)) if previous.get("id","")==id else 0.0
	progress=minf(1.0,progress+delta/float(local.manifest.settings.ecology_rules.native_biota.atmosphere_survey.scan_seconds))
	var scan: Dictionary={"kind":"atmosphere","id":id,"body_id":body.id,"progress":minf(.99,progress),"known":false,"sample":selected.duplicate(),"empty":candidates.is_empty(),"origin":body.get("native_ecology",{}).get("origin","sterile")}
	authority.scans[peer]=scan
	if progress<1:return true
	if not selected.is_empty():
		var draft:=authority.world.duplicate(true)
		FrontierEcology.ensure_planet(draft.ecology,body)
		FrontierEcology.scan(draft.ecology,body.id,selected)
		draft.ecology.observations[id].observed_layer="atmosphere"
		draft.crew.revision+=1
		if not authority.save_world.call(draft):
			authority.scans.erase(peer);authority.stopped=true;authority.error="대기층 관측 저장 실패로 공동 세계를 정지했습니다.";return true
		authority.world=draft
	scan.progress=1.0;scan.known=true
	return true

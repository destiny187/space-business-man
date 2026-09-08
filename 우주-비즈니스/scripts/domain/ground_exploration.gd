class_name FrontierGroundExploration
extends RefCounted
## First treatment inputs are visible surface deposits; no prerequisite traps.
static var cache: Dictionary={}
static func deposits(body: Dictionary) -> Array:
	if int(body.get("ground_rules",{}).get("version",0))<2 or int(body.planet_tier)!=2:return []
	var key: String=body.id+":"+FrontierUniverse.fingerprint(body.ground_rules)
	if cache.has(key):return cache[key].duplicate(true)
	var profile: Dictionary=body.get("mineral_profile",{})
	if profile.is_empty():return []
	var materials: Array=profile.primary+profile.secondary
	var cfg: Dictionary=body.ground_rules.expedition
	var field:=FrontierTerrainField.new();field.configure(int(body.streams.terrain),[],24.0,body.get("terrain_traits",{}))
	var rows: Array=[]
	for resource in ["silicon","phosphate"]:
		if resource not in materials:continue
		var phase:=float(FrontierUniverse.derive(int(body.seed),"outer:"+resource)%6283)/1000.0
		for i in int(cfg.samples):
			var angle:=phase+float(i)*.11;var radius:=float(cfg.radius)+float(i%int(cfg.radius_spread))
			var p:=FrontierExpeditionBusiness.ground(field,sin(angle)*radius,cos(angle)*radius,.7)
			if not p.is_finite():continue
			rows.append({"id":"expedition2:"+resource,"resource":resource,"required_tier":1,"capacity":int(cfg.capacity),"position":[p.x,0,p.z]});break
	cache[key]=rows.duplicate(true);return rows
static func inputs(body: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for row in deposits(body):
		if row.resource=="silicon":result.water="freshwater_module"
		elif row.resource=="phosphate":result.biolab="soil_activation_pack"
	return result
static func summary(body: Dictionary) -> String:
	if int(body.get("ground_rules",{}).get("version",0))<2 or int(body.planet_tier)!=2:return ""
	var items:=inputs(body)
	return ("현지 복원 추천 · 규소/인산염 외곽 탐사\n" if items.size()==2 else "지역 처리재 "+("규소" if items.has("water") else "인산염" if items.has("biolab") else "기초 재료")+"\n")

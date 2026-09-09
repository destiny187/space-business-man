class_name FrontierGroundProgression
extends RefCounted
## Manifest-snapshotted distribution. Old manifests retain their old deposits.
static var _config: Dictionary={}
static var _starter_cache: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/ground_progression.json"))
	return _config
static func processing_seconds(body: Dictionary) -> float:
	var e: Dictionary=body.traits;var c:=FrontierExpeditionBusiness.config()
	var air:=maxf(maxf(maxf(0,absf(float(e.oxygen)-.21)-.08)/float(c.oxygen_rate),maxf(0,absf(float(e.pressure)-1)-40.0/110.0)/float(c.pressure_rate)),maxf(0,float(e.toxicity)-40)/float(c.toxicity_rate))
	var heat:=maxf(0,absf(float(e.temperature)-18)-40.0/1.7)/float(c.thermal_rate)
	var water:=ceilf(maxf(0,40-float(e.water))/float(c.water_per_ice))*float(c.water_cycle_seconds)
	return maxf(air,maxf(heat,water))+maxf(float(c.contract_stable_seconds),float(c.contract_ecology_minimum)/float(c.biolab_rate))
static func intro_candidate(body: Dictionary) -> bool:
	if not FrontierUniverse.landable(body) or int(body.planet_tier)!=1 or body.get("traits",{}).is_empty():return false
	var t: Dictionary=body.traits
	# Prefer a meaningful, bounded restoration task; never change the generated climate.
	return float(t.temperature)>-55 and float(t.temperature)<65 and float(t.toxicity)<85 and processing_seconds(body)>=150 and processing_seconds(body)<=float(body.get("ground_rules",config()).intro_max_processing_seconds) and starter(body).size()>=5
static func starter(body: Dictionary) -> Array:
	var key: String=body.id+":"+FrontierUniverse.fingerprint(body.ground_rules)
	if _starter_cache.has(key):return _starter_cache[key].duplicate(true)
	var field:=FrontierTerrainField.new();field.configure(int(body.streams.terrain),[],24.0,body.get("terrain_traits",{}))
	var rows: Array=[]
	var missing:=absent_starter(body)
	for def in body.ground_rules.starter:
		if def.resource==missing:continue
		var best:=Vector3.INF
		for i in 160:
			var angle: float=float(def.angle)+float(i)*.17
			var radius: float=clampf(float(def.radius)+float(i%9-4),20,78)
			var p:=FrontierExpeditionBusiness.ground(field,sin(angle)*radius,cos(angle)*radius,.7)
			if not p.is_finite():continue
			var clear:=true
			for other in rows:
				if Vector2(p.x-other.position[0],p.z-other.position[2]).length()<5:clear=false;break
			if clear:best=p;break
		if not best.is_finite():continue
		rows.append({"id":def.id,"resource":def.resource,"capacity":def.capacity,"required_tier":1,"position":[best.x,0,best.z]})
	_starter_cache[key]=rows.duplicate(true);return rows

static func valid(value: Variant) -> bool:
	if not value is Dictionary or (value.get("version")!=1 and value.get("version")!=2 and value.get("version")!=3 and value.get("version")!=4):return false
	if not FrontierUniverse._finite(value.get("intro_max_processing_seconds"),120,1200) or not FrontierUniverse._finite(value.get("near_resource_radius"),20,200):return false
	if not value.get("starter") is Array or value.starter.size()!=(25 if int(value.version)>=3 else 5):return false
	if int(value.version)>=2:
		if not value.get("expedition") is Dictionary:return false
		for field in ["radius","capacity","samples","radius_spread"]:
			if not FrontierUniverse._finite(value.expedition.get(field),1,1000):return false
	var seen: Array=[]
	for row in value.starter:
		if not row is Dictionary or not row.get("id") is String or row.id in seen or row.get("resource") not in ["iron","copper","stone","ice"]:return false
		if not FrontierExpeditionBusiness.integer(row.get("capacity"),1,10000) or not FrontierUniverse._finite(row.get("radius"),20,80) or not FrontierUniverse._finite(row.get("angle"),-TAU,TAU):return false
		seen.append(row.id)
	return true

static func absent_starter(body: Dictionary) -> String:
	if int(body.get("ground_rules",{}).get("version",0))<4:return ""
	var profile: Dictionary=body.get("mineral_profile",{})
	var pool: Array=profile.get("primary",[])+profile.get("secondary",[])
	var absent: Array=[]
	for id in ["iron","copper","ice"]:
		if id not in pool:absent.append(id)
	if absent.is_empty():return ""
	return str(absent[FrontierUniverse.derive(int(body.streams.resource),"lotus-shortfall")%absent.size()])

class_name FrontierCorporateSites
extends RefCounted
## Immutable, lazy sites in spatial regions. Separate random streams never touch geology.
const THEMES := ["managed","frontier","industry","restricted","declining","wild"]
const COMPANIES := {"managed":"space_y","frontier":"lotus","industry":"mine","restricted":"coopertech","declining":"","wild":""}
const LABELS := {"managed":"운영 중심","frontier":"개척 전선","industry":"산업 공급권","restricted":"제한 연구권","declining":"쇠퇴 항로","wild":"미진출 탐사권"}
const SITE_NAMES := {"lotus":"Lotus 개척 보급기지","mine":"mine 광물 집하·정비소","coopertech":"CooperTech 전투로봇 시험시설","space_y":"Space Y 환경 운영항","":"철수한 물류항"}
static var cache: Dictionary={}
static var manifest_keys: Array=[]
static func cache_prefix(m: Dictionary) -> String:
	# Saved settings are immutable. Distinguish equal seeds with different saved rules.
	for row in manifest_keys:
		if is_same(row.settings,m.settings):return row.key
	var key: String=m.id+":"+FrontierUniverse.fingerprint(m.settings)
	if manifest_keys.size()>=8:manifest_keys.pop_front()
	manifest_keys.append({"settings":m.settings,"key":key})
	return key
static func rules(m: Dictionary) -> Dictionary:return m.settings.get("corporate_space",{}).get("expansion",{})
static func enabled(m: Dictionary) -> bool:return not rules(m).is_empty()
static func valid(v: Variant) -> bool:
	if not v is Dictionary or v.get("version")!=1:return false
	for e in [["cell_size",80,500],["near_step",.05,.25],["far_step",.5,3],["port_clearance",2500,6000],["leg_seconds",600,2400]]:
		if not FrontierUniverse._finite(v.get(e[0]),e[1],e[2]):return false
	if not v.get("weights") is Array or v.weights.size()!=6 or not v.get("occupancy") is Dictionary:return false
	var total:=0
	for n in v.weights:
		if not FrontierExpeditionBusiness.integer(n,0,100):return false
		total+=int(n)
	for theme in THEMES:
		if not FrontierExpeditionBusiness.integer(v.occupancy.get(theme),0,100):return false
	return total==100
static func address(system: int,slot: int) -> String:return "corp_%d_%d"%[system,slot]
static func system_of(id: String) -> int:
	var parts:=id.split("_")
	if parts.size()!=3 or parts[0]!="corp" or not parts[1].is_valid_int() or parts[2] not in ["0","1"]:return -1
	var index:=int(parts[1])
	return index if index>0 and index<125000 and address(index,int(parts[2]))==id else -1
static func profile(m: Dictionary,index: int) -> Dictionary:
	if not enabled(m) or index<=0 or FrontierUniverse.system(m,index).is_empty():return {"theme":"wild","sites":[],"routes":[]}
	var cfg:=rules(m);var key: String=cache_prefix(m)+":"+str(cfg.hash())+":"+str(index)
	if cache.has(key):return cache[key]
	var p:=FrontierUniverse.map_position(m,index);var cell:=Vector2i(floori(p.x/float(cfg.cell_size)),floori(p.y/float(cfg.cell_size)))
	var region_seed:=FrontierUniverse.derive(int(m.seed),"corporations-v1:%d:%d"%[cell.x,cell.y])
	var roll:=region_seed%100;var theme: String="wild"
	for i in THEMES.size():
		roll-=int(cfg.weights[i])
		if roll<0:theme=THEMES[i];break
	var seed_value:=FrontierUniverse.derive(int(m.seed),"sites-v1:"+str(index))
	if seed_value%100>=int(cfg.occupancy[theme]):theme="wild"
	if index==FrontierUniverse.system_index(m,FrontierCrewNavigation.first_destination(m)):theme="wild"
	var result: Dictionary={"theme":theme,"region":"%d:%d"%[cell.x,cell.y],"operator":COMPANIES[theme],"sites":[],"routes":[]}
	if theme!="wild":
		var candidates: Array=[]
		for orbit in FrontierUniverse.body_count(m,index):
			var ordinal:=FrontierUniverse.first_ordinal(m,index)+orbit
			var body:=FrontierUniverse.body(m,ordinal,false)
			if not FrontierUniverse.landable(body):continue
			var rank:=FrontierUniverse.derive(seed_value,"anchor:"+str(ordinal))%1000
			if theme=="industry" and "iron" in body.get("mineral_profile",{}).get("primary",[]):rank+=1000
			candidates.append({"body":body,"rank":rank})
		candidates.sort_custom(func(a,b):return a.rank>b.rank)
		if candidates.size()>=2:
			for slot in 2:
				var body: Dictionary=candidates[slot].body
				var company: String=COMPANIES[theme] if slot==0 else "space_y"
				if theme=="declining":company=""
				var managed: bool=theme=="managed" and slot==0 and candidates.size()>=3
				var state: String="restored" if managed else ("withdrawn" if theme=="declining" else ("developing" if theme=="frontier" and slot==0 else "operating"))
				var id:=address(index,slot)
				result.sites.append({"id":id,"system":index,"body":int(body.ordinal),"operator":company,"state":state,"managed":managed,"guarded":theme=="managed" and slot==0,"seed":FrontierUniverse.derive(seed_value,id),"name":SITE_NAMES[company] if slot==0 or company!="space_y" else "Space Y 물류 중계항","short_name":"%s-%d"%[{"space_y":"Y","lotus":"L","mine":"M","coopertech":"CT","":"OLD"}[company],body.ordinal],"model":"solar_mars_port" if company=="space_y" else "relay_"+(company if not company.is_empty() else "retired"),"cargo":{"managed":"환경 유지 모듈","frontier":"개척 보급품","industry":"광물·기계 부품","restricted":"봉인 장비","declining":"회수 중단"}[theme]})
			var ends: Array=[result.sites[0].id,result.sites[1].id];ends.sort()
			result.routes.append({"id":"routes-v1:"+str(ends[0])+":"+str(ends[1]),"ends":ends,"operator":"space_y","cargo":result.sites[0].cargo,"active":theme!="declining","seed":FrontierUniverse.derive(seed_value,"routes-v1:"+":".join(ends))})
		else:result.theme="wild";result.operator=""
	if cache.size()>=96:cache.erase(cache.keys()[0])
	cache[key]=result
	return result
static func body_info(m: Dictionary,ordinal: int) -> Dictionary:
	for row in profile(m,FrontierUniverse.system_index(m,ordinal)).sites:
		if int(row.body)==ordinal:return row
	return {}
static func definition(m: Dictionary,id: String,t: float) -> Dictionary:
	var index:=system_of(id)
	if index<0 or not enabled(m):return {}
	for site in profile(m,index).sites:
		if site.id!=id:continue
		var row: Dictionary=site.duplicate(true);var body:=FrontierUniverse.body(m,int(row.body),false)
		# Berths above the body, clear of its rings. The same exact endpoint drives ships and art.
		var point:=FrontierUniverse.position(m,int(row.body),t)+Vector3(0,FrontierUniverse.navigation_radius(body)+float(rules(m).port_clearance),0)
		row.position=FrontierExpeditionBusiness.array(point);row.model="res://assets/models/ships/"+row.model+".glb"
		return row
	return {}
static func all(m: Dictionary,index: int,t: float) -> Array:
	var result: Array=[]
	for site in profile(m,index).sites:result.append(definition(m,site.id,t))
	return result
static func guard_ports(m: Dictionary,index: int) -> Array:
	if index==0:return FrontierSpaceTraffic.PORTS
	var result: Array=[]
	for row in profile(m,index).sites:
		if row.guarded:result.append(row.id)
	return result

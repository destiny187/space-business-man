class_name FrontierCorporateTraces
extends RefCounted
## Saved optional gate. One trace per eligible site, independent of geology and traffic time.
static func rules(m: Dictionary) -> Dictionary:return m.settings.get("corporate_space",{}).get("traces",{})
static func records(world: Dictionary) -> Dictionary:return world.get("crew",{}).get("corporate_traces",{})
static func valid_rules(v: Variant) -> bool:
	if not v is Dictionary or v.get("version")!=1 or not v.get("types") is Dictionary or not v.get("offset") is Array or v.offset.size()!=3:return false
	for n in v.offset:
		if not FrontierUniverse._finite(n,0,2000):return false
	for e in [["identify_distance",1000,4000],["inspect_distance",300,900],["signal_distance",5000,15000],["identify_seconds",1,5],["inspect_seconds",2,8],["max_speed",20,150]]:
		if not FrontierUniverse._finite(v.get(e[0]),e[1],e[2]):return false
	for company in ["lotus","mine","coopertech"]:
		if not v.types.get(company) is Dictionary:return false
		for field in ["name","model","activity","evidence","status"]:
			if not v.types[company].get(field) is String or v.types[company][field].length()>512:return false
		if v.types[company].model!="ships/trace_"+company:return false
	return v.types.size()==3
static func site_id(id: String) -> String:return id.trim_prefix("trace:") if id.begins_with("trace:") else ""
static func valid(v: Variant) -> bool:
	if not v is Dictionary or v.size()>125000:return false
	for id in v:
		if not id is String or FrontierCorporateSites.system_of(site_id(id))<0 or not site_id(id).ends_with("_0") or not FrontierExpeditionBusiness.integer(v[id],1,2):return false
	return true
static func snapshot(rows: Dictionary,system: int) -> Dictionary:
	var result: Dictionary={};var keys: Array=rows.keys()
	for id in keys.slice(maxi(0,keys.size()-256)):result[id]=rows[id]
	var id: String="trace:"+FrontierCorporateSites.address(system,0)
	if rows.has(id):result[id]=rows[id]
	return result
static func all(m: Dictionary,system: int,t: float) -> Array:
	if rules(m).is_empty():return []
	var result: Array=[]
	for site in FrontierCorporateSites.all(m,system,t):
		if not rules(m).types.has(site.operator):continue
		var row: Dictionary=rules(m).types[site.operator].duplicate(true)
		row.merge({"id":"trace:"+site.id,"site":site.id,"system":system,"body":int(site.body),"body_id":FrontierUniverse.body_id(m,int(site.body)),"company":site.operator,"site_name":site.name})
		row.position=FrontierExpeditionBusiness.array(FrontierCrewWorld.vector(site.position)+FrontierCrewWorld.vector(rules(m).offset))
		result.append(row)
	return result
static func definition(m: Dictionary,id: String,t: float=0) -> Dictionary:
	for row in all(m,FrontierCorporateSites.system_of(site_id(id)),t):
		if row.id==id:return row
	return {}
static func occluded(m: Dictionary,system: int,t: float,origin: Vector3,point: Vector3) -> bool:
	var ray: Vector3=(point-origin).normalized();var distance:=origin.distance_to(point)
	var spheres: Array=[{"position":[0,0,0],"radius":float(FrontierUniverse.star_settings(m,system).star_radius)}]
	for orbit in FrontierUniverse.body_count(m,system):
		var ordinal:=FrontierUniverse.first_ordinal(m,system)+orbit
		var body:=FrontierUniverse.body(m,ordinal,false);var center:=FrontierUniverse.position(m,ordinal,t)
		spheres.append({"position":FrontierExpeditionBusiness.array(center),"radius":FrontierUniverse.navigation_radius(body)})
		for moon in int(body.get("moons",0)):spheres.append({"position":FrontierExpeditionBusiness.array(center+FrontierUniverse.moon_offset(body,moon,t)),"radius":FrontierUniverse.moon_radius(body,moon)})
	for site in FrontierCorporateSites.all(m,system,t):spheres.append({"position":site.position,"radius":280})
	for sphere in spheres:
		var offset:=FrontierCrewWorld.vector(sphere.position)-origin;var along:=offset.dot(ray)
		if along>0 and along<distance and (offset-ray*along).length()<float(sphere.radius):return true
	return false
static func target(m: Dictionary,nav: Dictionary,aim: Vector3) -> Dictionary:
	if rules(m).is_empty() or nav.get("mode","") != "idle" or aim.length_squared()<.5:return {}
	var origin:=FrontierCrewWorld.vector(nav.position);var t:=float(nav.get("orbit_time",0));var system:=int(nav.system)
	var best:=.985;var result: Dictionary={}
	for row in all(m,system,t):
		var point:=FrontierCrewWorld.vector(row.position);var offset:=point-origin
		var dot:=offset.normalized().dot(aim.normalized())
		if offset.length()>float(rules(m).signal_distance) or dot<=best or occluded(m,system,t,origin,point):continue
		best=dot;result=row;result.distance=offset.length()
	return result
static func reason(m: Dictionary,nav: Dictionary,target: Dictionary,stage: int) -> String:
	if stage>=2:return "활동 기록 확보 · J"
	var limit:=float(rules(m).identify_distance if stage==0 else rules(m).inspect_distance)
	if float(target.distance)>limit:return "%.0fm 이내로 접근"%limit
	if absf(float(nav.get("speed",0)))>float(rules(m).max_speed):return "속도를 %.0fm/s 이하로 낮추세요"%float(rules(m).max_speed)
	return ""

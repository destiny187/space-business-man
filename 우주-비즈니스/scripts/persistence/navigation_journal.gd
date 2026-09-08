class_name FrontierNavigationJournal
extends RefCounted
var manifest: Dictionary={}
var data: Dictionary={"version":1,"systems":{},"bodies":{},"favorites":{}}
var path: String=""
var error: String=""
func configure(m: Dictionary,world_id: String,player_id: String) -> void:
	manifest=m
	path="user://navigation_"+(world_id+":"+m.id+":"+player_id).sha256_text().substr(0,24)+".json"
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate):continue
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if valid(value):data=value;return
		error="항해 기록을 읽지 못했습니다. 원본 파일을 보존합니다."
func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1:return false
	for key in ["systems","bodies","favorites"]:
		if not value.get(key) is Dictionary:return false
	for key in value.systems:
		if not str(key).is_valid_int() or int(key)<0 or int(key)>=int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system):return false
	for key in value.bodies:
		if FrontierUniverse.ordinal_of(manifest,str(key))<0 or not value.bodies[key] is Dictionary:return false
		if value.bodies[key].has("resources"):
			if not value.bodies[key].resources is Array or value.bodies[key].resources.size()>FrontierMinerals.all().size():return false
			for resource in value.bodies[key].resources:
				if not resource is String or FrontierMinerals.entry(resource).is_empty():return false
		for field in ["scanned","visited"]:
			if not value.bodies[key].get(field,false) is bool:return false
		if value.bodies[key].get("site","") not in ["","active","settled","supply","exploration"]:return false
	for key in value.favorites:
		if FrontierUniverse.ordinal_of(manifest,str(key))<0 or not value.favorites[key] is bool:return false
	return true
func save() -> void:
	if path.is_empty() or not error.is_empty():return
	var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:error="항해 기록 저장 실패";return
	file.store_string(JSON.stringify(data));file.flush();file.close()
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak")!=OK:error="항해 기록 백업 실패";return
	if DirAccess.rename_absolute(path+".tmp",path)!=OK:error="항해 기록 저장 실패"
func mark(ordinal: int,field: String,value: Variant=true) -> bool:
	var id:=FrontierUniverse.body_id(manifest,ordinal)
	var record: Dictionary=data.bodies.get(id,{})
	if record.has(field) and record[field]==value:return false
	record[field]=value;data.bodies[id]=record
	return true
func observe(snapshot: Dictionary) -> void:
	var nav: Dictionary=snapshot.crew.navigation
	if nav.mode=="jump":return
	var changed:=false
	for row in snapshot.crew.get("survey",{}).values():
		var known: Array=data.bodies.get(row.body_id,{}).get("resources",[]).duplicate()
		if row.resource not in known:
			known.append(row.resource)
			changed=mark(FrontierUniverse.ordinal_of(manifest,row.body_id),"resources",known) or changed
	# A host-owned lease proves a previous landing, even after local journal loss.
	for supply in snapshot.get("supply_sites",[]):
		var supplied_ordinal:=int(supply.ordinal)
		changed=mark(supplied_ordinal,"site",supply.state) or changed
		changed=mark(supplied_ordinal,"visited") or changed
		var supplied_system:=str(FrontierUniverse.system_index(manifest,supplied_ordinal))
		if not data.systems.has(supplied_system):data.systems[supplied_system]=true;changed=true
	var system_key:=str(int(nav.system))
	if not data.systems.has(system_key):data.systems[system_key]=true;changed=true
	var ordinal:=FrontierUniverse.ordinal_of(manifest,snapshot.location)
	var near: bool=FrontierFlightTelemetry.read(manifest,nav).get("eta",-1)==0
	if near:ordinal=int(nav.target)
	if not snapshot.crew.get("landing",{}).is_empty() or (nav.mode=="idle" and near):changed=mark(ordinal,"visited") or changed
	var site: Dictionary=snapshot.get("navigation_site",{})
	if not site.is_empty() and not str(site.state).is_empty():changed=mark(int(nav.target),"site",site.state) or changed
	if changed:save()
func scanned(ordinal: int) -> void:
	if mark(ordinal,"scanned"):save()
func scan_flags() -> Dictionary:
	var result: Dictionary={}
	for id in data.bodies:
		if data.bodies[id].get("scanned",false):result[id]=true
	return result
func favorite(ordinal: int) -> void:
	var id:=FrontierUniverse.body_id(manifest,ordinal)
	if data.favorites.has(id):data.favorites.erase(id)
	else:data.favorites[id]=true
	save()
func status(ordinal: int) -> String:
	var id:=FrontierUniverse.body_id(manifest,ordinal);var record: Dictionary=data.bodies.get(id,{})
	var parts: PackedStringArray=[]
	if data.favorites.has(id):parts.append("★ 즐겨찾기")
	if record.get("site","")=="active":parts.append("▣ 개발 중")
	elif record.get("site","")=="supply":parts.append("▣ 생산 거점")
	elif record.get("site","")=="settled":parts.append("▣ 정산 완료")
	if record.get("visited",false):parts.append("✓ 방문")
	if record.get("scanned",false):parts.append("◉ 스캔")
	if parts.is_empty():parts.append("미스캔")
	return " · ".join(parts)
func ordinals(filter_index: int=0,query: String="") -> Array[int]:
	var ids: Dictionary=data.bodies.duplicate()
	for id in data.favorites:ids[id]=data.bodies.get(id,{})
	var result: Array[int]=[]
	for id in ids:
		if filter_index==1 and not data.favorites.has(id):continue
		if filter_index==2 and ids[id].get("site","")!="active":continue
		var ordinal:=FrontierUniverse.ordinal_of(manifest,id)
		if not query.is_empty() and not matches(ordinal,query):continue
		result.append(ordinal)
	result.sort();return result

func known_resources(ordinal: int) -> Array:
	var body:=FrontierUniverse.body(manifest,ordinal)
	var record: Dictionary=data.bodies.get(body.id,{})
	var resources: Array=record.get("resources",[]).duplicate()
	if record.get("scanned",false) or body.get("origin","")=="solar_reference":
		for id in FrontierOrbitalSurvey.report(body).resources:
			if id not in resources:resources.append(id)
	return resources
func matches(ordinal: int,query: String) -> bool:
	var needle:=query.strip_edges().to_lower()
	if needle.is_empty() or FrontierUniverse.body(manifest,ordinal).name.to_lower().contains(needle):return true
	for resource in known_resources(ordinal):
		if FrontierCatalog.entry("resources",resource).name.to_lower().contains(needle):return true
	return false

class_name FrontierCorporations
extends RefCounted
## Host-authored sightings of physical equipment; company identity never grants ownership.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/corporations.json"))
	return _config
static func company(id: String) -> Dictionary:return config().companies.get(id,{})
static func asset(id: String) -> Dictionary:return config().assets.get(id,{})
static func records(world: Dictionary) -> Dictionary:return world.get("crew",{}).get("corporations",{})
static func icon_path(id: String) -> String:return "res://assets/ui/corporations/"+id+".svg"
static func name_of(id: String) -> String:
	if id=="crew":return "원정대"
	return str(company(id).get("name","미확인"))
static func affiliations(asset_id: String) -> Array:
	var item:=asset(asset_id)
	return [{"role":"운영","id":item.operator,"name":name_of(item.operator)},{"role":"제조","id":item.manufacturer,"name":name_of(item.manufacturer)}]
static func candidate(asset_id: String,id: String,position: Array,body_id: String) -> Dictionary:
	return {"kind":"corporation","id":"corporation:"+asset_id+":"+id,"asset":asset_id,"company":asset(asset_id).company,"source_id":id,"body_id":body_id,"point":FrontierCrewWorld.vector(position)+Vector3.UP*float(asset(asset_id).height)}
static func target(world: Dictionary,actor: String,aim: Vector3) -> Dictionary:
	var body_id: String=world.crew.landing.body_id
	var origin:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP*1.72
	var candidates: Array=[]
	for row in world.get("lotus",{}).get("crates",{}).values():
		if row.body_id==body_id and row.landed:candidates.append(candidate("lotus_crate",row.id,row.position,body_id))
	for row in FrontierExpeditionBusiness.site(world).get("robots",{}).values():
		candidates.append(candidate("mine_miner",row.id,row.position,body_id))
	for id in FrontierExplorationIncidents.records(world):
		var row: Dictionary=FrontierExplorationIncidents.records(world)[id]
		if row.body_id==body_id and row.template=="illuti_dormant_combat_robot" and row.materialized:
			candidates.append(candidate("coopertech_robot",id,row.position,body_id))
	var nearest:=float(FrontierCrewSurface.config().scan_distance)
	var selected: Dictionary={}
	for row in candidates:
		var delta: Vector3=row.point-origin
		var along:=delta.dot(aim)
		if along<=0 or delta.length()>nearest or (delta-aim*along).length()>float(config().scan_radius):continue
		if not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),origin,row.point):continue
		selected=row;nearest=delta.length()
	return selected
static func known(world: Dictionary,row: Dictionary) -> bool:return records(world).has(row.company)
static func record(world: Dictionary,row: Dictionary) -> void:
	if not world.crew.has("corporations"):world.crew.corporations={}
	if known(world,row):return
	world.crew.corporations[row.company]={"body_id":row.body_id,"asset":row.asset,"source_id":row.source_id,"position":[row.point.x,row.point.y,row.point.z]}
static func info(row: Dictionary) -> Dictionary:
	var item:=asset(row.asset);var maker:=company(row.company)
	var roles:=affiliations(row.asset)
	return {"kind":"corporation","id":row.id,"company":row.company,"asset":row.asset,"name":item.name,"icon":"scan","point":[row.point.x,row.point.y,row.point.z],"subtitle":maker.role,"affiliations":roles,"notes":[{"icon":"scan","text":item.activity}],"condition":maker.description,"action":item.action}
static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()>config().companies.size():return false
	for id in value:
		var row: Variant=value[id]
		if not config().companies.has(id) or not row is Dictionary:return false
		if not row.get("asset") is String or not config().assets.has(row.asset) or asset(row.asset).company!=id:return false
		for field in ["body_id","source_id"]:
			if not row.get(field) is String or row[field].length()>192 or row[field].is_empty():return false
		if not FrontierUniverse._vector3_array(row.get("position")):return false
	return true

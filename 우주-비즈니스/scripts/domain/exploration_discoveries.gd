class_name FrontierExplorationDiscoveries
extends RefCounted
## Authored POIs use their own seed stream. Only observed progress is saved.
static var _config: Dictionary={}
static var _tiles: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration_discoveries.json"))
	return _config
static func ensure(world: Dictionary) -> void:
	if not world.has("discoveries"):world.discoveries={"version":1,"records":{}}
static func definition(id: String) -> Dictionary:return config().items.get(id,{})
static func records(world: Dictionary) -> Dictionary:return world.get("discoveries",{}).get("records",{})
static func eligible(body: Dictionary,d: Dictionary) -> bool:
	if int(d.tier)>int(body.planet_tier):return false
	var p:=FrontierEcology.profile(body)
	var pressure: float=float(p.pressure)*(100.0 if not body.get("terrain_traits",{}).is_empty() else 1.0)
	var wet: bool=float(p.moisture)>.08 and float(p.temperature)>0 and float(p.temperature)<80 and pressure>15
	var life: bool=p.origin!="sterile" and float(p.moisture)>.08 and float(p.temperature)>-25 and float(p.temperature)<85 and pressure>15
	match d.environment:
		"wind":return pressure>10
		"wet":return wet
		"life":return life
		"wet_life":return wet and life
		"wind_life":return life and pressure>15
		"hot":return float(p.temperature)>35 and pressure>10
	return true
static func tile(body: Dictionary,field: FrontierTerrainField,key: Vector2i) -> Array:
	var cache_key: String=body.id+":"+str(body.seed)+":"+str(key)
	if _tiles.has(cache_key):return _tiles[cache_key]
	var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.streams.discovery),"field-discoveries-v1:%d:%d"%[key.x,key.y])
	var candidates: Array=[]
	for id in config().items:
		var d:=definition(id)
		if eligible(body,d):candidates.append({"id":id,"order":rng.randf(),"tier":int(d.tier)})
	# T2 introduces at least two suitable upper-tier types before filling the mixed pool.
	candidates.sort_custom(func(a,b):return a.order<b.order)
	if int(body.planet_tier)>=2:
		var upper:=candidates.filter(func(d):return d.tier==2)
		for row in upper.slice(0,2):candidates.erase(row)
		candidates=upper.slice(0,2)+candidates
	var result: Array=[]
	var span: float=config().tile_size
	var original:=FrontierTerrainField.new();original.configure(field.seed_value,[],field.span,field.traits)
	var cap:=int(config().density[str(int(body.planet_tier))])
	var limit:=float(JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json")).region_half_extent)
	for candidate in candidates:
		if result.size()>=cap:break
		var d:=definition(candidate.id)
		for attempt in 32:
			var point:=Vector3(key.x*span+rng.randf_range(22,span-22),0,key.y*span+rng.randf_range(22,span-22))
			if Vector2(point.x,point.z).length()<38 or maxf(absf(point.x),absf(point.z))>limit-20:continue
			point.y=original.height(point.x,point.z)
			var underwater: bool=d.id in ["submerged_recorder","luminous_tidepool"]
			if underwater:
				if not FrontierSurfaceDrainage.liquid(field.traits) or point.y < -5.8 or point.y > -4.25:continue
			elif FrontierSurfaceDrainage.liquid(field.traits) and point.y< -3.9:continue
			if absf(original.height(point.x+4,point.z)-point.y)>2.2 or absf(original.height(point.x,point.z+4)-point.y)>2.2:continue
			if result.any(func(row):return FrontierCrewWorld.vector(row.position).distance_to(point)<35):continue
			var yaw:=rng.randf()*TAU
			var uneven:=false
			for step in d.stages:
				var offset:=FrontierCrewWorld.vector(step.point).rotated(Vector3.UP,yaw)
				if absf(original.height(point.x+offset.x,point.z+offset.z)-point.y)>.5:uneven=true;break
			if uneven:continue
			var id: String="poi:%d:%d:%s"%[key.x,key.y,d.id]
			result.append({"id":id,"template":d.id,"body_id":body.id,"position":[point.x,point.y,point.z],"yaw":yaw})
			break
	if _tiles.size()>256:_tiles.erase(_tiles.keys()[0])
	_tiles[cache_key]=result
	return result
static func nearby(body: Dictionary,field: FrontierTerrainField,p: Vector3) -> Array:
	var result: Array=[]
	var key:=Vector2i(floori(p.x/float(config().tile_size)),floori(p.z/float(config().tile_size)))
	for x in range(key.x-1,key.x+2):
		for z in range(key.y-1,key.y+2):result.append_array(tile(body,field,Vector2i(x,z)))
	return result
static func record_key(row: Dictionary) -> String:return str(row.body_id)+"/"+str(row.id)
static func progress(world: Dictionary,row: Dictionary) -> Dictionary:return records(world).get(record_key(row),{})
static func stage(world: Dictionary,row: Dictionary) -> int:return int(progress(world,row).get("stage",0))
static func work_point(row: Dictionary,index: int) -> Vector3:
	var d:=definition(row.template)
	var offset:=FrontierCrewWorld.vector(d.stages[mini(index,d.stages.size()-1)].point).rotated(Vector3.UP,float(row.yaw))
	return FrontierCrewWorld.vector(row.position)+offset+Vector3.UP*.8
static func target(world: Dictionary,actor: String,aim: Vector3) -> Dictionary:
	if not FrontierCrewSurface.landed(world) or not world.crew.members.has(actor):return {}
	var m: Dictionary=world.crew.members[actor]
	if m.area!="surface" or m.aboard:return {}
	var origin:=FrontierCrewWorld.vector(m.position)+Vector3.UP*1.72
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	var field:=FrontierCrewSurface.field(world)
	var closest:=float(config().probe_distance)
	var selected: Dictionary={}
	for source in nearby(body,field,origin):
		var point:=work_point(source,stage(world,source));var delta:=point-origin;var along:=delta.dot(aim)
		if along<=0 or delta.length()>closest or (delta-aim*along).length()>1.15:continue
		if not FrontierCrewSurface.visible_in_field(field,origin,point):continue
		selected=source.duplicate(true);selected.kind="discovery";selected.point=point;closest=delta.length()
	return selected
static func known(world: Dictionary,row: Dictionary) -> bool:
	var record:=progress(world,row)
	return not record.is_empty() and int(record.get("scanned_stage",-1))==int(record.stage)
static func scan(world: Dictionary,row: Dictionary,actor: String) -> void:
	ensure(world)
	var id:=record_key(row)
	if not world.discoveries.records.has(id):
		var record:=row.duplicate(true);record.erase("point");record.erase("kind")
		record.stage=0;record.scanned_stage=-1;record.discoverer=actor;record.claimed=false;record.clue={};record.sample={}
		world.discoveries.records[id]=record
	var record: Dictionary=world.discoveries.records[id]
	record.scanned_stage=record.stage
static func result(world: Dictionary,row: Dictionary) -> Dictionary:
	var d:=definition(row.template);var index:=stage(world,row);var finished: bool=index>=d.stages.size()
	return {"kind":"discovery","id":row.id,"name":d.name,"icon":"scan","point":FrontierExpeditionBusiness.array(row.point) if row.get("point") is Vector3 else row.position,"subtitle":"탐험 발견  T%d  %d/%d"%[int(d.tier),mini(index,d.stages.size()),d.stages.size()],"notes":[{"icon":"scan","text":d.knowledge if finished else d.stages[index].label}],"condition":"J 발견 기록에 장소와 조사 성과를 보존합니다.","action":"조사 완료" if finished else "F  "+str(d.stages[index].label)}
static func apply(world: Dictionary,actor: String,args: Dictionary) -> String:
	var aim:=FrontierCrewSurface.direction(args.get("aim"))
	if aim==Vector3.ZERO:return "발견물을 조준하세요."
	var row:=target(world,actor,aim)
	if row.is_empty() or args.get("id")!=row.id:return "발견물의 조사 지점을 가까이 조준하세요."
	var index:=stage(world,row);var d:=definition(row.template)
	if index>=d.stages.size():return "이미 조사를 마친 장소입니다."
	if args.get("stage")!=index:return "조사 단계가 바뀌었습니다."
	if not known(world,row):return "E를 유지해 현재 지점을 먼저 조사하세요."
	var point:=work_point(row,index)
	if (FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP).distance_to(point)>float(config().interaction_distance):return "조사 지점 4.5m 안으로 접근하세요."
	var step: Dictionary=d.stages[index]
	var tool:=FrontierEquipment.active(world.crew.members[actor])
	if not str(step.tool).is_empty() and tool.get("kind")!=step.tool:return "지형 변환기를 장착하세요." if step.tool=="terrain" else "채집기를 장착하세요."
	if d.mode=="pulse" and index==1 and fmod(float(world.crew.navigation.orbit_time)+float(row.yaw)*3,8.0)<3.0:return "분출 중입니다. 증기가 잦아든 뒤 조사하세요."
	FrontierItemInventory.merge_legacy(world,actor)
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	var stock: Dictionary=world.business.bags[actor]
	for resource in step.cost:
		if int(stock.get(resource,0))<int(step.cost[resource]):return "%s %d개가 필요합니다."%[FrontierCatalog.entry("resources",resource).name,int(step.cost[resource])]
	for resource in step.cost:stock[resource]-=int(step.cost[resource])
	var record: Dictionary=world.discoveries.records[record_key(row)]
	if index==d.stages.size()-1:
		if not FrontierItemInventory.fits(world,actor,d.reward):return "아이템 공간이 부족합니다. 보상은 현장에 남아 있습니다."
		FrontierExpeditionBusiness.transfer(stock,d.reward,1)
		if d.sample:
			var specimen_error:=_sample(world,actor,row,record)
			if not specimen_error.is_empty():return specimen_error
		if d.clue:_clue(world,row,record)
		if d.mode=="water":_release_water(world,row)
		record.claimed=true
	record.stage=index+1
	return ""
static func _sample(world: Dictionary,actor: String,row: Dictionary,record: Dictionary) -> String:
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	FrontierEcology.ensure_planet(world.ecology,body)
	var selected:=sample_identity(body,world.ecology.planets[world.location],row.id)
	if selected.is_empty():return "이 환경에서 회수 가능한 계통이 없습니다."
	selected.id=row.id;selected.point=FrontierCrewWorld.vector(row.position);selected.status="dormant";selected.layer="surface"
	FrontierEcology.scan(world.ecology,world.location,selected)
	var error:=FrontierSpecimenItems.collect(world,actor,selected)
	if error.is_empty():record.sample={"form_id":selected.form_id,"look_id":selected.look_id}
	return error
static func sample_identity(body: Dictionary,planet: Dictionary,id: String) -> Dictionary:
	var parts:=id.split(":")
	if parts.size()!=4 or parts[0]!="poi" or not parts[1].is_valid_int() or not parts[2].is_valid_int():return {}
	var d:=definition(parts[3])
	if d.is_empty() or not d.sample or not eligible(body,d):return {}
	var field:=FrontierTerrainField.new();field.configure(int(body.streams.terrain),[],24.0,body.get("terrain_traits",{}))
	if not tile(body,field,Vector2i(int(parts[1]),int(parts[2]))).any(func(row):return row.id==id):return {}
	var category: String="microbe" if parts[3]=="luminous_tidepool" else "plant"
	for lineage in planet.lineages:
		var form:=FrontierEcologyCatalog.form(lineage.form_id)
		if form.category==category and form.environment==planet.profile.environment:return lineage.duplicate(true)
	return {}
static func _clue(world: Dictionary,row: Dictionary,record: Dictionary) -> void:
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	var p:=FrontierCrewWorld.vector(row.position)
	var veins:=FrontierExpeditionBusiness.veins(body,p)
	if veins.is_empty():return
	var source: Dictionary=veins[0]
	for vein in veins:
		if vein.resource=="iron":source=vein;break
	record.clue={"resource":source.resource,"position":source.position,"id":source.id}
	var survey:=source.duplicate();survey.kind="mineral"
	FrontierSurfaceSurvey.record(world,survey)
static func _release_water(world: Dictionary,row: Dictionary) -> void:
	if not world.has("surface_water"):world.surface_water={}
	if not world.surface_water.has(world.location):world.surface_water[world.location]=FrontierSurfaceWater.create()
	var water: Dictionary=world.surface_water[world.location]
	var field:=FrontierCrewSurface.field(world)
	var center:=FrontierCrewWorld.vector(row.position)
	for i in int(config().water_release_cells):
		var p:=center+Vector3((i%4-1.5)*1.0,0,3.0+floori(i/4.0))
		p.y=field.height(p.x,p.z)+.8
		var key:=FrontierSurfaceWater.key(FrontierSurfaceWater.cell(p))
		if not water.cells.has(key):water.cells[key]=[.65,0.0]
	water.serial+=1
static func validate(world: Dictionary) -> String:
	if not world.has("discoveries"):return ""
	var value: Variant=world.discoveries
	if not value is Dictionary or value.get("version")!=1 or not value.get("records") is Dictionary:return "탐험 발견 저장 버전 오류"
	for key in value.records:
		var row: Variant=value.records[key]
		if not row is Dictionary or not row.get("template") is String or definition(row.template).is_empty():return "발견 유형 오류"
		if not row.get("body_id") is String or FrontierUniverse.ordinal_of(world.manifest,row.body_id)<0:return "발견 행성 오류"
		if not row.get("id") is String or key!=record_key(row) or not FrontierUniverse._vector3_array(row.get("position")) or not FrontierUniverse._finite(row.get("yaw"),0,TAU):return "발견 위치 오류"
		var count: int=definition(row.template).stages.size()
		if not FrontierExpeditionBusiness.integer(row.get("stage"),0,count) or not FrontierExpeditionBusiness.integer(row.get("scanned_stage"),-1,count):return "발견 단계 오류"
		if not row.get("claimed") is bool or row.claimed!=(row.stage==count) or int(row.scanned_stage)>int(row.stage):return "발견 보상 상태 오류"
		if not row.get("discoverer") is String or not row.get("clue") is Dictionary or not row.get("sample") is Dictionary:return "발견 기록 형식 오류"
	return ""
static func snapshot(world: Dictionary,body_id: String) -> Dictionary:
	var result: Dictionary={"version":1,"records":{}}
	for id in records(world):
		var row: Dictionary=records(world)[id]
		if row.body_id==body_id:result.records[id]=row.duplicate(true)
	return result

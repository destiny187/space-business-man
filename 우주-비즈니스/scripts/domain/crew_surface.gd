class_name FrontierCrewSurface
extends RefCounted
## Shared surface rules execute only on the host, against host-owned positions.
static var _config: Dictionary={}
static var _field:=FrontierTerrainField.new()
static var _field_key: String=""
static var _ground: Dictionary={}

static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_surface.json"))
	return _config

static func landed(world: Dictionary) -> bool:
	return not world.get("crew",{}).get("landing",{}).is_empty()

static func spawn_member(world: Dictionary,member: Dictionary,index: int) -> void:
	member.position=(config().landing_spawn_positions[index%6] if landed(world) else FrontierCrewWorld.config().spawn_positions[index%6]).duplicate()
	member.area="surface" if landed(world) else "cabin"
	member.aboard=not landed(world);member.ready=false

static func field(world: Dictionary) -> FrontierTerrainField:
	var id: String=world.crew.landing.body_id
	var edits: Array=world.terrain_edits.get(id,[])
	var key: String=world.crew.world_id+":"+id+":"+str(edits.size())
	if _field_key!=key:
		var body:=FrontierUniverse.body_from_id(world.manifest,id)
		_field.configure(int(body.streams.terrain),edits,float(world.terrain_settings.cell_size)*int(world.terrain_settings.chunk_cells))
		_field_key=key;_ground.clear()
	return _field

static func owns(member: Dictionary,equipment: String) -> bool:
	for item in member.profile.equipment:
		if item.definition==equipment:return true
	return false

static func direction(value: Variant) -> Vector3:
	if not FrontierUniverse._vector3_array(value):return Vector3.ZERO
	var aim:=FrontierCrewWorld.vector(value)
	return aim.normalized() if aim.length()>.98 and aim.length()<1.02 else Vector3.ZERO

static func visible_in_field(terrain: FrontierTerrainField,start: Vector3,end: Vector3) -> bool:
	if terrain.density(start)>0:return false
	var length:=start.distance_to(end)
	var steps:=ceili(length/.25)
	for step in range(1,steps):
		if terrain.density(start.lerp(end,float(step)/maxi(steps,1)))>0:return false
	return true

static func target(world: Dictionary,actor: String,aim: Vector3) -> Dictionary:
	if not landed(world) or not world.crew.members.has(actor) or aim.length_squared()<.9:return {}
	var member: Dictionary=world.crew.members[actor]
	if member.area!="surface" or not owns(member,"survey_scanner"):return {}
	var id: String=world.crew.landing.body_id
	var body:=FrontierUniverse.body_from_id(world.manifest,id)
	var record: Dictionary=world.ecology.planets[id]
	var terrain:=field(world)
	var position:=FrontierCrewWorld.vector(member.position)
	var origin:=position+Vector3.UP*1.72
	var distance_limit: float=config().scan_distance
	var selected: Dictionary={}
	var population:=0
	if _ground.size()>384:_ground.clear()
	for row in FrontierEcologyPlacement.candidates(body,record,position):
		if not _ground.has(row.id):_ground[row.id]=FrontierEcologyPlacement.ground(terrain,row)
		var point: Vector3=_ground[row.id]
		if not point.is_finite():continue
		var form:=FrontierEcologyCatalog.form(row.form_id)
		var state: String=FrontierEcology.status(record,form,point,row.layer)
		if row.introduced:state="active" if FrontierEcology.climate_at(record,point,row.layer).get("restored",false) else "dormant"
		if state=="absent" or (state=="dormant" and form.category=="animal" and not row.introduced):continue
		if point.distance_to(position)>float(FrontierEcologyCatalog.config().active_radius):continue
		population+=1
		if population>int(FrontierEcologyCatalog.config().max_actors):break
		var height: float=(float(form.geometry.near.max[1])-float(form.geometry.near.floor_y))*float(FrontierEcologyCatalog.look(form.id,row.look_id).scale)
		var center:=point+terrain.normal(point)*maxf(.35,height*.5)
		var delta:=center-origin
		var along:=delta.dot(aim)
		if along<=0 or delta.length()>distance_limit or (delta-aim*along).length()>clampf(height*.5,.65,2.2):continue
		if not visible_in_field(terrain,origin,center):continue
		row.point=point;row.status=state;selected=row;distance_limit=delta.length()
	return selected

static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,active: Dictionary) -> String:
	var crew: Dictionary=world.crew
	var member: Dictionary=crew.members[actor]
	if kind=="land":
		if landed(world):return "이미 착륙했습니다."
		if actor!=crew.pilot_id or crew.navigation.mode!="idle":return "궤도 접근을 마친 조종사가 착륙할 수 있습니다."
		var body:=FrontierUniverse.body(world.manifest,int(crew.navigation.target))
		var radius:=240.0+float(body.seed%190)
		if world.location!=body.id or FrontierCrewWorld.vector(crew.navigation.position).distance_to(FrontierCrewNavigation.center(int(crew.navigation.target)))-radius>float(world.manifest.settings.flight.arrival_clearance)+3:return "선정 행성의 궤도까지 접근하세요."
		for id in active.values():
			if not crew.members[id].aboard or not crew.members[id].ready:return "연결된 승무원 모두 착륙 준비를 완료해야 합니다."
		if not world.has("terrain_settings"):
			world.terrain_settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/terrain.json"));world.terrain_settings_hash=FrontierUniverse.fingerprint(world.terrain_settings)
		if not world.has("ecology"):world.ecology=FrontierEcology.create()
		FrontierEcology.ensure_planet(world.ecology,body)
		crew.landing={"body_id":body.id,"epoch":int(crew.revision)+1}
		var index:=0
		for id in active.values():spawn_member(world,crew.members[id],index);index+=1
		return ""
	if not landed(world) or member.area!="surface":return "같은 행성에 착륙한 뒤 실행하세요."
	var body_id: String=crew.landing.body_id
	var position:=FrontierCrewWorld.vector(member.position)
	var near_ship: bool=position.distance_to(FrontierCrewWorld.vector(config().ship_position))<=float(config().boarding_distance)
	if kind=="launch":
		for id in active.values():
			if FrontierExpeditionBusiness.total(FrontierExpeditionBusiness.bag(world,id))>0:return "사업 자원을 현장 창고에 반납한 뒤 출항하세요."
		if actor!=crew.pilot_id:return "조종사만 출항할 수 있습니다."
		for id in active.values():
			var other: Dictionary=crew.members[id]
			if not other.ready or FrontierCrewWorld.vector(other.position).distance_to(FrontierCrewWorld.vector(config().ship_position))>float(config().boarding_distance):return "모든 승무원이 우주선에 돌아와 출항 준비를 완료해야 합니다."
		crew.landing={}
		var index:=0
		for id in active.values():spawn_member(world,crew.members[id],index);index+=1
		return ""
	if kind in ["deposit","withdraw"]:
		if not near_ship:return "우주선의 공동 보관함에 가까이 돌아오세요."
		if not FrontierUniverse._finite(args.get("amount"),1,int(FrontierCrewWorld.config().backpack_capacity)) or args.amount!=floorf(args.amount):return "옮길 수량 오류"
		var amount: int=int(args.amount)
		if kind=="deposit":
			if int(member.carried)<amount:return "운반 화물이 부족합니다."
			member.carried-=amount;crew.rock+=amount
		else:
			if int(crew.rock)<amount or int(member.carried)+amount>int(FrontierCrewWorld.config().backpack_capacity):return "공동 재고 또는 배낭 공간이 부족합니다."
			member.carried+=amount;crew.rock-=amount
		return ""
	if kind=="surface_dig":
		if FrontierEquipment.active(member).get("kind")!="terrain":return "지형 변환기를 제작한 뒤 번호 슬롯에 장착하세요."
		if int(member.carried)>=int(FrontierCrewWorld.config().backpack_capacity):return "배낭을 비운 뒤 굴착하세요."
		if world.terrain_edits.get(body_id,[]).size()>=int(config().maximum_edits_per_planet):return "이 실증 행성의 굴착 기록 한도에 도달했습니다."
		var aim:=direction(args.get("aim"))
		if aim==Vector3.ZERO:return "조준 방향 오류"
		var terrain:=field(world)
		var origin:=position+Vector3.UP*1.72
		if terrain.density(origin)>0:return "안전한 빈 공간에서 조준하세요."
		var hit:=Vector3.INF
		for step in range(1,ceili(float(world.terrain_settings.dig_range)/.1)+1):
			var point:=origin+aim*float(step)*.1
			if terrain.density(point)>=0:hit=point;break
		if not hit.is_finite() or hit.y<float(world.terrain_settings.minimum_depth)+5:return "사거리와 굴착 가능한 지층을 확인하세요."
		if not world.terrain_edits.has(body_id):world.terrain_edits[body_id]=[]
		world.terrain_edits[body_id].append({"center":[hit.x,hit.y,hit.z],"radius":FrontierEquipment.active(member).radius})
		member.carried+=1
		return ""
	if kind=="surface_attack":
		var weapon:=FrontierEquipment.active(member)
		if weapon.get("kind")!="pulse":return "공격무기를 장착하세요."
		var row:=target(world,actor,direction(args.get("aim")))
		if direction(args.get("aim"))==Vector3.ZERO:return "조준 방향 오류"
		if row.is_empty() or FrontierEcologyCatalog.form(row.form_id).category!="animal":return ""
		if not crew.has("combat"):crew.combat={}
		var key: String=body_id+"/"+str(row.id)
		var hp: int=int(crew.combat.get(key,FrontierEquipment.config().animal_health))
		if hp<=0:return "이미 무력화된 개체입니다."
		crew.combat[key]=maxi(0,hp-int(weapon.damage))
		return ""
	if kind=="surface_collect":
		var row:=target(world,actor,direction(args.get("aim")))
		if row.is_empty() or row.id!=args.get("encounter_id") or position.distance_to(row.point)>float(config().sample_distance):return "스캔한 생명체를 4m 이내에서 직접 조준하세요."
		var before: int=world.ecology.specimens.size()
		var message:=FrontierEcology.collect(world.ecology,body_id,row)
		return "" if world.ecology.specimens.size()>before else message
	if kind not in ["surface_analyze","surface_restore","surface_introduce","surface_resupply"]:return "지원하지 않는 지표 작업입니다."
	if not near_ship:return "우주선의 연구·격리 지원 범위로 돌아오세요."
	var supplies: Dictionary={"depot_rock":crew.rock}
	var before: String=FrontierUniverse.fingerprint(world.ecology)
	var result: String=""
	var terrain:=field(world)
	var layer: String="cave" if terrain.height(position.x,position.z)-position.y>6 else "surface"
	match kind:
		"surface_analyze":
			if not args.get("form_id") is String:return "연구 대상 오류"
			result=FrontierEcology.analyze(world.ecology,args.form_id,supplies)
		"surface_restore":
			if not args.get("environment") is String or not FrontierEcologyCatalog.config().habitats.has(args.environment):return "복원 환경 오류"
			result=FrontierEcology.restore_plot(world.ecology,body_id,args.environment,position,layer,supplies)
		"surface_resupply":result=FrontierEcology.resupply_plot(world.ecology,body_id,supplies)
		"surface_introduce":
			if not args.get("sample_id") is String or not world.ecology.specimens.has(args.sample_id):return "격리 표본 오류"
			var aim:=direction(args.get("aim"))
			var forward:=Vector3(aim.x,0,aim.z).normalized()
			if forward.length_squared()<.5:return "앞쪽의 평탄한 구획을 조준하세요."
			var sample: Dictionary=world.ecology.specimens[args.sample_id]
			var candidate: Dictionary={"form_id":sample.form_id,"look_id":sample.look_id,"point":position+forward*3,"layer":layer,"yaw":0.0}
			var point:=FrontierEcologyPlacement.ground(terrain,candidate)
			if not point.is_finite():return "생명체가 설 수 있는 넓고 평탄한 장소가 필요합니다."
			for id in active.values():
				if FrontierCrewWorld.vector(crew.members[id].position).distance_to(point)<2:return "승무원과 거리를 두고 이식하세요."
			result=FrontierEcology.introduce(world.ecology,body_id,args.sample_id,point,layer)
	if before==FrontierUniverse.fingerprint(world.ecology):return result
	crew.rock=supplies.depot_rock
	return ""

static func validate_world(world: Dictionary) -> String:
	if landed(world):
		var id: String=world.crew.landing.body_id
		if FrontierUniverse.ordinal_of(world.manifest,id)<0 or id!=world.location or not world.has("terrain_settings") or not world.get("ecology") is Dictionary or not world.ecology.get("planets") is Dictionary or not world.ecology.planets.has(id):return "공동 착륙에 고정 지형·생태 기록이 필요합니다."
		if not world.crew.get("navigation") is Dictionary or world.crew.navigation.mode!="idle":return "착륙과 성간 항해가 동시에 진행될 수 없습니다."
	for crate in world.crew.recovery.values():
		if crate.area=="surface" and (not crate.get("body_id") is String or FrontierUniverse.ordinal_of(world.manifest,crate.body_id)<0):return "지표 회수 화물의 행성 주소 오류"
	return ""

static func reset_cache() -> void:
	_field_key="";_ground.clear()

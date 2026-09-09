class_name FrontierLotusSupport
extends RefCounted
## Persisted host logistics. Delivery progresses without a viewer or a registered business site.
static var _config: Dictionary = {}
static func config() -> Dictionary:
	if _config.is_empty():_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/lotus_support.json"))
	return _config
static func ensure(world: Dictionary) -> void:
	if not world.has("lotus"):
		world.lotus = {"version":1,"clock":0.0,"next_request":0.0,"free_remaining":int(config().free_requests),"counter":0,"crates":{}}
static func equip_new_world(world: Dictionary) -> void:
	ensure(world)
	world.crew.rock = int(config().starting_cargo.stone)
	world.crew.cargo = config().starting_cargo.duplicate(true)
	world.crew.cargo.erase("stone")
	var nav: Dictionary = world.crew.navigation.duplicate(true)
	world.crew.shuttles = {world.crew.owner_id:{"company":true,"state":"docked","pad_slot":0,"progress":0.0,"factory_id":"","system":int(nav.system),"location":world.location,"navigation_target":world.location,"navigation":nav,"landing":{},"cargo":{},"cargo_equipment":{},"rock":0}}
	world.lotus["initial_equipped"] = true
static func touchdown() -> float:
	return float(config().dispatch_seconds + config().approach_seconds + config().drop_seconds)
static func duration() -> float:return touchdown() + float(config().departure_seconds)
static func price(world: Dictionary,resource: String) -> int:
	return 0 if int(world.get("lotus",{}).get("free_remaining",config().free_requests)) > 0 else int(config().prices.get(resource,0))*int(config().package_amount)
static func phase(row: Dictionary) -> String:
	var age: float = row.elapsed
	if row.get("blocked",false):return "투하 장소 재탐색"
	if age < float(config().dispatch_seconds):return "보급선 출발 준비"
	if age < float(config().dispatch_seconds + config().approach_seconds):return "보급선 접근 중"
	if not row.landed:return "보급 상자 투하 중"
	return "수령 가능" if age >= duration() else "수령 가능 / 보급선 이탈 중"
static func snapshot(world: Dictionary,actor: String) -> Dictionary:
	var state: Dictionary = world.get("lotus",{})
	var visible: Dictionary = {}
	var here:=FrontierShuttles.location(world,actor)
	for id in state.get("crates",{}):
		if state.crates[id].body_id==here:visible[id]=state.crates[id].duplicate(true)
	return {"free_remaining":int(state.get("free_remaining",config().free_requests)),"cooldown":maxf(0,float(state.get("next_request",0))-float(state.get("clock",0))),"crates":visible,"credits":int(world.get("business",{}).get("credits",0))}
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,clearance: Callable=Callable()) -> String:
	ensure(world)
	var local:=FrontierShuttles.context(world,actor)
	var member: Dictionary = world.crew.members[actor]
	if not FrontierCrewSurface.landed(local) or member.aboard:return "행성 지표에서 Lotus 보급을 이용하세요."
	var point:=FrontierCrewWorld.vector(member.position)
	if kind=="lotus_collect":
		var row: Dictionary = world.lotus.crates.get(str(args.get("crate_id","")),{})
		if row.is_empty() or row.body_id!=local.location or not row.landed:return "이 구역에 도착한 보급 상자가 없습니다."
		if int(row.remaining)==0:return "이미 모두 수령한 보급 상자입니다."
		var target:=FrontierCrewWorld.vector(row.position)+Vector3.UP*.7
		if point.distance_to(target)>float(config().interaction_distance):return "보급 상자 가까이에서 수령하세요."
		if not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(local),point+Vector3.UP*1.7,target):return "보급 상자까지 통로를 확보하세요."
		FrontierItemInventory.merge_legacy(world,actor)
		var amount:=mini(int(row.remaining),FrontierItemInventory.room(world,actor,row.resource))
		if amount<=0:return "배낭 공간이 부족합니다. 상자에 물자를 보관합니다."
		if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
		if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
		var stock: Dictionary = world.business.bags[actor]
		stock[row.resource]=int(stock.get(row.resource,0))+amount
		row.remaining-=amount
		# Keep empty crate during departure so its lid animation and carrier don't vanish.
		if row.remaining==0 and row.elapsed>=duration():row["empty_seconds"]=0.0
		return ""
	if kind=="lotus_request" and point.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "선박 가까이에서 통신 단말을 이용하세요."
	if kind!="lotus_request":return "지원하지 않는 Lotus 요청입니다."
	var resource:=str(args.get("resource",""))
	if not config().prices.has(resource):return "기초 보급 재료를 선택하세요."
	if float(world.lotus.clock)<float(world.lotus.next_request):return "이전 보급의 출동 대기 시간이 남았습니다."
	if world.lotus.crates.size()>=int(config().maximum_crates):return "남아 있는 보급 상자의 물자를 먼저 회수하세요."
	var field:=FrontierCrewSurface.field(local)
	if absf(field.height(point.x,point.z)-point.y)>4:return "하늘이 열린 지표에서 보급을 호출하세요."
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	var fee:=price(world,resource)
	if int(world.business.credits)<fee:return "보급 운송에 필요한 공동 크레딧이 부족합니다."
	var ordinal:=int(world.lotus.counter)+1
	var seed_value:=FrontierUniverse.derive(int(world.manifest.seed),"lotus:"+str(ordinal))
	var candidate:=find_drop(world,local.location,point,seed_value,"",clearance)
	if not candidate.is_finite():return "근처에 안전한 투하 공간이 없습니다. 넓은 지표로 이동하세요."
	world.lotus.counter=ordinal
	world.business.credits-=fee
	if fee==0:world.lotus.free_remaining-=1
	world.lotus.next_request=float(world.lotus.clock)+float(config().cooldown_seconds)
	var id: String="lotus:"+str(ordinal)
	world.lotus.crates[id]={"id":id,"body_id":local.location,"caller":actor,"resource":resource,"remaining":int(config().package_amount),"position":FrontierExpeditionBusiness.array(candidate),"origin":FrontierExpeditionBusiness.array(point),"seed":seed_value,"elapsed":0.0,"landed":false,"blocked":false,"heading":float(seed_value%6283)/1000.0}
	return ""
static func tick(world: Dictionary,delta: float,clearance: Callable=Callable()) -> bool:
	ensure(world)
	var state: Dictionary = world.lotus
	var busy: bool=float(state.clock)<float(state.next_request)
	for row in state.crates.values():
		if row.elapsed<duration() or int(row.remaining)==0:busy=true;break
	if not busy:return false
	state.clock+=delta
	for id in state.crates.keys():
		var row: Dictionary=state.crates[id]
		if float(row.elapsed)<duration():
			var next:=minf(duration(),float(row.elapsed)+delta)
			# Recheck against terrain edits, construction, vehicles and people before release/touchdown.
			if next>=float(config().dispatch_seconds+config().approach_seconds) and not row.landed:
				var p:=FrontierCrewWorld.vector(row.position)
				if not clear_drop(world,row.body_id,p,id,clearance):
					var replacement:=find_drop(world,row.body_id,FrontierCrewWorld.vector(row.origin),int(row.seed),id,clearance)
					if not replacement.is_finite():row.blocked=true;continue
					row.position=FrontierExpeditionBusiness.array(replacement)
					# Approach the new position before dropping; no sudden payload teleport in descent.
					row.elapsed=float(config().dispatch_seconds);row.blocked=false;continue
				row.blocked=false
			row.elapsed=next
			if next>=touchdown():row.landed=true
		if int(row.remaining)==0 and float(row.elapsed)>=duration():
			row["empty_seconds"]=float(row.get("empty_seconds",0))+delta
			if row.empty_seconds>=4:state.crates.erase(id)
	return true
static func find_drop(world: Dictionary,body_id: String,center: Vector3,seed_value: int,ignore: String,clearance: Callable) -> Vector3:
	var local:=FrontierPlanetSupply.context(world,body_id)
	var field:=FrontierCrewSurface.field(local)
	for i in int(config().placement_samples):
		var rng:=FrontierUniverse.derive(seed_value,"drop:"+str(i))
		var angle:=float(rng%6283)/1000.0
		var radius:=lerpf(float(config().drop_radius_min),float(config().drop_radius_max),float((rng/6283)%1000)/999.0)
		var p:=center+Vector3(sin(angle)*radius,0,cos(angle)*radius)
		p=FrontierExpeditionBusiness.ground(field,p.x,p.z,float(config().crate_radius))
		if p.is_finite() and clear_drop(world,body_id,p,ignore,clearance):return p
	return Vector3.INF
static func clear_drop(world: Dictionary,body_id: String,p: Vector3,ignore: String,clearance: Callable) -> bool:
	var local:=FrontierPlanetSupply.context(world,body_id)
	var field:=FrontierCrewSurface.field(local)
	var r:=float(config().crate_radius)
	var floor_point:=FrontierExpeditionBusiness.ground(field,p.x,p.z,r)
	if not floor_point.is_finite() or absf(floor_point.y-p.y)>.25:return false
	if p.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<20:return false
	if FrontierSurfaceWater.depth(world.get("surface_water",{}).get(body_id,FrontierSurfaceWater.create()),p)>.05:return false
	var body:=FrontierUniverse.body_from_id(world.manifest,body_id)
	if FrontierSurfaceDrainage.liquid(body.get("terrain_traits",{})) and p.y<float(JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_hydrology.json")).sea_level):return false
	var site: Dictionary=world.get("business",{}).get("sites",{}).get(body_id,{})
	if not site.is_empty() and p.distance_to(FrontierCrewWorld.vector(site.center))<7:return false
	for facility in site.get("buildings",{}).values():
		if p.distance_to(FrontierCrewWorld.vector(facility.position))<float(FrontierCatalog.entry("buildings",facility.type).get("radius",3))+r+2:return false
	for robot in site.get("robots",{}).values():
		if p.distance_to(FrontierCrewWorld.vector(robot.position))<r+2:return false
	for rover in FrontierRovers.fleet(world).vehicles.values():
		if rover.location_kind=="surface" and rover.body_id==body_id and p.distance_to(FrontierRovers.point(rover))<r+4:return false
	for row in world.lotus.crates.values():
		if row.id!=ignore and row.body_id==body_id and p.distance_to(FrontierCrewWorld.vector(row.position))<r*2+2:return false
	for id in world.crew.members:
		if FrontierShuttles.area_key(world,id)=="surface:"+body_id and p.distance_to(FrontierCrewWorld.vector(world.crew.members[id].position))<r+2:return false
	for id in FrontierShuttles.fleet(world):
		if world.location==body_id and p.distance_to(FrontierShuttles.pad(world,id))<r+4:return false
	for vein in FrontierExpeditionBusiness.veins(body,p):
		if vein.get("underground",false):continue
		var q:=FrontierCrewWorld.vector(vein.position)
		if Vector2(q.x-p.x,q.z-p.z).length()<r+3:return false
	if not scenery_clear(world,body,field,p,r):return false
	return not clearance.is_valid() or bool(clearance.call(body_id,p,r))
static func scenery_clear(world: Dictionary,body: Dictionary,field: FrontierTerrainField,p: Vector3,radius: float) -> bool:
	# Use the same seeded candidates even on unoccupied planets; no scene/assets need loading.
	var details:=FrontierSurfaceDetails.new()
	var stream:=FrontierTerrainStreamer.new();stream.field=field
	details.terrain=stream;details.body=body
	details.settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_details.json"))
	details.cluster.seed=FrontierUniverse.derive(int(body.seed),"surface-clusters-v1")
	details.cluster.frequency=.062;details.cluster.fractal_octaves=2
	var clear:=true
	if details.settings.families.has(body.traits.id):
		var span: float=details.settings.tile_size
		for x in range(floori((p.x-radius-4)/span),floori((p.x+radius+4)/span)+1):
			for z in range(floori((p.z-radius-4)/span),floori((p.z+radius+4)/span)+1):
				for item in details.candidates(Vector2i(x,z)):
					var transform: Transform3D=item.transform
					if p.distance_to(transform.origin)<radius+2.0*transform.basis.get_scale().length()/sqrt(3.0):clear=false;break
				if not clear:break
			if not clear:break
	details.free();stream.free()
	if not clear:return false
	var record: Dictionary=world.get("ecology",{}).get("planets",{}).get(body.id,{})
	if not record.is_empty():
		for candidate in FrontierEcologyPlacement.candidates(body,record,p):
			if candidate.layer!="surface":continue
			var shape: Dictionary=FrontierEcologyCatalog.form(candidate.form_id).geometry.near
			var scale_value: float=FrontierEcologyCatalog.look(candidate.form_id,candidate.look_id).scale
			var extent:=Vector2(maxf(absf(shape.min[0]),absf(shape.max[0])),maxf(absf(shape.min[2]),absf(shape.max[2]))).length()*scale_value
			if Vector2(p.x-candidate.point.x,p.z-candidate.point.z).length()<radius+extent+1:return false
	return true
static func blocks(world: Dictionary,body_id: String,p: Vector3,radius: float) -> bool:
	for row in world.get("lotus",{}).get("crates",{}).values():
		if row.body_id==body_id and p.distance_to(FrontierCrewWorld.vector(row.position))<radius+float(config().crate_radius)+1:return true
	return false
static func validate(world: Dictionary) -> String:
	if not world.has("lotus"):return ""
	var state: Variant=world.lotus
	if not state is Dictionary or state.get("version")!=1 or not state.get("crates") is Dictionary:return "Lotus 지원 기록 오류"
	if not FrontierExpeditionBusiness.integer(state.get("free_remaining"),0,int(config().free_requests)) or not FrontierExpeditionBusiness.integer(state.get("counter"),0,100000000):return "Lotus 지원 한도 오류"
	for key in ["clock","next_request"]:
		if not FrontierUniverse._finite(state.get(key),0,1e12):return "Lotus 시간 기록 오류"
	if state.crates.size()>int(config().maximum_crates):return "Lotus 상자 한도 오류"
	for id in state.crates:
		var row: Variant=state.crates[id]
		if not row is Dictionary or row.get("id")!=id or not config().prices.has(row.get("resource","")):return "Lotus 화물 종류 오류"
		if FrontierUniverse.ordinal_of(world.manifest,str(row.get("body_id","")))<0 or not world.crew.members.has(row.get("caller","")):return "Lotus 배송 주소 오류"
		if not FrontierExpeditionBusiness.integer(row.get("remaining"),0,int(config().package_amount)) or not row.get("landed") is bool or not row.get("blocked") is bool:return "Lotus 화물 수량·상태 오류"
		for key in ["origin","position"]:
			if not FrontierUniverse._vector3_array(row.get(key)):return "Lotus 투하 좌표 오류"
		if not FrontierUniverse._finite(row.get("elapsed"),0,duration()) or not FrontierUniverse._finite(row.get("heading"),0,TAU) or not FrontierExpeditionBusiness.integer(row.get("seed"),0,2147483647):return "Lotus 배송 진행 오류"
		if bool(row.landed)!=(float(row.elapsed)>=touchdown()):return "Lotus 도착 상태 오류"
	return ""

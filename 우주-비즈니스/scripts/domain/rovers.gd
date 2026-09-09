class_name FrontierRovers
extends RefCounted
## Vehicle assets live in the host world; seats and short reservations live in the session.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/rovers.json"))
	return _config
static func fleet(world: Dictionary) -> Dictionary:return world.get("rovers",{"version":1,"counter":0,"vehicles":{},"jobs":{}})
static func ensure(world: Dictionary) -> Dictionary:
	if not world.has("rovers"):world.rovers=fleet(world)
	return world.rovers
static func research(member: Dictionary) -> int:return maxi(int(FrontierEarlyAccess.config().basic_field_logistics),int(member.get("loadout",{}).get("field_logistics",0)))
static func local(world: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for id in fleet(world).vehicles:
		var r: Dictionary=fleet(world).vehicles[id]
		if r.location_kind=="surface" and r.body_id==world.location:result[id]=r
	return result
static func seated(runtime: Dictionary,actor: String) -> Dictionary:
	for id in runtime.get("seats",{}):
		var index: int=runtime.seats[id].find(actor)
		if index>=0:return {"id":id,"seat":index}
	return {}
static func seats(runtime: Dictionary,id: String) -> Array:return runtime.get("seats",{}).get(id,["",""])
static func occupied(runtime: Dictionary,id: String) -> bool:return seats(runtime,id)!=["",""]
static func busy(runtime: Dictionary,id: String) -> bool:return runtime.get("tasks",{}).has(id)
static func point(r: Dictionary,offset: Array=[0,0,0]) -> Vector3:
	return FrontierCrewWorld.vector(r.position)+Basis.from_euler(FrontierCrewWorld.vector(r.rotation))*FrontierCrewWorld.vector(offset)
static func stopped(r: Dictionary) -> bool:return absf(float(r.speed))<=1.0
static func within(world: Dictionary,actor: String,r: Dictionary,distance: float) -> bool:
	return r.location_kind=="surface" and r.body_id==world.location and point(r).distance_to(FrontierCrewWorld.vector(world.crew.members[actor].position))<=distance
static func stats(r: Dictionary) -> Dictionary:
	var upgraded: bool=int(r.upgrade_level)>0
	return {"speed":float(config().speed)*(float(config().upgrade.speed_multiplier) if upgraded else 1.0),"battery":float(config().upgrade.battery if upgraded else config().battery),"health":float(config().upgrade.health if upgraded else config().health)}
static func room(r: Dictionary,resource: String) -> int:
	var count:=FrontierItemInventory.used(r.cargo,r.equipment.size());var stack:=FrontierItemInventory.stack_size(resource);var old:=int(r.cargo.get(resource,0))
	return maxi(0,int(config().cargo_slots)-count)*stack+(0 if old%stack==0 else stack-old%stack)
static func safe(world: Dictionary,p: Vector3,radius: float=2.3,ignore: String="") -> Vector3:
	var field:=FrontierCrewSurface.field(world)
	var result:=FrontierExpeditionBusiness.ground(field,p.x,p.z,radius)
	if not result.is_finite():return Vector3.INF
	if maxf(absf(p.x),absf(p.z))>float(world.terrain_settings.region_half_extent)-radius:return Vector3.INF
	var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	if Vector2(result.x-ship.x,result.z-ship.z).length()<radius+5.5:return Vector3.INF
	for b in FrontierExpeditionBusiness.site(world).get("buildings",{}).values():
		if Vector2(result.x-float(b.position[0]),result.z-float(b.position[2])).length()<radius+float(FrontierCatalog.entry("buildings",b.type).radius):return Vector3.INF
	for id in local(world):
		if id!=ignore and point(local(world)[id]).distance_to(result)<radius+2.4:return Vector3.INF
	return result
static func exit_point(world: Dictionary,r: Dictionary,preferred: int) -> Vector3:
	for offset in [[-2.45,0,0],[2.45,0,0],[0,0,3.2],[0,0,-3.2]] if preferred==0 else [[2.45,0,0],[-2.45,0,0],[0,0,3.2],[0,0,-3.2]]:
		var p:=safe(world,point(r,offset),.45,str(r.id))
		if p.is_finite():return p+Vector3.UP*.1
	return Vector3.INF
static func spawn_point(world: Dictionary,center: Vector3,ignore: String="",radius: float=7.0,validator: Callable=Callable()) -> Vector3:
	for i in 16:
		var angle:=TAU*i/16.0
		var p:=safe(world,center+Vector3(sin(angle),0,cos(angle))*radius,2.3,ignore)
		if p.is_finite() and (not validator.is_valid() or validator.call(p)):return p
	return Vector3.INF
static func factory_busy(world: Dictionary,id: String) -> bool:
	for row in fleet(world).jobs.values():
		if row.body_id==world.location and row.factory_id==id:return true
	return false
static func craft_reason(world: Dictionary,actor: String,id: String) -> String:
	var s:=FrontierExpeditionBusiness.site(world);var b: Dictionary=s.get("buildings",{}).get(id,{})
	if research(world.crew.members[actor])<1:return "착륙선에서 현장 물류 I을 연구하세요."
	if not FrontierPlanetSupply.operating(s) or b.get("type")!="factory":return "가동 중인 로봇 제작소가 필요합니다."
	if FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(b.position))>8:return "제작소 가까이 이동하세요."
	if not b.get("active",false):return "제작소의 전력·가동 상태를 확인하세요."
	if factory_busy(world,id) or not b.get("production",{}).is_empty():return "제작소가 다른 제품을 조립 중입니다."
	for job in s.jobs.values():
		if job.factory_id==id:return "로봇 조립이 끝나면 제작하세요."
	for job in world.get("engineering",{}).get("projects",{}).values():
		if job.get("facility_id")==id and job.get("stage") in ["prototype","trial"]:return "현장 공학 작업이 진행 중입니다."
	var pending_local:=0
	for job in fleet(world).jobs.values():
		if job.body_id==world.location:pending_local+=1
	if fleet(world).vehicles.size()+fleet(world).jobs.size()>=int(config().maximum_world_vehicles) or local(world).size()+pending_local>=int(config().maximum_local_vehicles):return "차량 보관 한도에 도달했습니다."
	if not FrontierExpeditionBusiness.affordable(s.inventory,config().cost):return "공동 창고의 로버 부품이 부족합니다."
	return ""
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,runtime: Dictionary) -> String:
	if kind in ["rover_transport_upgrade","rover_research2","rover_upgrade","rover_load","rover_unload","rover_cancel"]:return FrontierRoverTransport.apply(world,actor,kind,args,runtime)
	if not FrontierCrewSurface.landed(world):return "행성에 착륙한 뒤 차량을 사용하세요."
	var member: Dictionary=world.crew.members[actor];var actor_pos:=FrontierCrewWorld.vector(member.position)
	if member.aboard:return "우주선에서 내린 뒤 실행하세요."
	if kind=="rover_research":
		if actor_pos.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "착륙선 연구실에 접근하세요."
		if not FrontierEarlyAccess.available(world.get("business",{}),"robotics"):return "기초 설계가 필요합니다."
		if research(member)>=1:return "현장 물류 I 연구를 보유하고 있습니다."
		if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),config().research_cost):return "가방의 연구 재료가 부족합니다."
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],config().research_cost,-1)
		if not member.has("loadout"):member.loadout=FrontierEquipment.create(member.profile)
		member.loadout.field_logistics=1;return ""
	if kind=="rover_craft":
		var factory:=str(args.get("factory_id",""));var reason:=craft_reason(world,actor,factory)
		if not reason.is_empty():return reason
		var f:=ensure(world);f.counter+=1;var id: String="rover:"+str(int(f.counter))
		FrontierExpeditionBusiness.transfer(FrontierExpeditionBusiness.site(world).inventory,config().cost,-1)
		f.jobs[id]={"id":id,"factory_id":factory,"body_id":world.location,"progress":0.0};return ""
	var id:=str(args.get("id",""));var r: Dictionary=fleet(world).vehicles.get(id,{})
	if r.is_empty() or not within(world,actor,r,float(config().service_range)):return "가까운 현장 로버를 선택하세요."
	var seat:=seated(runtime,actor)
	if kind=="rover_exit":
		if seat.get("id")!=id:return "탑승한 차량이 아닙니다."
		# The request only starts safe braking; the authority completes exit after finding space.
		runtime.exits[actor]=id;return ""
	if busy(runtime,id):return "차량 정비·복구 작업이 진행 중입니다."
	if kind=="rover_enter":
		if not seat.is_empty():return "이미 차량에 탑승했습니다."
		if r.overturned or not stopped(r):return "바로 선 차량이 정차하면 탑승하세요."
		var index:=int(args.get("seat",-1))
		if index not in [0,1]:return "운전석 또는 동승석 문을 선택하세요."
		if point(r,config().doors[index]).distance_to(actor_pos)>float(config().door_range):return "선택한 문 3m 이내로 이동하세요."
		if seats(runtime,id)[index]!="":return "다른 승무원이 먼저 탑승했습니다."
		if not runtime.seats.has(id):runtime.seats[id]=["",""]
		runtime.seats[id][index]=actor;member.position=FrontierExpeditionBusiness.array(point(r,config().eyes[index])-Vector3.UP*1.72);r.event_serial+=1;r.event="door";return ""
	if kind=="rover_switch":
		if seat.get("id")!=id or int(seat.seat)!=1 or not stopped(r):return "정차한 동승석에서만 운전석으로 이동할 수 있습니다."
		if seats(runtime,id)[0]!="":return "운전석이 사용 중입니다."
		runtime.seats[id]=[actor,""];return ""
	if not seat.is_empty():return "먼저 로버에서 내리세요."
	if not stopped(r):return "차량이 정지하면 작업하세요."
	if kind=="rover_cargo_open":
		if point(r,config().cargo_point).distance_to(actor_pos)>float(config().cargo_range):return "후방 화물함에 접근하세요."
		r.event="door";r.event_serial+=1;return ""
	if kind=="rover_transfer":return transfer(world,actor,r,args)
	if kind=="rover_repair":
		if float(r.health)>=float(stats(r).health):return "내구도가 최대입니다."
		if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),config().repair_cost):return "가방에 철 5·구리 2가 필요합니다."
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],config().repair_cost,-1);r.health=minf(float(stats(r).health),float(r.health)+float(config().repair_amount));r.event="service";r.event_serial+=1;return ""
	if kind=="rover_rescue":
		if float(r.battery)>=20:return "배터리가 20 미만일 때 구조 충전할 수 있습니다."
		if int(world.business.credits)<int(config().rescue_cost):return "구조 충전 비용 50 Cr가 부족합니다."
		world.business.credits-=int(config().rescue_cost);r.battery=float(config().rescue_charge);r.event="start";r.event_serial+=1;return ""
	if kind=="rover_recover":
		if not r.overturned or occupied(runtime,id):return "전원이 내린 전복 차량을 바로 세울 수 있습니다."
		runtime.tasks[id]={"kind":"recover","actor":actor,"progress":0.0,"seconds":float(config().recovery_seconds),"origin":member.position.duplicate()};return ""
	return "지원하지 않는 차량 작업입니다."
static func transfer(world: Dictionary,actor: String,r: Dictionary,args: Dictionary) -> String:
	if point(r,config().cargo_point).distance_to(FrontierCrewWorld.vector(world.crew.members[actor].position))>float(config().cargo_range):return "후방 화물함 가까이 이동하세요."
	var withdraw: bool=args.get("withdraw",false)==true
	if not world.crew.members[actor].has("loadout"):world.crew.members[actor].loadout=FrontierEquipment.create(world.crew.members[actor].profile)
	var loadout:=FrontierEquipment.state(world.crew.members[actor])
	if args.has("item_id"):
		var item:=str(args.item_id);var key:=actor+"/"+item
		if withdraw:
			if not r.equipment.has(key):return "내가 보관한 장비만 꺼낼 수 있습니다."
			if loadout.items.has(item) or FrontierItemInventory.used(FrontierExpeditionBusiness.bag(world,actor),loadout.items.size()+1)>FrontierItemInventory.capacity(world.crew.members[actor]):return "가방 공간이 부족하거나 이미 소지한 장비입니다."
			loadout.items[item]=r.equipment[key].definition;r.equipment.erase(key)
		else:
			if not loadout.items.has(item):return "내 장비를 선택하세요."
			if FrontierItemInventory.used(r.cargo,r.equipment.size())>=int(config().cargo_slots):return "차량 화물칸이 가득 찼습니다."
			r.equipment[key]={"owner":actor,"item_id":item,"definition":loadout.items[item]};loadout.items.erase(item)
			for i in loadout.slots.size():
				if loadout.slots[i]==item:loadout.slots[i]=""
	else:
		var resource:=str(args.get("resource",""))
		if FrontierCatalog.entry("resources",resource).is_empty():return "옮길 자원을 선택하세요."
		var stock:=FrontierExpeditionBusiness.bag(world,actor)
		var source: Dictionary=r.cargo if withdraw else stock
		var destination: Dictionary=stock if withdraw else r.cargo
		var capacity:=FrontierItemInventory.room(world,actor,resource) if withdraw else room(r,resource)
		var amount:=mini(int(source.get(resource,0)),mini(capacity,int(FrontierItemInventory.config().resource_stack)))
		if amount<=0:return "옮길 재고 또는 화물 공간이 부족합니다."
		source[resource]-=amount;destination[resource]=int(destination.get(resource,0))+amount
	r.event="door";r.event_serial+=1;return ""
static func manufacture(world: Dictionary,dt: float,validator: Callable=Callable()) -> void:
	if not world.has("rovers"):return
	var f: Dictionary=world.rovers
	for id in f.jobs.keys():
		var job: Dictionary=f.jobs[id]
		if job.body_id!=world.location:continue
		var s:=FrontierExpeditionBusiness.site(world);var b: Dictionary=s.get("buildings",{}).get(job.factory_id,{})
		if not FrontierPlanetSupply.operating(s) or not b.get("active",false):continue
		job.progress=minf(float(config().craft_seconds),float(job.progress)+dt*FrontierProductionTier2.factor(b)*FrontierProgressionResearch.multiplier(FrontierProgressionResearch.shared(world)))
		if float(job.progress)<float(config().craft_seconds):continue
		var p:=spawn_point(world,FrontierCrewWorld.vector(b.position),"",float(config().spawn_radius),validator)
		if not p.is_finite():continue
		f.vehicles[id]={"id":id,"definition":config().definition,"owner_world_id":world.crew.world_id,"location_kind":"surface","body_id":world.location,"position":FrontierExpeditionBusiness.array(p),"rotation":[0.0,0.0,0.0],"upgrade_level":0,"battery":float(config().battery),"health":float(config().health),"cargo":FrontierExpeditionBusiness.inventory(),"equipment":{},"speed":0.0,"steering":0.0,"overturned":false,"distance":0.0,"event":"complete","event_serial":1}
		f.jobs.erase(id)
static func valid(world: Dictionary) -> String:
	if not world.has("rovers"):return ""
	if not world.get("crew") is Dictionary or not world.crew.get("members") is Dictionary:return "차량 세계 소유자 누락"
	var f: Variant=world.rovers
	if not f is Dictionary or f.get("version")!=1 or not FrontierExpeditionBusiness.integer(f.get("counter"),0,1000000) or not f.get("vehicles") is Dictionary or not f.get("jobs") is Dictionary:return "차량 원장 형식 오류"
	if f.vehicles.size()+f.jobs.size()>int(config().maximum_world_vehicles):return "차량 원장 한도 오류"
	var stored_items: Dictionary={}
	for id in f.vehicles.keys()+f.jobs.keys():
		if not id is String or not id.begins_with("rover:") or not id.trim_prefix("rover:").is_valid_int() or id!="rover:"+str(int(id.trim_prefix("rover:"))) or int(id.trim_prefix("rover:"))<1 or int(id.trim_prefix("rover:"))>int(f.counter):return "차량 고유 번호 오류"
	for id in f.vehicles:
		var r: Variant=f.vehicles[id]
		if not r is Dictionary or r.get("id")!=id or r.get("definition")!=config().definition or r.get("owner_world_id")!=world.crew.world_id or r.get("location_kind") not in ["surface","ship"]:return "차량 소유·위치 오류"
		if FrontierUniverse.ordinal_of(world.manifest,str(r.get("body_id","")))<0 or not FrontierUniverse._vector3_array(r.get("position")) or not FrontierUniverse._vector3_array(r.get("rotation")):return "차량 지표 위치 오류"
		if not FrontierExpeditionBusiness.integer(r.get("upgrade_level"),0,1) or not FrontierUniverse._finite(r.get("battery"),0,float(stats(r).battery)) or not FrontierUniverse._finite(r.get("health"),0,float(stats(r).health)):return "차량 강화·내구·전력 오류"
		if not FrontierExpeditionBusiness.valid_inventory(r.get("cargo"),400) or not r.get("equipment") is Dictionary or FrontierItemInventory.used(r.cargo,r.equipment.size())>int(config().cargo_slots):return "차량 화물칸 오류"
		for key in r.equipment:
			var item: Variant=r.equipment[key]
			if not item is Dictionary or key!=str(item.get("owner"))+"/"+str(item.get("item_id")) or not world.crew.members.has(item.get("owner")) or not FrontierEquipment.config().items.has(item.get("definition")):return "차량 장비 소유 기록 오류"
			if stored_items.has(key) or world.crew.members[item.owner].get("loadout",{}).get("items",{}).has(item.item_id) or world.crew.get("cargo_equipment",{}).has(key):return "차량 장비 중복 위치 오류"
			for site in world.get("business",{}).get("sites",{}).values():
				if site.get("stored_equipment",{}).has(key):return "차량·창고 장비 중복 오류"
			stored_items[key]=true
		if not FrontierUniverse._finite(r.get("speed"),-20,30) or not FrontierUniverse._finite(r.get("steering"),-1,1) or not r.get("overturned") is bool or not FrontierUniverse._finite(r.get("distance"),0,1000000000) or not r.get("event") is String or not FrontierExpeditionBusiness.integer(r.get("event_serial"),0,1000000000):return "차량 운동 기록 오류"
	for id in f.jobs:
		var job: Variant=f.jobs[id]
		if f.vehicles.has(id) or not job is Dictionary or job.get("id")!=id or not FrontierUniverse._finite(job.get("progress"),0,float(config().craft_seconds)):return "차량 제작 예약 오류"
		var s: Dictionary=world.get("business",{}).get("sites",{}).get(job.get("body_id"),{})
		if s.get("buildings",{}).get(job.get("factory_id"),{}).get("type")!="factory":return "차량 제작소 참조 오류"
	return FrontierRoverTransport.valid(f)
static func brake_all(world: Dictionary) -> void:
	for r in fleet(world).vehicles.values():r.speed=0.0;r.steering=0.0
static func release(world: Dictionary,runtime: Dictionary,actor: String) -> void:
	var seat:=seated(runtime,actor)
	if not seat.is_empty():
		var r: Dictionary=fleet(world).vehicles.get(seat.id,{})
		if not r.is_empty():r.speed=0.0
		runtime.seats[seat.id][int(seat.seat)]=""
	runtime.exits.erase(actor)
	for id in runtime.tasks.keys():
		if runtime.tasks[id].actor==actor:runtime.tasks.erase(id)

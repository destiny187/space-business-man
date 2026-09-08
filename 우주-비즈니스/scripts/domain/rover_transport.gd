class_name FrontierRoverTransport
extends RefCounted
static func config() -> Dictionary:return FrontierRovers.config().transport
static func ship(fleet: Dictionary) -> String:return str(fleet.get("ship_vehicle",""))
static func level(fleet: Dictionary) -> int:return int(fleet.get("transport_level",0))
static func units(r: Dictionary) -> float:
	return float(config().body_units)+FrontierExpeditionBusiness.total(r.cargo)*float(config().resource_units)+r.equipment.size()*float(config().equipment_units)
static func near_ship(world: Dictionary,actor: String) -> bool:return FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))<=float(FrontierCrewSurface.config().boarding_distance)
static func duration(member: Dictionary) -> float:return float(config().fast_seconds) if FrontierRovers.research(member)>=2 else float(config().seconds)
static func transport_busy(runtime: Dictionary) -> bool:
	for task in runtime.get("tasks",{}).values():
		if task.kind in ["load","unload"]:return true
	return false
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,runtime: Dictionary) -> String:
	var f:=FrontierRovers.ensure(world);var member: Dictionary=world.crew.members[actor]
	if not FrontierCrewSurface.landed(world) or member.aboard:return "착륙 후 우주선에서 내린 뒤 실행하세요."
	if not FrontierRovers.seated(runtime,actor).is_empty():return "먼저 로버에서 내리세요."
	if kind=="rover_transport_upgrade":
		if actor!=world.crew.owner_id or not near_ship(world,actor):return "호스트가 착륙선 정비소에서 개조하세요."
		if level(f)>=1:return "차량 적재 개조 I을 갖추고 있습니다."
		var site:=FrontierExpeditionBusiness.site(world)
		if not FrontierPlanetSupply.operating(site) or not FrontierExpeditionBusiness.affordable(site.inventory,config().cost):return "현장 공동 창고의 적재 개조 부품이 부족합니다."
		FrontierExpeditionBusiness.transfer(site.inventory,config().cost,-1);f.transport_level=1;f.ship_vehicle="";return ""
	if kind=="rover_research2":
		if not near_ship(world,actor):return "착륙선 연구실에 접근하세요."
		if FrontierRovers.research(member)!=1:return "현장 물류 I을 연구했으며 II가 없는 캐릭터가 진행할 수 있습니다."
		if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),config().research_cost):return "가방에 제어 회로 2·열전달 유닛 1이 필요합니다."
		FrontierExpeditionBusiness.transfer(world.business.bags[actor],config().research_cost,-1);member.loadout.field_logistics=2;return ""
	var id:=str(args.get("id",ship(f) if kind=="rover_unload" else ""));var r: Dictionary=f.vehicles.get(id,{})
	if r.is_empty():return "운용할 로버를 선택하세요."
	if kind=="rover_cancel":
		if runtime.tasks.get(id,{}).get("actor")!=actor:return "내가 시작한 차량 작업만 취소할 수 있습니다."
		runtime.tasks.erase(id);return ""
	if FrontierRovers.busy(runtime,id):return "차량 작업이 이미 진행 중입니다."
	if kind=="rover_upgrade":
		if not FrontierRovers.within(world,actor,r,8) or not FrontierRovers.stopped(r) or FrontierRovers.occupied(runtime,id) or r.overturned:return "바로 선 로버를 정차하고 전원 내린 뒤 8m 이내에서 정비하세요."
		if int(r.upgrade_level)>=1:return "로버는 이미 Mk.2입니다."
		if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),FrontierRovers.config().upgrade.cost):return "가방의 로버 개조 부품이 부족합니다."
		start(runtime,r,actor,"upgrade",float(FrontierRovers.config().upgrade.seconds),member.position);return ""
	if kind not in ["rover_load","rover_unload"]:return "지원하지 않는 운송 작업입니다."
	if level(f)<1:return "선박 정비소에서 차량 적재 개조 I을 제작하세요."
	if transport_busy(runtime):return "다른 차량 적재·하역이 진행 중입니다."
	if not near_ship(world,actor):return "착륙선 적재 구역에 접근하세요."
	if kind=="rover_load":
		if not ship(f).is_empty():return "선박의 차량 한 자리가 사용 중입니다."
		if not FrontierRovers.within(world,actor,r,8) or not FrontierRovers.stopped(r) or FrontierRovers.occupied(runtime,id) or r.overturned:return "전원이 내린 정상 자세의 정차 차량 8m 이내에서 적재하세요."
		if FrontierRovers.point(r).distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(config().range):return "착륙선 12m 이내 적재 구역에 주차하세요."
		if units(r)>float(config().capacity):return "선박의 차량 적재하중이 부족합니다."
		start(runtime,r,actor,"load",duration(member),member.position)
	else:
		if FrontierRovers.local(world).size()>=int(FrontierRovers.config().maximum_local_vehicles):return "이 행성의 차량 한도에 도달했습니다."
		if ship(f)!=id or r.location_kind!="ship":return "선박 적재함의 차량을 선택하세요."
		var p: Array=runtime.get("unload_point",[])
		if p.size()!=3:return "착륙선 주변의 하역 공간이 막혀 있습니다."
		start(runtime,r,actor,"unload",duration(member),member.position);runtime.tasks[id].destination=p.duplicate()
	return ""
static func start(runtime: Dictionary,r: Dictionary,actor: String,kind: String,seconds: float,origin: Array) -> void:
	runtime.get("status",{}).erase(actor)
	runtime.tasks[r.id]={"kind":kind,"actor":actor,"progress":0.0,"seconds":seconds,"origin":origin.duplicate(),"vehicle_origin":r.position.duplicate(),"health":r.health,"body_id":r.body_id,"event":r.event_serial}
static func interrupted(world: Dictionary,r: Dictionary,task: Dictionary,active: Array) -> String:
	if task.actor not in active:return "담당자가 나가 작업을 취소했습니다."
	if not FrontierCrewSurface.landed(world) or world.crew.members[task.actor].aboard:return "출항 준비로 차량 작업을 취소했습니다."
	if task.kind!="unload" and r.body_id!=world.location:return "현장을 떠나 차량 작업을 취소했습니다."
	if not near_ship(world,task.actor) and task.kind in ["load","unload"]:return "적재 구역을 벗어나 작업을 취소했습니다."
	if task.kind=="upgrade" and not FrontierRovers.within(world,task.actor,r,8):return "정비 구역을 벗어나 작업을 취소했습니다."
	if float(r.health)<float(task.health) or FrontierRovers.point(r).distance_to(FrontierCrewWorld.vector(task.vehicle_origin))>.4 or not FrontierRovers.stopped(r):return "차량 이동·피해로 작업을 취소했습니다."
	return ""
static func finish(world: Dictionary,r: Dictionary,task: Dictionary) -> String:
	var f:=FrontierRovers.ensure(world)
	match task.kind:
		"upgrade":
			var stock:=FrontierExpeditionBusiness.bag(world,task.actor)
			if not FrontierExpeditionBusiness.affordable(stock,FrontierRovers.config().upgrade.cost):return "가방의 개조 부품이 부족해 정비를 마치지 못했습니다."
			FrontierExpeditionBusiness.transfer(stock,FrontierRovers.config().upgrade.cost,-1);r.upgrade_level=1
			# Upgrading extends capacity; it does not erase existing wear or duplicate charge.
			r.event="service";r.event_serial+=1
		"load":
			if not ship(f).is_empty():return "차량 적재함이 사용 중입니다."
			r.location_kind="ship";r.speed=0.0;r.steering=0.0;f.ship_vehicle=r.id
		"unload":
			if ship(f)!=r.id:return "적재 차량이 바뀌었습니다."
			r.location_kind="surface";r.body_id=world.location;r.position=task.destination.duplicate();r.rotation=[0.0,0.0,0.0];r.speed=0.0;r.steering=0.0;f.ship_vehicle="";r.event="complete";r.event_serial+=1
	return ""
static func valid(f: Dictionary) -> String:
	if not FrontierExpeditionBusiness.integer(f.get("transport_level",0),0,1) or not f.get("ship_vehicle","") is String:return "차량 적재 개조 기록 오류"
	var aboard:=ship(f)
	if not aboard.is_empty():
		if level(f)<1 or not f.vehicles.has(aboard) or f.vehicles[aboard].location_kind!="ship" or units(f.vehicles[aboard])>float(config().capacity):return "선박 차량 자리·하중 오류"
	for id in f.vehicles:
		if f.vehicles[id].location_kind=="ship" and id!=aboard:return "선박 차량 중복 위치 오류"
	return ""

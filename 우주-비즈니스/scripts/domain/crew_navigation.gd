class_name FrontierCrewNavigation
extends RefCounted
static func create(world: Dictionary) -> Dictionary:
	var ordinal:=FrontierUniverse.ordinal_of(world.manifest,world.location)
	return {"system":ordinal/4,"target":FrontierUniverse.ordinal_of(world.manifest,world.get("navigation_target",world.location)),"position":world.flight_position.duplicate(),"direction":[0.0,0.0,-1.0],"speed":0.0,"mode":"idle","jump_left":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("mode") not in ["idle","approach","jump"]:return "공동 항해 상태 오류"
	for entry in [["system",249999],["target",999999]]:
		if not FrontierUniverse._finite(value.get(entry[0]),0,entry[1]) or value[entry[0]]!=floorf(value[entry[0]]):return "공동 항로 주소 오류"
	if not FrontierUniverse._vector3_array(value.get("position")) or not FrontierUniverse._vector3_array(value.get("direction")):return "공동 선체 위치 오류"
	if not FrontierUniverse._finite(value.get("speed"),0,1000) or not FrontierUniverse._finite(value.get("jump_left"),0,10):return "공동 항해 속도 오류"
	return ""
static func center(ordinal: int) -> Vector3:return [Vector3(-620,-130,-2400),Vector3(1150,340,-3600),Vector3(-2100,450,-4900),Vector3(2400,-500,-6000)][ordinal%4]
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,active: Dictionary) -> String:
	if FrontierCrewSurface.landed(world):return "지표의 승무원들과 우주선으로 복귀한 뒤 항해하세요."
	var crew: Dictionary=world.crew
	if actor!=crew.pilot_id:return "현재 조종사만 항로를 조작할 수 있습니다."
	var nav: Dictionary=crew.navigation
	if nav.mode!="idle":return "항해를 마친 뒤 다음 항로를 설정하세요."
	if kind=="navigate":
		if not FrontierUniverse._finite(args.get("ordinal"),0,int(world.manifest.settings.planet_count)-1) or args.ordinal!=floorf(args.ordinal):return "행성 주소가 올바르지 않습니다."
		nav.target=int(args.ordinal);world.navigation_target=FrontierUniverse.body_id(world.manifest,int(nav.target))
	elif kind=="depart":
		for id in active.values():
			if not crew.members[id].aboard or not crew.members[id].ready:return "연결된 승무원 모두 승선하고 준비해야 출항할 수 있습니다."
		nav.mode="approach" if int(nav.target)/4==int(nav.system) else "jump"
		nav.jump_left=float(world.manifest.settings.flight.jump_seconds) if nav.mode=="jump" else 0.0
		if nav.mode=="jump":
			var position:=FrontierCrewWorld.vector(nav.position);var nearest:=INF;var direction:=Vector3.FORWARD
			for i in 4:
				var separation:=position.distance_to(center(i))
				if separation<nearest:nearest=separation;direction=(position-center(i)).normalized()
			nav.direction=[direction.x,direction.y,direction.z]
	else:return "지원하지 않는 항해 명령입니다."
	return ""
static func step(world: Dictionary,delta: float) -> bool:
	var nav: Dictionary=world.crew.navigation
	if nav.mode=="idle":return false
	var cfg: Dictionary=world.manifest.settings.flight
	var propulsion: float=FrontierVesselRefit.stats(world).speed
	var position:=FrontierCrewWorld.vector(nav.position)
	var direction:=FrontierCrewWorld.vector(nav.direction)
	if nav.mode=="jump":
		nav.jump_left=maxf(0,float(nav.jump_left)-delta);nav.speed=cfg.boost_speed
		position+=direction*float(nav.speed)*delta
		if nav.jump_left<=0:
			nav.system=int(nav.target)/4;position=Vector3(0,0,80);nav.mode="approach"
	else:
		var body:=FrontierUniverse.body(world.manifest,int(nav.target))
		var target:=center(int(nav.target))
		var radius:=240.0+float(body.seed%190)
		var separation:=position.distance_to(target)-radius
		if separation<=float(cfg.arrival_clearance)+3:
			nav.mode="idle";nav.speed=0;world.location=body.id;world.visited[body.id]=true
			for id in world.crew.members:world.crew.members[id].ready=false
		else:
			direction=(target-position).normalized()
			nav.speed=move_toward(float(nav.speed),minf(float(cfg.cruise_speed)*propulsion,maxf(12,separation-float(cfg.arrival_clearance))),float(cfg.acceleration)*propulsion*delta)
			position+=direction*minf(float(nav.speed)*delta,maxf(0,separation-float(cfg.arrival_clearance)))
	nav.position=[position.x,position.y,position.z];nav.direction=[direction.x,direction.y,direction.z]
	world.flight_position=nav.position.duplicate()
	if nav.mode!="idle":world.location=FrontierUniverse.body_id(world.manifest,int(nav.system)*4)
	return nav.mode=="idle"

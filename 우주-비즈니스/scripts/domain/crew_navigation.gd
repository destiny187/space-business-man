class_name FrontierCrewNavigation
extends RefCounted
static func create(world: Dictionary) -> Dictionary:
	var ordinal:=FrontierUniverse.ordinal_of(world.manifest,world.location)
	return {"system":ordinal/int(world.manifest.settings.planets_per_system),"target":FrontierUniverse.ordinal_of(world.manifest,world.get("navigation_target",world.location)),"position":world.flight_position.duplicate(),"direction":[0.0,0.0,-1.0],"speed":0.0,"mode":"idle","jump_left":0.0,"orbit_time":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("mode") not in ["idle","approach","jump"]:return "공동 항해 상태 오류"
	for entry in [["system",249999],["target",999999]]:
		if not FrontierUniverse._finite(value.get(entry[0]),0,entry[1]) or value[entry[0]]!=floorf(value[entry[0]]):return "공동 항로 주소 오류"
	if not FrontierUniverse._vector3_array(value.get("position")) or not FrontierUniverse._vector3_array(value.get("direction")):return "공동 선체 위치 오류"
	if not FrontierUniverse._finite(value.get("orbit_time",0),0,1e12):return "궤도 시간 오류"
	if not FrontierUniverse._finite(value.get("speed"),0,1000) or not FrontierUniverse._finite(value.get("jump_left"),0,10):return "공동 항해 속도 오류"
	return ""
static func center(ordinal: int,manifest: Dictionary={},elapsed: float=0.0) -> Vector3:return FrontierUniverse.position(manifest,ordinal,elapsed)
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
		nav.mode="approach" if int(nav.target)/int(world.manifest.settings.planets_per_system)==int(nav.system) else "jump"
		nav.jump_left=float(world.manifest.settings.flight.jump_seconds) if nav.mode=="jump" else 0.0
		if nav.mode=="jump":
			var position:=FrontierCrewWorld.vector(nav.position);var nearest:=INF;var direction:=Vector3.FORWARD
			for i in int(world.manifest.settings.planets_per_system):
				var separation:=position.distance_to(center(int(nav.system)*int(world.manifest.settings.planets_per_system)+i,world.manifest,float(nav.get("orbit_time",0))))
				if separation<nearest:nearest=separation;direction=(position-center(int(nav.system)*int(world.manifest.settings.planets_per_system)+i,world.manifest,float(nav.get("orbit_time",0)))).normalized()
			nav.direction=[direction.x,direction.y,direction.z]
	else:return "지원하지 않는 항해 명령입니다."
	return ""
static func step(world: Dictionary,delta: float) -> bool:
	var nav: Dictionary=world.crew.navigation
	var old_time: float=float(nav.get("orbit_time",0))
	nav.orbit_time=old_time+delta
	if nav.mode=="idle":
		# Keep the vessel in its current body's reference frame even when another target is selected.
		var current: int=FrontierUniverse.ordinal_of(world.manifest,world.location)
		var drift:=center(current,world.manifest,float(nav.orbit_time))-center(current,world.manifest,old_time)
		var point:=FrontierCrewWorld.vector(nav.position)+drift
		nav.position=[point.x,point.y,point.z];world.flight_position=nav.position.duplicate()
		return false
	var cfg: Dictionary=world.manifest.settings.flight
	var propulsion: float=FrontierVesselRefit.stats(world).speed
	var position:=FrontierCrewWorld.vector(nav.position)
	var direction:=FrontierCrewWorld.vector(nav.direction)
	if nav.mode=="jump":
		nav.jump_left=maxf(0,float(nav.jump_left)-delta);nav.speed=cfg.boost_speed
		position+=direction*float(nav.speed)*delta
		if nav.jump_left<=0:
			nav.system=int(nav.target)/int(world.manifest.settings.planets_per_system);position=Vector3(0,2200,0) if world.manifest.settings.generator_version=="galaxy-v3" else Vector3(0,0,80);nav.mode="approach"
	else:
		var body:=FrontierUniverse.body(world.manifest,int(nav.target))
		var target:=center(int(nav.target),world.manifest,float(nav.get("orbit_time",0)))
		var radius:=FrontierUniverse.navigation_radius(body)
		var separation:=position.distance_to(target)-radius
		if separation<=float(cfg.arrival_clearance)+3:
			nav.mode="idle";nav.speed=0;world.location=body.id;world.visited[body.id]=true
			for id in world.crew.members:world.crew.members[id].ready=false
		else:
			var waypoint:=target
			if world.manifest.settings.generator_version=="galaxy-v3":
				var segment:=target-position
				var nearest:=position+segment*clampf(-position.dot(segment)/maxf(segment.length_squared(),1),0,1)
				if nearest.length()<1400:waypoint=Vector3(0,2200,0)
			direction=(waypoint-position).normalized()
			nav.speed=move_toward(float(nav.speed),minf(float(cfg.cruise_speed)*propulsion,maxf(12,separation-float(cfg.arrival_clearance))),float(cfg.acceleration)*propulsion*delta)
			position+=direction*minf(float(nav.speed)*delta,maxf(0,separation-float(cfg.arrival_clearance)))
	nav.position=[position.x,position.y,position.z];nav.direction=[direction.x,direction.y,direction.z]
	world.flight_position=nav.position.duplicate()
	if nav.mode!="idle":world.location=FrontierUniverse.body_id(world.manifest,int(nav.system)*int(world.manifest.settings.planets_per_system))
	return nav.mode=="idle"

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
	if not FrontierUniverse._finite(value.get("speed"),-1000,1000) or not FrontierUniverse._finite(value.get("jump_left"),0,120):return "공동 항해 속도 오류"
	if value.has("transit"):
		var route: Variant=value.transit
		if not route is Dictionary:return "성간 항로 형식 오류"
		for key in ["from","to","galaxy_position"]:
			if not route.get(key) is Array or route[key].size()!=2:return "성간 항로 좌표 오류"
			for axis in route[key]:
				if not FrontierUniverse._finite(axis,-100000,100000):return "성간 항로 범위 오류"
		if not FrontierUniverse._finite(route.get("duration"),1,120) or not FrontierUniverse._finite(route.get("progress"),0,1):return "성간 항로 진행 오류"
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
		nav.manual=false;nav.boundary=false
		nav.jump_left=float(world.manifest.settings.flight.get("transit_seconds",12.0)) if nav.mode=="jump" else 0.0
		if nav.mode=="jump":
			var source:=FrontierUniverse.system(world.manifest,int(nav.system))
			var destination:=FrontierUniverse.system(world.manifest,int(nav.target)/int(world.manifest.settings.planets_per_system))
			nav.transit={"from":source.map_position,"to":destination.map_position,"galaxy_position":source.map_position.duplicate(),"duration":nav.jump_left,"progress":0.0}
			var direction:=Vector3(destination.map_position[0]-source.map_position[0],0,destination.map_position[1]-source.map_position[1]).normalized()
			nav.direction=[direction.x,direction.y,direction.z]

	else:return "지원하지 않는 항해 명령입니다."
	return ""
static func step(world: Dictionary,delta: float) -> bool:
	var nav: Dictionary=world.crew.navigation
	var old_time: float=float(nav.get("orbit_time",0))
	nav.orbit_time=old_time+delta
	if nav.mode=="idle" and nav.get("manual",false):return false
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
		# Legacy in-flight saves acquire a deterministic route when resumed.
		if not nav.has("transit"):
			var source:=FrontierUniverse.system(world.manifest,int(nav.system))
			var destination:=FrontierUniverse.system(world.manifest,int(nav.target)/int(world.manifest.settings.planets_per_system))
			nav.transit={"from":source.map_position,"to":destination.map_position,"galaxy_position":source.map_position.duplicate(),"duration":maxf(1,nav.jump_left),"progress":0.0}
		nav.jump_left=maxf(0,float(nav.jump_left)-delta)
		var progress: float=1.0-float(nav.jump_left)/float(nav.transit.duration)
		nav.transit.progress=progress
		var travel: float=smoothstep(.12,.90,progress)
		var source:=Vector2(nav.transit.from[0],nav.transit.from[1])
		var destination:=Vector2(nav.transit.to[0],nav.transit.to[1])
		var galaxy_point:=source.lerp(destination,travel)
		nav.transit.galaxy_position=[galaxy_point.x,galaxy_point.y]
		nav.speed=float(cfg.boost_speed)*sin(PI*travel)
		# Local departure motion is presentation only; transit owns the galaxy position.
		position+=direction*float(nav.speed)*delta
		if nav.jump_left<=0:
			nav.transit.galaxy_position=nav.transit.to.duplicate()
			nav.system=int(nav.target)/int(world.manifest.settings.planets_per_system)
			var body:=FrontierUniverse.body(world.manifest,int(nav.target))
			var target:=center(int(nav.target),world.manifest,float(nav.orbit_time))
			position=target+target.normalized()*(FrontierUniverse.navigation_radius(body)+float(cfg.arrival_clearance)+1200)
			nav.mode="approach";nav.speed=0

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

static func phase(nav: Dictionary) -> String:
	if nav.mode!="jump":return "행성 접근" if nav.mode=="approach" else ("직접 조종" if nav.get("manual",false) else "궤도 대기")
	var p: float=nav.get("transit",{}).get("progress",0.0)
	if p<.12:return "성간 항해 · 충전"
	if p<.30:return "성간 항해 · 가속"
	if p<.72:return "성간 항해 · 초고속 순항"
	if p<.90:return "성간 항해 · 감속"
	return "성간 항해 · 항성계 진입"

## Controls are transient network input, never persisted as held keys.
static func steer(world: Dictionary,controls: Array,delta: float) -> void:
	var nav: Dictionary=world.crew.navigation
	if nav.mode!="idle" or FrontierCrewSurface.landed(world):return
	if controls==[0.0,0.0,0.0] and not nav.get("manual",false):return
	for member in world.crew.members.values():
		if member.get("connected",true) and not member.aboard:return
	nav.manual=true
	var cfg: Dictionary=world.manifest.settings.flight
	var direction:=FrontierCrewWorld.vector(nav.direction).normalized()
	if direction.length_squared()<.5:direction=Vector3.FORWARD
	direction=direction.rotated(Vector3.UP,-float(controls[1])*float(cfg.get("turn_speed",1.0))*delta)
	var right:=direction.cross(Vector3.UP).normalized()
	if right.length_squared()>.5:
		var pitched:=direction.rotated(right,float(controls[2])*float(cfg.get("turn_speed",1.0))*delta)
		if absf(pitched.y)<.98:direction=pitched
	nav.speed=move_toward(float(nav.speed),float(controls[0])*float(cfg.get("manual_speed",700)),float(cfg.acceleration)*delta*3)
	var start:=FrontierCrewWorld.vector(nav.position)
	var end:=start+direction*float(nav.speed)*delta
	var boundary: float=cfg.get("system_boundary",20000.0)
	nav.boundary=end.length()>boundary-800
	if end.length()>boundary:end=end.limit_length(boundary);nav.speed=0
	# Swept sphere checks stop even high speed frames before a celestial surface.
	var obstacles: Array=[{"point":Vector3.ZERO,"radius":1100.0}]
	for i in int(world.manifest.settings.planets_per_system):
		var ordinal: int=int(nav.system)*int(world.manifest.settings.planets_per_system)+i
		var body:=FrontierUniverse.body(world.manifest,ordinal)
		obstacles.append({"point":center(ordinal,world.manifest,float(nav.orbit_time)),"radius":FrontierUniverse.navigation_radius(body)+80})
	var segment:=end-start
	for obstacle in obstacles:
		var offset: Vector3=start-obstacle.point
		var nearest:=offset+segment*clampf(-offset.dot(segment)/maxf(segment.length_squared(),.0001),0,1)
		if nearest.length()<float(obstacle.radius) and end.distance_to(obstacle.point)<start.distance_to(obstacle.point):end=start;nav.speed=0;break
	nav.position=[end.x,end.y,end.z];nav.direction=[direction.x,direction.y,direction.z]
	world.flight_position=nav.position.duplicate()

class_name FrontierCrewNavigation
extends RefCounted
static func create(world: Dictionary) -> Dictionary:
	var ordinal:=FrontierUniverse.ordinal_of(world.manifest,world.location)
	return {"system":FrontierUniverse.system_index(world.manifest,ordinal),"target":FrontierUniverse.ordinal_of(world.manifest,world.get("navigation_target",world.location)),"position":world.flight_position.duplicate(),"direction":[0.0,0.0,-1.0],"speed":0.0,"mode":"idle","jump_left":0.0,"orbit_time":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.get("mode") not in ["idle","approach","jump"]:return "공동 항해 상태 오류"
	for entry in [["system",249999],["target",999999]]:
		if not FrontierUniverse._finite(value.get(entry[0]),0,entry[1]) or value[entry[0]]!=floorf(value[entry[0]]):return "공동 항로 주소 오류"
	if not FrontierUniverse._vector3_array(value.get("position")) or not FrontierUniverse._vector3_array(value.get("direction")):return "공동 선체 위치 오류"
	if not FrontierUniverse._finite(value.get("orbit_time",0),0,1e12):return "궤도 시간 오류"
	if not FrontierUniverse._finite(value.get("speed"),-10000,10000) or not FrontierUniverse._finite(value.get("jump_left"),0,120):return "공동 항해 속도 오류"
	if value.has("first_stellar_system") and not FrontierExpeditionBusiness.integer(value.first_stellar_system,0,249999):return "첫 성간 목적지 오류"
	if value.has("station_target") and not value.station_target is bool:return "정거장 항로 오류"
	if value.has("transit"):
		var route: Variant=value.transit
		if not route is Dictionary:return "성간 항로 형식 오류"
		for key in ["from","to","galaxy_position"]:
			if not route.get(key) is Array or route[key].size()!=2:return "성간 항로 좌표 오류"
			for axis in route[key]:
				if not FrontierUniverse._finite(axis,-100000,100000):return "성간 항로 범위 오류"
		if route.has("departure_origin") or route.has("departure_direction") or route.has("initial_direction"):
			for key in ["departure_origin","departure_direction","initial_direction"]:
				if not FrontierUniverse._vector3_array(route.get(key)):return "출발 항로 벡터 오류"
			for key in ["departure_direction","initial_direction"]:
				if not is_equal_approx(FrontierCrewWorld.vector(route[key]).length(),1.0):return "출발 방향 길이 오류"
		if not FrontierUniverse._finite(route.get("duration"),1,120) or not FrontierUniverse._finite(route.get("progress"),0,1):return "성간 항로 진행 오류"
	for key in ["hull","energy"]:
		if value.has(key) and not FrontierUniverse._finite(value[key],0,100):return "우주선 상태 범위 오류"
	if value.has("damage_cooldown") and not FrontierUniverse._finite(value.damage_cooldown,0,8):return "우주선 수리 시간 오류"
	return ""
static func center(ordinal: int,manifest: Dictionary={},elapsed: float=0.0) -> Vector3:return FrontierUniverse.position(manifest,ordinal,elapsed)
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary,active: Dictionary) -> String:
	if FrontierCrewSurface.landed(world):return "지표의 승무원들과 우주선으로 복귀한 뒤 항해하세요."
	var crew: Dictionary=world.crew
	if actor!=crew.pilot_id:return "현재 조종사만 항로를 조작할 수 있습니다."
	var nav: Dictionary=crew.navigation
	if nav.mode!="idle":return "항해를 마친 뒤 다음 항로를 설정하세요."
	if kind=="tutorial_depart":
		if int(nav.system)!=0:return "출격하기는 태양계에서만 사용할 수 있습니다."
		var target:=first_destination(world.manifest)
		if target<0:return "근처 개척 항로를 찾지 못했습니다. 항법도를 이용하세요."
		var error:=apply(world,actor,"navigate",{"ordinal":target},active)
		if not error.is_empty():return error
		return apply(world,actor,"depart",{},active)
	if kind=="navigate":
		if not FrontierUniverse._finite(args.get("ordinal"),0,int(world.manifest.settings.planet_count)-1) or args.ordinal!=floorf(args.ordinal):return "행성 주소가 올바르지 않습니다."
		nav.station_target=false;nav.target=int(args.ordinal);world.navigation_target=FrontierUniverse.body_id(world.manifest,int(nav.target))
	elif kind=="depart":
		var destination_system:=FrontierUniverse.system_index(world.manifest,int(nav.target))
		var distance:=FrontierUniverse.map_position(world.manifest,int(nav.system)).distance_to(FrontierUniverse.map_position(world.manifest,destination_system))
		if destination_system!=int(nav.system) and distance>FrontierVesselRefit.stellar_range(world)+.001:return "항속거리 초과 · 가까운 항성계를 경유하거나 비행체를 업그레이드하세요."
		if float(nav.get("hull",100))<=0:return "선체 응급 수리가 끝날 때까지 기다려 주세요."
		for id in active.values():
			if not crew.members[id].aboard or not crew.members[id].ready:return "연결된 승무원 모두 승선하고 준비해야 출항할 수 있습니다."
		nav.mode="approach" if FrontierUniverse.system_index(world.manifest,int(nav.target))==int(nav.system) else "jump"
		var energy_cost: float=world.manifest.settings.flight.get("transit_energy_cost",30.0)
		if nav.mode=="jump" and float(nav.get("energy",100.0))<energy_cost:return "고속 추진 에너지를 충전 중입니다. 잠시 기다려 주세요."
		if nav.mode=="jump" and not nav.has("first_stellar_system") and int(nav.system)==0:nav.first_stellar_system=FrontierUniverse.system_index(world.manifest,int(nav.target))
		if nav.mode=="jump":nav.energy=float(nav.get("energy",100.0))-energy_cost
		nav.station_target=false;nav.manual=false;nav.boundary=false;nav.boosting=false
		nav.jump_left=float(world.manifest.settings.flight.get("transit_seconds",12.0)) if nav.mode=="jump" else 0.0
		if nav.mode=="jump":
			var source:=FrontierUniverse.system(world.manifest,int(nav.system))
			var destination:=FrontierUniverse.system(world.manifest,FrontierUniverse.system_index(world.manifest,int(nav.target)))
			nav.transit={"from":source.map_position,"to":destination.map_position,"galaxy_position":source.map_position.duplicate(),"duration":nav.jump_left,"progress":0.0}
			var origin:=FrontierCrewWorld.vector(nav.position)
			var initial:=FrontierCrewWorld.vector(nav.direction).normalized()
			if initial.length_squared()<.5:initial=Vector3.FORWARD
			var direction:=departure_direction(world.manifest,int(nav.system),origin,initial,float(nav.orbit_time),float(nav.jump_left))
			if direction==Vector3.ZERO:return "안전한 출발 방향을 찾지 못했습니다. 천체에서 조금 떨어진 뒤 다시 출발하세요."
			nav.transit.departure_origin=nav.position.duplicate()
			nav.transit.departure_direction=FrontierExpeditionBusiness.array(direction)
			nav.transit.initial_direction=FrontierExpeditionBusiness.array(initial)
			nav.direction=[direction.x,direction.y,direction.z]

	else:return "지원하지 않는 항해 명령입니다."
	return ""
static func step(world: Dictionary,delta: float) -> bool:
	var nav: Dictionary=world.crew.navigation
	var cfg_state: Dictionary=world.manifest.settings.flight
	nav.hull=float(nav.get("hull",100.0));nav.energy=float(nav.get("energy",100.0))
	nav.damage_cooldown=maxf(0,float(nav.get("damage_cooldown",0))-delta)
	if nav.damage_cooldown<=0:nav.hull=minf(100,nav.hull+float(cfg_state.get("hull_repair",4))*delta)
	if nav.mode!="jump" and not nav.get("boosting",false):nav.energy=minf(100,nav.energy+float(cfg_state.get("energy_recharge",12))*delta)
	stellar_hazard(world,delta)
	var old_time: float=float(nav.get("orbit_time",0))
	nav.orbit_time=old_time+delta
	if nav.mode=="approach" and nav.get("station_target",false):return FrontierSpaceStation.step_approach(world,delta)
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
			var destination:=FrontierUniverse.system(world.manifest,FrontierUniverse.system_index(world.manifest,int(nav.target)))
			nav.transit={"from":source.map_position,"to":destination.map_position,"galaxy_position":source.map_position.duplicate(),"duration":maxf(1,nav.jump_left),"progress":0.0}
		nav.jump_left=maxf(0,float(nav.jump_left)-delta)
		var progress: float=1.0-float(nav.jump_left)/float(nav.transit.duration)
		nav.transit.progress=progress
		var travel: float=smoothstep(float(FrontierUniverse.presentation().stellar_transition.departure_start),.90,progress)
		var source:=Vector2(nav.transit.from[0],nav.transit.from[1])
		var destination:=Vector2(nav.transit.to[0],nav.transit.to[1])
		var galaxy_point:=source.lerp(destination,travel)
		nav.transit.galaxy_position=[galaxy_point.x,galaxy_point.y]
		nav.speed=float(cfg.boost_speed)*sin(PI*travel)
		# Local departure motion is presentation only; transit owns the galaxy position.
		position+=direction*float(nav.speed)*delta
		if nav.jump_left<=0:
			nav.transit.galaxy_position=nav.transit.to.duplicate()
			nav.system=FrontierUniverse.system_index(world.manifest,int(nav.target))
			var body:=FrontierUniverse.body(world.manifest,int(nav.target))
			var target:=FrontierUniverse.entry_focus(world.manifest,int(nav.target),float(nav.orbit_time))
			position=FrontierUniverse.entry_position(world.manifest,int(nav.target),float(nav.orbit_time))
			direction=(target-position).normalized()
			nav.mode="idle";nav.manual=true;nav.speed=0
			world.location=body.id;world.visited[body.id]=true
			for id in world.crew.members:world.crew.members[id].ready=false

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
				if nearest.length()<float(FrontierUniverse.star_settings(world.manifest,int(nav.system)).star_warning_radius):waypoint=Vector3(0,float(FrontierUniverse.star_settings(world.manifest,int(nav.system)).star_warning_radius)+2000,0)
			for moon in int(body.get("moons",0)):
				var moon_point:=target+FrontierUniverse.moon_offset(body,moon,float(nav.orbit_time))
				var segment:=waypoint-position
				var nearest:=position+segment*clampf((moon_point-position).dot(segment)/maxf(segment.length_squared(),1),0,1)
				var clearance:=FrontierUniverse.moon_radius(body,moon)+150
				if nearest.distance_to(moon_point)<clearance:
					var side:=segment.cross(Vector3.UP).normalized()
					if side.length_squared()<.1:side=Vector3.RIGHT
					waypoint=moon_point+side*(clearance+300)
			direction=(waypoint-position).normalized()
			nav.speed=move_toward(float(nav.speed),minf(float(cfg.cruise_speed)*propulsion,maxf(12,separation-float(cfg.arrival_clearance))),float(cfg.acceleration)*propulsion*delta)
			position+=direction*minf(float(nav.speed)*delta,maxf(0,separation-float(cfg.arrival_clearance)))
	nav.position=[position.x,position.y,position.z];nav.direction=[direction.x,direction.y,direction.z]
	world.flight_position=nav.position.duplicate()
	if nav.mode!="idle":world.location=FrontierUniverse.body_id(world.manifest,FrontierUniverse.first_ordinal(world.manifest,int(nav.system)))
	return nav.mode=="idle"

static func phase(nav: Dictionary) -> String:
	if nav.get("station_target",false) and nav.mode=="approach":return "정거장 접근"
	if nav.mode=="jump" and float(nav.get("transit",{}).get("progress",0))<float(FrontierUniverse.presentation().stellar_transition.departure_start):return "성간 항해 · 안전 항로 정렬"
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
	if float(controls[0])==0 and float(controls[1])==0 and float(controls[2])==0 and not nav.get("manual",false):return
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
	var boost_requested: bool=controls.size()>3 and float(controls[3])>.5 and float(controls[0])>0
	if not boost_requested or float(nav.get("energy",100))>=25:nav.boost_depleted=false
	nav.boosting=boost_requested and not nav.get("boost_depleted",false) and float(nav.get("energy",100))>0 and float(nav.get("hull",100))>0
	if nav.boosting:
		nav.energy=maxf(0,float(nav.get("energy",100))-float(cfg.get("boost_drain",22))*delta)
		if nav.energy<=0:nav.boost_depleted=true;nav.boosting=false
	var maximum: float=float(cfg.get("manual_speed",700))*float(FrontierVesselRefit.stats(world).speed)*(float(cfg.get("boost_multiplier",2.2)) if nav.boosting else 1.0)
	if float(nav.get("hull",100))<=0:maximum=0
	var previous_speed: float=float(nav.speed)
	nav.speed=move_toward(float(nav.speed),float(controls[0])*maximum,float(cfg.acceleration)*delta*3)
	var start:=FrontierCrewWorld.vector(nav.position)
	var end:=start+direction*float(nav.speed)*delta
	var boundary: float=FrontierUniverse.system_layout(world.manifest,int(nav.system)).boundary
	nav.boundary=end.length()>boundary-800
	if end.length()>boundary:end=end.limit_length(boundary);nav.speed=0
	# Swept sphere checks stop even high speed frames before a celestial surface.
	var obstacles: Array=[{"point":Vector3.ZERO,"radius":float(FrontierUniverse.star_settings(world.manifest,int(nav.system)).star_radius)+150}]
	var station:=FrontierSpaceStation.definition(world.manifest,int(nav.system),int(nav.get("first_stellar_system",-1)))
	if not station.is_empty():obstacles.append({"point":FrontierCrewWorld.vector(station.position),"radius":float(FrontierSpaceStation.config().radius)+80})
	for i in FrontierUniverse.body_count(world.manifest,int(nav.system)):
		var ordinal: int=FrontierUniverse.first_ordinal(world.manifest,int(nav.system))+i
		var body:=FrontierUniverse.body(world.manifest,ordinal)
		obstacles.append({"point":center(ordinal,world.manifest,float(nav.orbit_time)),"radius":FrontierUniverse.navigation_radius(body)+80})
		for moon in int(body.get("moons",0)):
			obstacles.append({"point":center(ordinal,world.manifest,float(nav.orbit_time))+FrontierUniverse.moon_offset(body,moon,float(nav.orbit_time)),"radius":FrontierUniverse.moon_radius(body,moon)+50})
	nav.proximity_braking=false
	if float(controls[0])>0:
		var safe_speed: float=maximum
		var brake: Dictionary=FrontierFlightTelemetry.config()
		var deceleration: float=float(cfg.acceleration)*float(brake.brake_acceleration_factor)
		for obstacle in obstacles:
			var offset: Vector3=obstacle.point-start
			var along: float=offset.dot(direction)
			var cross_distance: float=(offset-direction*along).length()
			var envelope: float=float(obstacle.radius)+float(brake.brake_margin)
			if along>0 and cross_distance<envelope:
				var free_path:=maxf(0,along-sqrt(maxf(0,envelope*envelope-cross_distance*cross_distance)))
				safe_speed=minf(safe_speed,maxf(float(brake.minimum_approach_speed),sqrt(2*deceleration*free_path)*.75))
		if safe_speed<maximum:
			nav.proximity_braking=true
			nav.speed=move_toward(previous_speed,minf(float(controls[0])*maximum,safe_speed),deceleration*delta)
			end=(start+direction*float(nav.speed)*delta).limit_length(boundary)
	var segment:=end-start
	for obstacle in obstacles:
		var offset: Vector3=start-obstacle.point
		var nearest:=offset+segment*clampf(-offset.dot(segment)/maxf(segment.length_squared(),.0001),0,1)
		if nearest.length()<float(obstacle.radius) and offset.dot(segment)<0:
			if absf(nav.speed)>120 and float(nav.get("damage_cooldown",0))<=0:
				nav.hull=maxf(0,float(nav.get("hull",100))-minf(45,absf(nav.speed)*.025));nav.damage_cooldown=8.0
			end=start;nav.speed=0;break
	nav.position=[end.x,end.y,end.z];nav.direction=[direction.x,direction.y,direction.z]
	world.flight_position=nav.position.duplicate()

static var departure_cache: Dictionary={}
static func first_destination(manifest: Dictionary) -> int:
	var cache_key: String=str(FrontierPlanetaryCycles.enabled(manifest))+":"+manifest.id+":"+str(manifest.settings.get("system_rules",{}).get("version",0))+":"+str(manifest.settings.get("ground_rules",{}).get("version",0))
	if departure_cache.has(cache_key):return departure_cache[cache_key]
	var origin:=FrontierUniverse.system(manifest,0)
	var start:=Vector2(origin.map_position[0],origin.map_position[1])
	var count: int=int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system)/manifest.settings.tier_weights.size()
	var candidates: Array=[]
	var samples:=mini(1024,count-1)
	for i in samples:
		var index: int=1+i*(count-1)/samples
		var system:=FrontierUniverse.system(manifest,index)
		var distance:=start.distance_squared_to(Vector2(system.map_position[0],system.map_position[1]))
		candidates.append({"index":index,"distance":distance})
	candidates.sort_custom(func(a,b):return a.distance<b.distance)
	for candidate in candidates:
		for orbit in FrontierUniverse.body_count(manifest,int(candidate.index)):
			var ordinal: int=FrontierUniverse.first_ordinal(manifest,int(candidate.index))+orbit
			var body:=FrontierUniverse.body(manifest,ordinal)
			if FrontierPlanetaryCycles.enabled(manifest) and not body.astro.intro_eligible:continue
			if FrontierUniverse.landable(body) and int(body.planet_tier)==1 and (not manifest.settings.has("ground_rules") or FrontierGroundProgression.intro_candidate(body)):
				departure_cache[cache_key]=ordinal;return ordinal
	return -1

static func stellar_hazard(world: Dictionary,delta: float) -> void:
	var nav: Dictionary=world.crew.navigation
	nav.star_warning=false;nav.star_danger=false
	if nav.mode=="jump" or FrontierCrewSurface.landed(world):return
	var cfg:=FrontierUniverse.star_settings(world.manifest,int(nav.system))
	var point:=FrontierCrewWorld.vector(nav.position)
	var distance:=point.length()
	nav.star_warning=distance<float(cfg.star_warning_radius)
	nav.star_danger=distance<float(cfg.star_damage_radius)
	if nav.star_danger:
		var heat:=1.0-clampf((distance-float(cfg.star_radius))/(float(cfg.star_damage_radius)-float(cfg.star_radius)),0,1)
		nav.hull=maxf(0,float(nav.get("hull",100))-lerpf(cfg.star_damage_per_second,cfg.star_damage_max_per_second,heat)*delta)
		nav.damage_cooldown=8.0
		if nav.hull<=0:nav.emergency_escape=true
	if nav.get("emergency_escape",false):
		var away:=point.normalized() if distance>1 else Vector3.UP
		point+=away*500*delta
		nav.position=[point.x,point.y,point.z];world.flight_position=nav.position.duplicate()
		nav.direction=[away.x,away.y,away.z];nav.speed=500;nav.manual=true
		if point.length()>float(cfg.star_warning_radius)+500:nav.emergency_escape=false;nav.speed=0

## Search closest-to-forward clear rays, including orbital motion during the departure shot.
static func departure_obstacles(manifest: Dictionary,index: int,elapsed: float,duration: float) -> Array:
	var result: Array=[{"point":Vector3.ZERO,"radius":float(FrontierUniverse.star_settings(manifest,index).star_warning_radius)}]
	var horizon: float=duration*float(FrontierUniverse.presentation().stellar_transition.swap_progress)
	for i in FrontierUniverse.body_count(manifest,index):
		var ordinal:=FrontierUniverse.first_ordinal(manifest,index)+i
		var body:=FrontierUniverse.body(manifest,ordinal)
		var center:=FrontierUniverse.position(manifest,ordinal,elapsed)
		var drift:=center.distance_to(FrontierUniverse.position(manifest,ordinal,elapsed+horizon))
		result.append({"point":center,"radius":FrontierUniverse.navigation_radius(body)+drift})
		for moon in int(body.get("moons",0)):
			var offset:=FrontierUniverse.moon_offset(body,moon,elapsed)
			var movement:=offset.distance_to(FrontierUniverse.moon_offset(body,moon,elapsed+horizon))
			result.append({"point":center+offset,"radius":FrontierUniverse.moon_radius(body,moon)+drift+movement})
	var station:=FrontierSpaceStation.definition(manifest,index)
	if not station.is_empty():result.append({"point":FrontierCrewWorld.vector(station.position),"radius":float(FrontierSpaceStation.config().radius)})
	return result
static func departure_clear(origin: Vector3,direction: Vector3,obstacles: Array) -> bool:
	var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
	for obstacle in obstacles:
		var offset: Vector3=origin-obstacle.point
		var radius: float=float(obstacle.radius)+float(cfg.departure_clearance)
		# If already in the conservative motion margin, only allow increasing separation.
		if offset.length()<radius:
			if offset.dot(direction)<=0:return false
			continue
		var distance:=clampf(-offset.dot(direction),0,float(cfg.distant_offset))
		if (offset+direction*distance).length()<radius:return false
	return true
static func departure_direction(manifest: Dictionary,index: int,origin: Vector3,forward: Vector3,elapsed: float,duration: float) -> Vector3:
	if forward.length_squared()<.5:forward=Vector3.FORWARD
	forward=forward.normalized()
	var up:=Vector3.RIGHT if absf(forward.y)>.98 else Vector3.UP
	var right:=forward.cross(up).normalized();up=right.cross(forward).normalized()
	var obstacles:=departure_obstacles(manifest,index,elapsed,duration)
	if departure_clear(origin,forward,obstacles):return forward
	var cfg: Dictionary=FrontierUniverse.presentation().stellar_transition
	for ring in range(1,int(cfg.departure_direction_steps)+1):
		var angle:=PI*float(ring)/float(cfg.departure_direction_steps)
		for spoke in int(cfg.departure_directions_per_ring):
			var turn:=TAU*float(spoke)/float(cfg.departure_directions_per_ring)
			var candidate: Vector3=(forward*cos(angle)+(up*cos(turn)+right*sin(turn))*sin(angle)).normalized()
			if departure_clear(origin,candidate,obstacles):return candidate
	return Vector3.ZERO

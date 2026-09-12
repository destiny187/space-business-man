extends RefCounted
## Committed ground attacks. All movement, collision and damage run on the host.
static func begin(live: Dictionary,info: Dictionary,destination: Vector3,field: FrontierTerrainField=null,row: Dictionary={}) -> void:
	var origin:=FrontierCrewWorld.vector(live.position)
	var forward:=FrontierCrewWorld.vector(live.aim)
	var goal:=origin
	var mode: String=info.get("behavior","melee")
	if mode=="charge":goal=origin+forward*float(info.charge_distance)
	elif mode=="leap":goal=origin+forward*minf(Vector2(destination.x-origin.x,destination.z-origin.z).length(),float(info.leap_distance))
	if mode=="leap" and field!=null:
		var landing:=_ground(field,row,goal,float(live.yaw))
		if landing.is_finite():goal=landing
	live.attack={"mode":mode,"origin":FrontierExplorationIncidents.array(origin),"goal":FrontierExplorationIncidents.array(goal),"hits":{},"pulses":0,"blocked":false,"travel":0.0}

static func valid(attack: Variant,crew: Dictionary) -> bool:
	if not attack is Dictionary:return false
	if attack.get("mode") not in ["melee","charge","leap","shockwave","double_sweep"]:return false
	for field_name in ["origin","goal"]:
		if not FrontierUniverse._vector3_array(attack.get(field_name)):return false
	if not attack.get("blocked") is bool or not FrontierUniverse._finite(attack.get("travel"),0,32) or not FrontierUniverse._finite(attack.get("pulses"),0,3):return false
	if not attack.get("hits") is Dictionary or attack.hits.size()>6:return false
	for id in attack.hits:
		if not crew.members.has(id) or not FrontierUniverse._finite(attack.hits[id],1,3):return false
	return true

static func pulse(live: Dictionary) -> void:
	live.struck=true;live.cue_serial=int(live.get("cue_serial",0))+1;live.attack.pulses+=1

static func recovery(live: Dictionary,info: Dictionary) -> bool:
	return live.phase=="attack" and float(live.time)>=float(info.windup)+float(info.active)

static func airborne(live: Dictionary,info: Dictionary) -> bool:
	return live.phase=="attack" and info.get("behavior","")=="leap" and float(live.time)>=float(info.windup) and not recovery(live,info) and not live.get("attack",{}).get("blocked",false)

static func step(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,delta: float,obstacle: Callable) -> void:
	var a: Dictionary=live.attack
	var elapsed:=float(live.time)-float(info.windup)
	if elapsed<0:return
	match a.mode:
		"charge":_charge(world,row,live,info,actors,field,delta,obstacle)
		"leap":_leap(world,row,live,info,actors,field,delta,obstacle)
		"shockwave":
			if a.pulses==0 and elapsed>=float(info.impact_delay):
				pulse(live)
				_area(world,row,live,info,actors,field,obstacle,1,false)
		"double_sweep":
			if a.pulses==0 and elapsed>=float(info.first_strike):
				pulse(live);_area(world,row,live,info,actors,field,obstacle,1,true)
			if a.pulses==1 and elapsed>=float(info.second_strike)+float(info.first_strike):
				pulse(live);_area(world,row,live,info,actors,field,obstacle,2,true)
		_:
			if a.pulses==0 and elapsed>=float(info.active)*.45:
				pulse(live);_area(world,row,live,info,actors,field,obstacle,1,true)
	if float(live.time)>=float(info.windup)+float(info.active)+float(info.recovery):FrontierWildlifeCombat.set_phase(live,"chase")

static func _area(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,obstacle: Callable,stroke: int,frontal: bool) -> void:
	var origin:=FrontierCrewWorld.vector(live.position)
	var forward:=FrontierCrewWorld.vector(live.aim)
	var reach:=float(info.reach)+.3 if frontal else float(info.attack_radius)
	for actor in actors:
		var member: Dictionary=world.crew.members[actor]
		if FrontierWildlifeCombat.safe(member) or int(live.attack.hits.get(actor,0)) & stroke:continue
		var dest:=FrontierCrewWorld.vector(member.position);var direction:=dest-origin;direction.y=0
		# Ground rings can be jumped; frontal attacks retain the existing vertical reach.
		var height_limit:=2.0 if frontal else float(FrontierWildlifeCombat.config().ground_attack_height)
		if direction.length()>reach or absf(dest.y-origin.y)>height_limit:continue
		if frontal and direction.length()>.01 and direction.normalized().dot(forward)<float(info.arc_cos):continue
		if not FrontierWildlifeCombat.clear(world,row,actor,field,origin+Vector3.UP*(minf(float(info.height)*.65,1.7) if frontal else .25),dest+Vector3.UP*(.5 if frontal else .25),obstacle):continue
		live.attack.hits[actor]=int(live.attack.hits.get(actor,0)) | stroke
		FrontierExplorationIncidents.hurt(world,actor,float(info.damage))

static func corridor(world: Dictionary,row: Dictionary,from: Vector3,to: Vector3,info: Dictionary,obstacle: Callable,actor: String) -> bool:
	var segment:=to-from
	if segment.length()<.001:return true
	if FrontierCombatCover.blocks_body(world,row.body_id,from,to,float(info.radius),float(info.height)):return false
	return not obstacle.is_valid() or obstacle.call(actor,str(row.id),from,to,float(info.radius),float(info.height))

static func _enters_safe_zone(from: Vector3,to: Vector3) -> bool:
	# Wildlife spawned inside the landing perimeter may leave it, but never rush inward.
	var boundary:=minf(Vector2(from.x,from.z).length(),float(FrontierWildlifeCombat.config().ship_safe_radius))
	return Vector2(to.x,to.z).length()<boundary-.001

static func _ground(field: FrontierTerrainField,row: Dictionary,point: Vector3,yaw: float) -> Vector3:
	var candidate:=row.duplicate();candidate.point=point;candidate.yaw=yaw
	return FrontierEcologyPlacement.ground(field,candidate)

static func _blocked(live: Dictionary,info: Dictionary) -> void:
	live.attack.blocked=true;live.time=float(info.windup)+float(info.active)
	pulse(live)

static func _charge(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,delta: float,obstacle: Callable) -> void:
	var a: Dictionary=live.attack
	if a.blocked:return
	if a.pulses==0:pulse(live)
	var duration:=clampf(float(live.time)-float(info.windup),0,float(info.active))
	var distance:=minf(float(info.charge_distance),duration*float(info.charge_speed))-float(a.travel)
	var forward:=FrontierCrewWorld.vector(live.aim)
	var steps:=maxi(1,ceili(distance/float(FrontierWildlifeCombat.config().attack_step_distance)))
	for i in steps:
		if distance<=.001:break
		var from:=FrontierCrewWorld.vector(live.position)
		var next:=_ground(field,row,from+forward*distance/steps,float(live.yaw))
		if not next.is_finite() or absf(next.y-from.y)>float(FrontierWildlifeCombat.Wildlife.config().maximum_step_height) or _enters_safe_zone(from,next) or not corridor(world,row,from,next,info,obstacle,str(live.target)):
			_blocked(live,info);return
		live.position=FrontierExplorationIncidents.array(next);a.travel+=distance/steps
		for actor in actors:
			var member: Dictionary=world.crew.members[actor]
			if FrontierWildlifeCombat.safe(member) or a.hits.has(actor):continue
			var dest:=FrontierCrewWorld.vector(member.position)
			# Include the authored snout/horns so contact stops before the head crosses the camera.
			var nose:=next+forward*float(info.attack_front)
			var closest:=Geometry2D.get_closest_point_to_segment(Vector2(dest.x,dest.z),Vector2(from.x,from.z),Vector2(nose.x,nose.z))
			if closest.distance_to(Vector2(dest.x,dest.z))>float(info.radius)+float(info.contact_radius) or absf(dest.y-next.y)>2.0:continue
			if not FrontierWildlifeCombat.clear(world,row,actor,field,next+Vector3.UP,dest+Vector3.UP,obstacle):continue
			a.hits[actor]=1;FrontierExplorationIncidents.hurt(world,actor,float(info.damage))
			_blocked(live,info);return

static func _leap(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,delta: float,obstacle: Callable) -> void:
	var a: Dictionary=live.attack
	if a.blocked or a.pulses>=2:return
	if a.pulses==0:pulse(live)
	var origin:=FrontierCrewWorld.vector(a.origin);var goal:=FrontierCrewWorld.vector(a.goal)
	var progress:=clampf((float(live.time)-float(info.windup))/float(info.active),0,1)
	var previous:=float(a.travel)
	var steps:=maxi(1,ceili((progress-previous)*maxf(origin.distance_to(goal),1.0)/float(FrontierWildlifeCombat.config().attack_step_distance)))
	for i in steps:
		var fraction:=lerpf(previous,progress,float(i+1)/steps)
		var ground:=_ground(field,row,origin.lerp(goal,fraction),float(live.yaw))
		var lift:=sin(fraction*PI)*float(info.leap_height)
		var from:=FrontierWildlifeCombat.body_position(live)
		if not ground.is_finite() or absf(ground.y-origin.y)>float(FrontierWildlifeCombat.config().leap_ground_height) or _enters_safe_zone(from,ground) or not corridor(world,row,from,ground+Vector3.UP*lift,info,obstacle,str(live.target)):
			_blocked(live,info);return
		live.position=FrontierExplorationIncidents.array(ground);live.air_height=maxf(0,lift);a.travel=fraction
	if progress>=1:
		live.air_height=0.0;pulse(live)
		_area(world,row,live,info,actors,field,obstacle,1,false)

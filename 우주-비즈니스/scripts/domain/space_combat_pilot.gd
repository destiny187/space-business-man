class_name FrontierSpaceCombatPilot
extends RefCounted
## Host-owned approach, locked firing lane, attack pass and banked withdrawal.
## Timers and projectile positions are saved; render joints never decide damage.
static func basis(direction: Vector3) -> Basis:
	return Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP))>.98 else Vector3.UP)
static func phase(enemy: Dictionary,name: String,duration: float) -> void:
	enemy.maneuver=name;enemy.maneuver_age=0.0;enemy.maneuver_duration=duration;enemy.burst=0;enemy.windup=0.0
static func initialize(enemy: Dictionary) -> void:
	if enemy.has("maneuver"):
		if enemy.maneuver=="align" and not enemy.has("pass_end"):enemy.pass_end=enemy.aim.duplicate()
		return
	enemy.velocity=[0.0,0.0,0.0];enemy.roll=0.0;enemy.throttle=0.2;enemy.cycle=0;enemy.recoil=0.0
	enemy.side=-1.0 if enemy.kind=="raider" and int(str(enemy.id).get_slice(":",1))%3==0 else 1.0
	phase(enemy,"approach",float(FrontierSpaceCombat.config().enemy[enemy.kind].approach_seconds))
static func launch(world: Dictionary,enemy: Dictionary,def: Dictionary) -> bool:
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter
	if e.projectiles.size()>=int(FrontierSpaceCombat.config().presentation.projectile_limit):return false
	var facing:=orientation(enemy)
	var missile: bool=def.get("weapon","pulse")=="missile"
	var source:=FrontierSpaceCombat.point(enemy.position)+facing*(Vector3(-11.3 if int(enemy.burst)%2==0 else 11.3,2.0,-7.94) if missile else Vector3(0,-1.3,-16))
	var direction: Vector3=(FrontierSpaceCombat.point(enemy.aim)-source).normalized()
	if -facing.z.dot(direction)<float(FrontierSpaceCombat.config().maneuver.fire_dot) or source.distance_to(FrontierSpaceCombat.point(enemy.aim))>float(def.range):return false
	FrontierSpaceCombat.emit(r,"missile_launch" if missile else "enemy_shot",int(e.system),source,source+direction*float(def.range),enemy.id)
	e.projectiles.append({"id":str(r.event_serial),"owner":str(enemy.id),"side":"pirate","kind":"missile" if missile else "pulse","position":FrontierSpaceCombat.arr(source),"velocity":FrontierSpaceCombat.arr(direction*(110.0 if missile else float(def.projectile_speed))),"life":3.2 if missile else float(def.range)/float(def.projectile_speed),"age":0.0,"damage":float(def.damage),"radius":float(def.projectile_radius)})
	enemy.recoil=1.0
	return true
static func orientation(enemy: Dictionary) -> Basis:
	return FrontierCrewNavigation.orientation(enemy)*Basis(Vector3.FORWARD,float(enemy.get("roll",0)))
static func turn_toward(facing: Vector3,desired: Vector3,up: Vector3,angle: float) -> Vector3:
	if desired.length_squared()<.5:return facing
	var separation:=facing.angle_to(desired)
	if separation<.0001:return desired
	var axis:=facing.cross(desired).normalized()
	if axis.length_squared()<.5:axis=up
	return facing.rotated(axis,minf(angle,separation)).normalized()

static func step(world: Dictionary,enemy: Dictionary,delta: float) -> void:
	initialize(enemy)
	var e: Dictionary=FrontierSpaceCombat.record(world).encounter
	var def: Dictionary=FrontierSpaceCombat.config().enemy[enemy.kind]
	var cfg: Dictionary=FrontierSpaceCombat.config().maneuver
	var nav: Dictionary=FrontierSpaceCombat.local_world(world,e.carrier).crew.navigation
	var position:=FrontierSpaceCombat.point(enemy.position);var target:=FrontierSpaceCombat.point(nav.position)
	var frame:=FrontierCrewNavigation.orientation(enemy);var facing: Vector3=-frame.z
	var heading:=FrontierSpaceCombat.point(nav.direction).normalized()
	var dt:=minf(delta,.2)
	enemy.age+=dt;enemy.recoil=maxf(0,float(enemy.recoil)-dt*5)
	if e.phase!="combat":
		enemy.windup=0.0;enemy.throttle=.16
		return
	enemy.maneuver_age+=dt
	var age:=float(enemy.maneuver_age);var duration:=float(enemy.maneuver_duration)
	var side:=float(enemy.side);var speed:=FrontierSpaceCombat.point(enemy.velocity).length()
	var desired:=FrontierSpaceSkills.decoy_target(world,position,target+heading*float(nav.speed)*float(cfg.aim_lead_seconds))
	var requested_speed:=float(def.speed)
	match str(enemy.maneuver):
		"approach":
			if age>=duration and position.distance_to(target)<float(def.range)*.85 and facing.dot((desired-position).normalized())>float(cfg.fire_dot):
				enemy.aim=FrontierSpaceCombat.arr(desired)
				var lane: Vector3=(desired-position).normalized()
				var lane_right:=basis(lane).x
				enemy.pass_direction=FrontierSpaceCombat.arr(lane)
				var offset:=float(def.pass_clearance)*float(cfg.pass_offset_factor)*(1.0+float(cfg.pass_length)/maxf(position.distance_to(desired),float(def.pass_clearance)))
				enemy.pass_end=FrontierSpaceCombat.arr(desired+lane*float(cfg.pass_length)+lane_right*side*offset)
				phase(enemy,"align",float(def.windup));enemy.windup=float(def.windup)
		"align":
			# Continue forward while charging; keep a frozen firing lane the player can evade.
			desired=FrontierSpaceCombat.point(enemy.aim)
			requested_speed*=float(cfg.align_speed_factor)
			enemy.windup=maxf(0,duration-age)
			if age>=duration:phase(enemy,"strike",float(def.strike_seconds));enemy.windup=0.0
		"strike":
			desired=FrontierSpaceCombat.point(enemy.pass_end)
			if enemy.kind in ["interdictor","gunship"]:requested_speed*=float(cfg.gunship_strike_speed_factor)
			if age<=float(def.burst_interval)*float(def.burst_count):
				desired=FrontierSpaceCombat.point(enemy.aim);requested_speed=float(def.speed)*float(cfg.align_speed_factor)
			var passed: bool=(position-FrontierSpaceCombat.point(enemy.aim)).dot(FrontierSpaceCombat.point(enemy.get("pass_direction",enemy.direction)))>float(def.pass_clearance)
			if (age>=duration and passed) or age>=duration*2:
				enemy.break_end=FrontierSpaceCombat.arr(position+facing*float(cfg.pass_length)+frame.x*side*float(def.flank_distance)+frame.y*float(def.pass_clearance))
				phase(enemy,"break",float(def.break_seconds))
		"break":
			desired=FrontierSpaceCombat.point(enemy.break_end)
			if age>=duration:
				enemy.cycle+=1;enemy.side=-side
				phase(enemy,"approach",float(def.approach_seconds))
	var desired_direction: Vector3=(desired-position).normalized()
	var clearance:=float(def.pass_clearance)
	var toward_target:=target-position
	var ahead:=toward_target.dot(facing)
	var lateral:=toward_target-facing*ahead
	if enemy.maneuver!="break" and ahead>0 and ahead<maxf(clearance*float(def.get("avoidance_margin_factor",cfg.avoidance_margin_factor)),speed*float(cfg.avoidance_seconds)) and lateral.length()<clearance:
		# Steer off the hull before the pass; never push/teleport a craft out of a safety sphere.
		var away: Vector3=-lateral.normalized() if lateral.length()>1 else frame.x*side
		desired_direction=(facing+away*(1.0-lateral.length()/clearance)*2).normalized()
	if float(enemy.get("slow_left",0))>0:requested_speed*=clampf(float(enemy.get("slow_factor",1)),.25,1.0)
	var angle:=facing.angle_to(desired_direction)
	requested_speed*=lerpf(1.0,float(cfg.minimum_speed_factor),clampf(angle/(PI*.5),0,1))
	speed=move_toward(speed,requested_speed,float(def.acceleration)*dt)
	var turn_rate:=lerpf(float(cfg.turn_speed_slow),float(cfg.turn_speed_fast),clampf(speed/float(def.speed),0,1))
	# Heavier missile ships use a wider arc, retaining their hull role.
	turn_rate*=float(def.turn_speed)/float(FrontierSpaceCombat.config().enemy.raider.turn_speed)
	var direction:=turn_toward(facing,desired_direction,frame.y,turn_rate*dt)
	var turn:=facing.signed_angle_to(direction,frame.y)/maxf(dt,.001)
	enemy.roll=lerpf(float(enemy.roll),clampf(-turn,-float(cfg.bank_limit),float(cfg.bank_limit)),1-exp(-dt*float(cfg.bank_response)))
	enemy.direction=FrontierSpaceCombat.arr(direction)
	enemy.up=FrontierSpaceCombat.arr(Quaternion(facing,direction)*frame.y)
	var velocity:=direction*speed
	var next:=position+velocity*dt
	var shift:=next-position
	var nearest:=position+shift*clampf((target-position).dot(shift)/maxf(shift.length_squared(),.0001),0,1)
	var clears_player:=nearest.distance_to(target)>=clearance or next.distance_to(target)>position.distance_to(target)
	if clears_player and FrontierSpaceCombat.clear_position(world,int(e.system),next,float(def.radius)+12) and (shift.length()<.001 or FrontierSpaceCombat.blocked_distance(world,int(e.system),position,direction,shift.length()+float(def.radius))>=shift.length()+float(def.radius)):
		enemy.position=FrontierSpaceCombat.arr(next)
	else:
		velocity=Vector3.ZERO
		# Turn toward an offset exit while stopped by an obstacle, then accelerate forward again.
		if enemy.maneuver!="break":
			enemy.break_end=FrontierSpaceCombat.arr(position+(position-target).normalized()*float(cfg.pass_length)+frame.x*side*clearance)
			phase(enemy,"break",float(def.break_seconds))
	enemy.velocity=FrontierSpaceCombat.arr(velocity);enemy.throttle=clampf(velocity.length()/float(def.speed),0,1)
	if enemy.maneuver=="strike" and int(enemy.burst)<int(def.burst_count) and float(enemy.maneuver_age)>=float(enemy.burst)*float(def.burst_interval):
		if launch(world,enemy,def):enemy.burst+=1
static func projectiles(world: Dictionary,delta: float) -> void:
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter
	var nav: Dictionary=FrontierSpaceCombat.local_world(world,e.carrier).crew.navigation
	for bolt in e.projectiles.duplicate():
		var start:=FrontierSpaceCombat.point(bolt.position);var velocity:=FrontierSpaceCombat.point(bolt.velocity)
		var missile: bool=bolt.get("kind","pulse")=="missile"
		var friendly: bool=bolt.get("side","pirate")=="crew"
		var ray:=velocity.normalized()
		# Player missiles fan out before steering toward the locked enemy. Enemy rockets retain their readable straight firing lane.
		if missile:
			var cfg: Dictionary=FrontierSpaceCombat.config().missile
			if friendly and float(bolt.get("age",0))>=float(cfg.fan_seconds):
				for enemy in e.enemies:
					if enemy.id!=bolt.get("target_id","") or float(enemy.hull)<=0:continue
					var desired: Vector3=(FrontierSpaceCombat.point(enemy.position)-start).normalized()
					var angle:=ray.angle_to(desired)
					if angle>.001:ray=ray.slerp(desired,minf(1,float(cfg.turn_speed)*delta/angle)).normalized()
					break
			velocity=ray*move_toward(velocity.length(),float(cfg.speed) if friendly else 340.0,float(cfg.acceleration)*delta)
			bolt.velocity=FrontierSpaceCombat.arr(velocity)
		var distance:=velocity.length()*minf(delta,float(bolt.life))
		var reach:=FrontierSpaceCombat.blocked_distance(world,int(e.system),start,ray,distance)
		var hit: Dictionary={};var hit_distance:=reach
		var targets: Array=e.enemies if friendly else [{"id":e.carrier,"position":nav.position,"hull":nav.get("hull",100),"radius":13.0 if e.carrier!="crew" else 22.0}]
		if not friendly:
			for device in e.get("deployables",[]):
				if device.kind=="decoy":targets.append({"id":str(device.id),"position":device.position,"hull":1.0,"radius":6.0,"decoy":true})
		for candidate in targets:
			if float(candidate.hull)<=0:continue
			var radius:=float(bolt.radius)+float(FrontierSpaceCombat.config().enemy[candidate.kind].radius if friendly else candidate.radius)
			var offset:=FrontierSpaceCombat.point(candidate.position)-start
			var along:=offset.dot(ray);var side2:=offset.length_squared()-along*along
			if side2>radius*radius or along+radius<0:continue
			var contact:=maxf(0,along-sqrt(maxf(0,radius*radius-side2)))
			if contact<=hit_distance:hit_distance=contact;hit=candidate
		bolt.life=maxf(0,bolt.life-delta);bolt.age=float(bolt.get("age",0))+delta
		var at:=start+ray*hit_distance
		if not hit.is_empty():
			if friendly:FrontierSpaceCombat.damage_enemy(world,hit,float(bolt.damage),start,at)
			elif hit.get("decoy",false):
				for device in e.get("deployables",[]).duplicate():
					if device.id==hit.id:e.deployables.erase(device)
				FrontierSpaceCombat.emit(r,"missile_blast",int(e.system),start,at,str(hit.id))
			else:FrontierSpaceCombat.damage_ship(world,e.carrier,float(bolt.damage),start)
		if not hit.is_empty() or bolt.life<=0 or reach<distance:
			if missile:FrontierSpaceCombat.emit(r,"missile_blast",int(e.system),start,at,str(bolt.id))
			elif hit.is_empty() and reach<distance:FrontierSpaceCombat.emit(r,"impact",int(e.system),start,at,"obstacle")
			e.projectiles.erase(bolt)
		else:bolt.position=FrontierSpaceCombat.arr(start+velocity*delta)

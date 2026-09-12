class_name FrontierSpaceCombatPilot
extends RefCounted
## Host-owned approach, locked firing lane, attack pass and banked withdrawal.
## Timers and projectile positions are saved; render joints never decide damage.
static func basis(direction: Vector3) -> Basis:
	return Basis.looking_at(direction.normalized(),Vector3.RIGHT if absf(direction.normalized().dot(Vector3.UP))>.98 else Vector3.UP)
static func phase(enemy: Dictionary,name: String,duration: float) -> void:
	enemy.maneuver=name;enemy.maneuver_age=0.0;enemy.maneuver_duration=duration;enemy.burst=0
static func initialize(enemy: Dictionary) -> void:
	if enemy.has("maneuver"):return
	enemy.velocity=[0.0,0.0,0.0];enemy.roll=0.0;enemy.throttle=0.2;enemy.cycle=0;enemy.recoil=0.0
	enemy.side=-1.0 if enemy.kind=="raider" else 1.0
	phase(enemy,"approach",float(FrontierSpaceCombat.config().enemy[enemy.kind].approach_seconds))
static func launch(world: Dictionary,enemy: Dictionary,def: Dictionary) -> void:
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter
	if e.projectiles.size()>=int(FrontierSpaceCombat.config().presentation.projectile_limit):return
	var facing:=basis(FrontierSpaceCombat.point(enemy.direction))
	var source:=FrontierSpaceCombat.point(enemy.position)+facing*Vector3(0,-1.3,-16)
	var direction: Vector3=(FrontierSpaceCombat.point(enemy.aim)-source).normalized()
	if facing.z.dot(direction)>-.6:return
	FrontierSpaceCombat.emit(r,"enemy_shot",int(e.system),source,source+direction*float(def.range),enemy.id)
	e.projectiles.append({"id":str(r.event_serial),"owner":str(enemy.id),"position":FrontierSpaceCombat.arr(source),"velocity":FrontierSpaceCombat.arr(direction*float(def.projectile_speed)),"life":float(def.range)/float(def.projectile_speed),"damage":float(def.damage),"radius":float(def.projectile_radius)})
	enemy.recoil=1.0
static func step(world: Dictionary,enemy: Dictionary,delta: float) -> void:
	initialize(enemy)
	var e: Dictionary=FrontierSpaceCombat.record(world).encounter
	var def: Dictionary=FrontierSpaceCombat.config().enemy[enemy.kind]
	var nav: Dictionary=FrontierSpaceCombat.local_world(world,e.carrier).crew.navigation
	var position:=FrontierSpaceCombat.point(enemy.position);var target:=FrontierSpaceCombat.point(nav.position)
	var heading:=FrontierSpaceCombat.point(nav.direction).normalized();var frame:=basis(heading)
	var right:=frame.x;var up:=frame.y
	var dt:=minf(delta,.2)
	enemy.age+=dt;enemy.recoil=maxf(0,float(enemy.recoil)-dt*5)
	if e.phase!="combat":
		enemy.windup=0.0;enemy.throttle=.16
		return
	enemy.maneuver_age+=dt
	var age:=float(enemy.maneuver_age);var duration:=float(enemy.maneuver_duration)
	var side:=float(enemy.side);var desired:=position;var speed:=float(def.speed)
	match str(enemy.maneuver):
		"approach":
			desired=target+heading*float(def.engagement_distance)+right*side*float(def.flank_distance)+up*35
			if age>=duration and position.distance_to(target)<float(def.range)*.85:
				enemy.aim=FrontierSpaceCombat.arr(target+heading*float(nav.speed)*.2)
				phase(enemy,"align",float(def.windup));enemy.windup=float(def.windup)
		"align":
			# Brake before locking: the player sees the full charge before any projectile exists.
			desired=position+FrontierSpaceCombat.point(enemy.velocity)*.12;speed*=.18
			enemy.windup=maxf(0,duration-age)
			if age>=duration:
				var lane: Vector3=(FrontierSpaceCombat.point(enemy.aim)-position).normalized()
				enemy.pass_end=FrontierSpaceCombat.arr(FrontierSpaceCombat.point(enemy.aim)+lane*190+right*side*95+up*30)
				phase(enemy,"strike",float(def.strike_seconds));enemy.windup=0.0
		"strike":
			desired=FrontierSpaceCombat.point(enemy.pass_end)
			if enemy.kind=="interdictor":speed*=.12
			if int(enemy.burst)<int(def.burst_count) and age>=float(enemy.burst)*float(def.burst_interval):
				launch(world,enemy,def);enemy.burst+=1
			if age>=duration:
				enemy.break_end=FrontierSpaceCombat.arr(position+FrontierSpaceCombat.point(enemy.direction)*100+right*side*200+up*90)
				phase(enemy,"break",float(def.break_seconds))
		"break":
			desired=FrontierSpaceCombat.point(enemy.break_end)
			if age>=duration:
				enemy.cycle+=1;enemy.side=-side
				phase(enemy,"approach",float(def.approach_seconds))
	var displacement:=desired-position
	var velocity:=FrontierSpaceCombat.point(enemy.velocity).move_toward(displacement.normalized()*minf(speed,displacement.length()*2),float(def.acceleration)*dt)
	var next:=position+velocity*dt
	var separation:=next-target
	if separation.length()<float(def.pass_clearance):
		# Fly a visible offset pass instead of crossing the player's hull.
		next=target+(separation.normalized() if separation.length()>.1 else right*side)*float(def.pass_clearance)
		velocity=(next-position)/maxf(dt,.001)
	var shift:=next-position
	if FrontierSpaceCombat.clear_position(world,int(e.system),next,float(def.radius)+12) and (shift.length()<.001 or FrontierSpaceCombat.blocked_distance(world,int(e.system),position,shift.normalized(),shift.length()+float(def.radius))>=shift.length()+float(def.radius)):
		enemy.position=FrontierSpaceCombat.arr(next)
	else:
		velocity=Vector3.ZERO
		if enemy.maneuver!="approach":phase(enemy,"approach",float(def.approach_seconds))
	var facing:=FrontierSpaceCombat.point(enemy.direction)
	var direction:=velocity.normalized() if velocity.length()>8 else (target-next).normalized()
	if enemy.maneuver=="align" or (enemy.kind=="interdictor" and enemy.maneuver=="strike"):direction=(FrontierSpaceCombat.point(enemy.aim)-next).normalized()
	if direction.length_squared()>.5:
		var turn:=facing.cross(direction).dot(up)
		enemy.roll=lerpf(float(enemy.roll),clampf(-turn*2.5,-.85,.85),1-exp(-dt*4))
		enemy.direction=FrontierSpaceCombat.arr(facing.slerp(direction,1-exp(-dt*float(def.turn_speed))).normalized())
	enemy.velocity=FrontierSpaceCombat.arr(velocity);enemy.throttle=clampf(velocity.length()/float(def.speed),.12,1)
static func projectiles(world: Dictionary,delta: float) -> void:
	var e: Dictionary=FrontierSpaceCombat.record(world).encounter
	var nav: Dictionary=FrontierSpaceCombat.local_world(world,e.carrier).crew.navigation
	var target:=FrontierSpaceCombat.point(nav.position)
	for bolt in e.projectiles.duplicate():
		var start:=FrontierSpaceCombat.point(bolt.position);var velocity:=FrontierSpaceCombat.point(bolt.velocity)
		var distance:=velocity.length()*delta;var ray:=velocity.normalized()
		var reach:=FrontierSpaceCombat.blocked_distance(world,int(e.system),start,ray,distance)
		var offset:=target-start;var along:=clampf(offset.dot(ray),0,reach)
		var radius:=float(bolt.radius)+(13.0 if e.carrier!="crew" else 22.0)
		bolt.life-=delta
		if (offset-ray*along).length()<radius:
			FrontierSpaceCombat.damage_ship(world,e.carrier,float(bolt.damage),start)
			e.projectiles.erase(bolt)
		elif bolt.life<=0 or reach<distance:e.projectiles.erase(bolt)
		else:bolt.position=FrontierSpaceCombat.arr(start+velocity*delta)

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
	var missile: bool=def.get("weapon","pulse")=="missile"
	var source:=FrontierSpaceCombat.point(enemy.position)+facing*(Vector3(-11.3 if int(enemy.burst)%2==0 else 11.3,2.0,-7.94) if missile else Vector3(0,-1.3,-16))
	var direction: Vector3=(FrontierSpaceCombat.point(enemy.aim)-source).normalized()
	if facing.z.dot(direction)>-.6:return
	FrontierSpaceCombat.emit(r,"missile_launch" if missile else "enemy_shot",int(e.system),source,source+direction*float(def.range),enemy.id)
	e.projectiles.append({"id":str(r.event_serial),"owner":str(enemy.id),"side":"pirate","kind":"missile" if missile else "pulse","position":FrontierSpaceCombat.arr(source),"velocity":FrontierSpaceCombat.arr(direction*(110.0 if missile else float(def.projectile_speed))),"life":3.2 if missile else float(def.range)/float(def.projectile_speed),"age":0.0,"damage":float(def.damage),"radius":float(def.projectile_radius)})
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
			if enemy.kind in ["interdictor","gunship"]:speed*=.12
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
	if enemy.maneuver=="align" or (enemy.kind in ["interdictor","gunship"] and enemy.maneuver=="strike"):direction=(FrontierSpaceCombat.point(enemy.aim)-next).normalized()
	if direction.length_squared()>.5:
		var turn:=facing.cross(direction).dot(up)
		enemy.roll=lerpf(float(enemy.roll),clampf(-turn*2.5,-.85,.85),1-exp(-dt*4))
		enemy.direction=FrontierSpaceCombat.arr(facing.slerp(direction,1-exp(-dt*float(def.turn_speed))).normalized())
	enemy.velocity=FrontierSpaceCombat.arr(velocity);enemy.throttle=clampf(velocity.length()/float(def.speed),.12,1)
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
			else:FrontierSpaceCombat.damage_ship(world,e.carrier,float(bolt.damage),start)
		if not hit.is_empty() or bolt.life<=0 or reach<distance:
			if missile:FrontierSpaceCombat.emit(r,"missile_blast",int(e.system),start,at,str(bolt.id))
			elif hit.is_empty() and reach<distance:FrontierSpaceCombat.emit(r,"impact",int(e.system),start,at,"obstacle")
			e.projectiles.erase(bolt)
		else:bolt.position=FrontierSpaceCombat.arr(start+velocity*delta)

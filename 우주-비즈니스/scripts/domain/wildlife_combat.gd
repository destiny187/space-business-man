class_name FrontierWildlifeCombat
extends RefCounted
## Host owns decisions, positions, attack clocks and damage. Models only present them.
const Attacks=preload("res://scripts/domain/wildlife_attacks.gd")
const Wildlife=preload("res://scripts/world/wildlife_behavior.gd")
static var _config: Dictionary={}
var cache: Dictionary={}
var cache_time:=0.0
var ground_cache: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/wildlife_combat.json"))
	return _config
static func pattern(form: Dictionary) -> String:
	var result: String=config().anatomical_attacks.get(form.get("construction",""),form.get("attack","none"))
	return result if config().patterns.has(result) and FrontierEcologyCatalog.ground_form(form) and form.get("locomotion_medium","") not in ["surface_air","atmosphere"] else "none"
static func profile(row: Dictionary) -> Dictionary:
	var form:=FrontierEcologyCatalog.form(row.form_id);var kind:=pattern(form)
	var result: Dictionary=config().patterns.get(kind,{"health":60,"speed":3.5,"reach":0.0}).duplicate()
	result.merge(config().get("anatomical_behaviors",{}).get(form.get("construction",""),{}),true)
	result.pattern=kind;result.nature="flee"
	if kind!="none":
		var roll:=FrontierUniverse.derive(47023,str(form.id)+":temperament-v1")%100
		result.nature="proactive" if roll<int(config().proactive_percent) else ("territorial" if roll<int(config().proactive_percent)+int(config().territorial_percent) else "retaliatory")
	var bounds: Dictionary=form.geometry.near
	var scale_value:=float(FrontierEcologyCatalog.look(row.form_id,row.look_id).get("scale",1.0))
	result.height=maxf(.3,(float(bounds.max[1])-float(bounds.floor_y))*scale_value)
	result.radius=maxf(.18,minf(float(bounds.max[0])-float(bounds.min[0]),float(bounds.max[2])-float(bounds.min[2]))*scale_value*.32)
	result.attack_front=maxf(0,float(bounds.max[2]))*scale_value
	result.reach+=minf(1.6,maxf(absf(float(bounds.min[2])),absf(float(bounds.max[2])))*scale_value*.35)
	return result
static func health(row: Dictionary) -> int:return int(profile(row).health)
static func key(body_id: String,row: Dictionary) -> String:return body_id+"/"+str(row.id)
static func state(crew: Dictionary,body_id: String,row: Dictionary) -> Dictionary:return crew.get("wildlife_encounters",{}).get(key(body_id,row),{})
static func ensure(crew: Dictionary,body_id: String,row: Dictionary) -> Dictionary:
	if not crew.has("wildlife_encounters"):crew.wildlife_encounters={}
	var id:=key(body_id,row)
	if not crew.wildlife_encounters.has(id):
		if crew.wildlife_encounters.size()>=int(config().maximum_encounters):return {}
		var at: Vector3=row.point;var home: Vector3=row.get("home_point",at)
		crew.wildlife_encounters[id]={"body_id":body_id,"encounter_id":row.id,"form_id":row.form_id,"look_id":row.look_id,"home":FrontierExplorationIncidents.array(home),"position":FrontierExplorationIncidents.array(at),"yaw":wrapf(float(row.get("behavior_yaw",row.yaw)),-PI,PI),"phase":"calm","time":0.0,"target":"","provoked":false,"aim":[0,0,-1],"struck":false,"serial":0,"hurt_serial":0,"flinch":0.0,"lost":0.0}
	return crew.wildlife_encounters[id]
static func set_phase(row: Dictionary,value: String) -> void:
	row.phase=value;row.time=0.0;row.serial+=1;row.erase("attack")
	if value=="attack":row.struck=false
static func body_position(live: Dictionary) -> Vector3:
	return FrontierCrewWorld.vector(live.position)+Vector3.UP*float(live.get("air_height",0))
static func hit(world: Dictionary,actor: String,row: Dictionary,amount: float) -> Dictionary:
	var id:=key(world.location,row)
	if not world.crew.has("combat"):world.crew.combat={}
	var before:=int(world.crew.combat.get(id,health(row)))
	var current:=state(world.crew,world.location,row)
	var info:=profile(row)
	if not current.is_empty() and Attacks.recovery(current,info):amount*=float(info.get("recovery_damage_multiplier",1.0))
	var hp:=maxi(0,before-roundi(amount));world.crew.combat[id]=hp
	var form:=FrontierEcologyCatalog.form(row.form_id)
	if Wildlife.eligible(form,row) and before>0:
		var live:=ensure(world.crew,world.location,row)
		if not live.is_empty():
			live.target=actor;live.provoked=true;live.hurt_serial+=1;live.lost=0.0
			if hp==0:set_phase(live,"down")
			elif live.flinch<=0 and not Attacks.airborne(live,info):
				set_phase(live,"hurt");live.flinch=float(config().flinch_cooldown)
	if hp==0 and before>0:
		if not world.crew.has("wildlife_stops"):world.crew.wildlife_stops={}
		world.crew.wildlife_stops[id]={"position":current.get("position",FrontierExplorationIncidents.array(row.point)),"yaw":wrapf(float(row.get("behavior_yaw",row.yaw)),-PI,PI)}
		FrontierSuitModules.on_kill(world.crew.members[actor])
	return {"damage":before-hp,"killed":before>0 and hp==0}
static func pose(field: FrontierTerrainField,row: Dictionary,home: Vector3,time: float,observers: Array[Vector3],crew: Dictionary,body_id: String) -> Dictionary:
	var live:=state(crew,body_id,row)
	if live.is_empty():return Wildlife.pose(field,row,home,time,observers,Wildlife.stopped(crew,body_id,row,home))
	var at:=body_position(live)
	var phase: String=live.phase
	return {"point":at,"basis":FrontierEcologyPlacement.surface_basis(field.normal(at),float(live.yaw)),"state":"attack" if phase=="attack" else ("dormant" if phase=="down" else ("move" if phase in ["chase","flee","return"] else ("stressed" if phase in ["warning","hurt"] else "idle"))),"phase":phase,"alert":phase=="warning","clock":float(live.time),"combat":live}
static func valid(crew: Dictionary) -> bool:
	var rows: Variant=crew.get("wildlife_encounters",{})
	if not rows is Dictionary or rows.size()>int(config().maximum_encounters):return false
	for id in rows:
		var r: Variant=rows[id]
		if not id is String or not r is Dictionary:return false
		for field_name in ["body_id","encounter_id","form_id","look_id","phase","target"]:
			if not r.get(field_name) is String:return false
		if id!=str(r.body_id)+"/"+str(r.encounter_id) or FrontierEcologyCatalog.form(r.form_id).is_empty() or FrontierEcologyCatalog.look(r.form_id,r.look_id).is_empty():return false
		if r.phase not in ["calm","warning","chase","attack","hurt","flee","return","down"] or (r.target!="" and not crew.members.has(r.target)):return false
		for field_name in ["home","position","aim"]:
			if not FrontierUniverse._vector3_array(r.get(field_name)):return false
		for field_name in ["time","serial","hurt_serial","flinch","lost"]:
			if not FrontierUniverse._finite(r.get(field_name),0,9007199254740000):return false
		if r.has("attack") and not Attacks.valid(r.attack,crew):return false
		if r.has("air_height") and not FrontierUniverse._finite(r.air_height,0,4):return false
		for extra in ["cue_serial"]:
			if r.has(extra) and not FrontierUniverse._finite(r[extra],0,9007199254740000):return false
		if r.has("air_velocity") and not FrontierUniverse._finite(r.air_velocity,-100,100):return false
		if not FrontierUniverse._finite(r.get("yaw"),-PI-.001,PI+.001) or not r.get("provoked") is bool or not r.get("struck") is bool:return false
	return true
static func resume(crew: Dictionary) -> void:
	for row in crew.get("wildlife_encounters",{}).values():
		row.air_height=0.0;row.air_velocity=0.0;row.erase("attack")
		if row.phase=="down":continue
		row.target="";row.provoked=false;row.flinch=0.0;row.lost=0.0;set_phase(row,"return")
func candidates(world: Dictionary,actors: Array,delta: float) -> Dictionary:
	cache_time-=delta
	if cache_time>0:return cache
	cache_time=float(config().candidate_seconds);cache={}
	for actor in actors:
		var local:=FrontierShuttles.context(world,actor)
		if not FrontierCrewSurface.landed(local):continue
		var body:=FrontierUniverse.body_from_id(world.manifest,local.location)
		var field:=FrontierCrewSurface.field(local);var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
		var count:=0;var cfg:=FrontierEcologyCatalog.placement_config(body)
		for row in FrontierEcologyPlacement.candidates(body,world.ecology.planets[body.id],p):
			var ground_key:=str(field.get_instance_id())+":"+str(field.revision)+":"+str(row.id)
			if ground_cache.size()>2048:ground_cache.clear()
			if not ground_cache.has(ground_key):ground_cache[ground_key]=FrontierEcologyPlacement.ground(field,row)
			var home: Vector3=ground_cache[ground_key]
			if not home.is_finite() or home.distance_to(p)>float(cfg.active_radius):continue
			var form:=FrontierEcologyCatalog.form(row.form_id)
			var status_value:=FrontierEcology.status(world.ecology.planets[body.id],form,home,row.layer)
			if status_value=="absent" or (status_value=="dormant" and form.category=="animal" and not row.introduced):continue
			count+=1
			if count>int(cfg.max_actors):break
			if status_value!="active" or not Wildlife.eligible(form,row):continue
			row.home_point=home;row.point=home;row.status=status_value;row.body_id=body.id
			cache[key(body.id,row)]=row
	return cache
func tick(world: Dictionary,delta: float,actors: Array,obstacle: Callable=Callable(),ready: Callable=Callable(),present: Array=[]) -> bool:
	var active: Array=[]
	for id in actors:
		var m: Dictionary=world.crew.members[id]
		if m.area=="surface" and not m.aboard and m.get("vehicle_id","")=="" and (not ready.is_valid() or ready.call(id)):active.append(id)
	var observers: Array=[]
	for id in (actors if present.is_empty() else present):
		var member: Dictionary=world.crew.members[id]
		if member.area=="surface" and not member.aboard and (not ready.is_valid() or ready.call(id)):observers.append(id)
	var rows:=candidates(world,observers,delta)
	var changed:=false;var retained: Dictionary={}
	for id in rows:
		var row: Dictionary=rows[id];var nearby: Array=[]
		for actor in observers:
			if FrontierShuttles.area_key(world,actor)=="surface:"+str(row.body_id) and FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(row.home_point)<float(FrontierEcologyCatalog.config().active_radius):nearby.append(actor)
		if nearby.is_empty():continue
		retained[id]=true
		nearby=nearby.filter(func(actor):return actor in active)
		if nearby.is_empty():continue
		if int(world.crew.get("combat",{}).get(id,1))==0 and float(state(world.crew,row.body_id,row).get("air_height",0))<=0:continue
		var local:=FrontierShuttles.context(world,nearby[0]);var field:=FrontierCrewSurface.field(local)
		var info:=profile(row);var live:=state(world.crew,row.body_id,row)
		if live.is_empty():
			if info.nature in ["flee","retaliatory"]:continue
			var points: Array[Vector3]=[]
			for actor in nearby:points.append(FrontierCrewWorld.vector(world.crew.members[actor].position))
			var motion:=Wildlife.pose(field,row,row.home_point,float(local.crew.navigation.orbit_time),points)
			row.point=motion.point;row.behavior_yaw=motion.basis.get_euler().y
			var chosen:=choose(world,row,info,nearby,field,obstacle)
			if chosen.is_empty():continue
			live=ensure(world.crew,row.body_id,row)
			if live.is_empty():continue
			live.target=chosen;set_phase(live,"warning")
		changed=true
		_step(world,row,live,info,nearby,field,delta,obstacle)
	for id in world.crew.get("wildlife_encounters",{}).keys():
		if not retained.has(id):world.crew.wildlife_encounters.erase(id);changed=true
	return changed
static func safe(member: Dictionary) -> bool:
	return float(member.get("vitals",{}).get("protection",0))>0 or Vector2(float(member.position[0]),float(member.position[2])).length()<float(config().ship_safe_radius)
static func clear(world: Dictionary,row: Dictionary,actor: String,field: FrontierTerrainField,from: Vector3,to: Vector3,obstacle: Callable) -> bool:
	var difference:=to-from
	if difference.length()<.01:return true
	if not FrontierCrewSurface.visible_in_field(field,from,to):return false
	if not FrontierCombatCover.intercept(world,row.body_id,from,difference.normalized(),difference.length()).is_empty():return false
	return not obstacle.is_valid() or obstacle.call(actor,str(row.id),from,to,0.0,0.0)
static func choose(world: Dictionary,row: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,obstacle: Callable) -> String:
	var best: float=float(config().notice_radius) if info.nature=="proactive" else float(config().territory_radius)
	var result:=""
	for actor in actors:
		var member: Dictionary=world.crew.members[actor]
		if safe(member):continue
		var at:=FrontierCrewWorld.vector(member.position);var gap: float=row.point.distance_to(at)
		if gap<best and clear(world,row,actor,field,row.point+Vector3.UP*minf(float(info.height)*.65,1.7),at+Vector3.UP,obstacle):result=actor;best=gap
	return result
static func _step(world: Dictionary,row: Dictionary,live: Dictionary,info: Dictionary,actors: Array,field: FrontierTerrainField,delta: float,obstacle: Callable) -> void:
	live.time+=delta;live.flinch=maxf(0,float(live.flinch)-delta)
	if float(live.get("air_height",0))>0 and (live.phase!="attack" or info.get("behavior","")!="leap" or live.get("attack",{}).get("blocked",false)):
		live.air_velocity=float(live.get("air_velocity",0))-float(config().fall_gravity)*delta
		live.air_height=maxf(0,float(live.air_height)+float(live.air_velocity)*delta)
		if live.air_height<=0:live.air_velocity=0.0
		return
	if live.phase=="down":return
	var at:=FrontierCrewWorld.vector(live.position);var home:=FrontierCrewWorld.vector(live.home)
	var target: String=live.target
	var allowed: bool=target in actors and not safe(world.crew.members[target])
	var dest:=FrontierCrewWorld.vector(world.crew.members[target].position) if allowed else home
	if not allowed or dest.distance_to(home)>float(config().leash_radius) or at.distance_to(home)>float(config().leash_radius):
		if live.phase not in ["return","calm"]:live.target="";live.provoked=false;set_phase(live,"return")
	if live.phase=="calm":
		if live.time<float(config().return_calm_seconds):return
		row.point=at
		var found:=choose(world,row,info,actors,field,obstacle) if info.nature in ["proactive","territorial"] else ""
		if not found.is_empty():live.target=found;set_phase(live,"warning")
		return
	if live.phase=="return":
		if at.distance_to(home)<.65:set_phase(live,"calm")
		else:move(world,row,live,home,info,field,delta,obstacle,actors[0])
		return
	if live.phase=="hurt":
		if live.time<float(config().flinch_seconds):return
		set_phase(live,"flee" if info.pattern=="none" or (info.nature!="proactive" and int(world.crew.combat.get(key(row.body_id,row),info.health))<float(info.health)*float(config().flee_health_fraction)) else "warning")
		return
	if live.phase=="flee":
		var away: Vector3=(at-dest).normalized()
		if away.length_squared()<.1:away=Vector3.RIGHT
		move(world,row,live,home+away*float(config().leash_radius)*.8,info,field,delta,obstacle,target)
		if live.time>float(config().give_up_seconds):live.target="";live.provoked=false;set_phase(live,"return")
		return
	var direction:=dest-at;direction.y=0
	if live.phase!="attack" and direction.length_squared()>.01:live.yaw=atan2(direction.x,direction.z)
	if live.phase=="warning":
		if live.time>=float(config().warning_seconds):set_phase(live,"chase")
		return
	if live.phase=="chase":
		var visible:=clear(world,row,target,field,at+Vector3.UP*minf(float(info.height)*.65,1.7),dest+Vector3.UP,obstacle)
		live.lost=0.0 if visible else float(live.lost)+delta
		if live.lost>float(config().give_up_seconds):live.target="";set_phase(live,"return");return
		if direction.length()<=float(info.get("start_range",info.reach)) and absf(dest.y-at.y)<2.0 and visible:
			live.aim=FrontierExplorationIncidents.array(direction.normalized() if direction.length()>.01 else Vector3(sin(live.yaw),0,cos(live.yaw)));set_phase(live,"attack")
			Attacks.begin(live,info,dest,field,row)
		else:move(world,row,live,dest,info,field,delta,obstacle,target)
		return
	if live.phase=="attack":
		if not live.has("attack"):Attacks.begin(live,info,dest,field,row)
		Attacks.step(world,row,live,info,actors,field,delta,obstacle)
static func move(world: Dictionary,row: Dictionary,live: Dictionary,destination: Vector3,info: Dictionary,field: FrontierTerrainField,delta: float,obstacle: Callable,actor: String) -> void:
	var at:=FrontierCrewWorld.vector(live.position);var direction:=destination-at;direction.y=0
	if direction.length()<.05:return
	var step:=minf(direction.length(),float(info.speed)*delta)
	var best:=Vector3.INF;var best_gap:=INF
	for turn in [0.0,.9,-.9,1.55,-1.55]:
		var forward:=direction.normalized().rotated(Vector3.UP,turn)
		var candidate:=row.duplicate();candidate.point=at+forward*step;candidate.yaw=atan2(forward.x,forward.z)
		var next:=FrontierEcologyPlacement.ground(field,candidate)
		if not next.is_finite() or absf(next.y-at.y)>float(Wildlife.config().maximum_step_height):continue
		var segment:=next-at
		if not FrontierCombatCover.intercept(world,row.body_id,at+Vector3.UP*.5,segment.normalized(),segment.length()+float(info.radius)).is_empty():continue
		if obstacle.is_valid() and not obstacle.call(actor,str(row.id),at,next,float(info.radius),float(info.height)):continue
		var gap:=next.distance_to(destination)
		if gap<best_gap:best=next;best_gap=gap
		if is_zero_approx(turn):break
	if best.is_finite():
		live.yaw=atan2((best-at).x,(best-at).z);live.position=FrontierExplorationIncidents.array(best)

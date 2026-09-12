class_name FrontierSpaceCombat
extends RefCounted
## Host-owned ship combat. No surface combat or peaceful traffic state is reused.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_combat.json"))
	return _config
static func create() -> Dictionary:
	return {"version":1,"clock":0.0,"cooldown":0.0,"safe_journeys":0,"serial":0,"event_serial":0,"flights":{},"ships":{},"encounter":{},"wrecks":[],"events":[]}
static func record(world: Dictionary) -> Dictionary:return world.get("crew",{}).get("space_combat",{})
static func carrier(world: Dictionary,actor: String) -> String:return "shuttle:"+actor if FrontierShuttles.aboard(world,actor) else "crew"
static func local_world(world: Dictionary,id: String) -> Dictionary:
	return FrontierShuttles.context(world,id.trim_prefix("shuttle:")) if id.begins_with("shuttle:") else world
static func commit(world: Dictionary,local: Dictionary,id: String) -> void:
	if id.begins_with("shuttle:"):FrontierShuttles.commit(world,local,id.trim_prefix("shuttle:"))
static func point(a: Array) -> Vector3:return FrontierCrewWorld.vector(a)
static func arr(p: Vector3) -> Array:return [p.x,p.y,p.z]
static func engagement(world: Dictionary,id: String) -> bool:
	var e: Dictionary=record(world).get("encounter",{})
	return not e.is_empty() and e.carrier==id and e.phase in ["warning","combat","recovering"]
static func same_space(world: Dictionary,actor: String,e: Dictionary) -> bool:
	var local:=FrontierShuttles.context(world,actor)
	return not e.is_empty() and not FrontierCrewSurface.landed(local) and local.crew.members[actor].aboard and local.crew.navigation.mode!="jump" and int(local.crew.navigation.system)==int(e.system)
static func guard(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var id:=carrier(world,actor)
	if kind=="shuttle_recall":id="shuttle:"+str(args.get("character_id",""))
	if not engagement(world,id):return ""
	# The authority permits recall only for an offline pilot; successful recall settles this encounter.
	if kind=="shuttle_recall":return ""
	if kind in ["navigate","depart","tutorial_depart","land","shuttle_recall","shuttle_dock"] or kind.begins_with("station_") or kind.begins_with("vessel_"):return "추격 범위를 벗어나거나 해적을 격퇴한 뒤 항해하세요."
	return ""
static func recalled(world: Dictionary,actor: String) -> void:
	var r:=record(world)
	if r.is_empty() or r.encounter.is_empty() or r.encounter.carrier!="shuttle:"+actor:return
	var ship: Dictionary=world.crew.shuttles[actor]
	ship.navigation.combat_active=false;ship.navigation.combat_recovery=false
	r.encounter={};r.flights.erase("shuttle:"+actor)
	r.cooldown=float(config().cooldown_seconds);r.safe_journeys=int(config().safe_journeys)
	emit(r,"recover",int(ship.navigation.system),point(ship.navigation.position),point(ship.navigation.position),"shuttle:"+actor)
static func ship_state(world: Dictionary,id: String) -> Dictionary:
	var r:=record(world)
	if not r.ships.has(id):r.ships[id]={"shield":float(config().finch_shield if id!="crew" else config().shield),"heat":0.0,"overheated":false,"cooldown":0.0,"hit_age":100.0}
	var local:=local_world(world,id);local.crew.navigation.combat_fitted=true
	commit(world,local,id)
	return r.ships[id]
static func emit(r: Dictionary,kind: String,system: int,origin: Vector3,target: Vector3,id: String="") -> void:
	r.event_serial+=1;r.events.append({"serial":r.event_serial,"kind":kind,"system":system,"origin":arr(origin),"target":arr(target),"id":id})
	while r.events.size()>32:r.events.pop_front()
static func clear_position(world: Dictionary,system: int,p: Vector3,radius: float=160.0) -> bool:
	var elapsed:=float(world.crew.navigation.get("orbit_time",0))
	if p.length()+radius>float(FrontierUniverse.system_layout(world.manifest,system).boundary):return false
	for obstacle in FrontierCrewNavigation.departure_obstacles(world.manifest,system,elapsed,8.0):
		if p.distance_to(obstacle.point)<float(obstacle.radius)+radius:return false
	return true
static func tier(world: Dictionary,system: int) -> int:
	var result:=1
	for i in FrontierUniverse.body_count(world.manifest,system):result=maxi(result,int(FrontierUniverse.body(world.manifest,FrontierUniverse.first_ordinal(world.manifest,system)+i,false).planet_tier))
	return result
static func eligible(world: Dictionary,id: String) -> bool:
	var local:=local_world(world,id);var nav: Dictionary=local.crew.navigation
	if FrontierCrewSurface.landed(local) or FrontierSolarOpening.active(nav) or nav.has("station_docked") or nav.get("star_warning",false):return false
	if int(nav.system)==0 or int(nav.system)==int(nav.get("first_stellar_system",-1)):return false
	return tier(world,int(nav.system))>=int(config().minimum_tier) and clear_position(world,int(nav.system),point(nav.position),350)
static func roll(world: Dictionary,id: String,variant: String) -> bool:
	var r:=record(world);r.serial+=1
	var rng:=RandomNumberGenerator.new();rng.seed=hash(str(world.manifest.seed)+"/pirate/"+str(r.serial)+"/"+id+"/"+variant)
	return rng.randf()<float(config().stellar_chance if variant=="stellar_arrival" else config().local_chance)
static func begin(world: Dictionary,id: String,variant: String) -> bool:
	var r:=record(world)
	if r.is_empty() or not r.encounter.is_empty():return false
	var local:=local_world(world,id);var nav: Dictionary=local.crew.navigation
	var origin:=point(nav.position);var heading:=point(nav.direction).normalized()
	var right:=heading.cross(Vector3.UP).normalized()
	if right.length_squared()<.5:right=Vector3.RIGHT
	var enemies: Array=[]
	var kinds: Array=["raider","interdictor"] if id=="crew" else ["raider"]
	for i in kinds.size():
		var p:=origin+heading*(270.0+i*75)+right*(-105.0+i*215)+Vector3.UP*50
		if not clear_position(world,int(nav.system),p,100):return false
		var cfg: Dictionary=config().enemy[kinds[i]]
		enemies.append({"id":str(r.serial)+":"+str(i),"kind":kinds[i],"position":arr(p),"direction":arr(-heading),"hull":float(cfg.hull),"shield":float(cfg.shield),"cooldown":1.0+i,"windup":0.0,"aim":arr(origin),"age":float(i)*2,"hit_age":100.0})
	nav.mode="idle";nav.manual=true;nav.speed=minf(float(nav.speed),float(config().combat_speed));nav.combat_active=true;nav.erase("freight_anchor")
	r.encounter={"id":"pirate:"+str(r.serial),"variant":variant,"carrier":id,"system":int(nav.system),"origin":arr(origin),"heading":arr(heading),"target":int(nav.target),"phase":"warning","warning":float(config().warning_seconds),"elapsed":0.0,"escape":0.0,"resume":0.0,"recovery":0.0,"salvage":0.0,"salvage_id":"","enemies":enemies,"projectiles":[]}
	ship_state(world,id);commit(world,local,id)
	emit(r,"warning",int(nav.system),origin,origin,id)
	return true
static func resume(world: Dictionary) -> void:
	var r:=record(world)
	if r.is_empty():return
	if not r.encounter.is_empty():
		r.encounter.resume=float(config().resume_seconds);r.encounter.projectiles=[]
	r.events=[]
static func intercept_arrival(world: Dictionary) -> bool:
	var r:=record(world);var nav: Dictionary=world.crew.navigation
	if r.is_empty() or not r.encounter.is_empty() or nav.mode!="jump" or r.flights.get("crew",{}).get("route","")!="ambush":return false
	var progress:=FrontierCrewNavigation.transit_progress(nav)
	if progress<.985:return false
	var old_system: int=nav.system;var old_position: Array=nav.position.duplicate()
	var target_system:=FrontierUniverse.system_index(world.manifest,int(nav.target))
	var entry:=FrontierUniverse.entry_position(world.manifest,int(nav.target),float(nav.orbit_time))
	var focus:=FrontierUniverse.entry_focus(world.manifest,int(nav.target),float(nav.orbit_time))
	var presentation: Dictionary=FrontierUniverse.presentation().stellar_transition
	var at:=entry+(entry-focus).normalized()*float(presentation.distant_offset)*(1-smoothstep(float(presentation.swap_progress),1,progress))
	nav.system=target_system;nav.position=arr(at)
	r.flights.crew.route=""
	if clear_position(world,target_system,at,350) and begin(world,"crew","stellar_arrival"):
		world.location=FrontierUniverse.body_id(world.manifest,FrontierUniverse.first_ordinal(world.manifest,target_system))
		world.flight_position=nav.position.duplicate();r.flights.crew.mode="idle"
		return true
	nav.system=old_system;nav.position=old_position
	return false
static func finish(world: Dictionary,outcome: String) -> void:
	var r:=record(world);var e: Dictionary=r.encounter
	var local:=local_world(world,e.carrier);var nav: Dictionary=local.crew.navigation
	nav.combat_active=false;nav.combat_recovery=false
	for enemy in e.enemies:enemy.windup=0.0
	e.phase=outcome;e.elapsed=0.0;e.projectiles=[]
	r.cooldown=float(config().cooldown_seconds);r.safe_journeys=int(config().safe_journeys)
	commit(world,local,e.carrier);emit(r,"escaped",int(e.system),point(nav.position),point(nav.position),e.carrier)
	if outcome=="escaped":transmit(world,"radio_withdraw")
static func transmit(world: Dictionary,kind: String) -> void:
	var r:=record(world);var e: Dictionary=r.encounter
	for enemy in e.enemies:
		if enemy.hull>0:
			emit(r,kind,int(e.system),point(enemy.position),point(local_world(world,e.carrier).crew.navigation.position),str(enemy.id))
			return
static func blocked_distance(world: Dictionary,system: int,origin: Vector3,direction: Vector3,reach: float) -> float:
	for obstacle in FrontierCrewNavigation.departure_obstacles(world.manifest,system,float(world.crew.navigation.get("orbit_time",0)),0):
		var offset: Vector3=obstacle.point-origin;var along:=offset.dot(direction)
		var side2:=offset.length_squared()-along*along;var radius:=float(obstacle.radius)
		if along>0 and side2<radius*radius:reach=minf(reach,maxf(0,along-sqrt(radius*radius-side2)))
	return reach
static func fire(world: Dictionary,actor: String,aim: Vector3) -> bool:
	var r:=record(world);var e: Dictionary=r.encounter
	if not same_space(world,actor,e) or e.phase not in ["warning","combat"] or float(e.resume)>0:return false
	var local:=FrontierShuttles.context(world,actor);var id:=carrier(world,actor);var nav: Dictionary=local.crew.navigation
	if id!="crew" or actor!=world.crew.pilot_id or nav.mode!="idle":return false
	var stats:=ship_state(world,id)
	if stats.cooldown>0 or stats.overheated:return false
	var direction:=point(nav.direction).normalized()
	if not aim.is_finite() or aim.dot(direction)<float(config().aim_dot):return false
	var frame:=FrontierSpaceCombatPilot.basis(direction)
	var origin:=point(nav.position)+frame*point(config().presentation.muzzle)
	# Third-person aiming converges from the camera reticle; muzzle geometry still blocks the ray.
	var camera_origin:=point(nav.position)+frame*point(config().presentation.camera)
	var focus_range:=blocked_distance(world,int(nav.system),camera_origin,aim,float(config().fire_range))
	for enemy in e.enemies:
		if float(enemy.hull)<=0:continue
		var offset:=point(enemy.position)-camera_origin;var along:=offset.dot(aim)
		var radius:=float(config().enemy[enemy.kind].radius);var side2:=offset.length_squared()-along*along
		if along>0 and side2<radius*radius:focus_range=minf(focus_range,maxf(0,along-sqrt(radius*radius-side2)))
	var ray: Vector3=(camera_origin+aim*focus_range-origin).normalized()
	var reach:=blocked_distance(world,int(nav.system),origin,ray,float(config().fire_range))
	var selected: Dictionary={}
	for enemy in e.enemies:
		if float(enemy.hull)<=0:continue
		var offset:=point(enemy.position)-origin;var along:=offset.dot(ray);var radius:=float(config().enemy[enemy.kind].radius)
		var side2:=offset.length_squared()-along*along
		if along>0 and side2<radius*radius:
			var distance:=maxf(0,along-sqrt(radius*radius-side2))
			if distance<reach:reach=distance;selected=enemy
	stats.cooldown=float(config().fire_interval);stats.heat=minf(1,stats.heat+float(config().fire_heat));stats.overheated=stats.heat>=1.0
	emit(r,"shot",int(nav.system),origin,origin+ray*reach,id)
	if not selected.is_empty():
		var amount:=float(config().fire_damage);var absorbed:=minf(float(selected.shield),amount)
		selected.shield-=absorbed;selected.hull=maxf(0,selected.hull-(amount-absorbed));selected.hit_age=0.0
		emit(r,"break" if absorbed>0 and selected.shield<=0 else "impact",int(nav.system),origin,origin+ray*reach,selected.id)
		if selected.hull<=0:
			r.wrecks.append({"id":str(e.id)+"/"+str(selected.id),"system":int(e.system),"position":selected.position.duplicate(),"kind":selected.kind,"loot":config().enemy[selected.kind].loot.duplicate(true)})
			while r.wrecks.size()>int(config().maximum_wrecks):r.wrecks.pop_front()
			emit(r,"destroy",int(nav.system),point(selected.position),point(selected.position),selected.id)
	return true
static func damage_ship(world: Dictionary,id: String,amount: float,source: Vector3=Vector3.INF) -> void:
	var local:=local_world(world,id);var stats:=ship_state(world,id);var nav: Dictionary=local.crew.navigation
	var absorbed:=minf(float(stats.shield),amount);stats.shield-=absorbed;stats.hit_age=0.0
	nav.hull=maxf(0,float(nav.get("hull",100))-(amount-absorbed));nav.damage_cooldown=8.0
	emit(record(world),"break" if absorbed>0 and stats.shield<=0 else "impact",int(nav.system),source if source.is_finite() else point(nav.position)+Vector3.UP,point(nav.position),id)
	commit(world,local,id)
static func tick(world: Dictionary,delta: float,inputs: Dictionary,peers: Dictionary,now: float) -> bool:
	var r:=record(world)
	if r.is_empty() or peers.is_empty():return false
	var cfg:=config();r.clock+=delta;r.cooldown=maxf(0,r.cooldown-delta)
	var pilots: Dictionary={}
	for peer in peers:
		var actor: String=peers[peer];var id:=carrier(world,actor)
		if actor==local_world(world,id).crew.pilot_id:pilots[id]={"actor":actor,"peer":peer}
	for id in r.ships:
		var stats: Dictionary=r.ships[id];stats.cooldown=maxf(0,stats.cooldown-delta);stats.hit_age+=delta
		stats.heat=maxf(0,stats.heat-float(cfg.heat_cooling)*delta)
		if stats.heat<=.2:stats.overheated=false
		if stats.hit_age>=float(cfg.shield_delay):stats.shield=minf(float(cfg.shield if id=="crew" else cfg.finch_shield),stats.shield+float(cfg.shield_rate)*delta)
	var changed:=false
	for id in pilots:
		var local:=local_world(world,id);var nav: Dictionary=local.crew.navigation
		if not r.flights.has(id):r.flights[id]={"mode":str(nav.mode),"route":"","seconds":0.0,"distance":0.0,"position":nav.position.duplicate()}
		var f: Dictionary=r.flights[id];var input: Dictionary=inputs.get(pilots[id].peer,{})
		var control: Array=input.get("flight_controls",[])
		var ready:=float(input.get("expires",-1))>=now and control.size()==6 and float(control[5])>.5
		var pos:=point(nav.position)
		if str(nav.mode)=="jump" and str(f.mode)!="jump":
			f.route="pending";f.seconds=0.0;f.distance=0.0
			var protected: bool=r.safe_journeys>0
			if r.safe_journeys>0:r.safe_journeys-=1
			var destination:=FrontierUniverse.system_index(world.manifest,int(nav.target))
			if r.cooldown<=0 and not protected and r.encounter.is_empty() and int(nav.system)!=0 and destination!=int(nav.get("first_stellar_system",-1)) and tier(world,destination)>=int(cfg.minimum_tier):
				f.route="ambush" if roll(world,id,"stellar_arrival") else "clear";changed=true
		if nav.mode=="idle" and f.route=="ambush" and ready:
			if eligible(world,id) and begin(world,id,"stellar_arrival"):changed=true
			f.route="";f.seconds=0.0;f.distance=0.0
		elif nav.mode!="jump" and f.mode=="jump" and f.route!="ambush":f.route=""
		if nav.mode!="jump" and f.route!="ambush" and ready and not FrontierCrewSurface.landed(local) and r.encounter.is_empty():
			if nav.mode=="approach" or absf(float(nav.speed))>20:
				f.seconds+=delta;f.distance+=minf(pos.distance_to(point(f.position)),float(cfg.combat_speed)*5*delta)
			if f.seconds>=float(cfg.local_seconds) and f.distance>=float(cfg.local_distance):
				f.seconds=0.0;f.distance=0.0
				var protected: bool=r.safe_journeys>0
				if r.safe_journeys>0:r.safe_journeys-=1
				if r.cooldown<=0 and not protected and eligible(world,id):
					if roll(world,id,"local_transit"):begin(world,id,"local_transit")
					changed=true
		f.mode=str(nav.mode);f.position=nav.position.duplicate()
	for id in pilots:
		var stats: Dictionary=r.ships.get(id,{})
		if stats.get("operation",{}).is_empty():continue
		var op: Dictionary=stats.operation
		var local:=local_world(world,id);var nav: Dictionary=local.crew.navigation
		var input: Dictionary=inputs.get(pilots[id].peer,{})
		var buttons: Array=input.get("flight_controls",[])
		if engagement(world,id) or nav.mode!="idle" or absf(float(nav.speed))>20 or float(input.get("expires",-1))<now or buttons.size()!=6 or float(buttons[5])<.5:
			stats.operation={};changed=true;continue
		op.elapsed+=delta
		if op.elapsed>=float(cfg.salvage_seconds):
			stats.operation={}
			var reason:=complete_operation(world,pilots[id].actor,op.kind,op.id)
			stats.operation_error=reason;changed=true
	var e: Dictionary=r.encounter
	if e.is_empty():return changed
	if not pilots.has(e.carrier):return changed
	var pilot: Dictionary=pilots[e.carrier];var local:=local_world(world,e.carrier);var nav: Dictionary=local.crew.navigation
	var input: Dictionary=inputs.get(pilot.peer,{});var controls: Array=input.get("flight_controls",[])
	var ready:=float(input.get("expires",-1))>=now and controls.size()==6 and float(controls[5])>.5
	# Menus do not pause combat; loading/disconnection holds only the initial/resume warning.
	if e.resume>0:
		if ready:e.resume=maxf(0,e.resume-delta)
		return changed
	if e.phase=="warning":
		if ready:e.warning=maxf(0,e.warning-delta)
		if e.warning<=0:e.phase="combat";transmit(world,"radio_contact");changed=true
	elif e.phase in ["escaped","victory","recovered"]:
		e.elapsed+=delta
		if e.elapsed>4:r.encounter={};return true
		return changed
	else:e.elapsed+=delta
	if e.phase=="recovering":
		e.recovery+=delta;nav.position=arr(point(nav.position).move_toward(point(e.recovery_point),250*delta));nav.speed=0.0
		if e.recovery>=float(cfg.recovery_seconds):nav.hull=float(cfg.recovery_hull);ship_state(world,e.carrier).shield=float(cfg.shield if e.carrier=="crew" else cfg.finch_shield)*.5;finish(world,"recovered");changed=true
		commit(world,local,e.carrier);return changed
	if float(nav.get("hull",100))<=0:
		e.phase="recovering";nav.combat_recovery=true;nav.speed=0.0
		var destination:=point(nav.position)
		for i in 12:
			var p:=point(nav.position)+Vector3(cos(i*TAU/12),.3,sin(i*TAU/12))*1000
			var shift:=p-point(nav.position)
			if clear_position(world,int(e.system),p,200) and blocked_distance(world,int(e.system),point(nav.position),shift.normalized(),shift.length())>=shift.length():destination=p;break
		e.recovery_point=arr(destination);commit(world,local,e.carrier);emit(r,"recover",int(e.system),point(nav.position),destination,e.carrier);return true
	for id in pilots:
		var member_input: Dictionary=inputs.get(pilots[id].peer,{});var buttons: Array=member_input.get("flight_controls",[])
		if float(member_input.get("expires",-1))>=now and buttons.size()==6 and float(buttons[4])>.5 and float(buttons[5])>.5:
			var wreck_count: int=r.wrecks.size()
			fire(world,pilots[id].actor,member_input.get("aim",Vector3.FORWARD))
			if r.wrecks.size()!=wreck_count:changed=true
	if not e.has("projectiles"):e.projectiles=[]
	var living:=0;var jammed:=false;var pos:=point(nav.position)
	for enemy in e.enemies:
		enemy.hit_age+=delta
		if enemy.hull<=0:continue
		living+=1
		if enemy.kind=="interdictor" and pos.distance_to(point(enemy.position))<float(cfg.escape_radius):jammed=true
		FrontierSpaceCombatPilot.step(world,enemy,delta)
	if e.phase=="combat":FrontierSpaceCombatPilot.projectiles(world,delta)
	if living==0:finish(world,"victory");return true
	var escaped:=pos.distance_to(point(e.origin))>float(cfg.escape_radius) and not jammed
	e.escape=minf(float(cfg.escape_seconds),e.escape+delta) if escaped else maxf(0,e.escape-delta*.5)
	if e.escape>=float(cfg.escape_seconds) or e.elapsed>=float(cfg.pursuit_seconds if e.carrier!="crew" else cfg.combat_seconds):finish(world,"escaped");return true
	return changed
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var r:=record(world)
	if r.is_empty():return "이 원정에는 해적 전투 규칙이 없습니다."
	var id:=carrier(world,actor);var local:=FrontierShuttles.context(world,actor);var nav: Dictionary=local.crew.navigation
	if FrontierCrewSurface.landed(local) or not local.crew.members[actor].aboard or actor!=local.crew.pilot_id or nav.mode!="idle" or engagement(world,id):return "교전을 벗어나 선박을 정지한 뒤 회수·정비하세요."
	if absf(float(nav.speed))>20:return "선박 속도를 낮춰 주세요."
	if kind not in ["space_repair","space_salvage"]:return "지원하지 않는 선박 작업입니다."
	var stats:=ship_state(world,id)
	if not stats.get("operation",{}).is_empty():return "현재 회수·정비가 진행 중입니다."
	if kind=="space_repair" and float(nav.get("hull",100))>=100:return "선체가 정상입니다."
	if kind=="space_salvage":
		var found:=false
		for w in r.wrecks:
			if w.id==args.get("id","") and int(w.system)==int(nav.system) and point(nav.position).distance_to(point(w.position))<=float(config().salvage_range):found=true;break
		if not found:return "회수 포드 100m 안에서 정지하세요."
	stats.operation={"kind":kind,"id":str(args.get("id","")),"elapsed":0.0}
	stats.operation_error=""
	return ""
static func complete_operation(world: Dictionary,actor: String,kind: String,wreck_id: String) -> String:
	var r:=record(world);var id:=carrier(world,actor);var local:=FrontierShuttles.context(world,actor);var nav: Dictionary=local.crew.navigation
	if kind=="space_repair":
		if int(world.get("business",{}).get("credits",0))<int(config().repair_cost):return "공동 수리비가 부족합니다. 기초 이동은 계속할 수 있습니다."
		world.business.credits-=int(config().repair_cost);nav.hull=100.0;nav.damage_cooldown=0.0
		commit(world,local,id);emit(r,"salvage",int(nav.system),point(nav.position),point(nav.position),id);return ""
	for i in r.wrecks.size():
		var wreck: Dictionary=r.wrecks[i]
		if wreck.id!=wreck_id:continue
		if int(wreck.system)!=int(nav.system) or point(nav.position).distance_to(point(wreck.position))>float(config().salvage_range):return "회수 범위를 벗어났습니다."
		var cargo: Dictionary=local.crew.get("cargo",{}).duplicate(true)
		for resource in wreck.loot:cargo[resource]=int(cargo.get(resource,0))+int(wreck.loot[resource])
		var counted:=cargo.duplicate();counted.stone=int(local.crew.get("rock",0))
		if FrontierItemInventory.used(counted,local.crew.get("cargo_equipment",{}).size())>int(local.crew.get("cargo_slots",FrontierItemInventory.config().warehouse_slots)):return "화물창 공간이 부족합니다. 포드는 현장에 남습니다."
		local.crew.cargo=cargo;commit(world,local,id);r.wrecks.remove_at(i);emit(r,"salvage",int(nav.system),point(nav.position),point(wreck.position),id);return ""
	return "이미 회수했거나 다른 포드입니다."
static func valid(r: Variant) -> bool:
	if not r is Dictionary or r.get("version")!=1:return false
	for key in ["clock","cooldown","safe_journeys","serial","event_serial"]:
		if not FrontierUniverse._finite(r.get(key),0,9007199254740000):return false
	if not r.get("ships") is Dictionary or r.ships.size()>7 or not r.get("flights") is Dictionary or r.flights.size()>7:return false
	for s in r.ships.values():
		if not s is Dictionary:return false
		for key in ["shield","heat","cooldown","hit_age"]:
			if not FrontierUniverse._finite(s.get(key),0,1e12):return false
		if not s.get("overheated") is bool or not s.get("operation",{}) is Dictionary or not s.get("operation_error","") is String:return false
		var op: Dictionary=s.get("operation",{})
		if not op.is_empty() and (op.get("kind") not in ["space_repair","space_salvage"] or not op.get("id") is String or not FrontierUniverse._finite(op.get("elapsed"),0,100)):return false
	for f in r.flights.values():
		if not f is Dictionary or not f.get("mode") is String or not f.get("route") is String or not FrontierUniverse._vector3_array(f.get("position")):return false
		for key in ["seconds","distance"]:
			if not FrontierUniverse._finite(f.get(key),0,1e12):return false
	var e: Variant=r.get("encounter")
	if not e is Dictionary:return false
	if not e.is_empty():
		if not e.get("id") is String or not e.get("carrier") is String or e.get("variant") not in ["stellar_arrival","local_transit"] or e.get("phase") not in ["warning","combat","recovering","escaped","victory","recovered"]:return false
		if not FrontierExpeditionBusiness.integer(e.get("system"),0,249999) or not FrontierExpeditionBusiness.integer(e.get("target"),0,999999):return false
		for key in ["origin","heading"]:
			if not FrontierUniverse._vector3_array(e.get(key)):return false
		for key in ["warning","elapsed","escape","resume","recovery","salvage"]:
			if not FrontierUniverse._finite(e.get(key),0,1e12):return false
		if e.phase=="recovering" and not FrontierUniverse._vector3_array(e.get("recovery_point")):return false
		if not e.get("enemies") is Array or e.enemies.size()>3:return false
		for enemy in e.enemies:
			if not enemy is Dictionary or not enemy.get("id") is String or not config().enemy.has(enemy.get("kind")):return false
			for key in ["position","direction","aim"]:
				if not FrontierUniverse._vector3_array(enemy.get(key)):return false
			for key in ["hull","shield","cooldown","windup","age","hit_age"]:
				if not FrontierUniverse._finite(enemy.get(key),0,1e12):return false
			if enemy.has("maneuver"):
				if enemy.maneuver not in ["approach","align","strike","break"]:return false
				for key in ["maneuver_age","maneuver_duration","burst","cycle","recoil","throttle"]:
					if not FrontierUniverse._finite(enemy.get(key),0,1e12):return false
				for key in ["roll","side"]:
					if not FrontierUniverse._finite(enemy.get(key),-1,1):return false
				for key in ["velocity","pass_end","break_end"]:
					if enemy.has(key) and not FrontierUniverse._vector3_array(enemy[key]):return false
		if not e.get("projectiles",[]) is Array or e.get("projectiles",[]).size()>int(config().presentation.projectile_limit):return false
		for bolt in e.get("projectiles",[]):
			if not bolt is Dictionary or not bolt.get("id") is String or not bolt.get("owner") is String:return false
			for key in ["position","velocity"]:
				if not FrontierUniverse._vector3_array(bolt.get(key)):return false
			for key in ["life","damage","radius"]:
				if not FrontierUniverse._finite(bolt.get(key),0,1e6):return false
	if not r.get("wrecks") is Array or r.wrecks.size()>int(config().maximum_wrecks) or not r.get("events") is Array or r.events.size()>32:return false
	for w in r.wrecks:
		if not w is Dictionary or not w.get("id") is String or not FrontierExpeditionBusiness.integer(w.get("system"),0,249999) or not FrontierUniverse._vector3_array(w.get("position")) or not config().enemy.has(w.get("kind")) or not w.get("loot") is Dictionary:return false
		for resource in w.loot:
			if FrontierCatalog.entry("resources",resource).is_empty() or not FrontierExpeditionBusiness.integer(w.loot[resource],1,10000):return false
	for event in r.events:
		if not event is Dictionary or not FrontierExpeditionBusiness.integer(event.get("serial"),1,9007199254740000) or not event.get("kind") is String or not event.get("id") is String or not FrontierExpeditionBusiness.integer(event.get("system"),0,249999) or not FrontierUniverse._vector3_array(event.get("origin")) or not FrontierUniverse._vector3_array(event.get("target")):return false
	return true

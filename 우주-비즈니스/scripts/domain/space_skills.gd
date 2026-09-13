class_name FrontierSpaceSkills
extends RefCounted
## Bounded host simulation. Only the active ship, encounter targets and effects change.
const Skills=preload("res://scripts/domain/vessel_skills.gd")
static func targets(e: Dictionary,origin: Vector3,aim: Vector3,reach: float,dot: float,limit: int=5) -> Array:
	var rows: Array=[]
	for enemy in e.get("enemies",[]):
		var offset:=FrontierSpaceCombat.point(enemy.position)-origin
		if float(enemy.hull)>0 and offset.length()<=reach and offset.normalized().dot(aim)>=dot:rows.append(enemy)
	rows.sort_custom(func(a: Dictionary,b: Dictionary):
		var aa: Vector3=FrontierSpaceCombat.point(a.position)-origin;var bb: Vector3=FrontierSpaceCombat.point(b.position)-origin
		return aa.length_squared()<bb.length_squared() if is_equal_approx(aa.normalized().dot(aim),bb.normalized().dot(aim)) else aa.normalized().dot(aim)>bb.normalized().dot(aim))
	return rows.slice(0,limit)
static func visible_targets(world: Dictionary,origin: Vector3,aim: Vector3,id: String) -> Array:
	var vessel: Dictionary=world.get("vessel",{});var e: Dictionary=FrontierSpaceCombat.record(world).encounter
	var possible:=targets(e,origin,aim,Skills.value(vessel,id,"range"),Skills.value(vessel,id,"lock_dot",-1))
	return possible.filter(func(enemy: Dictionary):return clear_target(world,origin,enemy))
static func clear_target(world: Dictionary,origin: Vector3,enemy: Dictionary) -> bool:
	var offset:=FrontierSpaceCombat.point(enemy.position)-origin;var e: Dictionary=FrontierSpaceCombat.record(world).encounter
	return FrontierSpaceCombat.blocked_distance(world,int(e.system),origin,offset.normalized(),offset.length())>=offset.length()-float(FrontierSpaceCombat.config().enemy[enemy.kind].radius)
static func stats(world: Dictionary) -> Dictionary:return FrontierSpaceCombat.record(world).get("ships",{}).get("crew",{})
static func cooldown(world: Dictionary,id: String) -> float:return float(stats(world).get("skill_cooldowns",{}).get(id,0))
static func movement(world: Dictionary) -> Vector2:
	if world.has("local_shuttle") or float(stats(world).get("boost_left",0))<=0:return Vector2.ONE
	var id:=str(stats(world).get("boost_skill","vector_burst"));var v: Dictionary=world.get("vessel",{})
	return Vector2(Skills.value(v,id,"speed_multiplier",1),Skills.value(v,id,"turn_multiplier",1))
static func activate(world: Dictionary,actor: String,slot: int,aim: Vector3) -> bool:
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.get("encounter",{})
	if not FrontierSpaceCombat.same_space(world,actor,e) or e.phase not in ["warning","combat"] or float(e.resume)>0:return false
	if FrontierSpaceCombat.carrier(world,actor)!="crew" or actor!=world.crew.pilot_id or world.crew.navigation.mode!="idle":return false
	var nav: Dictionary=world.crew.navigation;var frame:=FrontierCrewNavigation.orientation(nav)
	if not aim.is_finite() or not is_equal_approx(aim.length(),1.0) or aim.dot(-frame.z)<float(FrontierSpaceCombat.config().aim_dot):return false
	var vessel: Dictionary=world.get("vessel",{});var id:=Skills.slot_skill(vessel,slot);var d:=Skills.definition(id)
	if d.is_empty() or cooldown(world,id)>0:return false
	var ship:=FrontierSpaceCombat.ship_state(world,"crew")
	if not ship.get("charge",{}).is_empty():return false
	var origin:=FrontierSpaceCombat.point(nav.position);var muzzle:=origin+frame*Vector3(0,2.1,-6.8)
	var selected:=visible_targets(world,muzzle,aim,id) if d.kind in ["missile","snare","pulse","mark"] else []
	if selected.is_empty() and d.kind in ["missile","snare","pulse","mark"]:return false
	var amount:=int(Skills.value(vessel,id,"salvo",1))
	if d.kind=="missile":selected=selected.slice(0,int(Skills.value(vessel,id,"targets",1)))
	var projectiles:=amount*(selected.size() if d.kind=="missile" else 1)
	if d.kind in ["missile","spears"] and e.projectiles.size()+projectiles>int(FrontierSpaceCombat.config().presentation.projectile_limit):return false
	if d.kind in ["mine","decoy"] and e.get("deployables",[]).size()+(amount if d.kind=="mine" else 1)>int(Skills.config().maximum_deployables):return false
	if d.kind=="vent" and float(ship.heat)<=.01:return false
	if not ship.has("skill_cooldowns"):ship.skill_cooldowns={}
	ship.skill_cooldowns[id]=float(d.cooldown)
	if slot==0:ship.missile_cooldown=float(d.cooldown)
	var end:=muzzle+aim*Skills.value(vessel,id,"range",40)
	if d.kind=="lance":
		ship.charge={"id":id,"aim":FrontierSpaceCombat.arr(aim),"left":float(d.charge)}
		FrontierSpaceCombat.emit(r,"skill_charge",int(e.system),muzzle,end,id)
		return true
	FrontierSpaceCombat.emit(r,"skill_"+str(d.kind),int(e.system),muzzle,end,id)
	match str(d.kind):
		"missile":
			var cfg: Dictionary=FrontierSpaceCombat.config().missile
			for enemy in selected:
				for i in amount:
					var side: float=-1.0 if e.projectiles.size()%2==0 else 1.0
					var local_muzzle:=FrontierSpaceCombat.point(cfg.muzzle);local_muzzle.x=absf(local_muzzle.x)*side
					var source:=origin+frame*local_muzzle
					var ray: Vector3=(-frame.z+frame.x*side*float(cfg.fan_side)+frame.y*(float(cfg.fan_up)+i*.12)).normalized()
					FrontierSpaceCombat.emit(r,"missile_launch",int(e.system),source,FrontierSpaceCombat.point(enemy.position),"crew")
					e.projectiles.append({"id":str(r.event_serial),"owner":"crew","side":"crew","kind":"missile","target_id":str(enemy.id),"position":FrontierSpaceCombat.arr(source),"velocity":FrontierSpaceCombat.arr(ray*float(cfg.initial_speed)),"life":float(cfg.life),"age":0.0,"damage":Skills.value(vessel,id,"damage"),"radius":float(cfg.radius)})
		"spears":
			for i in amount:
				var ray: Vector3=(aim+frame.x*(float(i)-float(amount-1)*.5)*float(d.spread)).normalized()
				FrontierSpaceCombat.emit(r,"skill_spear_launch",int(e.system),muzzle,muzzle+ray*float(d.range),id)
				e.projectiles.append({"id":str(r.event_serial),"owner":"crew","side":"crew","kind":"pulse","position":FrontierSpaceCombat.arr(muzzle),"velocity":FrontierSpaceCombat.arr(ray*float(d.speed)),"life":float(d.range)/float(d.speed),"age":0.0,"damage":Skills.value(vessel,id,"damage"),"radius":5.0})
		"pulse","mark":
			for enemy in selected:
				FrontierSpaceCombat.damage_enemy(world,enemy,Skills.value(vessel,id,"damage"),muzzle,FrontierSpaceCombat.point(enemy.position))
				if d.kind=="pulse":enemy.slow_left=Skills.value(vessel,id,"duration");enemy.slow_factor=float(d.slow)
				else:enemy.mark_left=Skills.value(vessel,id,"duration");enemy.mark_multiplier=float(d.multiplier)
			if d.has("shield_restore"):ship.shield=minf(Skills.shield_max(world),float(ship.shield)+Skills.value(vessel,id,"shield_restore"))
		"snare":
			ship.snare={"id":id,"target":str(selected[0].id),"left":Skills.value(vessel,id,"duration"),"tick":0.0}
		"boost":
			ship.boost_left=Skills.value(vessel,id,"duration");ship.boost_skill=id
			ship.heat=minf(.99,float(ship.heat)+float(d.heat))
		"barrier":ship.barrier_left=Skills.value(vessel,id,"duration");ship.barrier_capacity=Skills.value(vessel,id,"capacity");ship.barrier_skill=id
		"vent":ship.heat=maxf(0,float(ship.heat)-Skills.value(vessel,id,"cooling"));ship.overheated=false
		"mine","decoy":
			if not e.has("deployables"):e.deployables=[]
			for i in (amount if d.kind=="mine" else 1):
				var at:=origin+frame*Vector3((i-(amount-1)*.5)*24,4,34+i*18)
				FrontierSpaceCombat.emit(r,"skill_deploy",int(e.system),at,at,id)
				e.deployables.append({"id":str(r.event_serial),"skill":id,"kind":str(d.kind),"position":FrontierSpaceCombat.arr(at),"life":Skills.value(vessel,id,"duration"),"age":0.0,"damage":Skills.value(vessel,id,"damage"),"range":Skills.value(vessel,id,"range")})
	return true
static func lance(world: Dictionary,id: String,aim: Vector3) -> void:
	var r:=FrontierSpaceCombat.record(world);var e: Dictionary=r.encounter
	var nav: Dictionary=world.crew.navigation;var v: Dictionary=world.get("vessel",{})
	var origin:=FrontierSpaceCombat.point(nav.position)+FrontierCrewNavigation.orientation(nav)*Vector3(0,2.1,-6.8)
	var reach:=FrontierSpaceCombat.blocked_distance(world,int(e.system),origin,aim,Skills.value(v,id,"range"))
	var hits: Array=[]
	for enemy in e.enemies:
		if float(enemy.hull)<=0:continue
		var offset:=FrontierSpaceCombat.point(enemy.position)-origin;var along:=offset.dot(aim)
		var radius:=float(FrontierSpaceCombat.config().enemy[enemy.kind].radius)+Skills.value(v,id,"width")
		if along>0 and along<reach and (offset-aim*along).length()<=radius:hits.append(enemy)
	hits.sort_custom(func(a: Dictionary,b: Dictionary):return origin.distance_squared_to(FrontierSpaceCombat.point(a.position))<origin.distance_squared_to(FrontierSpaceCombat.point(b.position)))
	for enemy in hits.slice(0,int(Skills.value(v,id,"targets",1))):FrontierSpaceCombat.damage_enemy(world,enemy,Skills.value(v,id,"damage"),origin,FrontierSpaceCombat.point(enemy.position))
	FrontierSpaceCombat.emit(r,"skill_lance",int(e.system),origin,origin+aim*reach,id)
static func tick_ship(world: Dictionary,delta: float) -> void:
	var ship:=stats(world)
	if ship.is_empty():return
	for id in ship.get("skill_cooldowns",{}):ship.skill_cooldowns[id]=maxf(0,float(ship.skill_cooldowns[id])-delta)
	for key in ["boost_left","barrier_left","bulwark_left","passive_cooldown","cooling_left"]:ship[key]=maxf(0,float(ship.get(key,0))-delta)
	var nav: Dictionary=world.crew.navigation;var v: Dictionary=world.get("vessel",{});var p:=Skills.passive(v)
	if FrontierSpaceStation.hull(v).get("passive")=="cooling":
		var held:=float(ship.get("boost_held",0))
		if nav.get("boosting",false):ship.boost_held=minf(20,held+delta)
		else:
			if held>=float(p.boost_seconds) and float(ship.passive_cooldown)<=0:
				ship.cooling_left=float(p.duration);ship.passive_cooldown=float(p.cooldown)
			ship.boost_held=0.0
		if float(ship.cooling_left)>0:ship.heat=maxf(0,float(ship.heat)-float(FrontierSpaceCombat.config().heat_cooling)*(float(p.multiplier)-1)*delta)
	var e: Dictionary=FrontierSpaceCombat.record(world).get("encounter",{})
	if e.is_empty() or e.get("carrier")!="crew" or e.get("phase") not in ["warning","combat"] or nav.mode!="idle":
		ship.charge={};ship.snare={};ship.boost_left=0.0;ship.barrier_left=0.0;return
	if float(e.resume)>0:return
	var charge: Dictionary=ship.get("charge",{})
	if not charge.is_empty():
		charge.left=maxf(0,float(charge.left)-delta)
		if charge.left<=0:
			ship.charge={}
			var aim:=FrontierSpaceCombat.point(charge.aim)
			if aim.dot(FrontierSpaceCombat.point(nav.direction))>=float(FrontierSpaceCombat.config().aim_dot):lance(world,str(charge.id),aim)
	for enemy in e.enemies:
		for key in ["slow_left","mark_left"]:enemy[key]=maxf(0,float(enemy.get(key,0))-delta)
	var snare: Dictionary=ship.get("snare",{})
	if not snare.is_empty():
		snare.left=maxf(0,float(snare.left)-delta);snare.tick+=delta
		var valid:=false;var origin:=FrontierSpaceCombat.point(nav.position)
		for enemy in e.enemies:
			if enemy.id!=snare.target or float(enemy.hull)<=0 or origin.distance_to(FrontierSpaceCombat.point(enemy.position))>Skills.value(v,snare.id,"range") or not clear_target(world,origin,enemy):continue
			valid=true;enemy.slow_left=.65;enemy.slow_factor=Skills.value(v,snare.id,"slow")
			if float(snare.tick)>=.5:
				FrontierSpaceCombat.damage_enemy(world,enemy,Skills.value(v,snare.id,"damage")*.5,origin,FrontierSpaceCombat.point(enemy.position),true)
				FrontierSpaceCombat.emit(FrontierSpaceCombat.record(world),"skill_tether",int(e.system),origin,FrontierSpaceCombat.point(enemy.position),snare.id);snare.tick=0.0
		if not valid or snare.left<=0:ship.snare={}
	for item in e.get("deployables",[]).duplicate():
		item.age+=delta;item.life=maxf(0,float(item.life)-delta)
		if item.kind=="mine" and float(item.age)>=Skills.value(v,item.skill,"arm_seconds"):
			var at:=FrontierSpaceCombat.point(item.position);var hit:=false
			for enemy in e.enemies:
				if float(enemy.hull)>0 and at.distance_to(FrontierSpaceCombat.point(enemy.position))<=float(item.range) and clear_target(world,at,enemy):
					FrontierSpaceCombat.damage_enemy(world,enemy,float(item.damage),at,FrontierSpaceCombat.point(enemy.position));hit=true
			if hit:FrontierSpaceCombat.emit(FrontierSpaceCombat.record(world),"missile_blast",int(e.system),at+Vector3.UP,at,item.id);item.life=0.0
		if item.life<=0:e.deployables.erase(item)
static func decoy_target(world: Dictionary,enemy_position: Vector3,fallback: Vector3) -> Vector3:
	for item in FrontierSpaceCombat.record(world).get("encounter",{}).get("deployables",[]):
		if item.kind=="decoy" and float(item.life)>0 and enemy_position.distance_to(FrontierSpaceCombat.point(item.position))<=float(item.range):return FrontierSpaceCombat.point(item.position)
	return fallback
static func absorb(world: Dictionary,amount: float,source: Vector3) -> float:
	var ship:=stats(world);var nav: Dictionary=world.crew.navigation
	if float(ship.get("barrier_left",0))>0 and float(ship.get("barrier_capacity",0))>0 and source.is_finite():
		var toward: Vector3=(source-FrontierSpaceCombat.point(nav.position)).normalized()
		var id:=str(ship.get("barrier_skill","forward_barrier"))
		if toward.dot(FrontierSpaceCombat.point(nav.direction))>=Skills.value(world.get("vessel",{}),id,"dot",.3):
			var absorbed:=minf(float(ship.barrier_capacity),amount);ship.barrier_capacity-=absorbed;amount-=absorbed
			if ship.barrier_capacity<=0:ship.barrier_left=0.0
	if float(ship.get("bulwark_left",0))>0:amount*=float(Skills.config().passives.bulwark.damage_multiplier)
	return amount
static func on_break(world: Dictionary) -> void:
	var v: Dictionary=world.get("vessel",{});var ship:=stats(world)
	if FrontierSpaceStation.hull(v).get("passive")!="bulwark" or float(ship.get("passive_cooldown",0))>0:return
	var p:=Skills.passive(v);ship.bulwark_left=float(p.duration);ship.passive_cooldown=float(p.cooldown)
static func valid_ship(s: Dictionary) -> bool:
	for key in ["boost_left","barrier_left","barrier_capacity","bulwark_left","passive_cooldown","cooling_left","boost_held"]:
		if not FrontierUniverse._finite(s.get(key,0),0,1000):return false
	for key in ["boost_skill","barrier_skill"]:
		if s.has(key) and (not s[key] is String or Skills.definition(s[key]).is_empty()):return false
	var cds: Variant=s.get("skill_cooldowns",{})
	if not cds is Dictionary or cds.size()>Skills.definitions().size():return false
	for id in cds:
		if not id is String or Skills.definition(id).is_empty() or not FrontierUniverse._finite(cds[id],0,100):return false
	for key in ["charge","snare"]:
		var effect: Variant=s.get(key,{})
		if not effect is Dictionary:return false
		if effect.is_empty():continue
		if not effect.get("id") is String or Skills.definition(effect.id).is_empty() or not FrontierUniverse._finite(effect.get("left"),0,100):return false
		if key=="charge" and not FrontierUniverse._vector3_array(effect.get("aim")):return false
		if key=="snare" and (not effect.get("target") is String or not FrontierUniverse._finite(effect.get("tick"),0,100)):return false
	return true
static func valid_encounter(e: Dictionary) -> bool:
	for enemy in e.get("enemies",[]):
		for key in ["slow_left","mark_left","slow_factor","mark_multiplier"]:
			if not FrontierUniverse._finite(enemy.get(key,0),0,100):return false
	var deployed: Variant=e.get("deployables",[])
	if not deployed is Array or deployed.size()>int(Skills.config().maximum_deployables):return false
	for item in deployed:
		if not item is Dictionary or not item.get("id") is String or not item.get("skill") is String or Skills.definition(item.skill).is_empty() or item.get("kind") not in ["mine","decoy"] or not FrontierUniverse._vector3_array(item.get("position")):return false
		for key in ["life","age","damage","range"]:
			if not FrontierUniverse._finite(item.get(key),0,10000):return false
	return true

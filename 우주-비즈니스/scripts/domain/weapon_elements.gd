class_name FrontierWeaponElements
extends RefCounted
## Bounded host status records. Secondary damage never starts another proc chain.
static func element(tool: Dictionary) -> Dictionary:
	return FrontierWeaponLoot.config().elements.get(tool.get("element_id","kinetic"),FrontierWeaponLoot.config().elements.kinetic)
static func health_factor(hit: Dictionary,tool: Dictionary) -> float:
	if tool.get("secondary",false):return 1.
	var spec:=element(tool)
	var resistance:=clampf(float(hit.get("resistances",{}).get(tool.get("element_id","kinetic"),0)),-.25,.5)
	return float(spec.armor if hit.kind=="robot" else spec.health)*(1.-resistance)
static func split(hit: Dictionary,tool: Dictionary,shield: float,damage: float) -> Dictionary:
	var factor:=float(tool.get("shield_multiplier",1))
	if not tool.get("secondary",false):factor=minf(float(FrontierWeaponLoot.config().shield_cap),factor+float(element(tool).shield)-1.)
	var result:=FrontierCrewVitals.split_shield_damage(shield,damage,maxf(.1,factor))
	result.health*=health_factor(hit,tool)
	return result
static func slow(crew: Dictionary,key: String) -> float:
	var result:=1.
	for effect in crew.get("weapon_statuses",{}).get(key,{}).get("effects",{}).values():
		if effect.element=="cryo" and float(effect.left)>0:result=minf(result,1.-float(effect.power))
	return result
static func own_effect(world: Dictionary,actor: String,hit: Dictionary,type: String) -> Dictionary:
	return world.crew.get("weapon_statuses",{}).get(str(hit.kind)+":"+str(hit.id),{}).get("effects",{}).get(actor+":"+type,{})
static func _record(world: Dictionary,hit: Dictionary) -> Dictionary:
	if not world.crew.has("weapon_statuses"):world.crew.weapon_statuses={}
	var records: Dictionary=world.crew.weapon_statuses;var key:=str(hit.kind)+":"+str(hit.id)
	if not records.has(key):
		if records.size()>=int(FrontierWeaponLoot.config().max_statuses):return {}
		var animal: Dictionary={}
		if hit.kind=="animal":
			for field in ["id","form_id","look_id","layer","introduced","yaw","behavior_yaw","combat_tier"]:
				if hit.row.has(field):animal[field]=hit.row[field]
			animal.point=FrontierExpeditionBusiness.array(hit.row.point);animal.home_point=FrontierExpeditionBusiness.array(hit.row.get("home_point",hit.row.point))
		records[key]={"body_id":world.location,"kind":hit.kind,"id":hit.id,"point":FrontierExpeditionBusiness.array(hit.point),"animal":animal,"effects":{},"credit":0.}
	return records[key]
static func after_hit(world: Dictionary,actor: String,hit: Dictionary,amount: float,tool: Dictionary,outcome: Dictionary) -> void:
	if tool.get("secondary",false) or hit.kind not in ["robot","animal"] or float(outcome.damage)+float(outcome.shield)<=0:return
	var type:=str(tool.get("element_id","kinetic"))
	var state: Dictionary=world.crew.members[actor].loadout.get("weapon_states",{}).get(tool.get("item_id",""),{})
	var special:=str(tool.get("legendary_id",""))
	if not special.is_empty() and not state.is_empty() and float(state.get("legend_wait",0))<=0:
		var shot:=str(tool.get("shot_key",""));var target:=str(hit.id)
		if special=="ember":outcome.special=outcome.killed and float(own_effect(world,actor,hit,"thermal").get("left",0))>0 and not own_effect(world,actor,hit,"thermal").get("propagated",false)
		elif special=="pierce":outcome.special=bool(outcome.weak)
		elif special=="arc":
			if state.get("arc_target","")!=target or float(state.get("arc_left",0))<=0:state.arc_count=0;state.arc_target=target
			if state.get("arc_shot","")!=shot:
				state.arc_count=int(state.get("arc_count",0))+1;state.arc_shot=shot;state.arc_left=2.
				if state.arc_count>=3:outcome.special=true;state.arc_count=0
		elif special=="shatter":
			var identity:=shot+":"+target
			if state.get("shatter_shot","")!=identity:state.shatter_shot=identity;state.shatter_count=0
			state.shatter_count+=1
			outcome.special=int(state.shatter_count)>=4 and float(own_effect(world,actor,hit,"cryo").get("left",0))>0
	if type not in ["thermal","cryo"] or float(outcome.damage)<=0 or outcome.killed:return
	var record:=_record(world,hit)
	if record.is_empty():return
	var key:=actor+":"+type
	if not record.effects.has(key):record.effects[key]={"owner":actor,"element":type,"buildup":0.,"left":0.,"power":0.,"idle":0.,"family":tool.firearm,"item_id":tool.item_id}
	var effect: Dictionary=record.effects[key]
	var share:=clampf(float(outcome.damage)/maxf(.001,amount*health_factor(hit,tool)),0,1)
	var budget:=minf(float(FrontierWeaponLoot.config().buildup_cap),float(tool.interval))/maxf(1,float(tool.pellets))*float(tool.get("buildup",1.))*share
	if tool.get("splash_secondary",false):budget*=float(tool.get("splash_factor",.6))
	effect.buildup+=budget;effect.idle=0.
	if effect.buildup<float(FrontierWeaponLoot.config().buildup_threshold):return
	effect.buildup=0.
	var power:=FrontierWeaponLoot.dps(tool)*float(FrontierWeaponLoot.config().thermal_dps_factor) if type=="thermal" else float(element(tool).slow)*(.5 if hit.kind=="robot" else 1.)
	# A weaker new weapon cannot perpetually extend an older stronger burn.
	if effect.left<=0 or power>=float(effect.power):
		effect.left=float(element(tool).duration)*float(tool.get("duration",1.));effect.power=power;effect.family=tool.firearm;effect.item_id=tool.item_id;effect.propagated=false
	outcome.status_started=type
	if hit.kind=="robot":world.incidents.records[hit.id].element_slow=slow(world.crew,"robot:"+str(hit.id))
static func _hit(record: Dictionary,world: Dictionary) -> Dictionary:
	var point:=FrontierCrewWorld.vector(record.point)
	var hit: Dictionary={"kind":record.kind,"id":record.id,"point":point,"weak":false,"zone":"body","anchor":point+Vector3.UP*.5}
	if record.kind=="animal":
		var animal: Dictionary=record.animal.duplicate()
		animal.point=FrontierCrewWorld.vector(animal.point);animal.home_point=FrontierCrewWorld.vector(animal.home_point)
		var live: Dictionary=world.crew.get("wildlife_encounters",{}).get(record.id,{})
		if not live.is_empty():animal.point=FrontierWildlifeCombat.body_position(live);hit.point=animal.point;hit.anchor=animal.point+Vector3.UP*.7
		hit.row=animal
	else:
		var row: Dictionary=world.incidents.records.get(record.id,{})
		if not row.is_empty():hit.point=FrontierCrewWorld.vector(row.position)+Vector3.UP;hit.anchor=hit.point+Vector3.UP
	return hit
static func tick(world: Dictionary,delta: float,present: Array) -> Dictionary:
	var events: Array=[];var changed:=false;var locals: Dictionary={}
	for actor in present:
		var member: Dictionary=world.crew.members.get(actor,{})
		if member.get("area")!="surface" or member.get("aboard",true):continue
		var local:=FrontierShuttles.context(world,actor)
		locals[local.location]=actor
	var records: Dictionary=world.crew.get("weapon_statuses",{})
	for key in records.keys():
		var record: Dictionary=records[key]
		if not locals.has(record.body_id):continue
		var local:=FrontierShuttles.context(world,locals[record.body_id]);var strongest: Dictionary={};var power:=0.
		var hit:=_hit(record,local)
		if (record.kind=="robot" and float(local.incidents.records.get(record.id,{}).get("hp",0))<=0) or (record.kind=="animal" and int(local.crew.get("combat",{}).get(record.id,1))<=0):
			records.erase(key);changed=true;continue
		for id in record.effects.keys():
			var effect: Dictionary=record.effects[id]
			if not world.crew.members.has(effect.owner):record.effects.erase(id);changed=true;continue
			var duration:=minf(delta,float(effect.left))
			if effect.element=="thermal" and duration>0 and float(effect.power)*duration>power:strongest=effect;power=float(effect.power)*duration
			effect.left=maxf(0,float(effect.left)-delta);effect.idle=minf(60.,float(effect.idle)+delta)
			if effect.idle>1.:effect.buildup=maxf(0,float(effect.buildup)-delta*float(FrontierWeaponLoot.config().buildup_decay))
			if effect.left<=0 and effect.buildup<=0:record.effects.erase(id)
			changed=true
		if not strongest.is_empty():
			record.credit+=power
			var amount:=floorf(record.credit);record.credit-=amount
			if amount>0:
				# Shuttle contexts contain their pilot only; damage attribution uses the
				# actual world owner without moving that player's location.
				local=local.duplicate();local.crew=local.crew.duplicate();local.crew.members=world.crew.members
				var tool: Dictionary={"secondary":true,"element_id":"thermal","weak":1.,"shield_multiplier":1.}
				var outcome:=FrontierFirearms._damage(local,strongest.owner,hit,amount,tool,false)
				var targets: Dictionary={};FrontierFirearms._record_damage(targets,hit,outcome)
				events.append({"actor":strongest.owner,"body_id":record.body_id,"family":strongest.family,"element_id":"thermal","effect":"status","impact_only":true,"status_only":true,"item_id":strongest.item_id,"serial":0,"contacts":[{"point":FrontierExpeditionBusiness.array(hit.point),"normal":[0,1,0],"kind":"organic" if hit.kind=="animal" else "armor","element_id":"thermal"}],"damage_targets":targets.values(),"hits":outcome,"rays":[]})
				FrontierShuttles.commit(world,local,locals[record.body_id])
		if record.kind=="robot" and local.incidents.records.has(record.id):local.incidents.records[record.id].element_slow=slow(world.crew,key)
		if record.effects.is_empty():records.erase(key)
	return {"changed":changed,"events":events}
static func followup(world: Dictionary,actor: String,tool: Dictionary,hit: Dictionary,outcome: Dictionary,rows: Array,direction: Vector3,obstacle: Callable) -> Array:
	var results: Array=[]
	if not outcome.get("special",false) or tool.get("secondary",false):return results
	var id:=str(tool.get("legendary_id",""));var spec: Dictionary=FrontierWeaponLoot.config().legendaries[id]
	var origin: Vector3=hit.point
	var state: Dictionary=world.crew.members[actor].loadout.weapon_states[tool.item_id]
	var targets: Array=[]
	if id=="shatter":
		if origin.distance_to(FrontierCrewWorld.vector(tool.get("shot_origin",[0,0,0])))>float(spec.radius):return results
		targets.append(hit);own_effect(world,actor,hit,"cryo").left=0.
	elif id=="pierce":
		var candidates: Array=rows.filter(func(row):return row.id!=hit.id and row.kind in ["animal","robot"])
		var next:=FrontierFirearms.Targets.intersect(candidates,origin+direction*.02,direction,float(spec.radius))
		if not next.is_empty():targets.append(next)
	else:
		var visited: Dictionary={str(hit.id):true}
		for row in rows:
			if visited.has(str(row.id)) or row.kind not in ["animal","robot"]:continue
			visited[str(row.id)]=true
			var point: Vector3=row.transform*row.bounds.get_center()
			if point.distance_to(origin)>float(spec.radius):continue
			var candidate: Dictionary=row.duplicate();candidate.point=point;candidate.weak=false;candidate.zone="body";targets.append(candidate)
		targets.sort_custom(func(a,b):return a.point.distance_squared_to(origin)<b.point.distance_squared_to(origin))
	var secondary:=tool.duplicate();secondary.secondary=true;secondary.shield_multiplier=1.;secondary.weak=1.
	for target in targets:
		if target.kind=="robot" and float(world.incidents.records.get(target.id,{}).get("hp",0))<=0:continue
		if target.kind=="animal" and int(world.crew.get("combat",{}).get(target.id,1))<=0:continue
		var delta: Vector3=target.point-origin;var length:=delta.length()
		if length>.05:
			var start:=origin+delta.normalized()*.03
			if not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),start,target.point):continue
			if not FrontierCombatCover.intercept(world,world.location,start,delta.normalized(),length).is_empty():continue
			if obstacle.is_valid() and float(obstacle.call(actor,start,delta.normalized(),length))<length-.05:continue
		if id=="ember":
			var source:=own_effect(world,actor,hit,"thermal");var record:=_record(world,target)
			if record.is_empty() or source.is_empty():continue
			var effect:=source.duplicate();effect.left=minf(1.5,float(effect.left));effect.buildup=0.;effect.idle=0.;effect.propagated=true
			var old: Dictionary=record.effects.get(actor+":thermal",{})
			if old.is_empty() or old.left<=0 or old.power<=effect.power:record.effects[actor+":thermal"]=effect
			results.append({"hit":target,"outcome":{"damage":0.,"shield":0.,"broken":false,"weak":false,"killed":false}})
		else:
			var neutral: Dictionary=target.duplicate();neutral.weak=false;neutral.zone="body"
			results.append({"hit":neutral,"outcome":FrontierFirearms._damage(world,actor,neutral,float(tool.damage)*float(spec.factor),secondary,false)})
		if results.size()>=(2 if id=="arc" else 1):break
	if not results.is_empty():state.legend_wait=float(spec.cooldown)
	return results
static func valid(crew: Dictionary) -> bool:
	var records: Variant=crew.get("weapon_statuses",{})
	if not records is Dictionary or records.size()>int(FrontierWeaponLoot.config().max_statuses):return false
	for key in records:
		var record: Variant=records[key]
		if not record is Dictionary or record.get("kind","") not in ["robot","animal"]:return false
		if not record.get("body_id") is String or not record.get("id") is String or key!=str(record.kind)+":"+str(record.id):return false
		if not FrontierUniverse._vector3_array(record.get("point")) or not FrontierUniverse._finite(record.get("credit"),0,1):return false
		if not record.get("effects") is Dictionary or record.effects.size()>12:return false
		if record.kind=="animal":
			var row: Variant=record.get("animal")
			if not row is Dictionary or FrontierEcologyCatalog.form(str(row.get("form_id",""))).is_empty():return false
			if not FrontierUniverse._vector3_array(row.get("point")) or not FrontierUniverse._vector3_array(row.get("home_point")):return false
		for effect in record.effects.values():
			if not effect is Dictionary or effect.get("element","") not in ["thermal","cryo"]:return false
			if not effect.get("owner") is String or not effect.get("item_id") is String or not FrontierFirearms.config().families.has(effect.get("family","")):return false
			for field in ["left","power","buildup","idle"]:
				if not FrontierUniverse._finite(effect.get(field),0,100000):return false
	return true

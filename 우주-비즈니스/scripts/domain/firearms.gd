class_name FrontierFirearms
extends RefCounted
## Host-owned weapon instances and finite ammunition; visual effects consume shot outcomes.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/firearms.json"))
	return _config
static func item(member: Dictionary,id: String) -> Dictionary:
	var data:=FrontierEquipment.state(member)
	var result: Dictionary=FrontierEquipment.config().items.get(data.items.get(id,""),{}).duplicate(true)
	if not result.has("firearm"):return result
	var family: Dictionary=config().families[result.firearm]
	for key in family:
		if key not in ["name","damage","interval"]:result[key]=family[key]
	var roll: Dictionary=data.get("weapon_rolls",{}).get(id,{"rarity":"standard"})
	result.rarity=roll.get("rarity","standard")
	var rarity: Dictionary=config().rarities[result.rarity]
	result.damage=roundi(float(result.damage)*float(rarity.damage))
	result.reload=float(result.reload)*float(rarity.reload)
	result.item_id=id
	return result
static func ensure(member: Dictionary,tool: Dictionary) -> Dictionary:
	var data: Dictionary=member.loadout
	if not data.has("weapon_states"):data.weapon_states={}
	var id: String=tool.item_id
	if not data.weapon_states.has(id):data.weapon_states[id]={"ammo":int(tool.magazine),"reload_left":0.0,"cooldown":0.0,"idle":10.0,"streak":0,"weak_streak":0,"breach":false}
	var state: Dictionary=data.weapon_states[id]
	state.ammo=mini(int(state.ammo),int(tool.magazine))
	return state
static func tick(member: Dictionary,delta: float) -> void:
	var data: Dictionary=member.get("loadout",{})
	for id in data.get("weapon_states",{}):
		var s: Dictionary=data.weapon_states[id]
		s.cooldown=maxf(0,float(s.cooldown)-delta);s.idle=minf(60,float(s.idle)+delta)
		if s.idle>1:s.streak=0
		if s.reload_left>0:
			s.reload_left=maxf(0,float(s.reload_left)-delta)
			if s.reload_left==0 and data.items.has(id):s.ammo=int(item(member,id).get("magazine",0));s.breach=false
static func begin_reload(member: Dictionary,tool: Dictionary) -> Dictionary:
	if not member.loadout.get("weapon_states",{}).has(tool.item_id) and member.loadout.get("weapon_states",{}).size()>=int(config().max_states):return {"ok":false,"error":"총기 상태 보관 한도입니다."}
	var s:=ensure(member,tool)
	if s.reload_left>0 or s.ammo>=int(tool.magazine):return {"ok":false,"code":"weapon_busy"}
	s.reload_left=float(tool.reload)*(.58 if s.breach and tool.effect=="breach_reload" else 1.0)
	s.streak=0
	return {"ok":true,"reload":true,"duration":s.reload_left,"weapon":s.duplicate(true)}
static func validate(data: Dictionary) -> String:
	for field in ["weapon_states","weapon_rolls"]:
		var records: Variant=data.get(field,{})
		if not records is Dictionary or records.size()>int(config().max_states):return "총기 개체 한도"
		for id in records:
			if not id is String or id.length()>160 or not records[id] is Dictionary:return "총기 개체 기록"
			var row: Dictionary=records[id]
			if field=="weapon_rolls":
				if not config().rarities.has(row.get("rarity","")):return "총기 희귀도"
			else:
				for key in ["ammo","reload_left","cooldown","idle","streak","weak_streak"]:
					if not FrontierUniverse._finite(row.get(key),0,10000):return "총기 탄창 상태"
				if row.ammo!=floorf(row.ammo) or not row.get("breach") is bool:return "총기 탄창 형식"
	if not data.get("crouched",false) is bool:return "낮은 자세 형식"
	return ""
static func eye(member: Dictionary) -> float:return 1.15 if member.get("loadout",{}).get("crouched",false) else 1.72
static func loot(seed_value: int,row: Dictionary) -> Dictionary:
	if row.get("gun_claimed",false):return {}
	var seed:=FrontierUniverse.derive(seed_value,FrontierExplorationIncidents.key(row)+":firearm-v1")
	var rng:=RandomNumberGenerator.new();rng.seed=seed
	if rng.randf()>float(config().drop_chance):return {}
	var tier:=clampi(int(row.tier),1,3);var candidates: Array=[]
	for id in FrontierEquipment.config().items:
		var definition: Dictionary=FrontierEquipment.config().items[id]
		if definition.has("firearm") and int(definition.tier)==tier:candidates.append(id)
	if candidates.is_empty():return {}
	var definition: String=candidates[rng.randi_range(0,candidates.size()-1)]
	var roll:=rng.randi_range(0,99);var rarity: String="standard";var keys: Array=config().rarities.keys()
	for i in keys.size():
		roll-=int(config().drop_weights[str(tier)][i])
		if roll<0:rarity=keys[i];break
	return {"definition":definition,"rarity":rarity}
static func drop(world: Dictionary,actor: String,row: Dictionary) -> String:
	var reward:=loot(int(world.manifest.seed),row)
	if reward.is_empty():return ""
	var member: Dictionary=world.crew.members[actor]
	if member.loadout.get("weapon_rolls",{}).size()>=int(config().max_states):return "총기 보관 한도입니다. 전리품은 현장에 남습니다."
	if FrontierItemInventory.used(FrontierExpeditionBusiness.bag(world,actor),member.loadout.items.size()+1)>FrontierItemInventory.capacity(member):return "총기를 넣을 배낭 공간이 필요합니다. 전리품은 현장에 남습니다."
	member.loadout.counter+=1
	var item_id: String="crafted:"+str(int(member.loadout.counter))
	member.loadout.items[item_id]=reward.definition
	if not member.loadout.has("weapon_rolls"):member.loadout.weapon_rolls={}
	member.loadout.weapon_rolls[item_id]={"rarity":reward.rarity,"source":row.id}
	row.gun_claimed=true;row.gun_drop=reward.duplicate();row.gun_drop.item_id=item_id;row.gun_drop.owner=actor
	return ""
static func fire(world: Dictionary,actor: String,args: Dictionary,obstacle: Callable=Callable()) -> Dictionary:
	var member: Dictionary=world.crew.members[actor]
	var tool:=FrontierEquipment.active(member)
	if not tool.has("firearm"):return {"ok":false,"error":"총기를 장착하세요."}
	if args.get("item_id")!=tool.item_id:return {"ok":false,"code":"weapon_changed"}
	var aim:=FrontierCrewSurface.direction(args.get("aim"))
	if aim==Vector3.ZERO or not args.get("ads",false) is bool:return {"ok":false,"error":"조준 방향 오류"}
	if not member.loadout.get("weapon_states",{}).has(tool.item_id) and member.loadout.get("weapon_states",{}).size()>=int(config().max_states):return {"ok":false,"error":"총기 상태 보관 한도입니다."}
	var s:=ensure(member,tool)
	if s.cooldown>.001 or s.reload_left>0:return {"ok":false,"code":"weapon_busy","weapon":s.duplicate(true)}
	if s.ammo<=0:return begin_reload(member,tool)
	var origin:=FrontierCrewWorld.vector(member.position)+Vector3.UP*eye(member)
	var terrain:=FrontierCrewSurface.field(world)
	if terrain.density(origin)>0:return {"ok":false,"error":"막힌 공간에서는 발사할 수 없습니다."}
	var ads: bool=args.get("ads",false)
	var lateral:=aim.cross(Vector3.UP).normalized();var clearance: Dictionary=config().muzzle_clearance
	var muzzle_offset:=aim*float(clearance.forward)+lateral*float(clearance.side)*(0.0 if ads else 1.0)-Vector3.UP*float(clearance.drop)
	if not FrontierCrewSurface.visible_in_field(terrain,origin,origin+muzzle_offset) or (obstacle.is_valid() and float(obstacle.call(actor,origin,muzzle_offset.normalized(),muzzle_offset.length()))<muzzle_offset.length()-.03):
		return {"ok":false,"code":"muzzle_blocked","error":"총구 앞의 공간을 확보하세요."}
	var spread:=float(tool.ads_spread if ads else tool.spread)
	var multiplier:=1.0
	match tool.effect:
		"steady":spread*=lerpf(1,.42,clampf(float(s.streak)/9,0,1))
		"first_strike":
			if s.idle>=.9:multiplier=1.3
		"braced":
			if member.loadout.get("crouched",false):spread*=.4
		"weak_chain":
			if int(s.weak_streak)>=2:multiplier=1.4
	var rays: Array=[];var totals: Dictionary={"damage":0.0,"shield":0.0,"broken":false,"weak":false,"killed":false,"organic":false}
	var side:=aim.cross(Vector3.UP).normalized()
	if side.length_squared()<.5:side=Vector3.RIGHT
	var up:=side.cross(aim).normalized()
	var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(world.manifest.seed),actor+":"+str(args.get("serial",0)))
	for i in int(tool.pellets):
		var angle:=rng.randf()*TAU;var radius:=sqrt(rng.randf())*spread
		var direction: Vector3=(aim+side*cos(angle)*radius+up*sin(angle)*radius).normalized()
		var reach:=float(tool.range)
		if obstacle.is_valid():reach=minf(reach,float(obstacle.call(actor,origin,direction,reach)))
		var hit:=_target(world,actor,origin,direction,reach)
		var point: Vector3=origin+direction*reach
		if not hit.is_empty():
			point=hit.point
			if hit.kind=="animal":totals.organic=true
			var damage:=float(tool.damage)*multiplier*lerpf(1.0,.55,clampf((origin.distance_to(point)-float(tool.range)*.5)/(float(tool.range)*.5),0,1))
			var outcome:=_damage(world,actor,hit,damage,tool,ads)
			for key in ["damage","shield"]:totals[key]+=float(outcome.get(key,0))
			for key in ["broken","weak","killed"]:totals[key]=totals[key] or outcome.get(key,false)
		if tool.effect=="splash":
			for row in FrontierExplorationIncidents.records(world).values():
				if row.body_id!=world.location or row.hp<=0 or FrontierExplorationIncidents.definition(row.template).mode!="robot":continue
				var center:=FrontierExplorationIncidents.point(row,Vector3(0,1.5,0));var gap:=center.distance_to(point)
				if gap>=float(tool.blast_radius) or hit.get("id","")==FrontierExplorationIncidents.key(row):continue
				if not FrontierCrewSurface.visible_in_field(terrain,point-direction*.1,center):continue
				if obstacle.is_valid() and float(obstacle.call(actor,point-direction*.15,(center-point).normalized(),gap))<gap-.8:continue
				var splash:=_damage(world,actor,{"kind":"robot","id":FrontierExplorationIncidents.key(row),"weak":false},float(tool.damage)*.6*(1-gap/float(tool.blast_radius)),tool,false)
				totals.damage+=float(splash.damage);totals.shield+=float(splash.shield);totals.broken=totals.broken or splash.broken;totals.killed=totals.killed or splash.killed
		rays.append([point.x,point.y,point.z])
	s.ammo-=1;s.cooldown=maxf(.06,float(tool.interval));s.idle=0.0;s.streak+=1
	s.weak_streak=(int(s.weak_streak)+1)%3 if totals.weak else 0
	if totals.broken:s.breach=true
	FrontierSuitModules.enter_combat(member)
	return {"ok":true,"weapon":s.duplicate(true),"hits":totals,"rays":rays,"origin":[origin.x,origin.y,origin.z],"family":tool.firearm,"effect":tool.effect,"serial":args.get("serial",0),"item_id":tool.item_id}
static func _target(world: Dictionary,actor: String,origin: Vector3,aim: Vector3,reach: float) -> Dictionary:
	var result: Dictionary={};var best:=reach+.001
	for row in FrontierExplorationIncidents.records(world).values():
		if row.body_id!=world.location or row.claimed:continue
		var mode: String=FrontierExplorationIncidents.definition(row.template).mode
		if (mode=="robot" and row.hp<=0) or (mode=="drone" and row.open) or mode not in ["robot","drone"]:continue
		var center:=FrontierExplorationIncidents.point(row,Vector3(0,1.5,0)) if mode=="robot" else FrontierExplorationIncidents.moving_point(row)
		var delta:=center-origin;var along:=delta.dot(aim);var radius:=.85 if mode=="robot" else .55
		var cross_sq: float=(delta-aim*along).length_squared()
		if along<=0 or cross_sq>radius*radius:continue
		var distance:=maxf(0,along-sqrt(radius*radius-cross_sq))
		if distance>best or not FrontierCrewSurface.visible_in_field(FrontierCrewSurface.field(world),origin,origin+aim*distance):continue
		var core_delta:=FrontierExplorationIncidents.point(row,Vector3(0,1.98,.52))-origin
		result={"kind":mode,"id":FrontierExplorationIncidents.key(row),"point":origin+aim*distance,"weak":mode=="robot" and row.phase=="cooling" and (core_delta-aim*core_delta.dot(aim)).length()<.4};best=distance
	var life:=FrontierCrewSurface.target(world,actor,aim,[],reach,origin)
	if not life.is_empty() and FrontierEcologyCatalog.form(life.form_id).category=="animal":
		var distance:=origin.distance_to(life.hit_point)
		if distance<best:
			var key: String=world.location+"/"+str(life.id)
			if int(world.crew.get("combat",{}).get(key,FrontierWildlifeCombat.health(life)))>0:result={"kind":"animal","id":key,"point":life.hit_point,"row":life,"weak":false}
	return result
static func _damage(world: Dictionary,actor: String,hit: Dictionary,damage: float,tool: Dictionary,ads: bool) -> Dictionary:
	var outcome: Dictionary={"damage":0.0,"shield":0.0,"broken":false,"weak":hit.get("weak",false),"killed":false}
	if hit.kind=="robot":
		var row: Dictionary=world.incidents.records[hit.id]
		var before:=float(row.get("shield",0));var hp:=float(row.hp)
		if outcome.weak:damage*=float(tool.weak) if ads else 1.25
		var split:=FrontierCrewVitals.split_shield_damage(before,damage,float(tool.get("shield_multiplier",1)))
		row.shield=maxf(0,before-float(split.absorbed));row.shield_wait=float(FrontierExplorationIncidents.config().robot.shield_delay)
		row.hp=maxf(0,hp-float(split.health));row.serial+=1;row.seen=true
		outcome.shield=before-row.shield;outcome.damage=hp-row.hp;outcome.broken=before>0 and row.shield<=0;outcome.killed=row.hp<=0
		if outcome.killed:FrontierExplorationIncidents.set_phase(row,"destroyed");FrontierSuitModules.on_kill(world.crew.members[actor])
	elif hit.kind=="drone":
		var row: Dictionary=world.incidents.records[hit.id];row.hits+=1;row.serial+=1;outcome.damage=damage
		if row.hits>=int(FrontierExplorationIncidents.config().tool.drone_hits):
			var point:=FrontierExplorationIncidents.moving_point(row);point.y=FrontierCrewSurface.field(world).height(point.x,point.z)+.35
			row.cargo_ground=FrontierExplorationIncidents.array(point);row.open=true;FrontierExplorationIncidents.set_phase(row,"disabled");outcome.killed=true
	else:
		var result:=FrontierWildlifeCombat.hit(world,actor,hit.row,damage)
		outcome.damage=result.damage;outcome.killed=result.killed
	return outcome

class_name FrontierWeaponLoot
extends RefCounted
## Immutable host rolls; legacy fixed quality remains a separate profile.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/weapon_loot.json"))
	return _config
static func allowed_affixes(family: String,element: String) -> Array:
	var ids: Array=[]
	for id in config().affixes:
		if id in ["buildup","duration"] and element not in ["thermal","cryo"]:continue
		if id in ["heat","cool"] and family!="laser":continue
		if id=="velocity" and family=="laser":continue
		ids.append(id)
	return ids
static func roll(definition: String,rarity: String,seed_value: int,element: String="",legendary: String="") -> Dictionary:
	var def: Dictionary=FrontierEquipment.config().items[definition]
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	if element.is_empty():element=config().elements.keys()[rng.randi_range(0,config().elements.size()-1)]
	if rarity=="legendary":
		var legends: Array=[]
		for id in config().legendaries:
			if config().legendaries[id].family==def.firearm:legends.append(id)
		if legendary.is_empty() and not legends.is_empty():legendary=legends[rng.randi_range(0,legends.size()-1)]
		if legendary.is_empty():return {}
		element=config().legendaries[legendary].element
	var result: Dictionary={"roll_version":2,"loot_pool_version":3,"rarity":rarity,"element_id":element,"legendary_id":legendary,"affixes":[],"seed":seed_value,"locked":false}
	var pool:=allowed_affixes(def.firearm,element);var groups: Array=[]
	for _i in int(config().option_counts[config().rarities.find(rarity)]):
		var candidates: Array=pool.filter(func(id):return config().affixes[id].group not in groups)
		var id: String=candidates[rng.randi_range(0,candidates.size()-1)];var spec: Dictionary=config().affixes[id]
		result.affixes.append({"id":id,"value":snappedf(rng.randf_range(spec.min,spec.max),.001)})
		groups.append(spec.group)
	var quality_rng:=RandomNumberGenerator.new();quality_rng.seed=FrontierUniverse.derive(seed_value,"weapon-damage-quality")
	result.damage_profile=damage_profile(float(def.damage),snappedf(quality_rng.randf_range(config().damage_quality.quality_min,config().damage_quality.quality_max),.001))
	return result
static func apply(tool: Dictionary,record: Dictionary) -> void:
	tool.roll_version=record.get("roll_version",1);tool.element_id=record.get("element_id","kinetic")
	tool.legendary_id=record.get("legendary_id","");tool.affixes=record.get("affixes",[]);tool.locked=record.get("locked",false)
	tool.buildup=1.0;tool.duration=1.0
	if int(tool.roll_version)!=2:return
	var profile: Dictionary=record.get("damage_profile",{})
	if not profile.is_empty():tool.damage=(float(profile.min)+float(profile.max))*.5
	var base_damage:=float(tool.damage)
	for affix in tool.affixes:
		var spec: Dictionary=config().affixes[affix.id];var factor:=1.+float(affix.value)*(-1. if spec.mode=="down" else 1.)
		tool[spec.stat]=float(tool.get(spec.stat,1.))*factor
		if affix.id=="weak":tool.head_multiplier=float(tool.get("head_multiplier",1.4))*factor
	tool.magazine=roundi(tool.magazine);tool.damage=snappedf(tool.damage,.01)
	if not profile.is_empty():
		tool.damage_min=float(profile.min)*float(tool.damage)/base_damage;tool.damage_max=float(profile.max)*float(tool.damage)/base_damage;tool.damage_mean=tool.damage;tool.damage_quality=profile.quality
	if not tool.legendary_id.is_empty():
		var special: Dictionary=config().legendaries[tool.legendary_id]
		tool.name=str(special.name)+" Mk."+str(int(tool.tier));tool.model=special.model
static func valid(record: Dictionary,definition: Dictionary) -> bool:
	if not record.has("roll_version"):return true
	if record.roll_version!=2 or not definition.has("firearm") or not config().elements.has(record.get("element_id","")):return false
	if not record.get("affixes") is Array or not record.get("locked",false) is bool:return false
	if record.has("damage_profile") and not valid_damage_profile(record.damage_profile):return false
	var rank: int=config().rarities.find(record.get("rarity",""))
	if rank<0 or record.affixes.size()!=int(config().option_counts[rank]):return false
	var legend: Variant=record.get("legendary_id","")
	if not legend is String:return false
	if rank==4:
		if not config().legendaries.has(legend):return false
		var spec: Dictionary=config().legendaries[legend]
		if spec.family!=definition.firearm or spec.element!=record.element_id:return false
	elif legend!="":return false
	var groups: Array=[];var allowed:=allowed_affixes(definition.firearm,record.element_id)
	for affix in record.affixes:
		if not affix is Dictionary or affix.get("id","") not in allowed:return false
		var spec: Dictionary=config().affixes[affix.id]
		if spec.group in groups or not FrontierUniverse._finite(affix.get("value"),float(spec.min)-.0001,float(spec.max)+.0001):return false
		groups.append(spec.group)
	return true
static func generate(seed_value: int,row: Dictionary) -> Dictionary:
	if row.get("gun_claimed",false):return {}
	if row.has("gun_reward_v2"):return row.gun_reward_v2.duplicate(true)
	var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(seed_value,FrontierExplorationIncidents.key(row)+":firearm-v2")
	if rng.randf()>float(config().drop_chance):return {}
	var source: String="elite" if row.get("robot_role","") in ["bastion","raptor"] else "cache"
	var value:=rng.randf()*100.;var rank:=0
	for weight in config().weights[source]:
		value-=float(weight)
		if value<0:break
		rank+=1
	var tier:=clampi(int(row.tier),1,3);var candidates: Array=[]
	for id in FrontierEquipment.config().items:
		var def: Dictionary=FrontierEquipment.config().items[id]
		if not def.has("firearm") or int(def.tier)!=tier:continue
		if rank==4 and not config().legendaries.values().any(func(s):return s.family==def.firearm):continue
		candidates.append(id)
	if candidates.is_empty():return {}
	var definition: String=candidates[rng.randi_range(0,candidates.size()-1)]
	var reward:=roll(definition,config().rarities[mini(rank,4)],rng.randi())
	reward.definition=definition;reward.source=row.id
	return reward
static func damage_profile(base: float,quality: float=1.0) -> Dictionary:
	var spec: Dictionary=config().damage_quality
	var low:=base*float(spec.base_min_factor);var high:=base*float(spec.base_max_factor)
	return {"version":1,"quality":quality,"base_min":low,"base_max":high,"min":low*quality,"max":high*quality}
static func valid_damage_profile(value: Variant) -> bool:
	if not value is Dictionary or value.get("version")!=1:return false
	if not FrontierUniverse._finite(value.get("quality"),.8,1.2):return false
	for key in ["base_min","base_max","min","max"]:
		if not FrontierUniverse._finite(value.get(key),.001,100000):return false
	return value.base_min<=value.base_max and value.min<=value.max and is_equal_approx(float(value.min),float(value.base_min)*float(value.quality)) and is_equal_approx(float(value.max),float(value.base_max)*float(value.quality))
static func damage_range(tool: Dictionary) -> Vector2:
	var damage:=float(tool.damage)
	if not tool.has("damage_min"):return Vector2(damage,damage)
	var factor:=damage/maxf(.001,float(tool.damage_mean))
	return Vector2(float(tool.damage_min),float(tool.damage_max))*factor
static func sample_damage(world: Dictionary,actor: String,tool: Dictionary,state: Dictionary) -> float:
	var limits:=damage_range(tool)
	if is_equal_approx(limits.x,limits.y):return limits.x
	state.damage_shots=int(state.get("damage_shots",0))+1
	var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(world.manifest.seed),actor+":"+str(tool.item_id)+":damage:"+str(state.damage_shots))
	return rng.randf_range(limits.x,limits.y)
static func dps(tool: Dictionary) -> float:
	var interval:=maxf(.06,float(tool.interval));var shots:=float(tool.magazine)
	var firing:=shots*interval;var wait:=float(tool.reload)+float(tool.get("reload_empty_extra",0))
	if tool.get("effect","")=="beam":
		var burst:=1./float(tool.heat_per_shot)
		wait+=floorf(shots/burst)*((1.-float(tool.heat_unlock))/float(tool.cool_rate)+float(tool.cool_delay))
	return float(tool.damage)*float(tool.pellets)*shots/maxf(.01,firing+wait)
static func cost(recipe: Dictionary,element: String) -> Dictionary:
	var result: Dictionary=recipe.cost.duplicate()
	if recipe.has("firearm"):
		for id in config().elements[element].cost:result[id]=int(result.get(id,0))+int(config().elements[element].cost[id])*int(recipe.tier)
	return result
static func details(tool: Dictionary) -> String:
	var lines: PackedStringArray=[]
	lines.append(str(config().elements[tool.get("element_id","kinetic")].name)+" 공격")
	var limits:=damage_range(tool)
	lines.append("피해 %.1f~%.1f"%[limits.x,limits.y])
	if int(tool.get("roll_version",1))!=2:lines.append("기존 개체의 고정 품질 보너스 유지")
	for affix in tool.get("affixes",[]):
		var spec: Dictionary=config().affixes[affix.id]
		lines.append("%s %s%d%%"%[spec.name,"−" if spec.mode=="down" else "+",roundi(float(affix.value)*100)])
	if not str(tool.get("legendary_id","")).is_empty():lines.append(config().legendaries[tool.legendary_id].description)
	return "\n".join(lines)
static func salvage(member: Dictionary,id: String) -> Dictionary:
	var tool:=FrontierFirearms.item(member,id);var result: Dictionary={}
	if not tool.has("firearm"):return result
	for resource in config().salvage:result[resource]=int(config().salvage[resource])*int(tool.tier)
	var state: Dictionary=member.loadout.get("weapon_states",{}).get(id,{})
	if not str(tool.ammo_type).is_empty():
		var rounds:=int(state.get("ammo",tool.magazine))+int(state.get("reload_rounds",0))
		if rounds>0:result[tool.ammo_type]=rounds
	return result
static func manage(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var member: Dictionary=world.crew.members[actor];var data: Dictionary=member.loadout;var id:=str(args.get("item_id",""))
	var tool:=FrontierFirearms.item(member,id)
	if not tool.has("firearm"):return "내 총기를 선택하세요."
	if kind=="equipment_weapon_lock":
		if not args.get("locked") is bool:return "잠금 상태를 확인하세요."
		if not data.has("weapon_rolls"):data.weapon_rolls={}
		if not data.weapon_rolls.has(id):data.weapon_rolls[id]={"rarity":"standard"}
		data.weapon_rolls[id].locked=args.locked;return ""
	if id in data.slots or tool.locked:return "장착을 해제하고 잠금을 풀어야 분해할 수 있습니다."
	var stock:=FrontierExpeditionBusiness.bag(world,actor);var result:=salvage(member,id);var after:=stock.duplicate()
	FrontierExpeditionBusiness.transfer(after,result,1)
	if FrontierItemInventory.used(after,data.items.size()-1)>FrontierItemInventory.capacity(member):return "반환할 부품과 탄약을 넣을 공간이 부족합니다."
	FrontierExpeditionBusiness.transfer(stock,result,1);data.items.erase(id)
	data.get("weapon_rolls",{}).erase(id);data.get("weapon_states",{}).erase(id)
	return ""

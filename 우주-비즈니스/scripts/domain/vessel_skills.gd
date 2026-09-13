class_name FrontierVesselSkills
extends RefCounted
## One catalogue for embedded hull abilities and separately acquired skill licences.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/vessel_combat.json"))
	return _config
static func definitions() -> Dictionary:return config().skills
static func definition(id: String) -> Dictionary:return definitions().get(id,{})
static func create() -> Dictionary:
	return {"version":1,"unlocked":config().starter_skills.duplicate(),"levels":{},"loadouts":{}}
static func state(vessel: Dictionary) -> Dictionary:return vessel.combat_skills if vessel.has("combat_skills") else create()
static func signature_skill(vessel: Dictionary) -> String:return str(FrontierSpaceStation.hull(vessel).get("signature_skill","seeker_salvo"))
static func passive(vessel: Dictionary) -> Dictionary:return config().passives.get(FrontierSpaceStation.hull(vessel).get("passive","tracking"),{})
static func level(vessel: Dictionary,id: String) -> int:return int(state(vessel).levels.get(id,0))
static func value(vessel: Dictionary,id: String,key: String,fallback: float=0.0) -> float:
	var v: Variant=definition(id).get(key,fallback)
	return float(v[clampi(level(vessel,id),0,v.size()-1)]) if v is Array else float(v)
static func equipped(vessel: Dictionary) -> Array:
	return state(vessel).loadouts.get(str(vessel.get("hull","kestrel")),config().default_slots)
static func slot_skill(vessel: Dictionary,slot: int) -> String:
	if slot==0:return signature_skill(vessel)
	return str(equipped(vessel)[slot-1]) if slot in [1,2] else ""
static func owned(vessel: Dictionary,id: String) -> bool:return id in state(vessel).unlocked
static func accessible(vessel: Dictionary,id: String) -> bool:return owned(vessel,id) or id==signature_skill(vessel)
static func upgrade_price(vessel: Dictionary,id: String) -> int:
	var rank:=level(vessel,id)
	if rank>=int(config().maximum_upgrade):return 0
	return int(config().upgrade_costs[rank])*int(config().tier_cost_factor[str(int(definition(id).tier))])
static func shield_max(world: Dictionary,id: String="crew") -> float:
	return float(FrontierSpaceCombat.config().finch_shield) if id!="crew" else float(FrontierSpaceStation.hull(world.get("vessel",{})).get("combat_shield",FrontierSpaceCombat.config().shield))
static func combat_speed(world: Dictionary) -> float:
	return float(FrontierSpaceCombat.config().combat_speed) if world.has("local_shuttle") else float(FrontierSpaceStation.hull(world.get("vessel",{})).get("combat_speed",FrontierSpaceCombat.config().combat_speed))
static func cargo_capacity(vessel: Dictionary) -> int:
	return maxi(int(FrontierItemInventory.config().warehouse_slots),int(FrontierSpaceStation.hull(vessel).get("cargo_slots",0)))
static func summary(vessel: Dictionary,id: String) -> String:
	var d:=definition(id)
	if d.is_empty():return "빈 슬롯"
	var details:=PackedStringArray()
	if d.has("targets"):details.append("최대 %d대"%int(value(vessel,id,"targets")))
	if d.has("salvo"):details.append("%d발%s"%[int(value(vessel,id,"salvo"))," / 대상" if d.kind=="missile" else ""])
	if d.has("damage"):details.append("피해 %d"%int(value(vessel,id,"damage")))
	if d.has("duration"):details.append("%.1f초 지속"%value(vessel,id,"duration"))
	details.append("재사용 %.0f초"%float(d.cooldown))
	return "  ".join(details)
static func apply(world: Dictionary,action: String,args: Dictionary) -> String:
	var vessel: Dictionary=world.vessel;var current:=state(vessel)
	var id:=str(args.get("item",""));var d:=definition(id)
	if d.is_empty():return "사용할 스킬을 선택하세요."
	var price:=0;var slot:=0
	match action:
		"station_skill_buy":
			if owned(vessel,id):return "이미 확보한 스킬입니다."
			price=int(d.price)
		"station_skill_upgrade":
			if not accessible(vessel,id):return "고유 스킬을 가진 선체를 운용하거나 스킬을 먼저 확보하세요."
			if level(vessel,id)>=int(config().maximum_upgrade):return "최대 강화 단계입니다."
			price=upgrade_price(vessel,id)
		"station_skill_equip":
			if not FrontierExpeditionBusiness.integer(args.get("slot"),1,2):return "1번 또는 2번 슬롯을 선택하세요."
			slot=int(args.slot)
			if not owned(vessel,id):return "다른 슬롯에 장착하려면 이 스킬을 별도로 확보하세요."
			if id==signature_skill(vessel) or id in equipped(vessel):return "같은 스킬은 중복 장착하지 않습니다."
		"station_skill_unequip":
			if not FrontierExpeditionBusiness.integer(args.get("slot"),1,2):return "해제할 슬롯을 선택하세요."
			slot=int(args.slot)
			if equipped(vessel)[slot-1]!=id:return "그 슬롯에 장착된 스킬을 선택하세요."
		_:return "지원하지 않는 스킬 정비입니다."
	if int(world.business.credits)<price:return "공동 크레딧이 부족합니다."
	# All checks precede mutation; a rejected selection does not create save defaults.
	var next:=current.duplicate(true)
	match action:
		"station_skill_buy":next.unlocked.append(id)
		"station_skill_upgrade":next.levels[id]=level(vessel,id)+1
		_:
			var slots:=equipped(vessel).duplicate();slots[slot-1]="" if action=="station_skill_unequip" else id
			next.loadouts[str(vessel.get("hull","kestrel"))]=slots
	vessel.combat_skills=next;world.business.credits-=price
	return ""
static func validate(vessel: Dictionary) -> String:
	if not vessel.has("combat_skills"):return ""
	var s: Variant=vessel.combat_skills
	if not s is Dictionary or s.get("version")!=1 or not s.get("unlocked") is Array or not s.get("levels") is Dictionary or not s.get("loadouts") is Dictionary:return "선박 스킬 기록 구조 오류"
	if s.unlocked.size()>definitions().size() or s.levels.size()>definitions().size() or s.loadouts.size()>FrontierSpaceStation.config().hulls.size():return "선박 스킬 기록 한도 오류"
	var seen: Dictionary={}
	for id in s.unlocked:
		if not id is String or definition(id).is_empty() or seen.has(id):return "보유 스킬 정의 오류"
		seen[id]=true
	for id in s.levels:
		if not id is String or definition(id).is_empty() or not FrontierExpeditionBusiness.integer(s.levels[id],0,int(config().maximum_upgrade)):return "스킬 강화 단계 오류"
	for hull in s.loadouts:
		if hull not in vessel.get("hulls",["kestrel"]):return "스킬 장착 선체 소유 오류"
		var slots: Variant=s.loadouts[hull]
		if not slots is Array or slots.size()!=2:return "스킬 슬롯 수 오류"
		var fixed:=str(FrontierSpaceStation.config().hulls[hull].signature_skill);var used: Dictionary={fixed:true}
		for id in slots:
			if not id is String:return "스킬 슬롯 형식 오류"
			if id.is_empty():continue
			if not seen.has(id) or used.has(id):return "미보유 또는 중복 스킬 장착"
			used[id]=true
	return ""

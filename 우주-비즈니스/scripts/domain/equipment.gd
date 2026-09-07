class_name FrontierEquipment
extends RefCounted
## Personal equipment is stored in the host world; carried materials remain world cargo.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	return _config
static func create(profile: Dictionary) -> Dictionary:
	var result: Dictionary={"items":{},"slots":["","","","",""],"selected":0,"kit":1,"counter":0}
	for item in profile.equipment:
		if item.definition=="rock_tool":
			var tier: int={"standard":1,"improved":2,"rare":3}[item.grade]
			result.items[item.id]="miner_"+str(tier)
			if result.slots[0].is_empty():result.slots[0]=item.id
	if result.slots[0].is_empty():
		result.items["crafted:1"]="miner_1"
		result.slots[0]="crafted:1"
		result.counter=1
	result.kit=0
	return result
static func state(member: Dictionary) -> Dictionary:
	return member.get("loadout",create(member.profile))
static func active(member: Dictionary) -> Dictionary:
	var data:=state(member)
	var id: String=data.slots[int(data.selected)]
	return config().items.get(data.items.get(id,""),{})
static func validate(value: Variant) -> String:
	if not value is Dictionary:return "장비 기록 형식"
	if not value.get("items") is Dictionary or value.items.size()>int(FrontierItemInventory.config().slots):return "장비 한도"
	if not value.get("slots") is Array or value.slots.size()!=int(config().slots):return "장착 슬롯"
	for key in ["selected","kit","counter"]:
		if not FrontierUniverse._finite(value.get(key),0,1000000) or value[key]!=floorf(value[key]):return "장비 수량"
	if int(value.selected)>=int(config().slots) or int(value.kit)>1:return "선택 슬롯"
	for id in value.items:
		if not id is String or not config().items.has(value.items[id]):return "장비 정의"
	if not FrontierExpeditionBusiness.integer(value.get("suit_tier",1),1,2):return "탐험복 개조 등급"
	var seen: Array=[]
	for id in value.slots:
		if not id is String or (id!="" and (not value.items.has(id) or id in seen)):return "슬롯 소유권"
		if id!="":seen.append(id)
	return ""
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var member: Dictionary=world.crew.members[actor]
	if not member.has("loadout"):member.loadout=create(member.profile)
	var data: Dictionary=member.loadout
	if kind in ["equipment_select","equipment_equip"]:
		if not FrontierUniverse._finite(args.get("slot"),0,int(config().slots)-1) or args.slot!=floorf(args.slot):return "장착 번호 오류"
		var slot:=int(args.slot)
		if kind=="equipment_select":data.selected=slot;return ""
		var id: String=str(args.get("item_id",""))
		if id!="" and not data.items.has(id):return "내가 소유한 장비만 장착할 수 있습니다."
		for i in data.slots.size():
			if data.slots[i]==id:data.slots[i]=""
		data.slots[slot]=id;return ""
	if kind=="equipment_suit_upgrade":
		if member.area!="surface":return "착륙 후 탐험복을 개조하세요."
		if int(data.get("suit_tier",1))>=2:return "탐험복은 이미 Mk.2입니다."
		var cost: Dictionary=FrontierProductionTier2.config().suit_upgrade.cost
		var stock:=FrontierExpeditionBusiness.bag(world,actor)
		if not FrontierExpeditionBusiness.affordable(stock,cost):return "배낭의 탐험복 개조 부품이 부족합니다."
		FrontierExpeditionBusiness.transfer(stock,cost,-1);data.suit_tier=2;return ""
	if kind=="equipment_upgrade":
		if member.area!="surface":return "착륙 후 장비를 개조하세요."
		var id:=str(args.get("item_id",""))
		if not data.items.has(id):return "내 장비를 선택하세요."
		var original: String=data.items[id]
		for key in config().items:
			var target: Dictionary=config().items[key]
			if target.get("upgrade_from","")!=original:continue
			var stock:=FrontierExpeditionBusiness.bag(world,actor)
			if not FrontierExpeditionBusiness.affordable(stock,target.cost):return "배낭의 Mk.2 부품이 부족합니다."
			FrontierExpeditionBusiness.transfer(stock,target.cost,-1);data.items[id]=key;return ""
		return "현재 최고 개조 단계입니다."
	if kind!="equipment_craft":return "지원하지 않는 장비 작업"
	if member.area!="surface":return "착륙 후 휴대 제작기를 사용하세요."
	var definition: String=str(args.get("definition",""))
	if not config().items.has(definition):return "제작 설계도 오류"
	if data.items.size()>=int(FrontierItemInventory.config().slots):return "장비 보관 한도에 도달했습니다."
	var recipe: Dictionary=config().items[definition]
	if not recipe.get("craftable",true):return "현재 제작은 Mk.2까지 지원합니다."
	var after_cost:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	FrontierExpeditionBusiness.transfer(after_cost,recipe.cost,-1)
	if FrontierItemInventory.used(after_cost,data.items.size()+1)>int(FrontierItemInventory.config().slots):return "아이템 보관 공간이 부족합니다."
	if definition=="miner_1":
		if int(data.kit)<=0:return "기초 조립 키트를 이미 사용했습니다. 소유 채집기를 장착하세요."
		data.kit-=1
	else:
		var bag:=FrontierExpeditionBusiness.bag(world,actor)
		if not FrontierExpeditionBusiness.affordable(bag,recipe.cost):return "내 배낭의 제작 재료가 부족합니다."
		FrontierExpeditionBusiness.transfer(bag,recipe.cost,-1)
	data.counter+=1
	data.items["crafted:"+str(int(data.counter))]=definition
	return ""

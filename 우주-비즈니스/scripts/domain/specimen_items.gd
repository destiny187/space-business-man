class_name FrontierSpecimenItems
extends RefCounted
## Physical samples use the existing item ledgers. Ecology keeps identity/research history only.
const PREFIX: String="specimen|"
static var definitions: Dictionary={}
static func is_item(id: String) -> bool:return id.begins_with(PREFIX)
static func resource(sample: Dictionary) -> String:
	return "specimen|%s|%s|%s|%s"%[sample.form_id,sample.look_id,sample.source_body,sample.id]
static func decode(id: String) -> Dictionary:
	if not is_item(id) or id.length()>512:return {}
	var parts:=id.split("|")
	if parts.size()!=5 or not FrontierPlayerProfile.identifier(parts[4],64):return {}
	if FrontierEcologyCatalog.look(parts[1],parts[2]).is_empty():return {}
	return {"form_id":parts[1],"look_id":parts[2],"source_body":parts[3],"id":parts[4]}
static func entry(id: String) -> Dictionary:
	if definitions.has(id):return definitions[id]
	var sample:=decode(id)
	if sample.is_empty():return {}
	var form:=FrontierEcologyCatalog.form(sample.form_id)
	var definition: Dictionary={"id":id,"name":str(form.name)+" 표본","category":"specimen","model":FrontierEcologyCatalog.model_key(form),"icon":str(form.category)+"_sample","sample":sample}
	definitions[id]=definition
	return definition
static func ensure(world: Dictionary) -> void:
	if not world.has("crew"):return
	if not world.has("ecology"):world.ecology=FrontierEcology.create()
	if int(world.ecology.get("item_storage_version",0))>=1:return
	if not world.crew.has("cargo"):world.crew.cargo={}
	# Old samples were shared ship cargo. Preserve all of them, even if this overfills the ship.
	for sample in world.ecology.specimens.values():
		if sample.state=="cargo":world.crew.cargo[resource(sample)]=1
	world.ecology.item_storage_version=1
static func collect(world: Dictionary,actor: String,encounter: Dictionary) -> String:
	ensure(world)
	var sample: Dictionary={"id":(world.location+":"+str(encounter.id)).sha256_text(),"source_body":world.location,"form_id":encounter.form_id,"look_id":encounter.look_id}
	var key:=resource(sample)
	if FrontierItemInventory.room(world,actor,key)<1:return "아이템창이 가득 찼습니다. 창고에 물건을 옮겨 공간을 확보하세요."
	var before: int=world.ecology.specimens.size()
	var result:=FrontierEcology.collect(world.ecology,world.location,encounter)
	if world.ecology.specimens.size()==before:return result
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	world.business.bags[actor][key]=1
	return ""
static func carried(stock: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in stock:
		if not is_item(key) or int(stock[key])<=0:continue
		var sample:=decode(key)
		if not sample.is_empty():result[sample.id]=sample
	return result
static func owns(world: Dictionary,actor: String,sample: Dictionary) -> bool:
	return int(FrontierExpeditionBusiness.bag(world,actor).get(resource(sample),0))==1
static func consume(world: Dictionary,actor: String,sample: Dictionary) -> void:
	world.business.bags[actor].erase(resource(sample))
static func stocks(world: Dictionary) -> Array:
	var result: Array=[world.get("crew",{}).get("cargo",{})]
	var business: Dictionary=world.get("business",{})
	result.append_array(business.get("bags",{}).values())
	for group in ["sites","crates"]:
		for row in business.get(group,{}).values():result.append(row.get("inventory",{}))
	for ship in world.get("crew",{}).get("shuttles",{}).values():result.append(ship.get("cargo",{}))
	for rover in world.get("rovers",{}).get("vehicles",{}).values():result.append(rover.get("cargo",{}))
	for site in business.get("sites",{}).values():
		for robot in site.get("robots",{}).values():result.append(robot.get("cargo",{}))
	for robot in business.get("hangar",{}).values():result.append(robot.get("cargo",{}))
	return result
static func prune(world: Dictionary) -> void:
	for stock in stocks(world):
		for key in stock.keys():
			if is_item(key) and int(stock[key])==0:stock.erase(key)
static func validate(world: Dictionary) -> String:
	var ecology: Dictionary=world.get("ecology",{})
	var unified:=int(ecology.get("item_storage_version",0))==1
	var seen: Dictionary={}
	for stock in stocks(world):
		for key in stock:
			if not is_item(key) or int(stock[key])==0:continue
			if not unified:return "표본 아이템 저장 버전이 없습니다."
			var decoded:=decode(key)
			if decoded.is_empty():return "표본 아이템 형식 오류"
			var id: String=decoded.id
			var sample: Dictionary=ecology.get("specimens",{}).get(id,{})
			if not FrontierExpeditionBusiness.integer(stock[key],1,1) or sample.is_empty() or sample.state!="cargo" or key!=resource(sample):return "표본 아이템과 채집 원본이 다릅니다."
			if seen.has(id):return "같은 표본이 여러 보관함에 중복되어 있습니다."
			seen[id]=true
	if unified:
		for sample in ecology.specimens.values():
			if sample.state=="cargo" and not seen.has(sample.id):return "표본의 보관 위치가 없습니다."
	return ""

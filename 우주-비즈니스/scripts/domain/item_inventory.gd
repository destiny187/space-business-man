class_name FrontierItemInventory
extends RefCounted
## One slot budget for personal resources and individually owned equipment.
static var _config: Dictionary={}
static func config() -> Dictionary:
	if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/inventory.json"))
	return _config
static func stacks(stock: Dictionary) -> Array:
	var result: Array=[]
	var ids:=stock.keys();ids.sort()
	for id in ids:
		var remaining:=int(stock[id])
		while remaining>0:
			var amount:=mini(remaining,int(config().resource_stack))
			result.append({"resource":id,"amount":amount});remaining-=amount
	return result
static func used(stock: Dictionary,items: int=0) -> int:
	var count:=items
	for amount in stock.values():count+=ceili(float(amount)/float(config().resource_stack))
	return count
# Storage validation retains the former ceiling so an older save never loses cargo.
static func storage_slots() -> int:return int(config().max_slots)
static func limit() -> int:return storage_slots()*int(config().resource_stack)
static func capacity(member: Dictionary) -> int:
	return mini(storage_slots(),int(member.get("loadout",{}).get("inventory_slots",config().slots))+FrontierProgressionResearch.personal(member,"logistics"))
static func room(world: Dictionary,actor: String,resource: String) -> int:
	var stock:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	stock.stone=int(stock.get("stone",0))+int(world.crew.members[actor].carried)
	var slots:=used(stock,FrontierEquipment.state(world.crew.members[actor]).items.size())
	var available:=capacity(world.crew.members[actor])
	var existing:=int(stock.get(resource,0));var stack:=int(config().resource_stack)
	var partial:=0 if existing%stack==0 else stack-existing%stack
	return maxi(0,available-slots)*stack+partial if slots<=available else 0
static func fits(world: Dictionary,actor: String,incoming: Dictionary) -> bool:
	var stock:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	stock.stone=int(stock.get("stone",0))+int(world.crew.members[actor].carried)
	FrontierExpeditionBusiness.transfer(stock,incoming,1)
	return used(stock,FrontierEquipment.state(world.crew.members[actor]).items.size())<=capacity(world.crew.members[actor])
static func merge_legacy(world: Dictionary,actor: String) -> void:
	var amount:=int(world.crew.members[actor].carried)
	if amount<=0:return
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	var stock: Dictionary=world.business.bags[actor]
	stock.stone=int(stock.get("stone",0))+amount;world.crew.members[actor].carried=0
static func ship_site(crew: Dictionary) -> Dictionary:
	var stock: Dictionary=crew.get("cargo",{}).duplicate()
	stock.stone=int(crew.rock)
	return {"inventory":stock,"stored_equipment":crew.get("cargo_equipment",{}),"buildings":{},"slot_capacity":int(crew.get("cargo_slots",config().warehouse_slots))}
static func ship_transfer(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var member: Dictionary=world.crew.members[actor]
	var position:=FrontierCrewWorld.vector(member.position)
	if member.area=="surface":
		if position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "우주선 창고 가까이 돌아오세요."
	elif member.area!="cabin" or position.distance_to(FrontierCrewWorld.vector(FrontierCrewWorld.config().locker_position))>float(FrontierCrewWorld.config().interaction_distance):return "선내 창고 가까이 이동하세요."
	var site:=ship_site(world.crew)
	if world.has("local_shuttle"):site["slot_capacity"]=int(FrontierShuttles.config().cargo_slots)
	if args.has("item_id"):
		var error:=warehouse_equipment(world,actor,{"item_id":args.item_id,"withdraw":kind=="withdraw"},site)
		if not error.is_empty():return error
		world.crew.cargo_equipment=site.stored_equipment;return ""
	if args.get("all_resources",false)==true and kind=="deposit":
		var error:=deposit_all(world,actor,site)
		if not error.is_empty():return error
		world.crew.rock=int(site.inventory.get("stone",0));site.inventory.erase("stone");world.crew.cargo=site.inventory;return ""
	if not FrontierExpeditionBusiness.integer(args.get("amount"),1,limit()):return "옮길 수량을 확인하세요."
	var amount:=int(args.amount);var resource:=str(args.get("resource","stone"))
	if FrontierCatalog.entry("resources",resource).is_empty():return "지원하지 않는 화물입니다."
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	var stock:=FrontierExpeditionBusiness.bag(world,actor)
	if args.get("quick",false)==true:
		amount=mini(amount,mini(int(site.inventory.get(resource,0)),room(world,actor,resource)) if kind=="withdraw" else mini(int(stock.get(resource,0)),warehouse_room(site,resource)))
		if amount<=0:return "옮길 재고 또는 목적지 공간이 부족합니다."
	if kind=="withdraw":
		if int(site.inventory.get(resource,0))<amount or room(world,actor,resource)<amount:return "우주선 재고 또는 배낭 공간이 부족합니다."
		site.inventory[resource]-=amount;stock[resource]=int(stock.get(resource,0))+amount
	else:
		if int(stock.get(resource,0))<amount:return "배낭의 수량이 부족합니다."
		if not warehouse_fits(site,{resource:amount}):return "우주선 창고 10칸이 가득 찼습니다."
		stock[resource]-=amount;site.inventory[resource]=int(site.inventory.get(resource,0))+amount
	world.crew.rock=int(site.inventory.get("stone",0));site.inventory.erase("stone");world.crew.cargo=site.inventory
	return ""

static func deposit_all(world: Dictionary,actor: String,site: Dictionary) -> String:
	var stock:=FrontierExpeditionBusiness.bag(world,actor)
	var moved:=0
	var keys:=stock.keys();keys.sort()
	for key in keys:
		if FrontierCatalog.entry("resources",key).is_empty():continue
		var amount:=mini(int(stock[key]),warehouse_room(site,key))
		if amount<=0:continue
		stock[key]-=amount;site.inventory[key]=int(site.inventory.get(key,0))+amount;moved+=amount
	if moved==0:return "보관할 자원이 없거나 창고 공간이 부족합니다."
	if site.has("delivered"):site.delivered+=moved
	return ""

# A landing depot starts with ten shared slots; each built storage adds ten.
static func warehouse_capacity(site: Dictionary) -> int:
	if site.has("slot_capacity"):return int(site.slot_capacity)
	var count:=1 if site.get("base_deployed",true) else 0
	for building in site.get("buildings",{}).values():
		if building.type=="storage":count+=1
	return count*int(config().warehouse_slots)
static func warehouse_used(site: Dictionary) -> int:
	return used(site.get("inventory",{}),site.get("stored_equipment",{}).size())
static func warehouse_fits(site: Dictionary,incoming: Dictionary,slots_delta: int=0) -> bool:
	var stock: Dictionary=site.inventory.duplicate()
	FrontierExpeditionBusiness.transfer(stock,incoming,1)
	return used(stock,site.get("stored_equipment",{}).size())<=warehouse_capacity(site)+slots_delta
static func warehouse_room(site: Dictionary,resource: String) -> int:
	var occupied:=warehouse_used(site);var available:=warehouse_capacity(site)
	if occupied>available:return 0
	var stack:=int(config().resource_stack);var existing:=int(site.inventory.get(resource,0))
	return maxi(0,available-occupied)*stack+(0 if existing%stack==0 else stack-existing%stack)
static func warehouse_equipment(world: Dictionary,actor: String,args: Dictionary,ship: Dictionary={}) -> String:
	var site:=FrontierExpeditionBusiness.site(world) if ship.is_empty() else ship
	if ship.is_empty() and not FrontierExpeditionBusiness.near_warehouse(site,FrontierCrewWorld.vector(world.crew.members[actor].position)):return "현장 창고 가까이 이동하세요."
	if not world.crew.members[actor].has("loadout"):world.crew.members[actor].loadout=FrontierEquipment.create(world.crew.members[actor].profile)
	var data:=FrontierEquipment.state(world.crew.members[actor])
	if not site.has("stored_equipment"):site.stored_equipment={}
	var id:=str(args.get("item_id",""));var key:=actor+"/"+id
	if args.get("withdraw",false):
		if not site.stored_equipment.has(key):return "내가 보관한 장비를 선택하세요."
		if data.items.has(id):return "이미 소지한 장비입니다."
		if used(FrontierExpeditionBusiness.bag(world,actor),data.items.size()+1)>capacity(world.crew.members[actor]):return "배낭 공간이 부족합니다."
		data.items[id]=site.stored_equipment[key].definition;site.stored_equipment.erase(key)
	else:
		if not data.items.has(id):return "내 장비를 선택하세요."
		if warehouse_used(site)>=warehouse_capacity(site):return "창고 공간이 부족합니다."
		site.stored_equipment[key]={"owner":actor,"item_id":id,"definition":data.items[id]}
		data.items.erase(id)
		for i in data.slots.size():
			if data.slots[i]==id:data.slots[i]=""
	return ""

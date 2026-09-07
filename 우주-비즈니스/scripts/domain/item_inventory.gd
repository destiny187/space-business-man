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
static func limit() -> int:return int(config().slots)*int(config().resource_stack)
static func room(world: Dictionary,actor: String,resource: String) -> int:
	var stock:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	stock.stone=int(stock.get("stone",0))+int(world.crew.members[actor].carried)
	var slots:=used(stock,FrontierEquipment.state(world.crew.members[actor]).items.size())
	var existing:=int(stock.get(resource,0));var stack:=int(config().resource_stack)
	var partial:=0 if existing%stack==0 else stack-existing%stack
	return maxi(0,int(config().slots)-slots)*stack+partial if slots<=int(config().slots) else 0
static func fits(world: Dictionary,actor: String,incoming: Dictionary) -> bool:
	var stock:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	stock.stone=int(stock.get("stone",0))+int(world.crew.members[actor].carried)
	FrontierExpeditionBusiness.transfer(stock,incoming,1)
	return used(stock,FrontierEquipment.state(world.crew.members[actor]).items.size())<=int(config().slots)
static func merge_legacy(world: Dictionary,actor: String) -> void:
	var amount:=int(world.crew.members[actor].carried)
	if amount<=0:return
	if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
	if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	var stock: Dictionary=world.business.bags[actor]
	stock.stone=int(stock.get("stone",0))+amount;world.crew.members[actor].carried=0
static func ship_transfer(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
	var member: Dictionary=world.crew.members[actor]
	var position:=FrontierCrewWorld.vector(member.position)
	if member.area=="surface":
		if position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))>float(FrontierCrewSurface.config().boarding_distance):return "우주선 보관함에 가까이 돌아오세요."
	elif member.area!="cabin" or position.distance_to(FrontierCrewWorld.vector(FrontierCrewWorld.config().locker_position))>float(FrontierCrewWorld.config().interaction_distance):return "공동 보관함에 가까이 이동하세요."
	if not FrontierExpeditionBusiness.integer(args.get("amount"),1,limit()):return "옮길 수량을 확인하세요."
	var amount:=int(args.amount)
	if kind=="withdraw":
		if int(world.crew.rock)<amount or room(world,actor,"stone")<amount:return "공동 재고 또는 아이템 공간이 부족합니다."
		if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
		if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
		world.business.bags[actor].stone+=amount;world.crew.rock-=amount
	else:
		var stock:=FrontierExpeditionBusiness.bag(world,actor)
		if int(stock.get("stone",0))<amount:return "운반 중인 암석이 부족합니다."
		stock.stone-=amount;world.crew.rock+=amount
	return ""

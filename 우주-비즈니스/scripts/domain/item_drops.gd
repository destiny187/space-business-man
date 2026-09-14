extends RefCounted
## Host-authored ground cargo. Requests name owned items, never client positions or rewards.
static func create(world: Dictionary,position: Array,stock: Dictionary,equipment: Dictionary={}) -> String:
 var ledger: Dictionary=world.business;ledger.counter+=1
 var inventory:=FrontierExpeditionBusiness.inventory();FrontierExpeditionBusiness.transfer(inventory,stock,1)
 var id: String="drop:"+str(int(ledger.counter))
 ledger.crates[id]={"body_id":world.location,"position":position.duplicate(),"inventory":inventory,"equipment":equipment.duplicate(true)}
 return id
static func apply(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
 var member: Dictionary=world.crew.members[actor]
 if member.area!="surface" or not FrontierCrewSurface.landed(world):return "지표에 내려놓을 수 있습니다."
 if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
 if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 var stock: Dictionary=world.business.bags[actor]
 if not member.has("loadout"):member.loadout=FrontierEquipment.create(member.profile)
 var data:=FrontierEquipment.state(member)
 if kind=="equipment_pickup":return pickup(world,actor,str(args.get("crate_id","")))
 var amount: Variant=args.get("amount",1)
 if not FrontierExpeditionBusiness.integer(amount,1,FrontierItemInventory.limit()):return "내려놓을 수량을 확인하세요."
 var item: String=str(args.get("item_id",""))
 if not item.is_empty():
  if int(amount)!=1 or not data.items.has(item):return "내가 소지한 장비를 선택하세요."
  if data.get("weapon_rolls",{}).get(item,{}).get("locked",false):return "보호를 해제한 뒤 내려놓으세요."
  var packed: Dictionary={"definition":data.items[item]}
  for field in ["weapon_states","weapon_rolls"]:
   if data.get(field,{}).has(item):packed[field]=data[field][item].duplicate(true);data[field].erase(item)
  data.items.erase(item)
  for i in data.slots.size():
   if data.slots[i]==item:data.slots[i]=""
  if data.get("back_slot","")==item:data.back_slot=""
  create(world,member.position,{},packed)
 else:
  var resource: String=str(args.get("resource",""))
  if FrontierCatalog.entry("resources",resource).is_empty() or int(stock.get(resource,0))<int(amount):return "내 배낭의 수량이 부족합니다."
  stock[resource]-=int(amount);create(world,member.position,{resource:int(amount)})
 return ""
static func pickup(world: Dictionary,actor: String,id: String) -> String:
 var ledger: Dictionary=world.business
 if not ledger.crates.has(id):return "이미 회수한 아이템입니다."
 var crate: Dictionary=ledger.crates[id];var member: Dictionary=world.crew.members[actor]
 if crate.body_id!=world.location or FrontierCrewWorld.vector(crate.position).distance_to(FrontierCrewWorld.vector(member.position))>4:return "같은 행성의 아이템 4m 안으로 접근하세요."
 var packed: Dictionary=crate.get("equipment",{})
 if not member.has("loadout"):member.loadout=FrontierEquipment.create(member.profile)
 var data:=FrontierEquipment.state(member)
 var stock: Dictionary=ledger.bags[actor].duplicate();FrontierExpeditionBusiness.transfer(stock,crate.inventory,1)
 if FrontierItemInventory.used(stock,data.items.size()+(0 if packed.is_empty() else 1))>FrontierItemInventory.capacity(member):return "배낭 공간이 부족합니다."
 if not packed.is_empty():
  data.counter+=1
  var item: String="crafted:"+str(int(data.counter))
  data.items[item]=packed.definition
  for field in ["weapon_states","weapon_rolls"]:
   if packed.has(field):
    if not data.has(field):data[field]={}
    data[field][item]=packed[field].duplicate(true)
 ledger.bags[actor]=stock;ledger.crates.erase(id)
 return ""
static func valid(packed: Variant) -> bool:
 if not packed is Dictionary:return false
 if packed.is_empty():return true
 if not FrontierEquipment.config().items.has(packed.get("definition","")):return false
 var loadout: Dictionary={"items":{"drop":packed.definition},"slots":["","","","",""],"selected":0,"counter":0,"kit":0}
 for field in ["weapon_states","weapon_rolls"]:
  if packed.has(field):loadout[field]={"drop":packed[field]}
 return FrontierEquipment.validate(loadout).is_empty()

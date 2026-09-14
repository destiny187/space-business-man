extends SceneTree
const Drops=preload("res://scripts/domain/item_drops.gd")
const Draft=preload("res://scripts/persistence/world_draft.gd")
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures+=1;printerr("FAIL "+label)
 else:print("PASS "+label)
func run() -> void:
 var world:=FrontierWorldStore.new("/tmp/playtest-field-research/world.json").read_state()
 if world.is_empty():quit(2);return
 var actor: String=world.crew.owner_id
 world.business.bags[actor].iron=20
 var before:=FrontierUniverse.fingerprint(world)
 var draft:=Draft.request(world,actor,"equipment_drop")
 check(Drops.apply(draft,actor,"equipment_drop",{"resource":"iron","amount":7}).is_empty(),"drop requested quantity")
 check(FrontierUniverse.fingerprint(world)==before,"scoped item draft does not mutate source")
 world=draft
 var id: String=world.business.crates.keys().back()
 check(world.business.bags[actor].iron==13 and world.business.crates[id].inventory.iron==7,"quantity conserved in physical crate")
 var guest: String="fixture-recipient"
 world.crew.members[guest]=world.crew.members[actor].duplicate(true);world.business.bags[guest]=FrontierExpeditionBusiness.inventory()
 check(Drops.apply(world,guest,"equipment_pickup",{"crate_id":id}).is_empty() and world.business.bags[guest].iron==7,"another member can recover stack")
 check(not Drops.apply(world,actor,"equipment_pickup",{"crate_id":id}).is_empty(),"duplicate pickup rejected")
 before=FrontierUniverse.fingerprint(world)
 check(not Drops.apply(world,actor,"equipment_drop",{"resource":"iron","amount":-3}).is_empty() and FrontierUniverse.fingerprint(world)==before,"invalid count leaves state unchanged")
 var member: Dictionary=world.crew.members[actor]
 var item: String=member.loadout.items.keys()[0]
 var definition: String=member.loadout.items[item]
 check(Drops.apply(world,actor,"equipment_drop",{"item_id":item,"amount":1}).is_empty(),"owned equipped tool drops")
 id=world.business.crates.keys().back()
 check(Drops.valid(world.business.crates[id].equipment) and not item in member.loadout.slots,"equipment crate validates and clears slot")
 check(Drops.apply(world,guest,"equipment_pickup",{"crate_id":id}).is_empty() and definition in world.crew.members[guest].loadout.items.values(),"equipment changes ownership on pickup")
 member.loadout.items["fixture:gun"]="pulse_1"
 if not member.loadout.has("weapon_rolls"):member.loadout.weapon_rolls={}
 member.loadout.weapon_rolls["fixture:gun"]=FrontierWeaponLoot.roll("pulse_1","rare",91731,"kinetic")
 var gun:=FrontierFirearms.item(member,"fixture:gun")
 var ammo:=FrontierFirearms.ensure(member,gun);ammo.ammo=3
 var roll: Dictionary=member.loadout.weapon_rolls["fixture:gun"].duplicate(true)
 check(Drops.apply(world,actor,"equipment_drop",{"item_id":"fixture:gun","amount":1}).is_empty(),"weapon can be dropped")
 id=world.business.crates.keys().back()
 check(Drops.valid(world.business.crates[id].equipment),"weapon crate validates rolled stats and ammunition")
 check(Drops.apply(world,guest,"equipment_pickup",{"crate_id":id}).is_empty(),"another member picks up weapon")
 var recipient: Dictionary=world.crew.members[guest].loadout
 var acquired: String="crafted:"+str(int(recipient.counter))
 check(recipient.weapon_rolls[acquired]==roll and int(recipient.weapon_states[acquired].ammo)==3,"weapon rolls and loaded ammo survive ownership transfer")
 world.crew.members.erase(guest);world.business.bags.erase(guest)
 var site:=FrontierExpeditionBusiness.site(world)
 site.buildings["fixture:solar"]={"type":"solar","position":member.position.duplicate(),"tier":1,"research_built":true,"enabled":true,"active":true,"production":{}}
 var stock: Dictionary=site.inventory.duplicate()
 var result:=FrontierExpeditionBusiness.apply_local(world,actor,"business_demolish",{"building_id":"fixture:solar"},{actor:true})
 print("DEMOLISH_RESULT ",result)
 check(result.is_empty() and not site.buildings.has("fixture:solar"),"demolition removes building")
 id=world.business.crates.keys().back()
 var cost: Dictionary=FrontierFacilityResearch.construction("solar").cost
 check(cost.keys().all(func(key):return world.business.crates[id].inventory.get(key)==floori(float(cost[key])*.5)) and site.inventory==stock,"half cost lands on ground, warehouse untouched")
 var error:=FrontierUniverse.validate_world(world);print("VALIDATION ",error)
 check(error.is_empty(),"drop and demolition world remains save-valid")
 print("ITEM_DROPS failures ",failures);quit(1 if failures else 0)

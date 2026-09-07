extends SceneTree
func _initialize() -> void:
	var profile:=FrontierPlayerProfile.new_character("스택 확인")
	var actor: String=profile.character_id
	var world:=FrontierUniverse.new_world(71491)
	world.crew=FrontierCrewWorld.create(profile)
	world.business=FrontierExpeditionBusiness.create()
	var member: Dictionary=world.crew.members[actor]
	member.loadout=FrontierEquipment.create(profile)
	world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	var bag: Dictionary=world.business.bags[actor]
	bag.iron=4699
	assert(FrontierItemInventory.used(bag,1)==48)
	assert(FrontierItemInventory.room(world,actor,"iron")==1)
	assert(FrontierItemInventory.room(world,actor,"copper")==0)
	assert(FrontierItemInventory.fits(world,actor,{"iron":1}))
	assert(not FrontierItemInventory.fits(world,actor,{"iron":2}))
	assert(not FrontierItemInventory.fits(world,actor,{"copper":1}))
	bag.iron=0;member.carried=9
	FrontierItemInventory.merge_legacy(world,actor);FrontierItemInventory.merge_legacy(world,actor)
	assert(bag.stone==9 and member.carried==0)
	member.area="cabin";member.position=FrontierCrewWorld.config().locker_position.duplicate()
	var before:=int(world.crew.rock)
	assert(FrontierItemInventory.ship_transfer(world,actor,"deposit",{"amount":9}).is_empty())
	assert(bag.stone==0 and world.crew.rock==before+9)
	assert(FrontierItemInventory.ship_transfer(world,actor,"withdraw",{"amount":9}).is_empty())
	assert(bag.stone==9 and world.crew.rock==before)
	assert(not FrontierItemInventory.ship_transfer(world,actor,"deposit",{"amount":10}).is_empty())
	assert(bag.stone==9)
	print("ITEM_STACKS PASS: shared capacity, partial stack, overflow rejection, legacy idempotence, ship transfer conservation")
	quit()

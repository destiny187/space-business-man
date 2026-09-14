extends "res://tests/check_ground_combat.gd"
func run() -> void:
	var owner:=fixture()
	if owner.is_empty():quit(1);return
	var member: Dictionary=core.world.crew.members[actor_id]
	var data: Dictionary=member.loadout;data.weapon_rolls={}
	for index in 5:
		var rarity: String=FrontierWeaponLoot.config().rarities[index]
		var record:=FrontierWeaponLoot.roll("pulse_2",rarity,123+index,"thermal")
		check(record.affixes.size()==int(FrontierWeaponLoot.config().option_counts[index]) and FrontierWeaponLoot.valid(record,FrontierEquipment.config().items.pulse_2),"five independent valid rarity profiles "+rarity)
		check(record==FrontierWeaponLoot.roll("pulse_2",rarity,123+index,"thermal"),"immutable seeded roll "+rarity)
	var id: String="fixture:pulse_2"
	data.weapon_rolls[id]={"rarity":"legendary"}
	var old:=FrontierFirearms.item(member,id)
	check(is_equal_approx(float(old.damage),roundf(float(FrontierEquipment.config().items.pulse_2.damage)*1.16)) and old.legendary_id=="","old legendary keeps fixed strength without invented affixes")
	var record:=FrontierWeaponLoot.roll("pulse_2","epic",87,"cryo")
	record.affixes=[{"id":"magazine","value":.2},{"id":"reload","value":.15},{"id":"recoil","value":.15}]
	data.weapon_rolls[id]=record
	var tool:=FrontierFirearms.item(member,id);var state:=FrontierFirearms.ensure(member,tool)
	check(int(tool.magazine)==29,"rolled magazine changes actual capacity")
	state.ammo=29;state.reload_rounds=0
	check(FrontierFirearms.validate(data).is_empty(),"expanded magazine passes saved capacity validation")
	var invalid:=record.duplicate(true);invalid.affixes[1]={"id":"magazine","value":.15}
	check(not FrontierWeaponLoot.valid(invalid,FrontierEquipment.config().items.pulse_2),"duplicate affix group rejected")
	var hit: Dictionary={"kind":"robot","id":robot_key,"point":FrontierCrewWorld.vector(source.position)+Vector3.UP,"weak":false,"zone":"body"}
	var electric:=tool.duplicate();electric.element_id="shock";electric.shield_multiplier=1.
	var split:=FrontierWeaponElements.split(hit,electric,25.,40.)
	check(is_equal_approx(split.absorbed,25.) and is_equal_approx(split.health,18.),"electric overflow only applies shield bonus to absorbed budget")
	var row: Dictionary=core.world.incidents.records[robot_key];row.hp=500.;row.shield=0.;row.claimed=false
	tool.element_id="thermal";tool.legendary_id="";tool.shot_key="1"
	for i in 10:FrontierFirearms._damage(core.world,actor_id,hit,1.,tool,false)
	check(FrontierWeaponElements.own_effect(core.world,actor_id,hit,"thermal").get("left",0)>0,"thermal buildup creates a timed burn")
	var before:=float(row.hp)
	var ticks:=FrontierWeaponElements.tick(core.world,1.,[actor_id])
	check(float(row.hp)<before and ticks.events.size()==1,"host burn deals attributed damage and emits contact result")
	tool.element_id="cryo"
	for i in 10:FrontierFirearms._damage(core.world,actor_id,hit,1.,tool,false)
	check(FrontierWeaponElements.slow(core.world.crew,"robot:"+robot_key)<1.,"cold buildup slows target without changing base speed")
	FrontierWeaponElements.tick(core.world,5.,[actor_id])
	check(is_equal_approx(FrontierWeaponElements.slow(core.world.crew,"robot:"+robot_key),1.),"cold expires back to normal speed")
	check(FrontierWeaponElements.valid(core.world.crew),"element status snapshot is valid")
	# Exercise ordinary acquisition through the transaction dispatcher, not a UI-only roll.
	var stock:=FrontierExpeditionBusiness.bag(core.world,actor_id)
	stock.copper=100;stock.crystal=100;stock.iron=100
	for resource in FrontierEquipment.config().items.pulse_1.cost:stock[resource]=100
	var craft:=command("equipment_craft",{"definition":"pulse_1","element_id":"shock"})
	check(craft.get("ok",false),"element-selected craft commits through host: "+str(craft))
	member=core.world.crew.members[actor_id];data=member.loadout
	var fresh: String="crafted:"+str(int(data.counter))
	var new_gun:=FrontierFirearms.item(member,fresh)
	check(new_gun.get("element_id")=="shock" and new_gun.get("roll_version")==2,"crafted instance stores chosen element")
	check(int(data.weapon_states.get(fresh,{}).get("ammo",-1))==0,"new finite-ammo weapon does not manufacture a loaded magazine")
	var lock_result:=command("equipment_weapon_lock",{"item_id":fresh,"locked":true})
	check(lock_result.get("ok",false),"host-owned favorite lock")
	check(not command("equipment_weapon_salvage",{"item_id":fresh}).get("ok",false),"locked weapon cannot be dismantled")
	command("equipment_weapon_lock",{"item_id":fresh,"locked":false})
	var saved_revision: int=core.world.crew.revision
	var salvage:=command("equipment_weapon_salvage",{"item_id":fresh})
	check(salvage.get("ok",false) and not core.world.crew.members[actor_id].loadout.items.has(fresh),"salvage atomically removes item")
	var repeated:=core.request(1,{"session_id":core.session_id,"sequence":serial,"revision":saved_revision,"kind":"equipment_weapon_salvage","args":{"item_id":fresh}})
	check(repeated.get("ok",false),"duplicate salvage returns existing receipt")
	print("WEAPON_LOOT_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

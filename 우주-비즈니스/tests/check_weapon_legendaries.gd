extends "res://tests/check_ground_combat.gd"
func run() -> void:
	if fixture().is_empty():quit(1);return
	var world: Dictionary=core.world;var member: Dictionary=world.crew.members[actor_id]
	member.loadout.weapon_rolls={}
	var at:=FrontierCrewWorld.vector(source.position)+Vector3.UP*2.
	var hit: Dictionary={"kind":"robot","id":robot_key,"point":at,"weak":false,"zone":"body"}
	var second: Dictionary=world.incidents.records[robot_key].duplicate(true);second.id=str(second.id)+":test-second";second.position=FrontierExpeditionBusiness.array(at+Vector3(2.,0,0)-Vector3.UP)
	var second_id:=FrontierExplorationIncidents.key(second);world.incidents.records[second_id]=second
	var rows: Array=[{"kind":"robot","id":second_id,"transform":Transform3D(Basis.IDENTITY,at+Vector3(2.,0,0)),"bounds":AABB(Vector3.ONE*-.3,Vector3.ONE*.6),"weak":false,"zone":"body"}]
	var clear:=func(_actor,_origin,_direction,reach):return reach
	var mapping: Dictionary={"ember":"pulse_2","shatter":"shotgun_2","arc":"smg_2","pierce":"sniper_3"}
	for legend in mapping:
		var definition: String=mapping[legend];var id: String="fixture:"+definition
		member.loadout.weapon_rolls[id]=FrontierWeaponLoot.roll(definition,"legendary",917,"",legend)
		var tool:=FrontierFirearms.item(member,id);var state:=FrontierFirearms.ensure(member,tool);state.legend_wait=0.
		tool.shot_origin=FrontierExpeditionBusiness.array(at+Vector3(0,0,8));tool.shot_key="1"
		var robot: Dictionary=world.incidents.records[robot_key];robot.hp=250.;robot.shield=0.;second.hp=250.;second.shield=0.
		world.crew.weapon_statuses={};hit.weak=false
		var outcome: Dictionary={}
		if legend in ["ember","shatter"]:
			var record:=FrontierWeaponElements._record(world,hit)
			record.effects[actor_id+":"+str(tool.element_id)]={"owner":actor_id,"element":tool.element_id,"buildup":0.,"left":3.,"power":10. if legend=="ember" else .1,"idle":0.,"family":tool.firearm,"item_id":id}
		if legend=="ember":robot.hp=1.;outcome=FrontierFirearms._damage(world,actor_id,hit,2.,tool,false)
		elif legend=="shatter":
			for i in 4:outcome=FrontierFirearms._damage(world,actor_id,hit,1.,tool,false)
		elif legend=="arc":
			for i in 3:
				tool.shot_key=str(i);outcome=FrontierFirearms._damage(world,actor_id,hit,1.,tool,false)
		else:
			hit.weak=true;outcome=FrontierFirearms._damage(world,actor_id,hit,1.,tool,true)
		check(outcome.get("special",false),"real damage reaches legendary trigger "+legend)
		var extra:=FrontierWeaponElements.followup(world,actor_id,tool,hit,outcome,rows,Vector3.RIGHT,clear)
		check(extra.size()==1 and state.legend_wait>0.,"bounded followup executes "+legend)
		if legend=="ember":check(FrontierWeaponElements.own_effect(world,actor_id,{"kind":"robot","id":second_id},"thermal").get("propagated",false),"transferred burn cannot propagate again")
		elif legend=="shatter":check(FrontierWeaponElements.own_effect(world,actor_id,hit,"cryo").left==0.,"shatter consumes own cold status")
		else:check(second.hp<250.,"secondary target loses actual HP "+legend)
	# New event generation freezes the complete reward, including absence of a gun.
	var record:=FrontierExplorationIncidents.create(source,int(world.manifest.seed))
	var first:=FrontierFirearms.loot(int(world.manifest.seed),record)
	check(record.has("gun_reward_v2") and first==FrontierFirearms.loot(int(world.manifest.seed)+1,record),"recorded drop ignores later seed/config reroll")
	print("WEAPON_LEGENDARY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

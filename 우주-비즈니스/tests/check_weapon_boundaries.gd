extends "res://tests/check_ground_combat.gd"
func run() -> void:
	if fixture().is_empty():quit(1);return
	var world: Dictionary=core.world;var member: Dictionary=world.crew.members[actor_id]
	var id: String="fixture:pulse_2"
	member.loadout.weapon_rolls={id:FrontierWeaponLoot.roll("pulse_2","epic",92,"cryo")}
	var draft:=preload("res://scripts/persistence/world_draft.gd").request(world,actor_id,"equipment_weapon_lock")
	check(is_same(draft.terrain_edits,world.terrain_edits) and is_same(draft.incidents,world.incidents),"weapon lock shares unrelated read-only world branches")
	check(not is_same(draft.crew.members[actor_id],member) and not is_same(draft.business.bags[actor_id],world.business.bags[actor_id]),"weapon transaction copies only affected member and bag")
	FrontierWeaponLoot.manage(draft,actor_id,"equipment_weapon_lock",{"item_id":id,"locked":true})
	check(not member.loadout.weapon_rolls[id].locked,"uncommitted lock leaves source untouched")
	var row: Dictionary=world.incidents.records[robot_key]
	var frozen:=FrontierWeaponLoot.roll("smg_2","legendary",22,"","arc");frozen.definition="smg_2"
	row.gun_reward_v2=frozen;row.gun_pool_version=3;row.gun_claimed=false
	world.business.bags[actor_id]={"iron":999999}
	var items: Dictionary=member.loadout.items.duplicate()
	check(not FrontierFirearms.drop(world,actor_id,row).is_empty() and member.loadout.items==items and not row.gun_claimed,"full bag rejects pickup without consuming reward")
	check(FrontierFirearms.loot(0,row)==frozen,"full-bag retry preserves original options")
	check(FrontierExplorationIncidents.validate(world).is_empty(),"frozen reward passes incident save validation")
	row.gun_reward_v2.affixes[0].value=9.
	check(not FrontierExplorationIncidents.validate(world).is_empty(),"invalid frozen option is rejected on load")
	row.gun_reward_v2=frozen.duplicate(true);row.gun_reward_v2.affixes=FrontierWeaponLoot.roll("smg_2","legendary",22,"","arc").affixes
	var at:=FrontierCrewWorld.vector(row.position)+Vector3.UP
	var hit: Dictionary={"kind":"robot","id":robot_key,"point":at,"weak":false,"zone":"body"}
	var status:=FrontierWeaponElements._record(world,hit)
	status.effects[actor_id+":thermal"]={"owner":actor_id,"element":"thermal","left":3.,"power":10.,"buildup":0.,"idle":0.,"family":"carbine","item_id":id}
	FrontierWeaponElements.tick(world,5.,[])
	check(status.effects[actor_id+":thermal"].left==3.,"no active player means no offline burn or expiry")
	member.loadout.weapon_rolls[id]=FrontierWeaponLoot.roll("pulse_2","legendary",17,"","ember")
	var gun:=FrontierFirearms.item(member,id);FrontierFirearms.ensure(member,gun)
	var second: Dictionary=row.duplicate(true);second.id+="blocked";second.hp=100.;var target_id:=FrontierExplorationIncidents.key(second);world.incidents.records[target_id]=second
	var targets: Array=[{"kind":"robot","id":target_id,"transform":Transform3D(Basis.IDENTITY,at+Vector3.RIGHT*2),"bounds":AABB(Vector3.ONE*-.1,Vector3.ONE*.2)}]
	var blocked:=FrontierWeaponElements.followup(world,actor_id,gun,hit,{"special":true},targets,Vector3.RIGHT,func(_actor,_start,_direction,_length):return 0.)
	check(blocked.is_empty(),"solid obstacle blocks legendary propagation")
	print("WEAPON_BOUNDARY_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

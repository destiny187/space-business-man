extends "res://tests/check_ground_combat.gd"
func run() -> void:
	if fixture().is_empty():quit(1);return
	var member: Dictionary=core.world.crew.members[actor_id];var id: String="fixture:pulse_2"
	var record:=FrontierWeaponLoot.roll("pulse_2","standard",743,"kinetic")
	var low:=FrontierWeaponLoot.damage_profile(25.,.8);var high:=FrontierWeaponLoot.damage_profile(25.,1.2)
	check(low.min==16. and low.max==24. and high.min==24. and high.max==36.,"quality endpoints are exactly minus and plus twenty percent")
	check(record==FrontierWeaponLoot.roll("pulse_2","standard",743,"kinetic") and record.damage_profile!=FrontierWeaponLoot.roll("pulse_2","standard",744,"kinetic").damage_profile,"item quality is frozen per seed and varies between items")
	var invalid:=record.duplicate(true);invalid.damage_profile.quality=1.201
	check(not FrontierWeaponLoot.valid(invalid,FrontierEquipment.config().items.pulse_2),"out-of-range quality rejected")
	invalid=record.duplicate(true);invalid.damage_profile.min=invalid.damage_profile.max+1.
	check(not FrontierWeaponLoot.valid(invalid,FrontierEquipment.config().items.pulse_2),"inverted or mismatched saved bounds rejected")
	member.loadout.weapon_rolls={id:record}
	var tool:=FrontierFirearms.item(member,id);var limits:=FrontierWeaponLoot.damage_range(tool)
	check(is_equal_approx((limits.x+limits.y)*.5,tool.damage),"DPS uses the range mean")
	var upgraded:=tool.duplicate();upgraded.damage*=1.25
	check(FrontierWeaponLoot.damage_range(upgraded).is_equal_approx(limits*1.25),"existing personal damage bonuses scale both endpoints")
	var old:=record.duplicate(true);old.erase("damage_profile");member.loadout.weapon_rolls[id]=old
	var legacy:=FrontierFirearms.item(member,id)
	check(FrontierWeaponLoot.damage_range(legacy)==Vector2(legacy.damage,legacy.damage),"already owned version-two weapons keep fixed damage")
	member.loadout.weapon_rolls[id]=record
	var state:=FrontierFirearms.ensure(member,tool);var sampled: Array=[]
	for i in 5:sampled.append(FrontierWeaponLoot.sample_damage(core.world,actor_id,tool,state))
	check(sampled.all(func(value):return value>=limits.x and value<=limits.y) and sampled[0]!=sampled[1],"successive shots vary only inside the stored range")
	var restored: Dictionary=JSON.parse_string(JSON.stringify(state))
	check(is_equal_approx(FrontierWeaponLoot.sample_damage(core.world,actor_id,tool,state),FrontierWeaponLoot.sample_damage(core.world,actor_id,tool,restored)),"saved shot sequence resumes without reroll")
	state.damage_shots=0;state.cooldown=0.;state.ammo=20
	core.inputs[1]={"expires":10000.,"controls_enabled":true}
	var args: Dictionary={"item_id":id,"aim":aim(),"ads":true}
	var first:=command("surface_fire",args)
	check(first.get("ok",false) and core.ballistics.shots.size()==1,"host launches physical shot with random damage")
	check(core.ballistics.shots[0].tool.shot_damage==first.shot_damage and state.damage_shots==1,"physical projectile carries the one committed shot roll")
	var repeat:=core.request(1,{"session_id":core.session_id,"sequence":serial,"revision":core.world.crew.revision,"kind":"surface_fire","args":args})
	check(repeat==first and state.damage_shots==1 and state.ammo==19,"duplicate fire neither rerolls nor spends another round")
	var robot: Dictionary=core.world.incidents.records[robot_key];robot.hp=100.;robot.shield=0.
	var hit: Dictionary={"kind":"robot","id":robot_key,"point":FrontierCrewWorld.vector(robot.position),"weak":false,"zone":"body"}
	var outcome:=core.ballistics._damage(core.world,core.ballistics.shots[0],hit,1.,1.)
	check(is_equal_approx(float(outcome.damage),float(first.shot_damage)),"actual ballistic health damage consumes frozen sample")
	var before:=int(state.damage_shots)
	check(not command("surface_fire",args).get("ok",false) and state.damage_shots==before,"busy weapon does not advance damage randomness")
	# Beam quanta also use the range, with no change to heat or cell accounting.
	member.loadout.items["fixture:laser_2"]="laser_2";member.loadout.slots[2]="fixture:laser_2"
	member.loadout.weapon_rolls["fixture:laser_2"]=FrontierWeaponLoot.roll("laser_2","standard",73,"kinetic")
	var beam:=FrontierEquipment.active(member);var beam_state:=FrontierFirearms.ensure(member,beam);beam_state.ammo=20
	var beam_event:=FrontierFirearms.fire(core.world,actor_id,{"item_id":beam.item_id,"aim":aim(),"ads":true},func(_actor,_origin,_direction,reach):return reach)
	check(beam_event.get("beam",false) and beam_state.damage_shots==1 and beam_state.ammo==19 and beam_state.heat>0.,"beam applies one damage roll per paid heat-producing quantum")
	print("WEAPON_DAMAGE_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)

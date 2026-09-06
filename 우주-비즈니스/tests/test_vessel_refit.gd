extends "res://tests/test_expedition_business.gd"
func shipyard(kind: String,args: Dictionary={}) -> Dictionary:
	core.update_position(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(0,0,4))
	return command(kind,args)
func module_id(kind: String,grade: String="standard") -> String:
	for id in core.world.vessel.modules:
		var row: Dictionary=core.world.vessel.modules[id]
		if row.type==kind and row.grade==grade:return id
	return ""
func run() -> void:
	core=FrontierCrewAuthority.new();var owner:=FrontierPlayerProfile.new_character("선박 검증",0);owner_id=owner.character_id
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"create unmodified legacy-compatible vessel")
	check(FrontierVesselRefit.stats(core.world).hangar==2 and not core.world.has("vessel"),"old world starts with original capacity and no destructive migration")
	check(not command("vessel_build",{"module_type":"drive"}).ok,"cannot refit while flying")
	navigate(core,15);ready_all(core);check(command("land").ok,"land for refit")
	check(command("business_register").ok,"free shared ledger")
	check(not shipyard("vessel_build",{"module_type":"drive"}).ok,"no material grant for ship crafting")
	for resource in ["iron","copper"]:mine_resource(resource,320 if resource=="iron" else 180)
	# Completed-contract savings fixture; all fabrication ore above was physically mined.
	core.world.business.credits+=10000
	core.update_position(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(0,0,4))
	var before:=FrontierUniverse.fingerprint(core.world)
	disk_ok=false
	check(not shipyard("vessel_draw",{"module_type":"lab"}).ok and FrontierUniverse.fingerprint(core.world)==before,"failed save spends nothing and does not advance draw")
	disk_ok=true
	var guest:=FrontierPlayerProfile.new_character("승무원",1)
	check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"guest joins compatible refit rules")
	core.update_position(2,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	check(not request(core,2,"vessel_build",{"module_type":"drive"}).ok,"guest cannot spend common ship fund")
	check(core.disconnect_member(2),"guest leaves cleanly")
	for kind in ["drive","lab","cargo"]:check(shipyard("vessel_build",{"module_type":kind}).ok,"craft "+kind)
	var drive:=module_id("drive");var lab:=module_id("lab");var cargo:=module_id("cargo")
	check(not drive.is_empty() and not lab.is_empty() and not cargo.is_empty(),"unique owned module IDs")
	if failures:quit(1);return
	before=FrontierUniverse.fingerprint(core.world)
	check(not shipyard("vessel_build",{"module_type":"drive"}).ok and FrontierUniverse.fingerprint(core.world)==before,"duplicate craft does not consume funds")
	ready_all(core);check(shipyard("vessel_equip",{"module_id":drive}).ok and not core.world.crew.members[owner_id].ready,"refit invalidates departure readiness")
	check(shipyard("vessel_equip",{"module_id":lab}).ok,"equip lab alongside propulsion")
	var stats:=FrontierVesselRefit.stats(core.world)
	check(is_equal_approx(stats.speed,1.1) and is_equal_approx(stats.research_speed,1.15) and stats.hangar==2,"equipped ship has actual propulsion and research stats")
	var fast:=core.world.duplicate(true);var normal:=core.world.duplicate(true);normal.erase("vessel")
	for w in [fast,normal]:
		w.crew.navigation.mode="approach";w.crew.navigation.position=[0,0,1000];w.crew.navigation.speed=0;FrontierCrewNavigation.step(w,.1)
	check(fast.crew.navigation.speed>normal.crew.navigation.speed,"navigation accelerates faster on same route")
	check(shipyard("vessel_equip",{"module_id":cargo}).ok,"utility choice replaces lab")
	check(FrontierVesselRefit.stats(core.world).research_speed==1.0 and FrontierVesselRefit.stats(core.world).hangar==3,"replacing lab removes research bonus and expands robot capacity")
	check(not shipyard("vessel_salvage",{"module_id":cargo}).ok,"installed module cannot be destroyed")
	for i in 6:
		core.advance_time(core.now+1)
		var receipt:=envelope(core,1,"vessel_draw",{"module_type":"cargo"})
		var result:=core.request(1,receipt)
		check(result.ok,"paid draw "+str(i+1)+": "+str(result.get("error","")))
		var after:=FrontierUniverse.fingerprint(core.world)
		check(core.request(1,receipt).ok and FrontierUniverse.fingerprint(core.world)==after,"duplicate network draw receipt is idempotent")
	check(core.world.vessel.draws==6 and core.world.vessel.last_draw.guaranteed and core.world.vessel.last_draw.type=="cargo" and core.world.vessel.last_draw.grade=="improved","sixth draw guarantees selected improved module")
	check(core.world.vessel.parts>=8,"duplicate results become development parts")
	check(shipyard("vessel_upgrade",{"module_id":drive}).ok,"develop standard drive using duplicate parts")
	check(is_equal_approx(FrontierVesselRefit.stats(core.world).speed,1.2),"equipped upgrade updates propulsion")
	check(not shipyard("vessel_upgrade",{"module_id":drive}).ok,"rare development requires certified biological research")
	var saved_vessel: Dictionary=core.world.vessel.duplicate(true)
	var reloaded:=FrontierCrewAuthority.new()
	check(reloaded.start(JSON.parse_string(JSON.stringify(core.world)),owner,persist),"save and reload equipped ship")
	check(FrontierUniverse.fingerprint(reloaded.world.vessel)==FrontierUniverse.fingerprint(saved_vessel),"reload preserves draws parts loadout and IDs")
	var invalid:=core.world.duplicate(true);invalid.vessel.loadout.utility=drive
	check(not FrontierUniverse.validate_world(invalid).is_empty(),"save rejects module in wrong slot")
	invalid=core.world.duplicate(true);invalid.business="broken"
	check(not FrontierUniverse.validate_world(invalid).is_empty(),"malformed business fails before load calculation")
	invalid=core.world.duplicate(true);invalid.vessel.modules[drive].grade="mythic"
	check(not FrontierUniverse.validate_world(invalid).is_empty(),"unknown grade rejected")
	# Constraint fixtures isolate capacity and power without inventing production robots.
	var limits:=core.world.duplicate(true)
	limits.business.hangar={"a":{},"b":{},"c":{}}
	limits.vessel.loadout.utility=""
	check(not FrontierVesselRefit.constraints(limits).is_empty(),"cannot remove capacity under carried robots")
	limits.business.hangar={};limits.vessel.modules[drive].grade="rare";limits.vessel.modules[lab].grade="rare";limits.vessel.loadout.utility=lab
	check(not FrontierVesselRefit.constraints(limits).is_empty(),"two highest power modules exceed reactor")
	limits.vessel.loadout.utility=cargo;limits.vessel.modules[cargo].grade="rare";limits.business.hangar={"a":{},"b":{},"c":{},"d":{}}
	check(not FrontierVesselRefit.constraints(limits).is_empty(),"heavy propulsion plus loaded pod exceed maximum mass")
	# Three returned robot fixtures exercise the real authority transfer path.
	core.world.business.technologies=FrontierExpeditionBusiness.config().technologies.duplicate()
	var current:=FrontierExpeditionBusiness.site(core.world)
	core.update_position(1,FrontierExpeditionBusiness.point(current.center))
	for i in 3:
		var rid:=FrontierExpeditionBusiness.identifier(core.world.business,"robot")
		current.robots[rid]={"id":rid,"grade":FrontierCatalog.table("grades").keys()[0],"position":current.center.duplicate(),"battery":100.0,"cargo":FrontierExpeditionBusiness.inventory(),"phase":"idle","target":"","status":"회수 대기","charging":false,"work":0.0,"path":[]}
	var ids: Array=current.robots.keys()
	check(command("business_robot_recover",{"robot_id":ids[0]}).ok and command("business_robot_recover",{"robot_id":ids[1]}).ok,"two returned robots fit base hold")
	check(shipyard("vessel_unequip",{"slot":"utility"}).ok,"unload pod with only two robots aboard")
	core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
	before=FrontierUniverse.fingerprint(core.world)
	check(not command("business_robot_recover",{"robot_id":ids[2]}).ok and FrontierUniverse.fingerprint(core.world)==before,"third robot recovery denied without capacity and retains ownership")
	check(shipyard("vessel_equip",{"module_id":cargo}).ok,"reinstall three-slot pod")
	core.update_position(1,FrontierExpeditionBusiness.point(FrontierExpeditionBusiness.site(core.world).center))
	check(command("business_robot_recover",{"robot_id":ids[2]}).ok and core.world.business.hangar.size()==3,"third robot transfers into expanded hangar")
	core.update_position(1,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)+Vector3(0,0,4))
	before=FrontierUniverse.fingerprint(core.world)
	check(not shipyard("vessel_unequip",{"slot":"utility"}).ok and FrontierUniverse.fingerprint(core.world)==before,"loaded pod removal is an atomic refusal")
	check(FrontierUniverse.validate_world(core.world).is_empty(),"expanded loaded hangar persists")
	var without_pod:=core.world.duplicate(true);without_pod.erase("vessel")
	check(not FrontierUniverse.validate_world(without_pod).is_empty(),"legacy base ship cannot save three robots")
	var forged: Dictionary=core.world.vessel.duplicate(true);forged.last_draw.guaranteed=false
	check(not FrontierVesselRefit.validate(forged,int(core.world.manifest.seed),core.world.crew.world_id).is_empty(),"forged guarantee result rejected")
	check(core.close(),"close persistent vessel world")
	print("VESSEL_REFIT_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

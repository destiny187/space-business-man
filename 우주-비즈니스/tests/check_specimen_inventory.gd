extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("표본 수납 확인",0)
	var actor: String=owner.character_id
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"start unified inventory")
	check(request(core,1,"start_game").ok,"start play")
	core.research_station_provider=func(_actor: String,_station: String):return {"enabled":true,"area":"surface","body_id":core.world.crew.get("landing",{}).get("body_id",""),"position":Vector3(0,2,0)}
	navigate(core,source_ordinal(core.world.manifest));ready_all(core)
	var landed:=request(core,1,"land")
	check(landed.ok,"land specimen origin")
	if not landed.ok:printerr(landed);quit(1);return
	var encounter:=find_sample(core,1)
	if encounter.is_empty():check(false,"find native sample");quit(1);return
	FrontierEcology.scan(core.world.ecology,core.world.location,encounter)
	var args: Dictionary={"encounter_id":encounter.id,"aim":[encounter.aim.x,encounter.aim.y,encounter.aim.z]}
	var original:=envelope(core,1,"surface_collect",args)
	var result:=core.request(1,original)
	check(result.ok,"host collects sample into normal bag")
	if not result.ok:printerr(result);quit(1);return
	var sample: Dictionary=core.world.ecology.specimens.values()[0]
	var key:=FrontierSpecimenItems.resource(sample)
	check(FrontierSpecimenItems.owns(core.world,actor,sample) and FrontierItemInventory.used({key:1})==1,"physical sample occupies one ordinary slot")
	check(core.request(1,original).ok and FrontierExpeditionBusiness.bag(core.world,actor)[key]==1,"replayed request cannot duplicate specimen")
	var old:=core.world.duplicate(true)
	old.ecology.erase("item_storage_version")
	old.business.bags[actor].erase(key)
	old.crew.cargo={"iron":1000}
	check(FrontierUniverse.validate_world(old).is_empty(),"legacy separate specimen archive validates")
	var history: Dictionary=old.ecology.specimens.duplicate(true)
	FrontierSpecimenItems.ensure(old);FrontierSpecimenItems.ensure(old)
	check(old.crew.cargo[key]==1 and old.ecology.specimens==history and FrontierItemInventory.warehouse_used(FrontierItemInventory.ship_site(old.crew))>10,"migration preserves sample and history even when ship overflows")
	check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(old))).is_empty(),"migrated save round-trip validates")
	core.update_position(1,Vector3(0,2,0))
	check(request(core,1,"deposit",{"resource":key,"amount":1}).ok and core.world.crew.cargo[key]==1 and not FrontierSpecimenItems.owns(core.world,actor,sample),"normal ship deposit moves unique sample")
	check(not request(core,1,"surface_introduce",{"station_id":"ship:research","sample_id":sample.id,"aim":[0,0,-1]}).ok,"sample in ship must be withdrawn before use")
	check(request(core,1,"withdraw",{"resource":key,"amount":1}).ok and FrontierSpecimenItems.owns(core.world,actor,sample),"normal ship withdrawal returns sample to bag")
	var invalid:=core.world.duplicate(true);invalid.crew.cargo[key]=1
	check(not FrontierUniverse.validate_world(invalid).is_empty(),"duplicate physical location rejected")
	var world: Dictionary=core.world
	world.crew.members[actor].loadout.inventory_slots=12
	var body:=FrontierUniverse.body_from_id(world.manifest,world.location)
	var candidates:=FrontierEcologyPlacement.candidates(body,world.ecology.planets[world.location],Vector3.ZERO)
	for row in candidates:
		if row.get("introduced",false) or world.ecology.planets[world.location].collected.has(row.id):continue
		FrontierEcology.scan(world.ecology,world.location,row)
		if FrontierSpecimenItems.carried(FrontierExpeditionBusiness.bag(world,actor)).size()>=6:break
		check(FrontierSpecimenItems.collect(world,actor,row).is_empty(),"additional sample uses available bag slot")
	check(FrontierSpecimenItems.carried(FrontierExpeditionBusiness.bag(world,actor)).size()==6,"six specimens share bag without former four-sample cap")
	var packet:=FrontierCrewSurfaceReplica.packet(world,actor)
	check(FrontierCrewSurfaceReplica.validate(packet,world.manifest) and packet.ecology.specimens.size()==6,"own specimen snapshot accepts unified capacity")
	var kept:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
	world.business.bags[actor]={"stone":1200}
	var count: int=world.ecology.specimens.size()
	for row in candidates:
		if world.ecology.planets[world.location].collected.has(row.id):continue
		var denied:=FrontierSpecimenItems.collect(world,actor,row)
		check(denied.contains("가득") and world.ecology.specimens.size()==count,"full bag rejects collection without consuming native encounter")
		break
	world.business.bags[actor]=kept
	check(persist(world),"save six ordinary specimen items")
	# Keep the original sample for the actual introduction transaction.
	navigate_after_board(core)
	core.update_position(1,Vector3(0,2,0))
	check(request(core,1,"surface_analyze",{"station_id":"ship:research","form_id":sample.form_id}).ok,"shared research preserved")
	check(request(core,1,"surface_restore",{"station_id":"ship:research","environment":"basalt"}).ok,"prepare target habitat")
	var introduced:=request(core,1,"surface_introduce",{"station_id":"ship:research","sample_id":sample.id,"aim":[0,0,-1]})
	check(introduced.ok,"host introduces own bag specimen")
	if not introduced.ok:printerr(introduced)
	check(core.world.ecology.specimens[sample.id].state=="introduced" and not FrontierSpecimenItems.owns(core.world,actor,sample),"introduction consumes item and preserves provenance archive")
	check(core.disconnect_member(1,false) and FrontierUniverse.validate_world(core.world).is_empty(),"disconnect safely retains remaining samples in ordinary recovery cargo")
	core.research_station_provider=Callable()
	print("SPECIMEN_INVENTORY ",checks," FAILURES ",failures);quit(1 if failures else 0)
func navigate_after_board(core: FrontierCrewAuthority) -> void:
	core.update_position(1,Vector3(0,2,0));ready_all(core)
	check(request(core,1,"surface_board").ok,"board with specimens")
	navigate(core,source_ordinal(core.world.manifest,FrontierUniverse.ordinal_of(core.world.manifest,core.world.location)+1));ready_all(core);check(request(core,1,"land").ok,"land specimen destination")

func source_ordinal(manifest: Dictionary,start: int=8) -> int:
	for ordinal in range(start,200):
		var body:=FrontierUniverse.body(manifest,ordinal)
		if body.get("landable",true) and body.kind=="basalt" and FrontierEcology.profile(body).origin!="sterile":return ordinal
	return -1
func navigate(core: FrontierCrewAuthority,ordinal: int) -> void:
	# Place the ship in orbit; flight timing is outside this inventory check.
	var body:=FrontierUniverse.body(core.world.manifest,ordinal)
	var nav: Dictionary=core.world.crew.navigation
	nav.system=FrontierUniverse.system_index(core.world.manifest,ordinal);nav.target=ordinal;nav.mode="idle"
	nav.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(ordinal,core.world.manifest,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))

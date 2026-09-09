extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("Lotus 검사",0)
	var id: String=owner.character_id
	var core:=FrontierCrewAuthority.new()
	check(core.start(FrontierUniverse.new_world(71491),owner,persist),"fresh world starts: "+core.error)
	if core.world.is_empty():quit(1);return
	check(int(core.world.crew.rock)==50 and core.world.crew.cargo.size()==3 and core.world.crew.cargo.values().all(func(n):return int(n)==50),"exact four starting stacks")
	check(core.world.crew.shuttles.size()==1 and core.world.crew.shuttles[id].company and core.world.crew.shuttles[id].state=="docked","one equipped company FINCH")
	var resumed:=FrontierCrewAuthority.new()
	var previous:=core.world.duplicate(true);previous.crew.cargo.iron=3
	check(resumed.start(previous,owner,persist) and resumed.world.crew.cargo.iron==3 and resumed.world.crew.shuttles.size()==1,"resume does not grant supplies again")
	check(request(core,1,"start_game").ok,"start session")
	var destination:=FrontierCrewNavigation.first_destination(core.world.manifest)
	var planet:=FrontierUniverse.body(core.world.manifest,destination)
	var world: Dictionary=core.world
	world.location=planet.id;world.navigation_target=planet.id
	world.crew.navigation.system=planet.system_ordinal;world.crew.navigation.target=destination
	world.crew.navigation.position=FrontierExpeditionBusiness.array(FrontierCrewNavigation.center(destination,world.manifest,float(world.crew.navigation.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(planet)+1))
	check(request(core,1,"ready",{"value":true}).ok,"ready")
	var result:=request(core,1,"land",{})
	check(result.ok,"land: "+str(result))
	if not result.ok:quit(1);return
	var initial_site:=FrontierExpeditionBusiness.site(core.world)
	check(not initial_site.get("base_deployed",true) and FrontierItemInventory.warehouse_capacity(initial_site)==0,"no free physical depot or warehouse slots")
	var storage_fixture: Dictionary=initial_site.duplicate(true)
	storage_fixture.buildings["storage:test"]={"type":"storage","position":[40,0,40]}
	check(FrontierItemInventory.warehouse_capacity(storage_fixture)==int(FrontierItemInventory.config().warehouse_slots) and FrontierExpeditionBusiness.near_warehouse(storage_fixture,Vector3(40,0,40)),"constructed warehouse provides access and capacity")
	var original_position: Array=core.world.crew.members[id].position.duplicate()
	core.world.crew.members[id].position=[500,0,500]
	check(not request(core,1,"lotus_request",{"resource":"iron"}).ok and core.world.lotus.free_remaining==3,"remote call rejected without charging")
	core.world.crew.members[id].position=original_position
	core.world.business.sites.clear()
	check(FrontierExpeditionBusiness.site(core.world).is_empty(),"fixture without a registered business site")
	core.lotus_clearance_provider=func(_body: String,_p: Vector3,_r: float):return false
	check(not request(core,1,"lotus_request",{"resource":"iron"}).ok and core.world.lotus.free_remaining==3,"blocked terrain rejects without charging")
	core.lotus_clearance_provider=Callable()
	var before:=FrontierUniverse.fingerprint(core.world)
	disk_ok=false
	check(not request(core,1,"lotus_request",{"resource":"iron"}).ok and FrontierUniverse.fingerprint(core.world)==before,"failed request save rolls back shipment and fee")
	disk_ok=true
	var packet:=envelope(core,1,"lotus_request",{"resource":"iron"})
	result=core.request(1,packet)
	check(result.ok,"request iron: "+str(result))
	if not result.ok:quit(1);return
	check(core.request(1,packet).ok and core.world.lotus.crates.size()==1 and core.world.lotus.free_remaining==2,"idempotent support request")
	check(not request(core,1,"lotus_request",{"resource":"ice"}).ok,"shared launch cooldown")
	var crate: Dictionary=core.world.lotus.crates.values()[0]
	check(not request(core,1,"lotus_collect",{"crate_id":crate.id}).ok,"no receipt before touchdown")
	check(FrontierLotusSupport.blocks(core.world,planet.id,FrontierCrewWorld.vector(crate.position),2),"construction reserves drop zone")
	var landing: Dictionary=core.world.crew.landing.duplicate(true)
	core.world.crew.landing={};core.world.crew.members[id].area="cabin";core.world.crew.members[id].aboard=true
	for i in 41:core.step_surface(1)
	crate=core.world.lotus.crates.values()[0]
	check(crate.landed and crate.elapsed==FrontierLotusSupport.duration(),"unoccupied planet receives durable crate without site")
	var restored:=FrontierCrewAuthority.new()
	check(restored.start(saved,owner,persist) and restored.world.lotus.crates[crate.id].landed,"arrived crate survives save reload")
	core.world.crew.landing=landing;core.world.crew.members[id].area="surface";core.world.crew.members[id].aboard=false
	var p:=FrontierCrewWorld.vector(crate.position)
	core.world.crew.members[id].position=FrontierExpeditionBusiness.array(p+Vector3(0,0,2))
	result=request(core,1,"lotus_collect",{"crate_id":crate.id})
	check(result.ok and FrontierExpeditionBusiness.bag(core.world,id).iron==50,"physical crate receipt: "+str(result))
	check(not request(core,1,"lotus_collect",{"crate_id":crate.id}).ok,"empty crate cannot pay twice")
	for i in 55:core.step_surface(1)
	check(core.world.lotus.crates.is_empty(),"empty crate removed after opening grace")
	var guest:=FrontierPlayerProfile.new_character("공용 운송 담당",1)
	var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok,"guest joins")
	core.world.crew.members[guest.character_id].position=FrontierExpeditionBusiness.array(FrontierShuttles.pad(core.world,id))
	result=request(core,2,"shuttle_board",{})
	check(result.ok and core.world.crew.shuttles.size()==1 and FrontierShuttles.aboard(core.world,guest.character_id),"guest flies single company craft: "+str(result))
	check(FrontierGroundProgression.absent_starter(planet) not in FrontierExpeditionBusiness.starter_veins(planet).map(func(row):return row.resource),"naturally absent starter material not injected")
	var dir: String="/tmp/lotus-domain";DirAccess.make_dir_recursive_absolute(dir)
	var store:=FrontierWorldStore.new(dir+"/world.json")
	check(store.write(core.world),"real disk serialization: "+store.last_error)
	check(not store.read_state().is_empty(),"disk readback validates support and loan")
	print("LOTUS_SUPPORT_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)

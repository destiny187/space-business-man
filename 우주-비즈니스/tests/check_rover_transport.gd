extends "res://tests/check_rover_ground.gd"
func verify_rover() -> void:
	var a:=app.session.authority;var owner: String=a.world.crew.owner_id
	rover_id=str(FrontierRovers.local(a.world).keys()[0]);var r: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id]
	move_to(FrontierRovers.point(r,[0,0,3.5]));app.close_menus()
	var stock:=FrontierExpeditionBusiness.bag(a.world,owner)
	for key in FrontierRovers.config().upgrade.cost:stock[key]=FrontierRovers.config().upgrade.cost[key]
	check(request("rover_upgrade",{"id":rover_id}).ok,"Mk2 begins with own held components")
	check(not request("rover_enter",{"id":rover_id,"seat":1}).ok,"maintenance reserves both seats")
	app.rovers.panel.vehicle_id=rover_id;app.open_menu(app.rovers.panel);await create_timer(1).timeout;await capture("rover-mk2-progress")
	check(await until(func():return int(FrontierRovers.fleet(a.world).vehicles[rover_id].upgrade_level)==1,25),"real 20-second upgrade completes")
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];check(FrontierRovers.stats(r).battery==150 and FrontierRovers.stats(r).health==400 and is_equal_approx(FrontierRovers.stats(r).speed,13.8),"Mk2 changes performance keeps four slots")
	app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	var site:=FrontierExpeditionBusiness.site(a.world)
	for key in FrontierRoverTransport.config().cost:site.inventory[key]=FrontierRoverTransport.config().cost[key]
	check(request("rover_transport_upgrade").ok,"base ship gains one vehicle berth without hull lottery")
	var validator:=func(p: Vector3):return app.surface_world.ready_at(p) and app.rovers.clear(p,Vector3(2.6,2.6,4.0),rover_id)
	var p:=FrontierRovers.spawn_point(a.world,FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position),rover_id,10.0,validator)
	check(p.is_finite(),"safe loading-zone fixture")
	if not p.is_finite():quit(1);return
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];r.position=FrontierExpeditionBusiness.array(p);r.rotation=[0.0,0.0,0.0];app.rovers.actors[rover_id].position=p;app.rovers.actors[rover_id].rotation=Vector3.ZERO
	move_to(p+Vector3(0,0,3.5));await create_timer(.3).timeout
	stock=FrontierExpeditionBusiness.bag(a.world,owner)
	for resource in ["iron","copper","stone"]:stock[resource]=100
	for resource in ["iron","copper","stone"]:check(request("rover_transfer",{"id":rover_id,"resource":resource}).ok,"load cargo "+resource)
	var item: String=a.world.crew.members[owner].loadout.items.keys()[0]
	check(request("rover_transfer",{"id":rover_id,"item_id":item}).ok,"owned equipment fourth slot")
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];check(is_equal_approx(FrontierRoverTransport.units(r),4.8),"four full slots fit 6 transport units")
	check(request("rover_load",{"id":rover_id}).ok,"load begins")
	check(not request("rover_transfer",{"id":rover_id,"resource":"iron","withdraw":true}).ok,"reservation forbids cargo mutation")
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];r.health-=1;await create_timer(.2).timeout
	check(not a.rover_runtime.tasks.has(rover_id) and FrontierRovers.fleet(a.world).vehicles[rover_id].location_kind=="surface","damage cancels loading and preserves ground asset")
	check(request("rover_load",{"id":rover_id}).ok,"retry load after interruption")
	check(float(a.rover_runtime.tasks[rover_id].seconds)==8,"logistics I loads in 8 seconds")
	app.test_camera_position=p+Vector3(7,5,10);app.yaw=.6;app.pitch=-.25
	await create_timer(3).timeout;await capture("rover-winch-loading")
	check(app.rovers.actors[rover_id].work.playing,"ElevenLabs winch loop plays during loading")
	check(await until(func():return FrontierRoverTransport.ship(FrontierRovers.fleet(a.world))==rover_id,8),"timed load commits single surface-to-ship location")
	var payload: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id].duplicate(true)
	var original_body: String=a.world.location
	check(not a.world.crew.get("cargo_equipment",{}).has(owner+"/"+item),"vehicle equipment not duplicated into ship warehouse")
	check(a.checkpoint() and app.world_store.read_state().rovers.vehicles[rover_id].location_kind=="ship","loaded rover survives save and reread")
	move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.test_camera_position=Vector3.ZERO
	stock=FrontierExpeditionBusiness.bag(a.world,owner)
	for key in FrontierRoverTransport.config().research_cost:stock[key]=FrontierRoverTransport.config().research_cost[key]
	check(request("rover_research2").ok,"personal logistics II research")
	app.open_menu(app.rovers.dock);await create_timer(.7).timeout;await capture("rover-ship-dock");app.close_menus()
	# A second ground asset remains at the old planet when the crew launches.
	var f:=FrontierRovers.ensure(a.world);var left: Dictionary=payload.duplicate(true);left.id="rover:2";left.location_kind="surface";left.equipment={};left.cargo=FrontierExpeditionBusiness.inventory();left.position=FrontierExpeditionBusiness.array(p+Vector3(12,0,0));f.counter=2;f.vehicles[left.id]=left
	check(request("surface_board").ok,"crew boards ship normally after vehicle loading")
	check(await until(func():return app.surface_world==null and not app.arrival.active,60),"normal takeoff carries vehicle berth")
	var world: Dictionary=a.world;var ordinal:=FrontierUniverse.ordinal_of(world.manifest,original_body)+1
	while not FrontierUniverse.landable(FrontierUniverse.body(world.manifest,ordinal)):ordinal+=1
	var body:=FrontierUniverse.body(world.manifest,ordinal);var nav: Dictionary=world.crew.navigation
	nav.system=FrontierUniverse.system_index(world.manifest,ordinal);nav.target=ordinal;nav.mode="idle";nav.speed=0.0;nav.orbit_time=0.0
	var orbit:=FrontierCrewNavigation.center(ordinal,world.manifest,0)+Vector3(0,0,FrontierUniverse.radius(body)+30);nav.position=FrontierExpeditionBusiness.array(orbit);nav.direction=[0,0,-1];world.location=body.id
	app.session._publish();await process_frame;request("ready",{"value":true});check(request("land",{"ordinal":ordinal}).ok,"selected destination landing command")
	check(await until(func():return app.surface_world!=null and not app.arrival.active,90),"next planet landing")
	app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	check(await until(func():return a.rover_runtime.get("unload_point",[]).size()==3,15),"host supplies safe unloading ghost")
	app.open_menu(app.rovers.dock);await create_timer(.5).timeout;await capture("rover-unload-preview")
	check(request("rover_unload",{"id":rover_id}).ok,"unload reserves ship vehicle")
	check(float(a.rover_runtime.tasks[rover_id].seconds)==5,"logistics II unloads in five seconds")
	check(await until(func():return FrontierRoverTransport.ship(FrontierRovers.fleet(a.world)).is_empty(),8),"same rover unloaded on next planet")
	app.close_menus();r=FrontierRovers.fleet(a.world).vehicles[rover_id]
	check(r.body_id==body.id and r.cargo==payload.cargo and r.equipment==payload.equipment and r.upgrade_level==payload.upgrade_level and r.health==payload.health,"identity cargo owner Mk2 and condition preserved across planet travel")
	check(FrontierRovers.fleet(a.world).vehicles["rover:2"].body_id==original_body,"left-behind rover retained at original planet")
	var error:=FrontierUniverse.validate_world(a.world);check(error.is_empty(),"transport world validates "+error)
	check(a.checkpoint(),"final vehicle save")
	await capture("rover-next-planet")
	print("ROVER_TRANSPORT_RESULT ",failures);await app.session.close_session();quit(1 if failures else 0)

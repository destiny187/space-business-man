extends "res://tests/check_rover_ground.gd"
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")
	if folder.is_empty() or not "--crew-ui-test" in OS.get_cmdline_user_args():quit(2);return
	root.size=Vector2i(1280,800);app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame;app.start_solo()
	if not await until(func():return app.session.active,15):quit(1);return
	app.onboarding.letter.hide();app.close_menus()
	var a:=app.session.authority;var owner: String=a.world.crew.owner_id
	rover_id=FrontierRoverTransport.ship(FrontierRovers.fleet(a.world))
	if rover_id.is_empty():check(false,"loaded vehicle fixture");quit(1);return
	var payload: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id].duplicate(true)
	var old_body: String=payload.body_id
	if not FrontierCrewSurface.landed(a.world):
		var ordinal:=int(a.world.crew.navigation.target)
		request("ready",{"value":true});var landing:=request("land",{"ordinal":ordinal});check(landing.ok,"explicit new destination landing "+str(landing))
		if not landing.ok:quit(1);return
	if not await until(func():return app.surface_world!=null and not app.arrival.active,90):check(false,"arrival scene");quit(1);return
	app.close_menus();move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position))
	if not await until(func():return a.rover_runtime.get("unload_point",[]).size()==3,20):check(false,"safe unloading point");quit(1);return
	var destination: String=a.world.location
	check(destination!=old_body,"arrived at different planet with loaded rover")
	var p:=FrontierCrewWorld.vector(a.rover_runtime.unload_point)
	app.open_menu(app.rovers.dock);await create_timer(.5).timeout;await capture("rover-unload-preview")
	check(request("rover_unload",{"id":rover_id}).ok,"five-second unload starts")
	check(float(a.rover_runtime.tasks[rover_id].seconds)==5,"logistics II duration")
	# A new obstacle after reservation must invalidate the final output, not delete cargo.
	var blocker:=StaticBody3D.new();blocker.collision_layer=1;blocker.position=p+Vector3.UP*1.5;var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(4,3,5);collision.shape=box;blocker.add_child(collision);app.add_child(blocker)
	check(await until(func():return not a.rover_runtime.tasks.has(rover_id),8),"blocked unload resolves")
	check(FrontierRoverTransport.ship(FrontierRovers.fleet(a.world))==rover_id and FrontierRovers.fleet(a.world).vehicles[rover_id].cargo==payload.cargo,"blocked output keeps same vehicle and cargo aboard")
	blocker.queue_free();await physics_frame;await create_timer(.7).timeout
	check(request("rover_unload",{"id":rover_id}).ok,"unload retry with free space")
	check(await until(func():return FrontierRoverTransport.ship(FrontierRovers.fleet(a.world)).is_empty(),8),"same rover unloaded on next planet")
	app.close_menus();var r: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id]
	check(r.body_id==destination and r.cargo==payload.cargo and r.equipment==payload.equipment and r.upgrade_level==payload.upgrade_level and r.health==payload.health and is_equal_approx(r.battery,payload.battery),"ID cargo ownership Mk2 condition and battery preserved")
	check(FrontierRovers.fleet(a.world).vehicles["rover:2"].body_id==old_body,"left-behind rover persists old planet")
	var other: String=""
	for id in a.world.crew.members:
		if id!=owner:other=id;break
	var draft:=a.world.duplicate(true)
	if not other.is_empty():
		draft.crew.members[other].position=FrontierExpeditionBusiness.array(FrontierRovers.point(r,[0,0,3.5]))
		var gear: Dictionary=r.equipment.values()[0]
		check(not FrontierRovers.transfer(draft,other,draft.rovers.vehicles[rover_id],{"item_id":gear.item_id,"withdraw":true}).is_empty(),"other crew cannot withdraw stored personal equipment")
	var error:=FrontierUniverse.validate_world(a.world);check(error.is_empty(),"transport world validates "+error)
	check(a.checkpoint(),"transport final save")
	var restored:=app.world_store.read_state();check(not restored.is_empty() and restored.rovers.vehicles[rover_id].body_id==destination,"unloaded vehicle save reload")
	var pos:=FrontierRovers.point(r);app.test_camera_position=pos+Vector3(7,4,9);app.yaw=.65;app.pitch=-.2;await create_timer(.3).timeout;await capture("rover-next-planet")
	print("ROVER_ARRIVAL_RESULT ",failures);await app.session.close_session();quit(1 if failures else 0)

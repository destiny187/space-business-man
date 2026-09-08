extends "res://tests/check_rover_ground.gd"
func verify_rover() -> void:
	var a:=app.session.authority;var owner: String=a.world.crew.owner_id
	rover_id=str(FrontierRovers.local(a.world).keys()[0]);var r: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id]
	r.overturned=false;r.rotation[2]=0
	if app.rovers.actors.has(rover_id):app.rovers.actors[rover_id].rotation.z=0
	var profile: Dictionary=a.world.crew.members[owner].profile.duplicate(true);profile.character_id=FrontierPlayerProfile.token();profile.name="동승 확인"
	app.session.set_process(false)
	var admitted:=a.admit(2,profile,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash());check(admitted.ok,"guest authority admitted")
	check(a.acknowledge(2,a.session_id).ok,"guest authority acknowledged");app.session.latest=a.snapshot(1);app.session.snapshot_received.emit(app.session.latest);await process_frame
	var guest: String=a.peers[2]
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];app.actors[owner].position=FrontierRovers.point(r,[-2.3,0,0]);a.update_position(1,app.actors[owner].position)
	a.world.crew.members[guest].position=FrontierExpeditionBusiness.array(FrontierRovers.point(r,[-2.3,0,0]))
	check(request("rover_enter",{"id":rover_id,"seat":0}).ok,"driver claim")
	check(not request("rover_enter",{"id":rover_id,"seat":0},2).ok,"same seat second claimant denied")
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];a.world.crew.members[guest].position=FrontierExpeditionBusiness.array(FrontierRovers.point(r,[2.3,0,0]))
	check(request("rover_enter",{"id":rover_id,"seat":1},2).ok,"second physical seat claim")
	a.input(2,1,[0,0],[0,0,-1],true,false,[0,0,0],0,true,[0,0,1,0]);check(a.inputs[2].scanning,"passenger scanner accepted")
	check(not request("surface_attack",{},2).ok,"passenger personal weapon blocked")
	app.rovers.chase=true;await create_timer(.3).timeout;await capture("rover-two-seats")
	check(a.disconnect_member(2,false),"passenger disconnect clears seat")
	check(FrontierRovers.seats(a.rover_runtime,rover_id)[1]=="","passenger release");app.session.set_process(true)
	request("rover_exit",{"id":rover_id});check(await until(func():return app.rovers.seat().is_empty(),3),"driver safe exit")
	# Validate collision-space fallback using an actual blocking shape on the left side.
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];var original:=FrontierRovers.point(r)
	var saved:=a.world.duplicate(true);var runtime_saved:=a.rover_runtime.duplicate(true)
	a.rover_runtime.seats[rover_id]=[owner,""];r.speed=5
	check(a.disconnect_member(1,false),"driver disconnect persists braking")
	check(float(FrontierRovers.fleet(a.world).vehicles[rover_id].speed)==0 and FrontierRovers.seats(a.rover_runtime,rover_id)[0]=="","driver disconnect zero speed and empty seat")
	a.world=saved;a.rover_runtime=runtime_saved;a.peers[1]=owner;app.session._publish()
	# Real hold input completes recovery on the terrain, preserving the asset.
	r=FrontierRovers.fleet(a.world).vehicles[rover_id];r.overturned=true;r.rotation[2]=PI*.55;app.rovers.actors[rover_id].rotation.z=PI*.55
	app.close_menus();app.arrival.cancel();app.outside=false
	move_to(original+Vector3(5,0,0));await until(func():return app._locomotion_enabled(),15);app.rovers.test_controls=[0.0,0.0,1.0,1.0]
	check(request("rover_recover",{"id":rover_id}).ok,"recovery starts outside rover")
	check(await until(func():return not FrontierRovers.fleet(a.world).vehicles[rover_id].overturned,5),"three-second hold restores supported vehicle")
	print("RECOVERY_DIAG ",a.rover_runtime," VEHICLE ",FrontierRovers.fleet(a.world).vehicles[rover_id])
	app.rovers.test_controls=[0.0,0.0,1.0,0.0]
	# Charge at the real powered pad.
	r=FrontierRovers.fleet(a.world).vehicles[rover_id]
	for b in FrontierExpeditionBusiness.site(a.world).buildings.values():
		if b.type!="charger":continue
		var p:=FrontierCrewWorld.vector(b.position)+Vector3(3.6,0,0);r.position=FrontierExpeditionBusiness.array(p);app.rovers.actors[rover_id].position=p;r.battery=10;move_to(p+Vector3(0,0,5));break
	await create_timer(1.5).timeout
	check(float(FrontierRovers.fleet(a.world).vehicles[rover_id].battery)>10,"powered charger replenishes stationary rover")
	var error:=FrontierUniverse.validate_world(a.world);check(error.is_empty(),"seat/recovery world valid "+error)
	check(a.checkpoint(),"save after recovery")
	print("ROVER_SEATS_RESULT ",failures);await app.session.close_session();quit(1 if failures else 0)

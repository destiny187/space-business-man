extends "res://tests/check_rover_ground.gd"
func verify_rover() -> void:
	var a:=app.session.authority
	rover_id=str(FrontierRovers.local(a.world).keys()[0]);var r: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id]
	move_to(FrontierRovers.point(r,[0,0,3.5]));app.close_menus();app.arrival.cancel()
	var result:=request("rover_load",{"id":rover_id});check(result.ok,"loaded renderer fixture "+str(result))
	if not result.ok:quit(1);return
	await create_timer(1).timeout
	check(app.rovers.ropes.mesh.get_surface_count()==1,"stable winch mesh presents one surface")
	check(await until(func():return FrontierRoverTransport.ship(FrontierRovers.fleet(a.world))==rover_id,8),"load finishes")
	move_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position));app.open_menu(app.rovers.dock);root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await create_timer(.7).timeout;await capture("rover-dock-small")
	check(request("rover_unload",{"id":rover_id}).ok,"unload finishes renderer fixture")
	check(await until(func():return FrontierRoverTransport.ship(FrontierRovers.fleet(a.world)).is_empty(),8),"unload completes")
	print("ROVER_RENDER_RESULT ",failures)
	await app.session.close_session();app.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)

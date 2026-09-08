extends "res://tests/check_rover_ground.gd"
func verify_rover() -> void:
	var a:=app.session.authority
	rover_id=str(FrontierRovers.local(a.world).keys()[0]);var r: Dictionary=FrontierRovers.fleet(a.world).vehicles[rover_id]
	move_to(FrontierRovers.point(r,[-2.3,0,0]));app.close_menus();app.arrival.cancel()
	check(request("rover_enter",{"id":rover_id,"seat":0}).ok,"camera seat")
	await create_timer(.3).timeout
	var node: FrontierRoverActor=app.rovers.actors[rover_id]
	app.yaw+=.4;await process_frame
	var offset:=wrapf(app.yaw-node.rotation.y,-PI,PI)
	node.rotation.y+=.3;r=FrontierRovers.fleet(a.world).vehicles[rover_id];r.rotation[1]=node.rotation.y
	await create_timer(.2).timeout
	check(absf(wrapf(app.yaw-node.rotation.y,-PI,PI)-offset)<.01,"camera follows chassis yaw while preserving free-look offset")
	request("rover_exit",{"id":rover_id});check(await until(func():return app.rovers.seat().is_empty(),4),"camera fixture safe exit")
	print("ROVER_CAMERA_RESULT ",failures);await app.session.close_session();app.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
